---
kind: feature
lifecycle: idea
feature: terminate-session
status: IDEA 2026-06-22 (concept captured; not yet designed/architect-reviewed).
target_version: unscheduled
severity: N/A (enhancement) — gives a "destructive stop" (next start is fresh) distinct from today's "stop = pause-and-resume".
related: context-cost-awareness, model-switching-cost-research
---

# Feature (idea): `terminate` a session — stop now, start FRESH next time (EC2 stop vs terminate)

## Concept
Model it on AWS EC2:
- **stop** = pause. The instance/session is preserved; starting it again **resumes** where it left
  off. This is today's `--shutdown` + `--start`/`--restart` (which resume via `claude -c`).
- **terminate** = destructive. Stop the session AND mark it so the **next start begins a FRESH
  conversation** (no resume), not a continuation.

Today claude-mux only has the "stop = resume" model (plus `--restart --fresh` / "restart this
session fresh" / "kill this session", which restart fresh *immediately*). There is no "stop now,
fresh *later*" — that's the gap `terminate` fills.

## Proposed behavior
- New command `--terminate SESSION` + conversational triggers "terminate this session" /
  "terminate session NAME".
- It stops the session like `--shutdown` (clean teardown, removes `.claudemux-running` so
  auto-restore won't bring it back), AND writes a one-shot **`.claudemux-terminate`** marker in the
  project folder.
- On the **next** start of that project (`--start`, `--restart`, or an explicit relaunch), the
  launch path checks for `.claudemux-terminate`: if present → launch **fresh** (omit the `-c`
  resume flag, like `--fresh`) and **remove the marker** (one-shot). Subsequent starts resume
  normally again.

## Mechanism (fits the marker-file philosophy)
- `.claudemux-terminate` is a **boolean, one-shot** flag (`touch` to set; presence = "next start is
  fresh"; removed when consumed). Per CLAUDE.md marker conventions: `touch` for flags, auto-gitignored
  by the existing `.claudemux-*` pattern (`ensure_gitignore_entry`).
- **Reuses the existing fresh-launch path.** `create_claude_session`/`launch_single_session` already
  support a `fresh_start`/no-`-c` mode (used by `--restart --fresh`, the wrapper's `_resume=''` when
  the `@claude-mux-restart` option is `fresh`). Terminate just sets `fresh_start=true` at the next
  start when the marker is present, then `rm` the marker. Minimal new surface.

## Open design questions (for brainstorming / architect)
- **Does terminate DELETE the conversation transcript, or just not resume it?** "Fresh start" only
  requires omitting `-c` — the old `.jsonl` transcript under `~/.claude/projects/<encoded>/` stays on
  disk (recoverable via `claude --resume`). True EC2-terminate is destructive, but deleting a
  transcript is real data loss. RECOMMENDATION: default to **non-resume only** (keep the transcript,
  just don't load it); optionally offer a `--terminate --purge` that also archives/removes the
  transcript, behind explicit confirmation. Capture as a decision, lean non-destructive-to-data.
- **Protection:** terminate is destructive-ish → mirror `--shutdown`'s protection (home/protected
  sessions need `--force`?). Probably yes.
- **Naming/overlap clarity:** distinguish four verbs cleanly — `stop`/`shutdown` (pause, resume next),
  `terminate` (stop, fresh next), `restart --fresh` / "kill" (fresh NOW), `delete` (move project to
  trash). Make the injection trigger rules unambiguous so Claude picks the right one.
- **Auto-restore:** terminate removes `.claudemux-running`, so the `--autolaunch` tick won't restore
  it (stays down until a manual start) — confirm that's the desired semantics (it matches "stopped").
- **What if the session is currently running?** terminate stops it first (like shutdown), then writes
  the marker. Caller-self terminate (terminate the session you're in) — does it make sense, and does
  it use the in-place path? Likely "terminate this session" = stop self + marker; the next manual
  start is fresh. (Can't fresh-restart-in-place and also "stay stopped" — terminate means stay down.)
- **vs just using `--restart --fresh`:** that restarts immediately. Terminate is for "I'm done now,
  but when I come back I want a clean slate" without keeping it running. Different intent/timing.

## Files to update (when built — Change Checklist sketch)
- `src/*.sh`: new `--terminate` flag parse (`src/10-flags.sh`), dispatch (`src/90-dispatch.sh`),
  the terminate command (stop + write marker), and the start-path marker check+consume
  (`src/55`/`src/70`/the `--start`/`--restart`/autolaunch path).
- Marker registry + conventions in CLAUDE.md ("Project Folder Indicators"): add `.claudemux-terminate`.
- `commands_help()` (`src/10-flags.sh`), the compressed feature list + trigger rules in
  `build_system_prompt()` (`src/30-helpers.sh`) — add "terminate this session / terminate SESSION".
- `docs/GUIDE.md`, `docs/CLI.md`, `README.md` (conversational examples), `dev/IMPLEMENTATION-SPEC.md`,
  `dev/CODEMAP.md`, `dev/SKELETON.md`, CHANGELOG, a tip in `internal/tips.md` + `tip_of_day`.

## Out of scope (unless explicitly chosen)
- Deleting/purging transcripts by default (data loss) — make it opt-in if offered at all.
- Anything beyond the resume-vs-fresh distinction (terminate is NOT delete-the-project; that's
  `--delete`).
