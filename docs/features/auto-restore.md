# Feature: Auto-restore (v2.0 self-healing keystone)

Implementable design spec. Lifted from the v2.0 Milestone section of `docs/ISSUES.md` once ready to build; assumptions verified before finalizing (see "Verified assumptions"). Test plan: `auto-restore-tests.md`.

## Goal

Persist each running session's state to a per-project marker so the LaunchAgent can restore the user's working set after a reboot, and self-heal mid-day crashes. Reboot recovery and runtime watchdog are one mechanism, differing only in *when* the tick fires.

## Scope

**In:** marker + lifecycle, the `--autolaunch` restore walk, `should_be_alive()` predicate, exit-code branch (clean-quit vs crash), resume + crash-loop guard, staggering, `-l` statuses (`queued`/`failed`), default-on + global `AUTORESTORE` opt-out. Zombie recovery is **subsumed** (falls out of the liveness predicate), not a separate feature.

**Out (separate or deferred):** auto-startup (designed as an extension point only), ready-handshake fix (own feature doc), Claude Code upgrade detection (own feature doc), the `starting` status badge (parked).

## State files

| Path | Kind | Purpose |
|---|---|---|
| `<project>/.claudemux-running` | per-project marker (empty file) | presence = "this session should be alive." Travels with the folder; auto-gitignored via `.claudemux-*`. |
| `~/.claude-mux/restore-state/<session>.json` | central runtime state | crash-loop + stagger bookkeeping: `{ "last_attempt_ts": <epoch>, "death_count": <int>, "tripped": <bool> }` |

Marker is per-project (intent that travels). Health/stagger state is central runtime state (same class as `tip-state/`), keyed by session name.

## Lifecycle

- On session start (`-d`, `-n`, `--restart`): write `.claudemux-running` **first**, then start tmux/Claude.
- On `--shutdown`: remove `.claudemux-running` **first**, then kill tmux. Order prevents a race where a concurrent restore relaunches a mid-shutdown session.
- A clean in-pane quit (`/exit`, Ctrl-C ×2 → exit 0) removes the marker via the exit-code branch (below).
- A crash / `tmux kill-session` / reboot (abnormal, non-zero or no chance to clean up) leaves the marker → resurrected.
- `home` gets no marker; the LaunchAgent always starts it first.

**Invariant:** marker present ⇒ session should be alive. Cleared two ways, both = intent to stop: `--shutdown`, or a clean in-pane quit (exit 0).

## `should_be_alive()` predicate (one helper, used by tick AND `-l`)

```
should_be_alive(session) ⇔
    (.claudemux-running present AND AUTORESTORE on AND not tripped)   # auto-restore
    OR (.claudemux-autostart present)                                # always-on (future, see Extension point)
```
Both the restore walk and the `-l` status logic call this single helper so the listing never promises a restore the tick won't perform. Written generic now so per-project `AUTORESTORE` (a future `.claudemux-no-restore` marker) or auto-startup drop in by editing only the helper.

## The `--autolaunch` tick

- Extend the flag the LaunchAgent already calls (`autolaunch_dispatch`). After ensuring `home` is up (first, outside the staggered batch), walk `PROJECT_DIRS` for sessions where `should_be_alive()` is true and `claude_running_in_session()` is false; launch them (staggered).
- Pure bash; no home Claude turn, no injection delay, no token cost.
- **Cadence (verified):** the plist runs `claude-mux --autolaunch` with `RunAtLoad=true`, `KeepAlive=true`, `ThrottleInterval=60`. `autolaunch_dispatch` is one-shot (does its work, returns; dispatch then `exit 0`), so launchd re-fires it ~every 60s → boot recovery and runtime watchdog from one code path.
- **Constraint:** `--autolaunch` MUST stay one-shot. If it ever became a long-running loop, `KeepAlive` would not re-fire it on a timer and the watchdog breaks.
- **`LAUNCHAGENT_MODE` gate:** the dispatch already branches on `none`/`home`. The restore walk extends the `home` path (or adds a mode); `none` continues to self-unload the plist.

## Liveness predicate

Use `claude_running_in_session()` (process-tree check), NOT `tmux has-session`. A "zombie" (tmux pane alive, claude dead) is the same failure as a fully-dead session and must be resurrected the same way; `has-session` would see the live pane and wrongly skip it.

- **Depth (verified sufficient):** the function checks direct children + grandchildren (2 levels). Real trees: `create_claude_session` → claude is a grandchild (pane shell → `bash launch_script` → claude); `launch_single_session` → claude is a direct child (pane command is the script). Both ≤2 levels.
- **Constraint:** the exit-code wrapper restructure must NOT add a process layer that pushes claude to level 3, or this check goes blind. (Existing open issue: "claude_running_in_session only checks 2 levels deep" — deepen it if nesting ever grows.)

## Exit-code branch (clean-quit vs crash)

Clean quit → remove marker (stay dead); abnormal exit → leave marker (resurrect). Exit codes verified empirically (Claude Code v2.1.149): `/exit` and Ctrl-C ×2 → 0; SIGTERM → 143; SIGKILL → 137.

**The current launch line conflates two non-zero cases** (`claude -c … || claude …`): resume-fails-to-start (want fresh fallback) vs ran-then-crashed (want marker kept, no inline relaunch). The `||` can't tell them apart. **Restructure required:**
```bash
start=$(date +%s)
claude -c … ; rc=$?
if [[ $rc -ne 0 && $(( $(date +%s) - start )) -lt 10 ]]; then
    # exited non-zero almost immediately → resume-failed-to-start → fresh fallback
    claude … ; rc=$?
fi
# branch on the FINAL rc:
[[ $rc -eq 0 ]] && rm -f "$working_dir/.claudemux-running"   # clean quit → stay dead
# non-zero after running ≥10s → crash → marker stays → tick resurrects (under crash-loop guard)
```
- The startup-time threshold (~10s, tunable) is the resume-failure-vs-crash discriminator.
- Must read the **final** claude's exit code, not the `||` chain's.
- Keep the wrapper at ≤2 process levels (see Liveness constraint).
- `--shutdown`/`--restart` also exit via `/exit` (rc 0): `--shutdown` already removed the marker (redundant), `--restart` re-writes it after relaunch. So the branch only *changes* behavior for manual `/exit` and crash.

## Resurrection policy: resume + crash-loop guard

- **Resume (`claude -c`), not fresh** — bringing back the working set is the point.
- **Crash-loop guard via uptime delta:** on each tick that finds a marked session dead, `uptime = now - last_attempt_ts`. `uptime < MIN_HEALTHY` → died fast → `death_count++`; else → ran fine → `death_count = 0`. **Trip at `death_count >= 3`.**
- **Constants:** `MIN_HEALTHY = 5 min`, trip threshold `= 3`.
- **On trip:** stop resurrecting; set `tripped=true` (tick skips tripped); keep the marker. Surface `failed` in `-l` + a one-shot notice routed to `home` ("Session X crash-looped 3× and was stopped. Likely a poisoned transcript — say 'restart X fresh'."). A user `restart`/`restart fresh` clears `tripped` and resets the counter. **Do NOT auto-fresh** (silent context loss; revisit in v2.1 once briefs exist).

## Staggering (avoid the reboot thundering-herd)

Cap concurrency by counting recent launches via the existing `last_attempt_ts` (no new state):
```
# STAGGER_CONCURRENCY=3 (configurable), STARTING_WINDOW=90s
ensure home up first   # home is NOT part of the batch
down = [ s if should_be_alive(s) and not claude_running_in_session(s) ]
in_flight = count(s where now - last_attempt_ts(s) < STARTING_WINDOW)
slots = STAGGER_CONCURRENCY - in_flight
for s in ordered(down)[:slots]:        # deterministic (sorted) order for v1
    last_attempt_ts(s) = now ; launch(s, resume)
```
~3 sessions per ~90s window; a 20-session set recovers in a few minutes, no spike.

**Sizing rationale:** measured idle per-session footprint ≈ 80-110 MB RSS / ~0% CPU (2026-06-07), so local resources are not the constraint (10 concurrent ≈ ~1 GB, trivial). The only plausible limit is API-side (token burst / rate limits), unmeasurable locally. `3` is a moderate default chosen as API-burst insurance — **configurable, tune from real reboot experience.**

## `-l` statuses

| Condition | Status |
|---|---|
| marker + claude alive (+ protected) | `running` / `protected` |
| marker + claude dead + `should_be_alive` + not tripped | `queued` |
| marker + claude dead + tripped | `failed` |
| marker + claude dead + `AUTORESTORE` off | `stopped` |
| no marker | `stopped` / `idle` |

`queued`/`failed` derive from existing state (marker + restore-state), no `capture-pane`. `starting` stays parked.

## Default-on + `AUTORESTORE`

On by default (headline reliability feature; opt-in would bury it). Single global `AUTORESTORE=true/false` config var ships from the start as the escape hatch (default `true`), covering the resource-cost concern and tmux-native surprise. Marker lifecycle is independent of the flag: markers are written/removed normally; `AUTORESTORE` only gates whether the tick *acts*.

## Extension point: auto-startup (out of scope)

A future `.claudemux-autostart` per-project marker = declarative "always keep this up" (generalizes what `home` already does). Drops into `should_be_alive()` as a second OR clause with no rework. Not built in v2.0.

## Verified assumptions (pre-build, 2026-06-07)

1. **LaunchAgent cadence** — CONFIRMED: `KeepAlive`+`ThrottleInterval=60` + one-shot `--autolaunch` ⇒ ~60s re-fire. Constraint: keep `--autolaunch` one-shot.
2. **`claude_running_in_session` depth** — CONFIRMED: 2 levels covers both launch paths (grandchild / direct child). Constraint: don't add a wrapper nesting level.
3. **Exit-code `||` conflation** — CONFIRMED problem: resume-fail vs crash both non-zero; restructure with a startup-time threshold (above).
4. Exit codes (0 vs 137/143) and idle footprint (~80-110 MB) — measured this cycle.

## Change-checklist impact (when built)

- New config var `AUTORESTORE` → `config.example`, `config_help()`, settings table in `implentation-spec.md`.
- New marker `.claudemux-running` → marker registry in `docs/CODEMAP.md`, `ensure_gitignore_entry()`.
- New state dir `~/.claude-mux/restore-state/` → CODEMAP global-state table.
- Modified: `autolaunch_dispatch`, the launch script (exit-code wrapper), `--shutdown`, `status_claude_sessions` (statuses), `create_claude_session`/`launch_single_session` (marker write) → CODEMAP + SKELETON.
- Release notes: behavior change (crash/`kill-session` resurrects within ~60s; `/exit` or `--shutdown` to truly stop).
- VERSION bump: minor (v2.0.0 is the milestone; sequencing per ISSUES.md).
