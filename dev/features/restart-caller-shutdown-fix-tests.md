---
feature: restart-caller-shutdown-fix
---

# Test Plan: Fix `--restart` (all) killing itself mid-loop

Test plan for `restart-caller-shutdown-fix.md`. Manual tests; no automated harness yet (see ISSUES.md - test suite is a planned v2.0.4+ deliverable).

## Pre-build verification (run these first to confirm the diagnosis)

### V0.1 Reproduce the bug on current code (v2.0.3)
**Setup:**
1. Have ≥6 managed sessions running, with at least one (e.g. `aaa-test`) sorting *alphabetically before* the caller and at least one (e.g. `zzz-test`) sorting *after* the caller.
2. Note which session is "home" / caller.
3. `claude-mux -l` snapshot.

**Action:** From the caller session, run "restart all sessions" (`claude-mux --restart`).

**Expect (the bug):**
- Sessions alphabetically before caller: `/exit`ed but never relaunched → idle.
- Sessions alphabetically after caller: never received `/exit` → still running.
- Caller: revived only if it has the LaunchAgent safety net (home), otherwise also stranded.
- Log shows `=== claude-mux restart starting ===` and `Remembering N running session(s)` but no `=== claude-mux restart complete ===` line.

**Status:** confirmed on 2026-06-16 from home; 10 remembered, only 7 `/exit`s logged, no complete line.

### V0.2 Confirm `shutdown_single_session` accepts `force=true`
```bash
grep -n 'local force=' claude-mux  # expect line ~1720
```

### V0.3 Confirm `shutdown_claude_sessions` (no-arg path) walks every session
```bash
sed -n '1775,1805p' claude-mux  # expect list-sessions loop with no caller exclusion
```

## Happy path (post-fix)

### T1.1 Restart-all from a non-caller-named session — caller mid-alphabet
**Setup:** 5 managed sessions: `aaa`, `bbb`, `home` (caller), `xxx`, `yyy`. All running Claude.

**Action:** `claude-mux --restart` from `home`.

**Expect:**
- All 5 sessions exit cleanly and recreate.
- `aaa`, `bbb`, `xxx`, `yyy` recreate in the foreground loop, interleaved (`shutdown_single_session` then `create_claude_session` per session).
- `home` recreates last via the background handoff.
- Log shows `=== claude-mux restart complete ===`.
- `claude-mux -l` after restart: all 5 running.
- Each session's `.claudemux-running` marker present at the end.

### T1.2 Restart-all when caller sorts first alphabetically
**Setup:** 4 sessions: `aaa-caller` (caller), `mmm`, `xxx`, `yyy`.

**Action:** `claude-mux --restart` from `aaa-caller`.

**Expect:** All 4 recreate (this was the worst case for the bug - caller exited first, killing the script before any others). With fix: caller is partitioned out, so it doesn't get exited until the background handoff after all others restart.

### T1.3 Restart-all when caller sorts last alphabetically
**Setup:** 4 sessions: `aaa`, `mmm`, `xxx`, `zzz-caller` (caller).

**Action:** `claude-mux --restart` from `zzz-caller`.

**Expect:** All 4 recreate. This was the case where the original bug looked least-broken (caller-exit happened after all non-callers were exited, but relaunch loop still never ran). With fix: each non-caller is exited+relaunched in turn, then caller restarts via handoff.

### T1.4 Restart-all with no caller (run from outside tmux)
**Setup:** 5 managed sessions running. Open a fresh terminal outside any tmux session.

**Action:** `claude-mux --restart`.

**Expect:** All 5 recreate. `_caller_session` is empty (no `$TMUX`), so `_caller_entry` is empty and everything goes through the per-session loop. No background handoff runs (`_caller_entry` empty check at 4536).

## Protected sessions

### T2.1 Restart-all with protected non-caller session (decision pending)
**Setup:** 3 sessions: `home` (caller, protected), `aaa`, `bbb-protected` (has `.claudemux-protected` marker).

**Action:** `claude-mux --restart` from home.

**Expect (per the recommendation to force-restart protected):**
- `aaa` recreates normally.
- `bbb-protected` recreates (force=true passed to `shutdown_single_session`).
- `home` recreates via handoff.

**Alternative (if user decides to preserve "skip protected non-callers" current behavior):** `bbb-protected` stays running unchanged; only `aaa` and `home` recycle.

### T2.2 Restart-all when caller is protected (the normal home case)
**Setup:** Standard config: `home` is the caller and protected.

**Action:** `claude-mux --restart` from home.

**Expect:** home recreates via background handoff (the handoff doesn't check protection - it's the user-initiated restart of the caller, not an accidental shutdown).

## Failure modes

### T3.1 One non-caller session refuses to `/exit` within 10s
**Setup:** Manually wedge one session (e.g. send it Ctrl-C several times to leave Claude in a state where /exit hangs).

**Action:** `claude-mux --restart`.

**Expect:**
- `shutdown_single_session` logs `WARN: Claude in 'NAME' did not exit within 10s` then `kill-session`s it.
- Recreate proceeds on a fresh tmux session.
- Other sessions continue restarting in their turn (not blocked).

### T3.2 `create_claude_session` fails for one session (e.g. project dir deleted)
**Setup:** Delete one project's directory after capturing the restart list but before the loop runs (race-y; easier: pre-arrange a session whose dir is unreadable).

**Action:** `claude-mux --restart`.

**Expect:** That session is logged as failed; loop continues to next session; other sessions still restart. (Optional: tally into `_restart_errors`.)

### T3.3 Crash mid-restart (deliberate kill of the restart script)
**Setup:** 5 sessions. Run `claude-mux --restart`, then immediately `kill -9` the restart script PID (or unplug the simulated way: from another terminal `pkill -9 -f 'claude-mux --restart'`).

**Expect:**
- Sessions already shut down + recreated are fine.
- Session currently mid-shutdown: tmux session killed, marker handling depends on decision under "Open questions / marker policy" below.
- Sessions not yet reached: still running, untouched.

This test verifies the bug we're fixing: even a partial restart shouldn't strand sessions invisibly. Auto-restore should be able to recover whatever's down.

## Auto-restore interaction

### T4.1 Marker preservation across a successful restart
**Setup:** 1 managed session `aaa` running. Note `.claudemux-running` marker present.

**Action:** `claude-mux --restart aaa`.

**Expect:**
- During shutdown: `.claudemux-running` marker NOT removed (`preserve_marker=true`).
- `.claudemux-restarting/` directory present during the shutdown+create window.
- During create: `.claudemux-running` is rewritten by `create_claude_session` (idempotent; same content).
- After restart: `.claudemux-running` present; `.claudemux-restarting/` removed.

### T4.2 Crashed restart is recoverable by auto-restore
**Setup:** 1 managed session `aaa` running. Build a test version of the restart loop that crashes after `shutdown_single_session` but before `create_claude_session` (e.g. `kill -9 $$` injected at that point) for `aaa`. LaunchAgent active (60s tick).

**Action:** Trigger the doctored restart from `home`.

**Expect:**
- Restart crashes; `aaa` is tmux-killed; `.claudemux-running` still present (preserved through shutdown); `.claudemux-restarting/` still present (never cleaned up by the crashed script).
- First tick after crash: consumes `.claudemux-restarting/` (`rmdir`), logs `Auto-restore: skipping 'aaa' this tick (restart in flight)`, does not restore.
- Second tick (~120s after crash): `.claudemux-restarting/` gone, `.claudemux-running` present, session down → autorestore launches `aaa`.
- `aaa` is running at T+~120s, with no human intervention.

This is the defense-in-depth win that justifies the marker preservation. Today (v2.0.3) the same scenario strands `aaa` indefinitely.

### T4.3 Auto-restore tick during a normal restart-all
**Setup:** 5 sessions; LaunchAgent active. Trigger a `--restart` from `home` and observe the log over the next 2 minutes.

**Expect:**
- If the tick happens to fire during the restart window:
  - For any session currently in the `.claudemux-restarting/` window: tick consumes the marker, skips that session for this tick, logs the skip.
  - For any session already finished (or not yet started): tick checks normally (no marker → may or may not restore depending on session state).
- If the tick does not fire during the window: zero observable effect; restart-all completes normally.
- No duplicate session errors; no zombies; final state is N sessions running.

### T4.4 Concurrent restart-all calls (defense)
**Setup:** Open two terminals into the same tmux server. From terminal A run `claude-mux --restart`; from terminal B, while A is running, also run `claude-mux --restart`.

**Expect:**
- B's per-session loop attempts `mkdir .claudemux-restarting` for each session. For sessions A is currently restarting: `mkdir` fails (already exists) → B skips that session and logs `restart marker already held; another restart is in flight`. (Optional fast-follow: B can wait-and-retry instead of skip. For v2.0.4 skip is fine and matches the "first writer wins" semantics.)
- B may successfully claim and restart sessions A hasn't reached yet, interleaved with A.
- No session is restarted twice concurrently in the same project dir.

## Side effects

### T5.1 `--restart` from outside any session, no tmux
Same as T1.4 but verify no regression.

### T5.2 `--restart SESSION` (single named restart) unchanged
**Setup:** 3 sessions. `claude-mux --restart aaa` from home.

**Expect:** Only `aaa` restarts. `home` and others untouched. (Single-named path is separate code; should be unaffected by the fix.)

### T5.3 `--restart --fresh` (restart all, no `-c`)
**Setup:** 3 sessions running.

**Action:** `claude-mux --restart --fresh` from home.

**Expect:** All 3 recreate, none resume conversation (each starts a new transcript). `FRESH_START=true` is passed through to `create_claude_session` per session.

### T5.4 `--restart` while a session is mid-`/compact`
**Setup:** Start a `/compact` on one session, then immediately restart-all from another.

**Expect:** That session's `shutdown_single_session` sends `/exit` while compact is running; waits up to 10s; either compact finishes and exit lands, or wait expires and kill-session takes over. Restart proceeds on a fresh tmux session.

## Verification commands

### Test infrastructure
```bash
# Snapshot session state
snapshot() {
    echo "=== $1 ==="
    /Users/jonathan/bin/claude-mux -l
    echo "--- markers ---"
    find ~/Claude -maxdepth 3 -name '.claudemux-running' 2>/dev/null
    echo "--- log tail ---"
    tail -20 ~/Library/Logs/claude-mux.log
}

snapshot "before restart"
/Users/jonathan/bin/claude-mux --restart
sleep 30  # let all sessions reach ready
snapshot "after restart"
```

### Diagnostic: was the caller actually partitioned out?
After the fix, the log should show no `Sending /exit to session 'home'` line during the per-session loop. The caller-handoff branch logs `Restarting caller session 'home' via background handoff` instead.

```bash
grep -E 'restart starting|/exit|caller session|restart complete' ~/Library/Logs/claude-mux.log | tail -30
```

Expected sequence with fix (caller=home, 3 sessions `aaa`, `home`, `xxx`):
```
=== claude-mux restart starting ===
Remembering 3 running session(s) for restart
Restarting session 'aaa' in /path/to/aaa
Sending /exit to session 'aaa'         # from shutdown_single_session
Killing tmux session 'aaa'             # only if Claude didn't exit cleanly
Restarting session 'xxx' in /path/to/xxx
Sending /exit to session 'xxx'
...
Restarting caller session 'home' via background handoff
=== claude-mux restart complete ===
# Background:
Sending /exit to session 'home'  # via inline send-keys in handoff (4544)
```

The crucial absence: no `Sending /exit to session 'home'` *between* the per-session shutdowns and the handoff. That's the bug fix.

## Open questions (resolve before coding)

Marker policy + restart-marker concurrency: **resolved in design doc 2026-06-16.** `.claudemux-running` is preserved through restart via new `preserve_marker=true` arg to `shutdown_single_session`. Concurrency is gated by a `.claudemux-restarting/` directory (mkdir-based lock, consume-on-sight by the auto-restore tick). See design doc "Concurrency model" section. Tests T4.1-T4.4 cover the resolved design.
