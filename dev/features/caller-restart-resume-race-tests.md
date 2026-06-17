---
feature: caller-restart-resume-race
---

# Test Plan: Caller (home) restart loses conversation — relaunch races the killed process

Test plan for `caller-restart-resume-race.md`. The decisive test is behavioral: restart all sessions **from home** and verify home's transcript **continues** (line count grows in the same file) rather than a new transcript being created.

## Test infrastructure

```bash
# Newest home transcript + line count
HD=~/.claude/projects/-Users-jonathan-Claude
newest() { ls -t "$HD"/*.jsonl | head -1; }
snap()   { f=$(newest); echo "$(basename "$f") = $(wc -l < "$f") lines"; }
```

A "resume" = the same transcript file grows. A "fresh" = a new `*.jsonl` file appears in `$HD` and the prior one stops growing.

## Pre-build verification (confirm the diagnosis / current behavior)

### V0.1 Reproduce the regression on current code (v2.0.4 deployed)
1. `snap` to record home's current transcript.
2. From **home** (RC or pane), say "restart all sessions".
3. After ~60-90s, `snap` again.
**Expect (bug):** a NEW transcript file is newest; the prior one stopped growing. Home greeted you with a fresh "Session ready!" and lost context. Confirmed 2026-06-16.

### V0.2 Confirm the resuming path still resumes (control)
1. `snap`.
2. From a DIFFERENT session, `claude-mux --restart home`.
3. `snap` after ~20s.
**Expect:** same file, grew. Confirmed (30->58, 136->164 this session).

### V0.3 Confirm `poll_until_ready` is reusable pre-/exit
```bash
grep -n 'poll_until_ready()' claude-mux       # ~2834
sed -n '2834,2880p' claude-mux                # returns only; does not send Ready?
```

## Happy path (post-fix)

### T1.1 Restart-all from home — home resumes (THE test)
**Setup:** several sessions running incl. home; home has a non-trivial conversation (note its transcript + line count).
**Action:** from home, "restart all sessions".
**Expect:**
- Home's **existing** transcript continues (line count grows); no new `*.jsonl` for home.
- Log shows the handoff: `Restarting caller session 'home' via background handoff`, then `Creating tmux session 'home'`, then `Session 'home' created`.
- No `Primary resume launch for 'home' failed` diagnostic.
- Home's "Session ready!" comes back **with its prior context** (ask it something only the prior convo knew).
- All other sessions also resumed (regression check).

### T1.2 Restart-all from home while home is actively mid-output
**Setup:** trigger the restart such that home is still generating its restart summary when the handoff reaches the quiescence wait.
**Expect:** `poll_until_ready` holds the handoff until home finishes its turn; `/exit` then lands cleanly; home resumes. (This is the exact failing condition pre-fix.)

### T1.3 Restart-all from a non-home caller
**Setup:** run "restart all sessions" from a project session (e.g. claude-mux), not home.
**Expect:** that caller resumes via the handoff (same fix applies to any caller); home and others resume via their normal paths.

### T1.4 Single-named `--restart home` still resumes (regression)
**Action:** `claude-mux --restart home` from another session.
**Expect:** unchanged — resumes (create_claude_session path, untouched by this fix).

## Failure / edge modes

### T2.1 Caller never goes quiescent (poll_until_ready times out)
**Setup:** wedge home so it stays busy >120s (e.g. a long-running tool call).
**Expect:** after the ~120s `poll_until_ready` timeout, the handoff proceeds to `/exit` -> 10s wait -> `kill-session` -> **ensure-gone poll + settle** -> relaunch. Worst case degrades to current behavior (possible fresh), never worse. Home still comes back up (not stranded).

### T2.2 `--restart --fresh` from home
**Action:** "restart all sessions fresh" (or `--restart --fresh`) from home.
**Expect:** home comes back **fresh by design** (FRESH_START omits `-c`). The quiescence wait still applies (clean exit) but resume is intentionally skipped. No regression.

### T2.3 Crash during the handoff window
**Setup:** kill the handoff subshell after `kill-session` but before relaunch.
**Expect:** `.claudemux-restarting` left in place + `.claudemux-running` preserved -> auto-restore tick recovers home within ~120s (v2.0.4 behavior, unaffected). Home resumes on the tick (settled, create_claude_session path).

### T2.4 Auto-restore tick during the (now longer) handoff window
**Setup:** LaunchAgent active; the quiescence wait may extend the handoff window beyond a tick.
**Expect:** the tick consumes `.claudemux-restarting` on sight and defers home for that tick (v2.0.4 consume-on-sight), so it never races the handoff's own relaunch. Verify no double-create of home.

## Side effects

### T3.1 Restart latency
**Expect:** restart-all from home takes slightly longer (handoff now waits for home's turn to finish + a short settle) — acceptable; the alternative is losing home's conversation. Non-caller sessions are unaffected (their loop is unchanged).

### T3.2 RC reconnect after the restart
**Expect:** RC drops on home's restart and reconnects after the new home sends "Ready?" — unchanged behavior; only the resume content is fixed.

## Verification commands

```bash
# Watch the handoff sequence + confirm no resume-failure diagnostic for home:
grep -E "caller session 'home'|Creating tmux session 'home'|Session 'home' created|Primary (resume|fresh) launch for 'home'" ~/Library/Logs/claude-mux.log | tail -15

# Confirm home's transcript continued instead of forking:
ls -t ~/.claude/projects/-Users-jonathan-Claude/*.jsonl | head -2
# After T1.1 the newest should be the SAME file as before, with more lines.
```

## Acceptance

- T1.1: restart-all **from home** resumes home's conversation (same transcript grows; prior context intact). This is the regression closed.
- T1.2: resumes even when home was mid-turn at handoff time.
- T1.3/T1.4: other callers and single-named restart unaffected.
- T2.x: timeout, fresh, crash, and tick-race paths degrade safely, never strand home.
