---
feature: restart-all-throttle
---

# Test Plan: throttle restart-all

Tests for `restart-all-throttle.md`. Decisive metric: a restart-all of N (> 
`STAGGER_CONCURRENCY`) sessions spaces the `Ready?` sends so no more than
`STAGGER_CONCURRENCY` land per `STARTING_WINDOW`, and every session ends with a
"Session ready!" confirmation (no rate-limit on the tail sessions).

The throttle is timing behavior, so most checks are structural (the helper math)
plus one live restart-all observation. Use low knob values to keep live tests
fast: `STAGGER_CONCURRENCY=2 STARTING_WINDOW=6` makes a 5-session restart pace
visibly without minutes of waiting.

## Pre-build verification (confirm before coding)

- **V0.1 Burst reproduces / loop has no spacing:** confirmed — the `restart`
  dispatch `_other_list` loop calls `create_claude_session` back-to-back with no
  `sleep`; the only inter-session sleep (`SLEEP_BETWEEN`, end of
  `create_claude_session`) is gated on `COMMAND == "start"`. Re-confirm the gate
  if that line changed.
- **V0.2 `Ready?` is fire-and-forget:** confirmed — `create_claude_session` sends
  `send-keys -l "Ready?"` + `Enter` then returns; it does not wait for the
  model's reply. The API turn drains after the loop advances.
- **V0.3 Knobs validated at load:** confirm `STAGGER_CONCURRENCY` and
  `STARTING_WINDOW` are integer-validated in the config-load block (they are, in
  the `for _var_name in … STAGGER_CONCURRENCY STARTING_WINDOW` loop) so the
  helper can trust them.

## Static / generation checks (post-build)

- **T0.1** `bash -n claude-mux` passes.
- **T0.2** `claude-mux --dry-run --restart` (all) lists "Would restart …" for each
  session and **emits no sleep / no throttle delay** (DRY_RUN skips the throttle).
  Wall-clock is effectively instant.
- **T0.3** Helper in isolation: source/extract `restart_throttle_wait` and drive
  it with a seeded timestamp array. With `STAGGER_CONCURRENCY=2`,
  `STARTING_WINDOW=6`:
  - empty array → returns immediately (no sleep).
  - array of 1 recent ts → returns immediately (1 < 2).
  - array of 2 recent ts → sleeps until the oldest ages past 6s, then returns;
    measured wait ≈ `6 - (now - oldest)`.
  - array of 2 ts already older than 6s → prunes both, returns immediately.

## Core behavior (live restart-all)

Run from a session with ≥ 5 managed sessions, or spin up throwaway sessions.
Set low knobs for the run: `STAGGER_CONCURRENCY=2 STARTING_WINDOW=6`.

- **T1.1 Pacing holds.** `claude-mux --restart` (all). Timestamp each
  `Restarting session 'X'` log line. The first `STAGGER_CONCURRENCY` (2) fire
  back-to-back; each subsequent start is `>= STARTING_WINDOW/STAGGER_CONCURRENCY`
  after the one before it (allowing for `create_claude_session`'s own poll time).
  No window of `STARTING_WINDOW` seconds contains more than `STAGGER_CONCURRENCY`
  starts.
- **T1.2 Every session confirms ready.** After the restart-all settles, each
  non-caller session shows the two-line "Session ready!" reply (and the caller,
  restarted in place, also confirms). No session left on a rate-limit error.
  (Pre-fix, the tail sessions could show the rate-limit line and no confirmation.)
- **T1.3 Caller still last + in place.** The calling session is restarted after
  all others, in its own pane (no kill-session), and confirms ready. Throttle did
  not reorder or skip the caller. (Regression guard for restart-in-place.)
- **T1.4 Under `STAGGER_CONCURRENCY`.** With only 2 sessions and
  `STAGGER_CONCURRENCY=2`: restart-all fires both immediately, no sleep, same
  wall-clock as today. (Throttle inert below the cap.)

## Regression

- **T3.1 Auto-restore untouched.** `autorestore_walk` behavior is unchanged
  (still tick-based, still `STAGGER_CONCURRENCY`/`STARTING_WINDOW`). Spot-check:
  kill a should-be-alive session, confirm the tick still restores it staggered.
- **T3.2 `-a` / start path untouched.** `claude-mux -a` (or start) still spaces
  via `SLEEP_BETWEEN` as before — the new throttle wraps only the `restart`
  `_other_list` loop, not `create_claude_session` itself.
- **T3.3 Single-named restart.** `claude-mux --restart NAME` (one session) does
  not invoke the throttle (no `_other_list` burst); behaves as today.
- **T3.4 `.claudemux-restarting` marker discipline.** The per-session
  `mkdir`/`rmdir` of the restart lock still brackets each `create_claude_session`
  and is not stranded by a throttle sleep (the sleep happens *before* the
  `mkdir`, not between `mkdir` and `rmdir`).
- **T3.5 Restart errors still surface.** `_restart_errors` exit-code path
  unchanged; a failed create still flags non-zero exit.

## Cleanup

Restore `STAGGER_CONCURRENCY` / `STARTING_WINDOW` to their config/defaults after
the low-knob live runs. Remove any throwaway sessions created for testing.

## Acceptance

- T1.1–T1.2: restart-all paces at the auto-restore budget and every session
  confirms ready — the primary fix.
- T1.3–T1.4: caller-last/in-place intact; throttle inert below the cap.
- T3.1–T3.5: auto-restore, `-a`, single-restart, lock discipline, and error exit
  all unregressed.
- T0.1–T0.3: syntax clean, DRY_RUN skips the throttle, helper math correct in
  isolation.
