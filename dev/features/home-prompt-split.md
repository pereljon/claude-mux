---
kind: feature
lifecycle: shipped
feature: home-prompt-split
status: SHIPPED in v2.1.0 (committed aa6627c, RELEASED 2026-07-23, deployed to ~/bin). Architect APPROVE-WITH-NOTES (notes applied); code review APPROVE (0 findings). Full rollout ordering executed 2026-07-23: release -> restart home -> strip ~/Claude/CLAUDE.md (comms + template pointer; migration procedure relocated to ~/.claude-mux/analytical-project-migration.md) -> restart home. Other sessions pick up the injection on their next restart.
target_version: 2.1.0 (minor — changes session-visible injection behavior across all sessions; decided at build 2026-07-23)
related: model-switch-confirm, orchestrator-hub
---

# Feature: split the home orchestrator prompt out of the ancestor CLAUDE.md into claude-mux's home injection

## Problem (observed live 2026-07-22, in this very claude-mux dev session)
`~/Claude/CLAUDE.md` is written as the home session's **identity** ("**SYSTEM PROMPT: Home Session -
Session Orchestrator** … This is the home session … the only session with write access to
`~/.claude-mux/`"). But the home session's cwd **is** `~/Claude` (BASE_DIR), so that file is
simultaneously (a) home's own project CLAUDE.md and (b) the **ancestor** CLAUDE.md that Claude Code's
walk-up-the-tree loading injects into **every** project under `~/Claude/`. Confirmed live: this
session (`~/Claude/development/claude-mux`) loaded BOTH the project CLAUDE.md and the home
orchestrator file — so a project session is told it *is* the home orchestrator (false), and imports
orchestration/comms/config rules irrelevant to project work.

**Latent correctness bug it also fixes:** the line "All edits to `~/.claude-mux/` must be made from
**this session**" is written from home's POV. A project session loads that same line today and "this
session" ambiguously reads as *itself* — the opposite of the intent (it could think it holds config
authority).

## Verified current architecture (read 2026-07-22 — trust this, it's not assumed)
- **Single injection source:** `build_system_prompt()` at `src/30-helpers.sh:667`. Both launch paths
  call it — `launch_single_session` (`src/70-start-launch.sh:124`) and `create_claude_session`
  (`src/55-session-launch.sh:153`) — and the restart-in-place wrapper regenerates via
  `--print-system-prompt <session>` (dispatch `90-dispatch.sh`). So there is **one** edit site, not
  the "two injection functions" the old Change Checklist implies.
- **Home detection ALREADY EXISTS:** `build_system_prompt` gates home-only content on
  `[[ "$session_name" == "home" ]]` (`src/30-helpers.sh:676`), emitting `home_line` (home identity)
  and `home_management` (config/template self-management block).
- **The config grant is ALREADY home-gated:** `home_management` line `:684` — "Config and template
  edits must be done from the home session — only home has filesystem permissions for
  `~/.claude-mux/`." Home already gets the positive grant via injection.
- **The non-home prohibition is ABSENT:** the shared Rules block (`:706+`) has no "do not edit
  `~/.claude-mux/`" line. Non-home sessions currently get *nothing* about config — so the only place
  that guardrail exists today is the ambiguous ancestor-CLAUDE.md line. Stripping CLAUDE.md without
  adding it to the non-home injection would drop the guardrail entirely.
- **Consequence:** the mechanism the user imagined (a new fragment + home-detection) is largely
  already here. This feature mostly *relocates content into the existing home gate* + *adds one
  non-home line* + *strips CLAUDE.md*, rather than building new machinery.

## The categorization (step-4 analysis, the design core)
Three destinations. `[SHARED-CLAUDE]` loads into ALL `~/Claude/` sessions (home included) via
ancestor loading; `[HOME-INJ]` is emitted only when `session_name == "home"`; `[NON-HOME-INJ]` is a
line in the shared Rules block (reaches every session; phrase so it's correct for home too, or gate
it to non-home).

| Current `~/Claude/CLAUDE.md` content | Destination | Notes |
|---|---|---|
| Title "SYSTEM PROMPT: Home Session - Session Orchestrator" | HOME-INJ | identity; false for project sessions. Already partly covered by `home_line`. |
| `<context>` "This is the home session … project work happens in dedicated sessions" | HOME-INJ | overlaps existing `home_line` — consolidate, don't duplicate. |
| Communication Style (no filler, no emotional descriptors, **no em-dashes**, definitive statements) | SHARED-CLAUDE | stays in CLAUDE.md (per decision); good for every session. |
| …its line "Act without asking … **operational session in auto mode**" | HOME-INJ | home-specific posture; split out of the comms block. |
| Session Management ("`claude-mux -L` … protected … `--force`") | HOME-INJ | overlaps existing shared Rule `:714` (protected-session) — consolidate. |
| Config & Template Authority (both grant + prohibition) | **ONE role-neutral line, all sessions** | "config/template edits are home's responsibility; if you ARE home you may edit, else route to home." Replaces the home-only grant at `home_management:684`; self-disambiguates; kills the "this session" ambiguity. (Gating grant+prohibition separately is the fallback.) |
| Project Conventions (analytical-project template is source of truth) | SHARED-CLAUDE *(or HOME-INJ for leanness)* | user's own convention; fine to load into all the user's projects. NOT a forced isolation. |
| Migrating a project to the template (5-step procedure) | SHARED-CLAUDE *(or HOME-INJ for leanness)* | home-oriented, but harmless if shared. Judgment: keep in CLAUDE.md unless per-project context cost matters. |
| Project Directory Map (dev/metro18/personal/work table) | SHARED-CLAUDE *(or drop)* | redundant with live `claude-mux -L`; keep in CLAUDE.md if wanted, or drop and consult -L on demand. |

## What MUST be home-only vs what can be shared (corrected 2026-07-22)
Correction to an earlier over-complication in this doc: there is **NO necessary "home-only personal
content that must be isolated in its own file."** The only HARD rule is that **home-identity content
must not leak to children** (it is factually false for a project session — "you are the home
session"). Everything else is a placement *judgment*, not a forced isolation:
- **Shared user content is fine in `~/Claude/CLAUDE.md` even if personal.** The user's own
  orchestration conventions, project-structure norms, even the directory map can live in the ancestor
  CLAUDE.md and load into every project — they are all the *same user's* projects, so consistent
  conventions loading everywhere is desirable, not a leak. "Personal" ≠ "must isolate." (This drops
  the earlier options a/b/c home-only-file branch entirely.)
- **Only home-identity/role must be injected home-only** (false-if-leaked): "this is the home
  session," "you are the orchestrator," protected-as-self, the "operational / auto mode" posture.
- **Config/template authority ships with claude-mux as ONE role-neutral rule** (so every claude-mux
  user gets it without hand-authoring a CLAUDE.md): a single line correct for all sessions — "config
  and template edits (`~/.claude-mux/`) are the home session's responsibility; if you ARE the home
  session you may edit them directly, otherwise route the change to the home session." This
  self-disambiguates (kills the "this session" ambiguity) and removes the need for separate
  grant/prohibition gating — though gating (`home_management` grant + a `session_name != "home"`
  prohibition) remains a viable alternative if the neutral line reads awkwardly.

So the buckets collapse to three, no special file: (1) **home-identity/role** → home injection;
(2) **config authority** → one shipped role-neutral injection line; (3) **everything the user wants
shared** (comms style + any shared conventions/map) → stays in `~/Claude/CLAUDE.md`, loading into all
their sessions, no isolation required.

## Result after the split
- `~/Claude/CLAUDE.md` → keeps the **Communication Style** block (minus the "auto mode" line) plus
  ANY shared conventions the user wants everywhere; loses only the home-IDENTITY framing. No child
  is told it is the home session.
- Home-orchestrator identity/role → `build_system_prompt`'s existing home gate (consolidate the
  overlaps so it is not duplicated with CLAUDE.md).
- Config authority → one role-neutral injected line (ships generically; not dependent on CLAUDE.md).

## Build steps (ordered — pending architect review; anchors verified 2026-07-22)
0. **DECIDED (Q1): extend `home_management` in place** — no new fragment, no Makefile `MODULES`
   change. (If the text unexpectedly grows large enough to warrant a `home_orchestrator_prompt()`
   fragment, remember the landmine: a stray fragment not in `MODULES` compiles to nothing and
   `make check` stays green.)
1. **Consolidate the home gate** in `build_system_prompt` (`src/30-helpers.sh:676-691`): fold the
   home-orchestrator identity/role into the existing `home_line` / `home_management`, de-duplicating
   against shared Rule `:714`. No home-only-file pointer (dropped). Personal shared conventions stay
   in `~/Claude/CLAUDE.md`, so nothing personal needs to enter the shipped injection.
2. **Config authority as ONE role-neutral line.** Preferred: replace the home-gated grant (`:684`)
   with a single line emitted for ALL sessions in the shared Rules block (`:706+`): "Config and
   template edits (`~/.claude-mux/`) are the home session's responsibility; if you ARE the home
   session you may edit them directly, otherwise route the change to the home session." (Alternative:
   keep the home-gated grant AND add a `session_name != "home"` prohibition.) **Verify first**
   whether non-home sessions are actually OS-blocked from `~/.claude-mux/` — all sessions run as the
   same unix user, so the `:684` "only home has filesystem permissions" claim is likely convention,
   not enforcement, which is exactly why this rule is warranted regardless.
3. **Strip `~/Claude/CLAUDE.md`** per the Q4 resolution (keep comms style + analytical-project
   pointer; drop directory map; migration procedure moves to an on-demand doc with at most a
   one-line pointer). NOTE: this is a change to a file OUTSIDE this repo — coordinate final wording
   with the user; do not bundle it into a claude-mux commit.
   **HARD ORDERING (architect-required):** ship code → **restart home** (so its baked prompt carries
   the orchestrator identity) → strip CLAUDE.md → restart home again for the clean single-source
   state. NEVER strip before the post-ship home restart, or home is identity-bare in the gap.
   (Running sessions bake the prompt at launch; until the strip, CLAUDE.md still supplies identity,
   so home is covered on both sides of the sequence. Non-home sessions in the window just get
   today's known leak plus one harmless extra line — no regression.)
4. **Docs/version:** `make build` + `make check`; README "Session System Prompt" section MUST match
   the new injection; IMPLEMENTATION-SPEC injection docs; CHANGELOG; VERSION; SKELETON if the
   home/non-home branch changes flow; CODEMAP if a new fragment/function is added.

## Files to update (Change Checklist)
- `src/30-helpers.sh` — `build_system_prompt` home gate (consolidate home identity/role; NO
  personal-notes pointer, that branch is dropped) + the shared role-neutral config line. No new
  fragment (Q1: extend in place).
- `~/Claude/CLAUDE.md` — strip per Q4 resolution: keep comms style + analytical-project pointer;
  drop directory map; migration procedure moves to an on-demand doc (OUTSIDE repo; content approved
  2026-07-23, final wording at build step 3).
- README "Session System Prompt" section, `dev/IMPLEMENTATION-SPEC.md`, CHANGELOG, VERSION,
  `dev/SKELETON.md`, `dev/CODEMAP.md` (if a fragment/function is added).

## Open questions — ALL RESOLVED 2026-07-23 (user approved leans)
1. **New fragment vs extend `home_management` in place** — RESOLVED: extend in place. No new
   fragment, no Makefile `MODULES` change (avoids the stray-fragment landmine of build step 0).
   Revisit only if the text grows unexpectedly large during build.
2. **Config authority form** — RESOLVED: single role-neutral line in the shared Rules block,
   replacing the home-gated grant at `:684`. Self-disambiguating; ships generically.
3. **Is the config rule needed?** — RESOLVED: YES; verified 2026-07-23 against
   `setup_claude_mux_permissions()` (`src/50-restore-state.sh:549`). Home alone gets
   `Read/Edit/Write(~/.claude-mux/**)` allow rules + `additionalDirectories`; non-home sessions get
   NO deny rule, and all sessions run as the same unix user — a non-home session in bypass/auto mode
   (or via Bash) can physically write `~/.claude-mux/`. The `:684` "only home has filesystem
   permissions" claim is convention + prompt-friction, NOT enforcement. The injected rule is the
   guardrail; also reword away the false "filesystem permissions" claim.
4. **What stays in `~/Claude/CLAUDE.md`** — RESOLVED (user's call, 2026-07-23): KEEP Communication
   Style (minus the "auto mode" line, which moves to home-inj) and the analytical-project template
   pointer (project sessions are the ones that need it). DROP the Project Directory Map (redundant
   with `claude-mux -L`). MOVE the 5-step migration procedure OUT of the shared file to an on-demand
   doc home consults (path TBD at edit time, e.g. alongside the template in `~/.claude-mux/`), with
   at most a one-line pointer. Not a claude-mux code concern; coordinate at build step 3.
5. **Generality check (ship-scope)** — RESOLVED: the shipped claude-mux change is just (a) the home
   identity/role in the injection's existing home gate and (b) the role-neutral config line. All
   user-specific content stays in the user's own `~/Claude/CLAUDE.md` (shared) — nothing personal
   enters shipped code. That is the clean line.

## Recorded assumption: name-only home gate (architect note, 2026-07-23)
The injection gate keys on `session_name == "home"` (`src/30-helpers.sh:676`) while the permission
grant keys on `PROJECT_DIR == BASE_DIR` (`src/70-start-launch.sh:44,78`). A project folder whose
basename sanitizes to `home` OUTSIDE BASE_DIR would get the orchestrator *identity* injection but
not the `~/.claude-mux/**` grant. In practice tmux `has-session` dedup (`src/55-session-launch.sh:158`)
plus the always-on protected home session block a second live `home`, so this cannot easily manifest.
Accepted as-is; this feature escalates what rides on the name gate, so the assumption is recorded
here deliberately rather than left implicit. The wording of the config line should anchor to the
concrete signal the session actually has ("if this session is named `home`…" — the tmux-name header
at `:696` — not an abstract "if you ARE the home session").

## Out of scope
- The orchestrator-hub / dashboard work (separate parked investigation).
- Changing Claude Code's ancestor-CLAUDE.md loading behavior (upstream; not ours).

Test plan: `dev/features/home-prompt-split-tests.md`.
