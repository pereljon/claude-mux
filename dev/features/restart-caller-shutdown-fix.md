---
kind: feature
lifecycle: shipped
feature: restart-caller-shutdown-fix
status: implemented (v2.0.4)
target_version: 2.0.4
severity: HIGH (correctness)
---

# Feature: Fix `--restart` (all) killing itself mid-loop

Implementable design spec. Test plan: `restart-caller-shutdown-fix-tests.md`.

## Problem

`claude-mux --restart` (no SESSION arg, i.e. restart-all) frequently leaves most managed sessions stranded idle when invoked from inside a managed session. Observed 2026-06-16 from `home`: 10 sessions remembered for restart, only `home` and `claude-mux` came back; 6 ended idle (`/exit`ed but never relaunched), 3 stayed running (never got `/exit`).

## Root cause

claude-mux:4524 calls the blanket `shutdown_claude_sessions` *after* having carefully partitioned the restart list into `_other_list` and `_caller_entry` to avoid the caller. The blanket shutdown ignores the partition and `/exit`s every managed session in alphabetical order, including the caller.

Sequence when the caller is `home`:
1. Restart-all loop captures 10 running sessions → `_restart_list`.
2. Partitions into `_other_list` (9) + `_caller_entry` (1: home). Comment at 4505-4506 even says *"We can't kill-session on the caller because this script is running in that pane (SIGHUP would kill us)."*
3. **Bug**: `shutdown_claude_sessions` at 4524 sends `/exit` to all 10 alphabetically (10th-ave-remodel, 1925-gough-remodel, ai-project-workflows-101, argentina-property, claude-mux, datetime-hook, **home**, jacuzzi, m18-transition, sylvia-estate).
4. `/exit` reaches home (7th alphabetically). Home's clean-exit wrapper `kill-session`s home → SIGHUP kills the `claude-mux --restart` process running in home's pane.
5. Sessions alphabetically *after* home (jacuzzi, m18-transition, sylvia-estate) never receive `/exit` → stay running.
6. Sessions alphabetically *before* home are `/exit`ed but the relaunch loop (4526-4531) never runs → idle.
7. Caller background-handoff at 4536 never runs either → home would be stranded too, but the LaunchAgent KeepAlive tick happens to restart home (home-only safety net).

Compounding: `shutdown_claude_sessions` calls `remove_running_marker` per session before `/exit`. The 6 stranded sessions have no `.claudemux-running` marker, so the `--autolaunch` tick won't auto-restore them either ("intentional stop"). They're invisibly stuck until the user manually starts them.

The bug is purely ordering-dependent: when the caller sorts alphabetically late (e.g. `zzz-test`), more sessions get processed before the SIGHUP and the bug looks like partial success; when the caller is `home` or earlier, the bug hits hard.

## Scope

**In:**
1. Replace the blanket `shutdown_claude_sessions` in the restart-all path with a per-session shutdown of `_other_list` only, interleaved with the relaunch (`mkdir restart marker → shutdown → create → rmdir restart marker`, per session).
2. Extend `shutdown_single_session` with a `preserve_marker` parameter (default false; restart paths pass true) so the `.claudemux-running` marker stays through a restart - if the restart crashes mid-way, the next auto-restore tick can recover.
3. Add a `.claudemux-restarting` restart marker marker (atomic `mkdir`/`rmdir`) around each session's shutdown+create to prevent the auto-restore tick from racing with the restart loop. Tick semantics: **consume-on-sight** (see "Concurrency model" below).
4. Apply the same restart marker + preserve_marker treatment to (a) the caller-handoff branch (claude-mux:4536-4560), and (b) the single-named `--restart SESSION` path.
5. Pass `force=true` to `shutdown_single_session` so restart-all can recycle protected sessions (decided: matches the `--restart` user expectation).

**Out:**
- No change to `--shutdown` path - working correctly.
- No change to alphabetical iteration order in `shutdown_claude_sessions` - the blanket function stays as-is for its own callers (`--shutdown`, `--shutdown SESSION...`).
- No new config var or constant - the restart marker has no timeout.
- No new injection prompt or user-visible flag.

## Decided: force-restart protected sessions

Today, the blanket `shutdown_claude_sessions` skips protected sessions unless `FORCE` (1792-1796), and `--restart` doesn't set `FORCE`. So `--restart` (all) *accidentally* skips protected non-callers. Fix passes `force=true` to `shutdown_single_session`, restoring intuitive semantics: `--restart` restarts everything that's running, protection is for `--shutdown` accidents only. Document in CHANGELOG as a behavior change.

## Design

### Concurrency model: `.claudemux-restarting` marker (consume-on-sight)

A new per-project marker. Family-wise it's a marker like the others (`.claudemux-running`, `.claudemux-protected`, `.claudemux-ignore`), but it's a **transient lock** rather than a long-lived flag:

```
.claudemux-restarting/   # presence = "an intentional restart is in flight; auto-restore stay out this tick"
```

**Implemented as a directory created via `mkdir`, removed via `rmdir`** (matches the existing lock pattern at claude-mux:3558). Convention for the codebase: `mkdir` for locks (atomic claim-this-name), `touch` for flags (long-lived presence-only). The `.claudemux-restarting` lock fits the former; `.claudemux-running` / `.claudemux-protected` / `.claudemux-ignore` stay as `touch`-style flags.

Auto-add to `.gitignore` via the existing `.claudemux-*` pattern — no `ensure_gitignore_entry` change needed.

**Tick semantics: consume-on-sight, single-shot deferral.** When the `--autolaunch` tick walks projects, the first thing it checks per candidate is:

```bash
if [[ -d "$_proj/.claudemux-restarting" ]]; then
    rmdir "$_proj/.claudemux-restarting" 2>/dev/null
    log "Auto-restore: skipping '$_name' this tick (restart in flight)"
    continue
fi
```

Translation: *"a restart marker means someone is mid-restart right now; don't touch this session this tick, and remove the restart marker so we don't keep deferring forever."*

- **Common case:** restart completes in <60s. Tick may not fire during the window at all; restart marker is removed by the restart loop. Zero observable effect.
- **Tick fires mid-restart:** restart marker consumed, that session skipped this tick. Next tick (~60s later): if restart finished, session is up and `claude_running_in_session` returns true → no action. If restart crashed: restart marker is gone, marker is preserved (see below), session correctly recovered.
- **Crashed restart recovery latency:** up to ~120s (one tick to consume restart marker + one tick to actually recover). Vastly better than today's "stranded forever" failure mode.
- **Self-healing:** if a stale restart marker is ever left behind (bug, manual `mkdir`, whatever), the next tick clears it. No timeout constant, no `stat` call, no decision about what "fresh" means.

The dangerous race window is the sub-second gap between `kill-session` and `new-session`. Once `new-session` succeeds, the tmux session exists and the tick's `claude_running_in_session` check handles the rest - autorestore won't double-create against an existing tmux session.

### Marker preservation through restart

`shutdown_single_session` (claude-mux:1716) today removes `.claudemux-running` before sending `/exit` (line 1734). For `--shutdown` (intent: stop) this is correct. For `--restart` (intent: recycle) this is the second half of the v2.0.3 stranding bug: if the script dies mid-loop, the marker is gone and auto-restore won't recover the session.

Add a third arg:

```bash
shutdown_single_session() {
    local session="$1"
    local force="${2:-$FORCE}"
    local preserve_marker="${3:-false}"     # NEW
    ...
    if [[ "$preserve_marker" != "true" ]]; then
        remove_running_marker "$(session_marker_dir "$session")"
    fi
    ...
}
```

`--shutdown` callers don't pass it → unchanged behavior. Restart paths pass `true` → marker survives a crashed restart and the restart marker's deferral gives auto-restore a clean handoff.

### Code change (restart-all loop, claude-mux:4523-4531)

```bash
# BEFORE
# Shut down and recreate all non-caller sessions
shutdown_claude_sessions
detect_github_ssh_accounts
while IFS='|' read -r _name _dir; do
    [[ -z "$_name" ]] && continue
    log "Restarting session '$_name' in $_dir"
    restore_state_clear "$_name"   # user restart un-trips crash-loop history
    create_claude_session "$_name" "$_dir" "" "$FRESH_START"
done <<< "$_other_list"

# AFTER
# Shut down and recreate non-caller sessions individually.
# CRITICAL: must NOT call shutdown_claude_sessions here - that walks every
# managed session including the caller, whose /exit SIGHUPs this script
# mid-loop and strands the rest. The partition above split the caller out
# for exactly this reason; honor it.
detect_github_ssh_accounts
while IFS='|' read -r _name _dir; do
    [[ -z "$_name" ]] && continue
    log "Restarting session '$_name' in $_dir"
    restore_state_clear "$_name"
    mkdir "$_dir/.claudemux-restarting" 2>/dev/null   # restart marker: auto-restore defers this tick
    shutdown_single_session "$_name" true true        # force=true, preserve_marker=true
    create_claude_session "$_name" "$_dir" "" "$FRESH_START"
    rmdir "$_dir/.claudemux-restarting" 2>/dev/null   # release; tick consumes if we crashed
done <<< "$_other_list"
```

### Code change (caller-handoff branch, claude-mux:4536-4560)

The caller handoff has its own inline `/exit` + `kill-session` + recreate. Apply the same restart marker pattern there:

```bash
# Inside the background ( ) & block, around the existing send-keys+kill+recreate
mkdir "$_caller_dir/.claudemux-restarting" 2>/dev/null
# ... existing /exit + wait + kill-session ...
if ! "$CLAUDE_MUX_BIN" -d "$_caller_dir" --no-attach${FRESH_START:+ --fresh} 2>>"$LOG_FILE"; then
    echo "ERROR: Failed to recreate caller session '$_caller_name' in $_caller_dir" >> "$LOG_FILE"
fi
rmdir "$_caller_dir/.claudemux-restarting" 2>/dev/null
```

The caller's `.claudemux-running` marker stays present through the handoff (the inline code today doesn't remove it - that's accidentally correct; just make it explicit by adding a comment).

### Code change (single-named `--restart SESSION`)

The single-restart path lives elsewhere in the dispatch (look for the `restart)` case earlier than 4471). It already builds and runs `create_claude_session` directly; wrap its shutdown+create in the same restart marker pattern so a crashed single-restart can also recover.

### Code change (autorestore_walk, claude-mux:4234)

One block at the top of the per-candidate loop:

```bash
for _proj in "${candidates[@]}"; do
    # ... existing parse of _name, _dir from _proj ...

    # Restart-in-flight restart marker: defer this session for one tick.
    if [[ -d "$_proj/.claudemux-restarting" ]]; then
        rmdir "$_proj/.claudemux-restarting" 2>/dev/null
        log "Auto-restore: skipping '$_name' this tick (restart in flight)"
        continue
    fi

    # ... existing should_be_alive / claude_running_in_session / restore logic ...
done
```

### Why `shutdown_single_session` is the right primitive

- Idempotent: `has-session` guard + (optional) marker removal + `/exit` + bounded wait + `kill-session`.
- Takes explicit `force` arg (claude-mux:1719-1720); we add `preserve_marker` in the same style.
- Returns non-zero on failure - lets us tally `_restart_errors` per-session if we want (optional fast-follow).
- Already battle-tested via `shutdown_claude_sessions` named-session path (1769) and `--delete` (2477).

### Sequencing inside the per-session loop

Interleaved (`shutdown → create` per session) instead of today's "shut all down → relaunch all" is a small behavioral change worth noting:

- Total wall-clock time similar (bounded 10s wait rarely hit; most `/exit`s complete in <2s).
- Each session's relaunch starts ~10s sooner - faster perceived recovery.
- Caller handoff still runs last (unchanged) - caller is always the final session to restart.

Acceptable; documented in CHANGELOG.

## Why not other approaches considered

- **"Make `shutdown_claude_sessions` skip the caller"**: pollutes a general-purpose function with restart-specific logic, and the partition already exists at the call site. Better to honor the partition than rewrite the primitive.
- **"Pre-write the marker back after `shutdown_claude_sessions` runs"**: race-prone; the SIGHUP can land between marker delete and marker write.
- **"Run the whole restart-all from the background handoff"**: heavier refactor; the partition pattern is correct, just not honored.
- **"Time-based stale restart marker (mtime + 5min timeout)"**: rejected in favor of consume-on-sight. Simpler (no clock, no constant), faster crash-recovery (~120s vs ~5min), self-clears stale garbage in one tick instead of waiting for the timeout.

## Verified facts (current code)

- `shutdown_single_session` exists at claude-mux:1716, accepts `force` as 2nd arg (1720), does marker-remove + `/exit` + 10s wait + `kill-session` (1734-1751). Add `preserve_marker` as 3rd arg.
- `shutdown_claude_sessions` (1755) blanket path always walks every managed session alphabetically via tmux `list-sessions -F '#{session_name}'` (1779).
- Restart-all caller-partition at 4504-4521 is correct in intent; bug is purely the `shutdown_claude_sessions` call at 4524 that bypasses it.
- Caller background handoff at 4536-4560 does its own per-session shutdown for the caller; needs restart marker wrap added.
- `restore_state_clear` (claude-mux:2121) is safe to call before shutdown (clears crash-loop state regardless of current session state).
- `create_claude_session` (2802) is safe to call after `shutdown_single_session` killed the old tmux session - it `new-session`s fresh.
- `should_be_alive` (2184) is the autorestore predicate; restart marker check goes in `autorestore_walk` (4234) per-candidate, not inside `should_be_alive` (so the consume-on-sight side effect isn't hidden inside a predicate).
- Existing `mkdir`-based lock pattern at claude-mux:3558 (update-check) confirms the atomic-mkdir idiom is already used in the codebase.
- `.claudemux-*` gitignore pattern (CLAUDE.md "Marker-file philosophy") already covers `.claudemux-restarting` - no `ensure_gitignore_entry` change needed.

## Change checklist (per CLAUDE.md)

- [ ] `claude-mux` shutdown_single_session: add `preserve_marker` 3rd arg; gate `remove_running_marker` on it.
- [ ] `claude-mux` restart-all loop (4523-4531): replace blanket shutdown with per-session `mkdir restart marker → shutdown(force,preserve) → create → rmdir restart marker`. Add explanatory comment.
- [ ] `claude-mux` caller-handoff (4536-4560): wrap in same restart marker; add comment noting marker is preserved through the handoff.
- [ ] `claude-mux` single-named `--restart SESSION` path: same restart marker wrap.
- [ ] `claude-mux` autorestore_walk (4234): add consume-on-sight restart marker check at top of per-candidate loop.
- [ ] `CLAUDE.md` "Project Folder Indicators - Marker-File Philosophy" table: add `.claudemux-restarting` row.
- [ ] `dev/CODEMAP.md`: note `shutdown_single_session` signature change (new `preserve_marker` arg); new caller for it (restart loop); new marker `.claudemux-restarting` in the marker registry; restart marker check in `autorestore_walk`.
- [ ] `dev/SKELETON.md`: update restart-all flow (restart marker + per-session interleaved); update autorestore_walk flow (restart marker skip at top).
- [ ] `CHANGELOG.md`: v2.0.4 entry. Behavior changes to note: (a) restart-all restarts protected non-caller sessions (was silently skipping); (b) sessions relaunch in interleaved order (was all-shutdown-then-all-relaunch); (c) `.claudemux-running` preserved through restart so crashed restarts are recoverable by auto-restore.
- [ ] `VERSION=` bump to 2.0.4.
- [ ] `docs/ISSUES.md`: move this entry from Open to Resolved (v2.0.4).
- [ ] No injection prompt change required.
- [ ] No `commands_help()` change required (no new flag).
- [ ] No `config.example` change required.
- [ ] Release gate: `claude-mux` changed → release required.

## Open questions (resolve with user before coding)

1. **Bundle with other v2.0.4 items?** This fix is high-severity and small. Candidates from the v2.0.3 code review (HIGH-1..HIGH-4: config-source validation, heredoc quote-safety, `local` in `launch_single_session`, model_flag assert) are also small. Ship as one v2.0.4 patch or separately?
2. **Per-session error tally?** Could increment `_restart_errors` per failed `shutdown_single_session` / `create_claude_session`; today the restart-all loop has no error tally. Optional; not required for the fix.

## Parked for separate discussion

- **Should `home` always restart last (regardless of caller)?** Current design is caller-last (technical requirement: can't SIGHUP your own script). `home` is last only when it's the caller (the normal case). Pro of "always last": `home` is the orchestrator + has LaunchAgent fallback. Con: special-cases `home` in a way that doesn't generalize (v2.x agent-network may make any session an orchestrator). Not blocking this fix; revisit if pain emerges.
