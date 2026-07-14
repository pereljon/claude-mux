---
kind: feature
lifecycle: idea
feature: terminate-session
status: IDEA 2026-06-22 (concept + pre-termination behavior + concurrency boundary captured; not yet architect-reviewed). One verification item open (SessionStart on fresh launch).
target_version: unscheduled
severity: N/A (enhancement) — gives a "destructive stop" (next start is fresh) distinct from today's "stop = pause-and-resume".
related: context-cost-awareness, model-switching-cost-research, restart-in-place
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

## Pre-termination behavior: what to offer before terminating (decided 2026-06-22)

Hard constraint that shapes everything: **only the in-session Claude can produce a
handoff.** The `--terminate` shell command manages tmux/processes; it cannot read
conversation content. So anything that captures "what I was doing" must be written *by the
session itself, before it exits*. This splits by trigger:

- **Conversational** ("terminate this session"): Claude is present — it can write a
  handoff, then call `--terminate` on itself. Natural path.
- **CLI / remote** (`--terminate NAME` from home): the target Claude is not running the
  command. A handoff would require messaging the target, waiting for it to write, then
  terminating. More moving parts; **handoff is conversational-path-only** unless we later
  build a request-then-wait flow.

### Recommendations on the three options raised

1. **Warning / confirmation — YES, always.** Terminate breaks continuity (next start
   won't resume). Confirm like `--delete`: in-chat confirmation for the conversational
   trigger; protected/home sessions require `--force`. Prevents the footgun of "terminate"
   meaning "just stop."

2. **Write current context to files (raw dump) — NO.** The transcript already lives on
   disk at `~/.claude/projects/<encoded>/*.jsonl` and **stays there after terminate**
   (terminate omits `-c`, it does not delete). Fully recoverable via `claude --resume`. A
   raw dump duplicates that and defeats the clean-slate purpose.

3. **Handoff for next session — YES, but curated and opt-in.** This is the genuinely
   useful one, and it reframes terminate as the missing middle between **compact**
   (continuity, but context keeps growing) and **fresh** (cheap, but amnesia):
   terminate-with-handoff = clean low-cost context **seeded with intent** (current task,
   state, next steps, key files). Directly serves the `context-cost-awareness` thread:
   "reset the meter without losing the plot." Curated note, NOT a raw dump.

### Verification needed before designing the handoff (OPEN)

A fresh launch (no `-c`) still fires Claude Code's **SessionStart hook**, which already
loads a "Previous session summary" into a session (it did so for the home session this
very run). So the machinery to seed a fresh session may largely already exist. **Verify
how the SessionStart summary behaves on a `-c`-less (fresh) launch** before committing to
a handoff mechanism. Two candidate mechanisms, pick after verifying:

- **(a) Reuse SessionStart summary** — terminate just ensures a fresh summary is written,
  then leans on the existing summary system to seed the fresh session. Leaner; reuses
  proven machinery. **Lean toward this if verification shows fresh launches get the
  summary.**
- **(b) Bespoke `.claudemux-handoff.md`** — terminate writes a one-shot handoff file that
  the fresh-launch path explicitly points the new session at (consumed/removed on read).
  More explicit and self-contained, but duplicates the summary system.

### Decisions to pin (carry into the design doc when it matures)

| # | Decision | Recommendation |
|---|---|---|
| 1 | Warning/confirm before terminate | YES — in-chat + `--force` for protected. |
| 2 | Offer a handoff | YES — opt-in, conversational-path-only, curated not raw. |
| 3 | Handoff mechanism | Verify SessionStart-on-fresh first; lean (a) reuse summary. |
| 4 | Raw transcript | Keep on disk; never auto-dump or delete. Purge stays separate + opt-in (see Open design questions). |

## Concurrency / multiple-live-sessions-per-project boundary (raised 2026-06-22)

User's question: does a terminate/handoff mechanism eventually lead to **multiple live
sessions from a single project**, with the concurrency that implies?

**Answer: it does not have to, and the design should explicitly keep that door shut.**
Terminate/handoff is **sequential by construction** — terminate *stops* the session, then
a *later* start (fresh) picks up the baton. The handoff is a baton pass between
**sequential** sessions of one folder, never a fork primitive. Building it does not
require, imply, or move us toward concurrent sessions.

The slope only appears if "seed a session from a handoff" were later generalized into
"spawn a *second, parallel* seeded session on the same folder." That would collide with
several core invariants and is a much bigger feature — **out of scope here and not a
prerequisite for terminate.**

### Why multiple-live-per-folder is a can of worms (for the record)

claude-mux is 1:1 session↔folder by design (session name = folder basename; markers and
history are folder-scoped). Two live `claude` processes on one folder would break:

- **Session name collision** — name is derived from the basename; two sessions need a
  disambiguating scheme.
- **Transcript clobber** — Claude Code stores history per encoded project path; two live
  processes interleave/clobber the same `.jsonl` and make `-c`/`--resume` ambiguous.
- **Marker races** — `.claudemux-running`, `.claudemux-restarting/`, `.claudemux-prompt`
  (mode-600, regenerated per launch) are folder-scoped; concurrent sessions race/overwrite
  them.
- **Working-tree edit conflicts** — two agents editing the same files concurrently. The
  deepest problem, and not one claude-mux can paper over.
- **Hook / build / test races** — per-session hooks acting on shared folder state.

### The escape hatch already exists: worktrees, not multi-live

If parallel work on one project is ever wanted, the right primitive is **git worktrees** —
each worktree is a **separate folder**, so it gets its **own session naturally**,
preserving the 1:1 invariant and sidestepping every hazard above. claude-mux already aligns
with this (the broader tooling uses worktree isolation for parallel agents). So:
**parallelism = more folders (worktrees), not more sessions per folder.** Terminate/handoff
stays a sequential baton; multi-live is intentionally not pursued.

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
