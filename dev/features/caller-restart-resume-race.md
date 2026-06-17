---
feature: caller-restart-resume-race
status: SUPERSEDED / REVERTED - hypothesis was wrong
superseded_by: caller-restart-resume-investigation.md
severity: HIGH (regression, data/context loss)
---

> **SUPERSEDED (2026-06-17).** The "relaunch races the dying process's conversation lock"
> hypothesis below turned out to be wrong: the fix (poll_until_ready before /exit +
> ensure-gone/settle) did NOT stop home forking and was reverted. The real, current
> understanding, every hypothesis tried, and the WIP helper candidate are in
> `caller-restart-resume-investigation.md`. This file is kept for history only.

# Feature: Caller (home) restart loses conversation — relaunch races the killed process

Implementable design spec. Test plan: `caller-restart-resume-race-tests.md`.

## Problem

When "restart all sessions" is triggered from the home session, **home comes back as a fresh conversation, losing its history.** Every other session resumes correctly. Reproduced repeatedly 2026-06-16. Each restart spawns a brand-new home transcript (e8fd3de4 -> 873c5390 -> 04b5d131 -> 48f535e4), each a standalone fresh session.

## Root cause (empirically established)

A **relaunch timing race** in the caller-handoff path, newly exposed by the v2.0.4 restart fix.

- The caller (home) is restarted by the background handoff (claude-mux:~4593), which sends `/exit`, then `kill-session`, then **immediately** re-execs `claude-mux -d home` -> `launch_single_session` -> `claude -c`.
- When restart-all is triggered *from* home, home is **busy** finishing the restart command's turn when `/exit` arrives, so `/exit` can't take effect; after the 10s wait the handoff **hard-kills** home with `kill-session` and relaunches `claude -c` ~immediately.
- `claude -c` then races the dying process: the prior conversation's lock/finalization hasn't released, so `claude --continue` treats it as unavailable and **opens a fresh conversation**. Exit 0, no error (which is why the v2.0.4 resume-failure diagnostic never fired).

### Why it's a v2.0.4 regression ("it didn't used to happen")

Pre-v2.0.4, restart-all from home hit the stranding bug: the blanket `shutdown_claude_sessions` SIGHUP-killed the script before the handoff ran, so home was revived ~60s later by the **LaunchAgent autorestore -> `create_claude_session`**. That 60s gap let the old process fully die and settle, so `claude -c` resumed cleanly. v2.0.4 fixed the stranding, so the handoff now runs and relaunches home **immediately**, introducing the race.

### Evidence (all reproduced this session)

| Path | Home state at `/exit` | Relaunch timing | Result |
|---|---|---|---|
| `create_claude_session` (`--restart home` from another session) | idle, clean exit | after full exit | **resume** (transcript grew 30->58, 136->164) |
| same, with an RC client actively attached to home | idle, clean exit | after full exit | **resume** (ruled out RC) |
| old pre-v2.0.4 path | hard-killed | +60s (LaunchAgent) | **resume** (settled) |
| **v2.0.4 caller handoff** | **busy/mid-turn** | **immediate after kill** | **fresh** |

Flags fully exonerated: `claude -c --remote-control --permission-mode auto --model sonnet --allow-dangerously-skip-permissions` resumes correctly in isolation (headless tests recalled the seeded codeword every time). RC client attachment exonerated (idle home resumed with a live RC client present). Model, BASE_DIR, mid-turn-transcript-incompleteness all exonerated (the old path hard-killed mid-turn and still resumed via the settled LaunchAgent relaunch).

## Scope

**In:** the caller-handoff block in the restart-all path (claude-mux:~4589-4617). Make the relaunch wait until the old session is cleanly gone before `claude -c`.

**Out:**
- The per-session restart-all loop (non-callers) — uses `create_claude_session` after `shutdown_single_session` waits for a clean exit; resumes correctly, no change.
- The single-named `--restart SESSION` path — same, resumes correctly.
- `claude -c` flag set — exonerated, unchanged.
- No new config var, flag, or marker.

## Design

Two complementary changes inside the handoff subshell, both enforcing "don't relaunch until the old session is cleanly gone."

### 1. Wait for the caller to go quiescent before `/exit`

Replace the fixed `sleep 1` with a wait for home to finish its turn, so `/exit` lands between turns and home exits **cleanly** (no hard-kill). Reuse the existing `poll_until_ready` (claude-mux:2834), which already waits for not-busy + prompt-drawn + quiescent with a ~120s timeout. A short initial `sleep 1` stays, to let the main `--restart` process exit and home resume its turn before we start polling.

```bash
(
    sleep 1                              # let the main --restart process finish
    poll_until_ready "$_caller_name" || true   # wait until home finishes its turn (bounded ~120s)
    mkdir "$_caller_dir/.claudemux-restarting" 2>/dev/null
    if "$TMUX_BIN" has-session -t "$_caller_name" 2>/dev/null; then
        "$TMUX_BIN" send-keys -t "$_caller_name" -l "/exit" && "$TMUX_BIN" send-keys -t "$_caller_name" Enter
        _w=0
        while [[ $_w -lt 20 ]]; do
            "$TMUX_BIN" has-session -t "$_caller_name" 2>/dev/null && claude_running_in_session "$_caller_name" || break
            sleep 0.5; (( _w++ ))
        done
        "$TMUX_BIN" kill-session -t "$_caller_name" 2>/dev/null
    fi
    # 2. Ensure the old session is fully gone before relaunch (close the lock race)
    _g=0
    while [[ $_g -lt 20 ]]; do
        "$TMUX_BIN" has-session -t "$_caller_name" 2>/dev/null || break
        sleep 0.5; (( _g++ ))
    done
    sleep 1                              # brief settle for conversation-lock release
    if ! "$CLAUDE_MUX_BIN" -d "$_caller_dir" --no-attach${FRESH_START:+ --fresh} 2>>"$LOG_FILE"; then
        echo "ERROR: Failed to recreate caller session '$_caller_name' in $_caller_dir" >> "$LOG_FILE"
    fi
    rmdir "$_caller_dir/.claudemux-restarting" 2>/dev/null
) &
disown
```

### 2. Post-kill "ensure gone" + settle (in the block above)

After `kill-session`, poll until `has-session` is false (the tmux session is truly gone), then a brief `sleep 1` settle, before `claude -c`. This closes the race even in the fallback case where a hard-kill was still needed (e.g., `poll_until_ready` timed out because home never went idle).

### Why this works

- Quiescence wait -> home exits cleanly (not hard-killed) -> transcript finalized and lock released before relaunch -> `claude --continue` resumes, exactly like the `create_claude_session` path that resumed in every test.
- The "ensure gone + settle" is defense-in-depth for the hard-kill fallback, reproducing the settling that the old LaunchAgent 60s delay provided — without the 60s.

### Why not other approaches

- **Fixed longer `sleep`** before relaunch: a guess; too short doesn't fix it, too long slows every restart. Polling is correct.
- **Route the caller through `create_claude_session`** instead of `claude-mux -d`: larger refactor; the caller must be restarted from a disowned subshell (can't kill its own script synchronously), and `create_claude_session` isn't structured for that. The handoff + quiescence wait is the minimal correct change.
- **Resume by explicit `--resume <id>`**: doesn't address the lock race; `--continue` already finds the right session once the old process has released it.

## Verified facts (current code)

- Caller handoff block at claude-mux:~4589-4617; currently `sleep 1` then `/exit` + 10s wait + `kill-session` + immediate `claude-mux -d`.
- `poll_until_ready` (claude-mux:2834) waits for not-busy ("esc to interrupt" absent) + prompt-drawn + 2-snapshot quiescence, ~120s timeout; returns only (does not send "Ready?"). Already used post-launch at 3031 and 3367.
- `create_claude_session` (resumes) waits for a clean exit via `shutdown_single_session` before relaunch; the handoff did not wait equivalently.
- Empirical: `--restart home` (create_claude_session) resumed home twice (incl. with a live RC client); the handoff produced fresh transcripts every time.
- This is a regression introduced by the v2.0.4 restart fix (commit b9577f0), which is **unpushed/unreleased** — so the fix should land before v2.0.4 ships.

## Change checklist (per CLAUDE.md)

- [ ] `claude-mux` caller-handoff block: `sleep 1` -> `sleep 1` + `poll_until_ready || true` before `/exit`; add post-kill "ensure gone" poll + settle before relaunch.
- [ ] `dev/SKELETON.md`: update the restart-all caller-handoff pseudocode (quiescence wait + ensure-gone settle).
- [ ] `dev/CODEMAP.md`: no signature change; note `poll_until_ready` gains a caller (the handoff) if the function index tracks callers. Likely no change.
- [ ] `CHANGELOG.md`: v2.0.5 entry — fix: restarting all sessions from home no longer drops home's conversation (relaunch waited for the killed process to settle).
- [ ] `docs/ISSUES.md`: add resolved entry (home-resets-fresh regression).
- [ ] `VERSION=` already 2.0.5 (bundled with the disambiguation change).
- [ ] No injection / config / CLI-flag changes.
- [ ] Release gate: `claude-mux` changed -> release; must ship at or before the v2.0.4 push so the regression never reaches users.

## Open questions

1. **Bundle into v2.0.5 with the disambiguation change** (both uncommitted) or ship the resume-race fix as its own commit first? Recommendation: same v2.0.5, separate commits (this one first — it's the regression).
2. **`poll_until_ready` timeout (~120s) as the quiescence bound** acceptable for the handoff? If home is genuinely stuck busy >120s, we fall through to `/exit` + hard-kill + the ensure-gone settle (degrades to current behavior, not worse). Recommendation: accept.
