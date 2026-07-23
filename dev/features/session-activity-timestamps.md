---
kind: feature
lifecycle: designing
feature: session-activity-timestamps
status: DESIGNING 2026-07-15 (decisions captured from live brainstorm; pre-architect-review). Hook landscape verified against src/. SessionStart source token for /clear to be confirmed empirically at build.
target_version: 2.1.0 (minor) — new capability, new hook, new per-project marker
severity: N/A (enhancement) — feeds v2.0 situational-awareness + v2.1 context-discipline
related: context-cost-awareness.md, terminate-session.md, tip-ready-handshake.md, notice-delivery-reliability.md
---

# Feature: per-session activity timestamps

Record when each session was created, last used, last compacted, etc., in a durable
per-project marker file, and use those timestamps for **sort-by-recency**, **relative-age
display** in listings, and a **context-discipline staleness nudge**. Auto-unload of
inactive sessions is explicitly deferred to a follow-on (see Out of scope).

## Decisions (from brainstorm 2026-07-15)

- **Store:** one durable JSON marker per project, `.claudemux-activity.json`, epoch seconds.
  Chosen over tmux user options because the headline uses (sort stopped projects,
  reason about inactivity) require timestamps that **outlive the session**; tmux options
  die with the session. Matches the documented "richer state → JSON marker" convention.
- **Goals in scope (all four the user picked):** sort by recency; relative-age display;
  context-discipline nudge. Auto-unload **deferred**.
- **`/clear` tracking included:** requires a new `SessionStart` hook (see Hook additions).
  User chose to add it now rather than defer.

## Timestamp fields

`.claudemux-activity.json` (epoch seconds; `null`/absent = unknown):

| Field | Meaning | Written at | Reset semantics |
|---|---|---|---|
| `created` | folder's first-ever claude-mux launch | launch, only if field absent | never overwritten |
| `conversation_started` | age of the *current* conversation | new `SessionStart` hook when `source ∈ {startup, clear}`; also on first create | resets on `/clear` and fresh start; **survives** resume + compact |
| `last_activity` | last real user prompt or `-s` command | `on_prompt`, **after** the `Ready?` handshake no-op | bumped every real prompt |
| `last_compact` | last `/compact` | `on_compact` (existing PreCompact) | — |
| `last_restart` | last restart (in-place or kill+recreate) | restart paths | — |
| `stopped_at` | last clean shutdown | `shutdown_single_session` (clean, non-preserve) | cleared/updated on next launch |

Optional, low-cost, flagged for the build decision (not required): `last_mode_switch`,
`last_model_switch`. Skip unless wanted — lean over featureful.

### Why `last_activity` must skip the handshake

The synthetic `Ready?` prompt claude-mux sends itself after every restart/compact-reconnect
would otherwise bump `last_activity`, making a just-restarted-but-untouched session look
active and defeating the inactivity signal. Same class as `tip-ready-handshake.md`.
`on_prompt` already no-ops on `Ready?`; place the `last_activity` write **after** that
early-exit. **Restructure note:** the write must also precede the existing "both features
off" and other early-exits in `on_prompt`, so activity is always stamped on a real prompt
regardless of `TIP_OF_DAY`/`UPDATE_CHECK`.

## Storage details

- Path: `<project>/.claudemux-activity.json`, mode default, auto-gitignored (the existing
  `.claudemux-*` pattern via `ensure_gitignore_entry()` already covers it).
- Format: flat JSON, epoch seconds. Written with a single `python3 -c json.dump` (atomic
  enough for single-user; temp+rename if we want to be strict).
- **Read-modify-write:** each write reads the existing file, updates one field, writes back
  — so concurrent writers (e.g. `on_prompt` + `on_compact` near-simultaneously) don't clobber
  sibling fields. Single-user, low contention; last-writer-wins on a field is acceptable.
- Travels with the folder across rename/move/sync (marker-file philosophy).

## Hook additions

New **`SessionStart`** hook: `--on-session-start` handler in `src/75-tip-notices.sh` (or a
new module). It:
1. Reads `source` from the hook's stdin JSON.
2. Stamps `conversation_started = now` when `source ∈ {startup, clear}` (fresh conversation);
   leaves it untouched for `resume`/`compact` (continuation).
3. Also ensures `created` is set (first-ever launch).

Registration mirrors the existing `UserPromptSubmit`/`PreCompact` wiring:
- `src/50-restore-state.sh`: add `SessionStart` to the ensure-hooks python blocks + the
  desired-state matcher.
- `--install-hooks`: backfill `SessionStart` into pre-existing projects.
- `src/10-flags.sh`: `--on-session-start` flag + help; `src/90-dispatch.sh`: dispatch case.

**Verify at build:** the exact `source` token Claude Code emits for `/clear` (expected
`"clear"`). The SessionStart hook mechanism itself is confirmed (this repo's sessions
already receive SessionStart context injections).

## Uses

### 1. Sort by recency
`status_claude_sessions()` (`src/40-shutdown.sh:152`) and the idle-project loop read each
project's `.claudemux-activity.json`, key on `last_activity` (fallback `created`, then
folder mtime, then 0), sort descending.

**Sub-decision (flag for review):** does recency become the *default* order, or opt-in via
a `LIST_SORT=status|recency|name` config? Changing the default reorders everyone's `-l`/`-L`.
Recommendation: `LIST_SORT` config, default `recency` (it's the more useful order and the
feature's point), documented in CHANGELOG. The `<assistant-must-display>` all-rows-verbatim
rule is order-agnostic, so sorting doesn't conflict with it.

### 2. Relative-age display
New helper `fmt_relative_age(epoch)` → `"2h ago"`, `"3d ago"`, `"just now"`. Appended per
row in the status output (e.g. running: `used 2h ago`; idle: `idle 4d`). Keep it terse so
it doesn't bloat the line.

### 3. Context-discipline staleness nudge
Surface staleness **in the listing**, not as an injected `on_prompt` nudge (injection is the
noisy tip/notice channel; keep it clean). Heuristic: `conversation_started` old AND
(`last_compact` absent OR long ago) → mark the row (e.g. `⚠ stale — consider compacting`).
Thresholds via config with conservative defaults. Pure display; never auto-acts.

## Edge cases

| Case | Behavior |
|---|---|
| First-ever launch | `created` + `conversation_started` set; others absent. |
| Restart (resume) | `last_restart` bumped; `conversation_started` **unchanged** (same conversation). |
| `/clear` | `conversation_started` reset to now; `created` unchanged. |
| Compact | `last_compact` bumped; `conversation_started` **unchanged**. |
| `Ready?` handshake | No `last_activity` bump (write is after the handshake no-op). |
| Missing/corrupt `.claudemux-activity.json` | Treated as all-unknown; listing falls back to folder mtime, then unsorted-stable. Never errors. |
| Pre-feature project (no file) | Created lazily on first write; sorts to bottom until then. No backfill needed for correctness. |
| Clock skew / multi-machine | Epoch seconds; display humanizes. Skew only affects sort order cosmetically. |

## Why moderate-risk (minor, not patch)

- Adds a **new hook** (`SessionStart`) registered across all projects + backfill — new
  surface, must not break existing hook wiring.
- Adds a **new per-project marker** and a per-prompt write in the `on_prompt` hot path
  (tiny, single-user, but in a hot path).
- Changes listing output (age column) and possibly default sort order (behavior change).
- Mitigations: every read falls back to "unknown" and never errors; writes are best-effort
  (`|| true`); the activity write is isolated from the tip/notice logic.

## Files to update (Change Checklist)

- `src/75-tip-notices.sh` (or new module): `--on-session-start` handler; `last_activity`
  write in `on_prompt` (post-handshake, pre-feature-guards); `last_compact` write in
  `on_compact`; activity read/write helpers (`activity_stamp`, `activity_read`).
- `src/55-session-launch.sh` + `src/70-start-launch.sh`: stamp `created`/`conversation_started`
  at launch (both wrappers).
- `src/40-shutdown.sh`: `stopped_at` on clean shutdown; recency sort + `fmt_relative_age`
  display + staleness marker in `status_claude_sessions()`; `last_restart` on restart paths.
- `src/50-restore-state.sh`: register `SessionStart` hook (ensure + matcher); backfill.
- `src/10-flags.sh`: `--on-session-start` flag + help; `LIST_SORT` config help + staleness
  threshold config.
- `src/90-dispatch.sh`: dispatch `--on-session-start`.
- `src/00-defaults.sh`: `VERSION=2.1.0`; `LIST_SORT` default; staleness thresholds.
- `config.example` + `config_help()`: `LIST_SORT`, staleness thresholds.
- `dev/CODEMAP.md` + `make codemap`: new functions + config vars + dispatch case + the new
  `.claudemux-activity.json` marker in the marker registry.
- `dev/SKELETON.md`: `on_prompt` restructure (activity write ordering), new hook flow,
  listing sort/display path.
- `dev/IMPLEMENTATION-SPEC.md`: timestamps section, new hook, marker.
- `CLAUDE.md`: marker-file table gets `.claudemux-activity.json`; hook list gains SessionStart.
- `README.md` + translations: activity/age in listings, if user-facing enough.
- `CHANGELOG.md`: new feature; note the default-sort change if adopted.
- `docs/ISSUES.md`: move this from planned to in-progress/resolved.
- `internal/tips.md` + `tip_of_day()` array: a tip about sort-by-recency / age display.
- `dev/features/INDEX.md` via `make features-index` after lifecycle changes.

## Out of scope (follow-on)

- **Auto-pause/stop/unload inactive sessions** — the only destructive use. Deferred by user
  decision ("build safe parts first"). When built: opt-in config, conservative threshold,
  and it MUST never touch `home` or any protected session. Ties into `terminate-session.md`
  and `context-cost-awareness.md`.
- Injected (`on_prompt`) staleness nudges — kept as listing display only, to avoid adding
  to the tip/notice injection channel.
- `last_mode_switch` / `last_model_switch` — optional; add only if wanted.
