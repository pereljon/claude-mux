# Test plan: Auto-restore

Companion to `auto-restore.md`. Covers pre-build verification (done), behavior/unit checks, integration, end-to-end, and edge cases. claude-mux is a bash tool tested manually + with shell assertions; "tests" here are concrete procedures, not a framework.

## 0. Pre-build verification (DONE — 2026-06-07)

| # | Check | Result |
|---|---|---|
| 1 | LaunchAgent re-fires `--autolaunch` ~every 60s | CONFIRMED: `RunAtLoad`+`KeepAlive`+`ThrottleInterval=60`, `autolaunch_dispatch` one-shot. Constraint: keep one-shot. |
| 2 | `claude_running_in_session` depth catches the real claude PID | CONFIRMED: 2 levels (grandchild in `create_claude_session`, direct child in `launch_single_session`). Constraint: no extra nesting. |
| 3 | Exit-code `\|\|` fallback vs the exit-code branch | PROBLEM CONFIRMED: resume-fail and crash both non-zero; needs startup-time-threshold restructure. |
| 4 | Exit codes: `/exit`, Ctrl-C ×2, SIGTERM, SIGKILL | MEASURED: 0, 0, 143, 137 (v2.1.149). |
| 5 | Idle per-session footprint (for stagger sizing) | MEASURED: ~80-110 MB RSS / ~0% CPU → local not the constraint. |

## 1. Marker lifecycle (behavior)

- **T1.1** Start a session (`-d`) → `<project>/.claudemux-running` exists; created before claude launches.
- **T1.2** `--shutdown SESSION` → marker removed *before* tmux kill; verify no resurrection on the next tick.
- **T1.3** Marker is auto-gitignored in a git project (matches `.claudemux-*`).
- **T1.4** Marker survives a simulated crash (kill claude, marker still present) and a reboot (file persists on disk).
- **T1.5** `home` never gets a marker; LaunchAgent starts it regardless.

## 2. Exit-code branch (the restructured wrapper)

- **T2.1** Clean `/exit` (rc 0) → marker removed → NOT resurrected by the next tick. (Stays dead.)
- **T2.2** Ctrl-C ×2 (rc 0) → same as T2.1.
- **T2.3** `kill -TERM` the claude PID (rc 143) after it ran ≥10s → marker kept → resurrected within ~60s.
- **T2.4** `kill -9` (rc 137) after ≥10s → marker kept → resurrected.
- **T2.5** Resume-failure: induce `claude -c` to fail immediately (e.g., corrupt/absent transcript) → wrapper runs the fresh fallback within the <10s window, session comes up fresh, marker handling correct.
- **T2.6** Discriminator boundary: a crash at ~9s vs ~11s after start — confirm <threshold → fresh-fallback path, ≥threshold → crash path. Tune threshold if misclassified.
- **T2.7** Process depth: after the restructure, `claude_running_in_session` still finds claude (≤2 levels). Regression guard for the constraint.

## 3. The `--autolaunch` tick + `should_be_alive()`

- **T3.1** Manually invoke `claude-mux --autolaunch` with a dead-but-marked session present → it relaunches (resume).
- **T3.2** `AUTORESTORE=false` → tick relaunches nothing; `-l` shows `stopped` for marked-dead sessions.
- **T3.3** Tripped session (`tripped=true` in restore-state) → tick skips it.
- **T3.4** `should_be_alive()` returns true for marker+on+not-tripped; false for AUTORESTORE off, for tripped, and for no-marker.
- **T3.5** Cadence: leave a session dead-but-marked; confirm it comes back within ~one `ThrottleInterval` (~60s) without manual action (the watchdog).

## 4. Crash-loop guard

- **T4.1** Make a session die fast repeatedly (e.g., a wrapper that exits non-zero in <MIN_HEALTHY): after 3 fast deaths, `tripped=true`, tick stops resurrecting, `-l` shows `failed`, and a one-shot notice reaches `home`.
- **T4.2** A session that runs ≥MIN_HEALTHY then dies once → `death_count` resets to 0 (not treated as a loop); it resurrects normally.
- **T4.3** `restart`/`restart fresh` on a `failed` session clears `tripped`, resets `death_count`, brings it back.
- **T4.4** No auto-fresh: confirm the guard never silently discards the transcript.

**Test-method note (learned 2026-06-08 E2E):** to exercise the guard cleanly, let each relaunch run **>10s before killing claude**, and drive ticks with `claude-mux --autolaunch`. Killing a *healthy* claude **within 10s** of launch trips the launch wrapper's resume-fail fresh-fallback (it reads the fast death as "resume failed to start" and retries fresh in-pane); that fresh claude can then stack with a tick-driven relaunch, leaving stray processes and a confusing "claude still running after trip" state. The trip *logic* still works (death_count 0→1→2→3, `failed`, home notice, all verified), but the process state is messy. A real crash-loop (poisoned transcript) does NOT have this problem: the fresh-fallback also fails, nothing stacks, and the trip leaves the session cleanly down. Verified end-to-end on a throwaway session: trip at 3 + home notice, then `restart fresh` cleared `tripped` (restore-state file removed) and relaunched.

## 5. Staggering

- **T5.1** Mark N (e.g., 8) sessions dead, run the tick repeatedly: no more than `STAGGER_CONCURRENCY` (3) are launched per `STARTING_WINDOW` (90s); the rest drain over subsequent ticks.
- **T5.2** `home` is launched first and is not counted in the staggered batch.
- **T5.3** Order is deterministic (sorted) across runs.
- **T5.4** `last_attempt_ts` is shared cleanly with the crash-loop guard (no interference between the two readers).
- **T5.5** Peak system load during a full staggered restore stays modest (sanity vs the ~80-110 MB/session baseline).

## 6. `-l` statuses

- **T6.1** Running+protected → `protected`; running → `running`.
- **T6.2** Marker + dead + AUTORESTORE on + not tripped → `queued`.
- **T6.3** Marker + dead + tripped → `failed`.
- **T6.4** Marker + dead + AUTORESTORE off → `stopped`.
- **T6.5** No marker → `stopped`/`idle`.
- **T6.6** Status computation uses no `capture-pane` (cheap; verify `-l` latency unchanged with many sessions).
- **T6.7** `-l` and the tick agree (both via `should_be_alive`): a `queued` session is exactly one the tick will restore.

## 7. End-to-end (post-build, the items that need the feature live)

- **T7.1 Reboot recovery:** with several sessions running, reboot the machine; after login, the working set returns automatically (staggered, home first); cleanly-stopped sessions stay down.
- **T7.2 Mid-day crash recovery:** kill a running session's claude; it self-heals within ~60s, no user action.
- **T7.3 Zombie recovery:** drop a session to a shell (claude dead, pane alive); the tick resurrects it (liveness predicate, not `has-session`).
- **T7.4 First-time backfill:** on upgrade to the version adding this, already-running sessions get markers written so the first reboot doesn't lose them.

## 8. Edge cases / interactions

- **E8.1** Hidden (`.claudemux-ignore`) + marked → comes back hidden. Protected (`.claudemux-protected`) + marked → comes back protected. Markers are orthogonal to the restore walk.
- **E8.2** `tmux kill-session` (non-zero/abnormal) → resurrected within ~60s (documented behavior change). To truly stop: `/exit` or `--shutdown`.
- **E8.3** `--restart` of a marked session: marker removed by the wrapper's clean exit, re-written by relaunch; no gap where the tick double-launches.
- **E8.4** Toggle `AUTORESTORE` off then on: markers stay inert while off, honored again when on (no corruption).
- **E8.5** Concurrent tick + manual `--shutdown` race: marker-removed-first ordering prevents resurrecting a mid-shutdown session.
- **E8.6** `restore-state/<session>.json` missing/corrupt → treated as fresh (death_count 0, not tripped); never crashes the tick.

## 9. Regression / change-checklist verification

- Config: `AUTORESTORE` in `config.example` + `config_help()` + settings table.
- Markers: `.claudemux-running` in CODEMAP marker registry + auto-gitignore.
- State: `~/.claude-mux/restore-state/` in CODEMAP global-state table.
- Docs: CODEMAP (new/changed functions), SKELETON (logic flow), CHANGELOG, release notes (behavior change).
- `bash -n claude-mux` clean; deploy to `~/bin/`; smoke-test `-l`, `-d`, `--shutdown`, `--restart`, `--autolaunch`.

## Notes

- The exit-code threshold (~10s) and stagger constants (`3` / `90s`) are first guesses — record real values observed during T2.6 and T5.1 and tune.
- T7.1 (reboot) is the one test that can't be automated cheaply; run it manually at least once before declaring the feature done.
