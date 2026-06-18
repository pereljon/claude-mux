---
feature: restart-all-throttle
status: PLANNED
target_version: 2.0.9 (patch)
severity: Medium (handshake unreliable under burst; unattended-recovery risk)
related: auto-restore.md, ready-handshake.md, restart-in-place.md, restart-caller-shutdown-fix.md
---

# Feature: throttle restart-all so the later sessions don't get rate-limited

## Problem (observed 2026-06-17)

"Restart all sessions" from `home` with 11 sessions left the last-restarted
sessions (`jacuzzi`, `m18-transition`, `sylvia-estate`) showing
`API Error: Server is temporarily limiting requests (not your usage limit) ·
Rate limited` on their post-boot `Ready?` turn. The sessions stayed alive
(Claude up, prompt drawn, RC active) and resumed intact, but the rate-limited
`Ready?` never produced the "Session ready!" confirmation, and RC never
reconnected for them. `sylvia-estate` only recovered because the user manually
re-sent `Ready?`. There is no automatic retry.

### Root cause

The restart-all loop (dispatch `restart` case, the `while IFS='|' read -r _name
_dir` over `_other_list`) recreates every non-caller session in **one
synchronous pass with no spacing**:

```
shutdown_single_session → create_claude_session → (next session immediately)
```

`create_claude_session` blocks on `poll_until_ready` (TUI prompt drawn +
quiescent, ~a few seconds) and then sends `Ready?` **fire-and-forget**
(`send-keys -l "Ready?"` + `Enter`, then returns without waiting for the model's
reply). The model processes that `Ready?` turn (a real API call: resume context
load + the two-line ready reply) **asynchronously**, after the loop has already
moved on. So ~10 sessions' `Ready?` API turns pile into a ~60s window and trip
the server's per-org request limiter. Latest-sorted sessions land at the tail of
the burst and get throttled hardest.

### The asymmetry this fixes

Auto-restore (`autorestore_walk`) **already throttles** and never bursts: each
LaunchAgent tick counts sessions attempted within `STARTING_WINDOW` (90s) as
`in_flight`, computes `slots = STAGGER_CONCURRENCY - in_flight` (3), launches up
to `slots`, and defers the rest to the next ~60s tick. Budget: **≤
`STAGGER_CONCURRENCY` launches per any `STARTING_WINDOW` sliding window.**

That throttle is *tick-based* — it works across LaunchAgent invocations and
relies on being re-run every ~60s. The restart-all loop is a *single synchronous
pass* and bypasses it entirely. Also note the existing inter-session
`sleep "$SLEEP_BETWEEN"` at the end of `create_claude_session` only fires when
`COMMAND == "start"` (the `-a` launch path) — **not** for `restart`. So
restart-all is the one bulk path with zero pacing.

## Design

Make the restart-all loop honor the **same budget** auto-restore uses
(`STAGGER_CONCURRENCY` per `STARTING_WINDOW`), inline, reusing the existing
config knobs. No new config var, no new throttle concept — just apply the one
the user already tuned for auto-recovery to the path that currently skips it.

### Why pacing, not concurrency

`create_claude_session` is synchronous, so the loop is *already* serialized — it
never launches two sessions in parallel. The thing that overflows is the
fire-and-forget `Ready?` **API turns** stacking up faster than they drain.
Therefore the lever is **spacing between `Ready?` sends**, sized so no more than
`STAGGER_CONCURRENCY` land per `STARTING_WINDOW`.

### Mechanism (sliding window, mirrors autorestore)

Keep a local array of launch timestamps for the sessions restarted in this pass.
Before each `create_claude_session`:

1. Prune timestamps older than `STARTING_WINDOW`.
2. If the in-window count is `>= STAGGER_CONCURRENCY`, sleep until the oldest
   in-window timestamp ages out (so a slot frees), then re-prune.
3. Launch, then record `now`.

This reproduces autorestore's "≤3 per 90s" exactly: the first
`STAGGER_CONCURRENCY` sessions fire back-to-back (a burst of 3 is safe — that is
the same burst auto-restore allows per tick), then the loop paces at roughly
`STARTING_WINDOW / STAGGER_CONCURRENCY` (90/3 = 30s) per subsequent session as
old turns age out. A local timestamp array is used (not `restore_state`) because
the loop calls `restore_state_clear` at the top of each iteration, so
restore-state is not a reliable in-flight source here.

Pseudo-shape (in the `_other_list` loop):

```bash
local _starts=()                         # epoch seconds of recent Ready? sends
while IFS='|' read -r _name _dir; do
    [[ -z "$_name" ]] && continue
    # Throttle: ≤ STAGGER_CONCURRENCY launches per STARTING_WINDOW (reuse auto-restore budget)
    if [[ "$DRY_RUN" != "true" ]]; then
        restart_throttle_wait _starts        # prunes + sleeps if window full
    fi
    log "Restarting session '$_name' in $_dir"
    restore_state_clear "$_name"
    mkdir "$_dir/.claudemux-restarting" 2>/dev/null
    shutdown_single_session "$_name" true true
    create_claude_session "$_name" "$_dir" "" "$FRESH_START"
    rmdir "$_dir/.claudemux-restarting" 2>/dev/null
    _starts+=("$(date +%s)")                 # record this Ready? send
done <<< "$_other_list"
```

`restart_throttle_wait` is a small helper (passed the timestamp array by name, or
operating on a shared var) that prunes entries older than `STARTING_WINDOW` and,
while the remaining count `>= STAGGER_CONCURRENCY`, sleeps `1`s and re-prunes.
Bash array-by-name handling (`local -n`) is available; if avoiding namerefs for
portability, operate on a function-scoped global the loop also reads.

### The caller (+1)

The caller restarts **last, in place** (`restart_caller_in_place`) and is the
11th `Ready?`. By the time the loop reaches it, the throttle has spaced the
prior 10, so earlier turns have largely drained and the caller's own `Ready?` is
unlikely to clip. No extra handling needed; if we want belt-and-suspenders, one
final `restart_throttle_wait _starts` before `restart_caller_in_place` costs
nothing. **Decision needed:** include the pre-caller wait or not (default: yes,
it is one cheap call).

### Backstop (option 2, separate decision)

ISSUES.md also proposes detecting the rate-limit line in `await_ready_handshake`
and re-sending `Ready?` after a backoff. That is a genuine backstop and **also
helps auto-restore** (3 concurrent could still occasionally clip a busy org), but
it is a larger, cross-cutting change: there are four `Ready?` send sites
(`await_ready_handshake`, `create_claude_session`, `launch_single_session`, the
`on_compact` monitor), and reliable detection means scraping the pane for the
error line after the send. **Recommendation: ship the throttle alone as v2.0.9
(biggest single win, smallest diff), and track the handshake retry as a separate
follow-up** rather than bundling. Confirm this scoping before coding.

## Edge cases

| Case | Behavior |
|---|---|
| Fewer than `STAGGER_CONCURRENCY` sessions | No sleep ever fires; behaves exactly as today. |
| `DRY_RUN` | Throttle skipped entirely (no real boots, nothing to pace). |
| `STAGGER_CONCURRENCY` or `STARTING_WINDOW` set to 0 / unusual | Reuse existing validation/clamping; a 0 window degrades to "sleep each time" — document, don't crash. Confirm the config validation already guards these (it validates them as integers at load). |
| `poll_until_ready` times out for a session | `create_claude_session` returns after its own timeout; we still record the timestamp and pace normally. |
| Caller-only restart (no `_other_list`) | Loop body never runs; throttle is a no-op. |
| Single-named `--restart NAME` (not all) | Out of scope — one session, no burst. Throttle only wraps the restart-*all* `_other_list` loop. |

## Why low-risk

- One dispatch case (`restart`) + one small helper; no change to
  `create_claude_session`, the launch wrappers, or the handshake.
- Reuses existing config knobs (`STAGGER_CONCURRENCY`, `STARTING_WINDOW`) already
  validated at load — no new config, no migration.
- Worst case if the helper misbehaves: extra/insufficient sleep, never a failed
  restart (the launch path is unchanged).
- Tradeoff: restart-all of N sessions now takes longer (paced at ~30s/session
  past the first 3). For 11 sessions: ~3 fast + 8×~30s ≈ 4 min vs. today's ~1
  min. Acceptable: a reliable handshake beats a fast-but-throttled one, and
  restart-all is infrequent. **Confirm the user accepts the slower wall-clock.**

## Files to update (Change Checklist)

- `claude-mux`: add `restart_throttle_wait` helper; wrap the `_other_list` loop;
  optional pre-caller wait. `VERSION=` → 2.0.9.
- `dev/CODEMAP.md`: new helper row; note the `restart` dispatch case now throttles.
- `dev/SKELETON.md`: restart-all logic flow — add the throttle step in the
  `_other_list` loop.
- `dev/IMPLEMENTATION-SPEC.md`: restart section — document restart-all now honors
  the `STAGGER_CONCURRENCY`/`STARTING_WINDOW` budget (cross-reference auto-restore).
- `CHANGELOG.md`: Fixed — restart-all paces session boots to avoid rate-limiting
  the later sessions' `Ready?` handshake.
- `docs/ISSUES.md`: move the "Restart-all bursts session boots…" entry to Resolved
  in v2.0.9 (note option 2 / handshake-retry remains a tracked follow-up).
- No README / translations / config.example / injection / tips changes (behavior
  of an existing command, not a new command, flag, or config var). If the slower
  wall-clock is worth a user-facing note, add a one-line GUIDE.md mention only.

## Out of scope

- Handshake rate-limit detect + retry (`await_ready_handshake`) — tracked as a
  separate follow-up (see Backstop above).
- Changing `STAGGER_CONCURRENCY` / `STARTING_WINDOW` defaults.
- Tuning the `-a` / `start` path (already has `SLEEP_BETWEEN`; out of scope).
- Single-named `--restart NAME` (no burst).
