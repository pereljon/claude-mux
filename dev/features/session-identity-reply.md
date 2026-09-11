---
kind: feature
lifecycle: ready
feature: session-identity-reply
status: READY 2026-08-17. Architect-reviewed twice; second pass APPROVE-WITH-CHANGES, all changes folded in (breadcrumb dropped from auto `ready`; branch on its own line so the floor is emitted first; memory path corrected to `memory/MEMORY.md`; worktree `.git`-file handled; Fable kept, basis noted; SKELETON hard-stop sub-clauses called out). Sourcing is Read-only (no raw git). Not yet built.
target_version: 2.4.0 (minor) — enriches the ready handshake + adds a new conversational identity trigger; injection-behavior change
severity: N/A (enhancement) — orientation-on-reconnect UX; the current handshake gives no session name and no situational context
related: clear-ready-handshake, ready-handshake, tip-ready-handshake
---

# Feature: named `ready` handshake + `what is this session`

## Problem

Two gaps in session self-report:

1. The `ready` handshake replies `Session ready! / Running [model] in [mode] mode.` — it
   never names **which** session, so on reconnect (especially Remote Control, where
   sessions look alike) the user can't tell them apart.
2. There is no conversational way to ask a session to describe itself. The format should
   be consistent (identity + recent work + next step), not improvised.

## Design constraints (from two architect reviews — these shaped the design)

- **No raw shell in the reply path.** The injection already tells sessions never to use
  raw `git`/`ls`/`tmux` because it triggers **permission prompts** (`src/30-helpers.sh`
  ~line 712; only the `claude-mux` binary is allowlisted per project). Raw `git` on every
  `ready` would contradict that and cause a **prompt storm on bulk `--restart` /
  autolaunch** — unanswerable for RC/mobile users. **All sourcing is via the Read tool**
  (no prompt), never a shell command.
- **The hard stop is load-bearing.** `ready` fires on autolaunch and bulk restart; its
  job is confirm-and-STOP, never start work. The auto reply carries **no `Next:` line** and
  no next-step inference. Rich inference lives only in on-demand `what is this session`.
- **Unconditional floor, emitted first.** The name + model + mode lines are emitted
  **before any Read**. Enrichment (branch) is a separate later line, best-effort, that can
  contribute nothing. Worst case == today's greeting + the session name.
- **No per-restart file cost.** The auto reply does **not** read `MEMORY.md` (dropped by
  decision 2026-08-17): unreliable at project root, and a Read on every autolaunch tick is
  cost on a turn whose job is an instant confirm. The only Read in the auto path is
  `.git/HEAD` for the branch, which is cheap and prompt-free.

## Design

Two injection rules in `build_system_prompt()` (`src/30-helpers.sh`), the single source of
the prompt (both launchers call it). No new CLI flag, config var, or shell logic. Uses
`${session_name}` / `${permission_mode:-auto}` (already in scope). The `ready` rule is in
the **common** trailing rules (verified ~line 716, after the home interpolations), so it
applies to `home` too.

### 1. `ready` handshake — lean, replaces the current two-line rule

Floor (always, emitted first, before any tool call):

```
Session `<session_name>` is ready!
Running <model> in <mode> mode
```

Then one best-effort line, appended only if it resolves:
- **Branch:** on its **own line** `Branch: \`<branch>\``, obtained by **Reading
  `.git/HEAD`** (`ref: refs/heads/<branch>` → `<branch>`). Omit the line entirely if:
  no `.git/HEAD` (non-git, or a worktree/submodule where `.git` is a *file* not a dir),
  or a detached HEAD (HEAD holds a raw SHA, no `refs/heads/`). No shell, no `git`.

Rendered example (git repo):
```
Session `claude-mux` is ready!
Running Opus 4.8 in auto mode
Branch: `main`
```
Rules baked into the injection text:
- **Model name:** report the actual name as Claude Code shows it, **version-inclusive if
  known** ("Opus 4.8"). Parenthetical family examples stay family-only:
  `Opus/Sonnet/Haiku/Fable`. (Fable is a current family, `claude-fable-5`, verified against
  this session's live model list; it is simply not yet reflected in the old examples. Do
  not enumerate versions in the examples.)
- **Hard stop:** emit the floor first, then the branch line if resolvable, then STOP — no
  further turn until the user speaks; do not begin work. No `Next:` line.

### 2. New rule — `what is this session` (on-demand, full block)

Placed after the `status` rule (~line 719). Rendered shape:

```
This is the `<session_name>` session — <one-sentence purpose>.

• Session name: `<session_name>`
• Project: <path>
• Model: <model> · Mode: <mode> (<meaning>)
• Branch: `<branch>`            ← only if `.git/HEAD` Read yields a branch

What we've been working on:
• <2–4 bullets, Read-sourced: memory/MEMORY.md, then docs/ISSUES.md>

Next step(s): <one line>

<one short closing question>
```

- **Purpose line (sourced, not invented):** from the project's `CLAUDE.md` (its opening
  description) or, failing that, the first entry of `memory/MEMORY.md`; if neither exists,
  a plain "session in <dir>".
- **Work bullets:** Read `memory/MEMORY.md` (the claude-mux memory index — note the
  `memory/` subdir, NOT project root), then `docs/ISSUES.md`. Read tool only.
- **Branch:** the same `.git/HEAD` Read trick; omit if unresolved.
- **No raw git anywhere.** Omit any bullet whose source is absent.

### Relationship to the existing `status` rule (avoid drift)

`status` stays operational and unchanged: session name, model, permission mode, context
estimate, then `claude-mux -l`. `what is this session` is the **identity/orientation**
block and does **not** run `-l`. To prevent drift it uses the **same model/mode phrasing**
as `status`. They answer different questions: `status` = "operational state + fleet list";
`what is this session` = "who am I and what am I doing."

## Degradation ladder (auto `ready`)

Floor is unconditional; the branch line is the only variable:

| `.git/HEAD` state | Ready reply |
|---|---|
| normal branch | floor + `Branch: \`<branch>\`` |
| detached HEAD (raw SHA) | floor only (branch omitted) |
| worktree/submodule (`.git` is a file) | floor only (Read of `.git/HEAD` fails → omitted) |
| non-git | floor only == today's greeting + name |

## Files touched (Change Checklist)

- `src/30-helpers.sh` — rewrite the `ready` rule; add the `what is this session` rule
  (`make build`; `make check`).
- `dev/SKELETON.md` — update the "Ready trigger" Key Invariant (~901–902) to the new lean
  shape. **Preserve these sub-clauses:** the turn still emits only its own reply (no
  further turn), the injected literal `Ready?` is still swallowed and `on_prompt` still
  no-ops on it, and the hard-stop "do not begin work" wording survives. The only change is
  the reply *shape* (named floor + optional branch line) and that the turn may now make a
  single `.git/HEAD` Read before emitting the branch line.
- `README.md` "Session System Prompt" section — mirror the new injection.
- `internal/tips.md` + `tip_of_day()` array — a tip teaching `what is this session`.
- `CHANGELOG.md`; `VERSION` → 2.4.0; `docs/ISSUES.md` entry.
- No `dev/CODEMAP.md` change (no function added/renamed; prompt text only). No config var,
  no CLI flag.
- Follow the **Injection rule checklist** standard.
