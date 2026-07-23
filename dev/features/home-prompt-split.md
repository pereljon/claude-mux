---
kind: feature
lifecycle: designing
feature: home-prompt-split
status: DESIGNING 2026-07-22. Architecture VERIFIED against src this session (build_system_prompt already gates home content). Pre-architect-review. Sequence AFTER model-switch-confirm (v2.0.14) ships — both touch the injection.
target_version: TBD (leaning minor, e.g. 2.1.0 — it changes session-visible injection behavior across all sessions); decide at build
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
0. **If a new fragment is used** for a `home_orchestrator_prompt()` helper (to keep large text out of
   `30-helpers.sh`), it MUST be added to the Makefile explicit `MODULES` list (same landmine as
   model-switch-confirm — a stray fragment compiles to nothing, `make check` stays green). If instead
   we extend the existing `home_management` string in place, no Makefile change. **Decide first.**
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
3. **Strip `~/Claude/CLAUDE.md`** to the Communication Style block. NOTE: this is a home-orchestration
   change to a file OUTSIDE this repo — coordinate/confirm the final content with the user; do not
   bundle it into a claude-mux commit.
4. **Docs/version:** `make build` + `make check`; README "Session System Prompt" section MUST match
   the new injection; IMPLEMENTATION-SPEC injection docs; CHANGELOG; VERSION; SKELETON if the
   home/non-home branch changes flow; CODEMAP if a new fragment/function is added.

## Files to update (Change Checklist)
- `src/30-helpers.sh` — `build_system_prompt` home gate (consolidate + personal-notes pointer) + the
  non-home config-prohibition line. (Optionally `src/XX-orchestrator-prompt.sh` + Makefile `MODULES`
  if a helper fragment is used.)
- `~/Claude/CLAUDE.md` — strip to comms-only (OUTSIDE repo; confirm with user).
- Personal home-only notes file (option a) — path TBD (`~/.claude-mux/home.md` or
  `~/Claude/.home-orchestrator.md`); OUTSIDE repo.
- README "Session System Prompt" section, `dev/IMPLEMENTATION-SPEC.md`, CHANGELOG, VERSION,
  `dev/SKELETON.md`, `dev/CODEMAP.md` (if a fragment/function is added).

## Open questions (resolve before finalizing)
1. **New fragment vs extend `home_management` in place** (build step 0). Lean: extend in place unless
   the text gets large enough to warrant a `home_orchestrator_prompt()` helper fragment.
2. **Config authority: single role-neutral line vs grant+prohibition gating** (build step 2). Lean
   the single neutral line (simpler, self-disambiguating, ships generically).
3. **Is the config rule needed, or are non-home sessions actually blocked?** Verify the real
   permission behavior for `~/.claude-mux/` writes from a non-home session (likely convention, not OS).
4. **What shared conventions (if any) the user keeps in `~/Claude/CLAUDE.md`** beyond comms style —
   directory map, analytical-project conventions, migration procedure are all fine to keep there
   (loading into the user's own projects) or to drop in favor of on-demand `claude-mux -L` / template
   lookups. User's call; not a claude-mux code concern.
5. **Generality check (ship-scope):** the shipped claude-mux change is just (a) the home
   identity/role in the injection's existing home gate and (b) the role-neutral config line. All
   user-specific content stays in the user's own `~/Claude/CLAUDE.md` (shared) — nothing personal
   enters shipped code. That is the clean line.

## Out of scope
- The orchestrator-hub / dashboard work (separate parked investigation).
- Changing Claude Code's ancestor-CLAUDE.md loading behavior (upstream; not ours).

Test plan: `dev/features/home-prompt-split-tests.md`.
