# Test plan: session-identity-reply

Companion to `session-identity-reply.md`. claude-mux is a bash tool with an
injection-prompt behavior change; "tests" are concrete manual procedures on throwaway
sessions plus artifact/build checks. The load-bearing properties (no permission prompts,
hard stop) are LLM-behavioral, so they need **repeated, multi-mode** trials, not one run.

## 0. Pre-build verification

| # | Check | How | Expected |
|---|---|---|---|
| 1 | `ready` rule is common (applies to home) | Read `build_system_prompt` | Rule after home interpolations, before per-session triggers |
| 2 | `${session_name}` + `${permission_mode}` in scope | Read function args | Both present ($1,$2), already interpolated |
| 3 | Reading `.git/HEAD` yields branch without shell | Read `.git/HEAD` on a repo | `ref: refs/heads/<branch>`; detached HEAD → raw SHA (→ omit) |
| 4 | `Fable` is a real user-visible family (HARD GATE) | live model list / claude-api ref | Confirmed `claude-fable-5` before baking into examples; else revert to Opus/Sonnet/Haiku |
| 5 | claude-mux memory index path | inspect a project with memory | Index is at `memory/MEMORY.md` (subdir), NOT project root |

## 1. Build / artifact checks

- `make build` regenerates `claude-mux`; `make check` clean.
- `make features-index` regenerated after frontmatter change.
- Built `claude-mux` contains the new greeting exactly once; old `Session ready!` two-line
  rule gone; `what is this session` rule present.
- **No raw git** (`git `, `git log`, `rev-parse`, `git branch`) string in either new rule
  (grep the built artifact) — sourcing is Read-only.

## 2. Permission-prompt safety (CRITICAL — the finding that sank the first draft)

Run `ready` under EACH mode — `default`, `plan`, `acceptEdits`, `bypassPermissions` — on a
throwaway git project:
- **Zero Bash permission prompts** in every mode.
- Also confirm the `.git/HEAD` Read is not blocked by any `.git`/dotfile deny rule (a
  distinct prompt path from Bash). If it is, branch degrades to omitted, not a hang.
- Repeat on a **bulk `--restart` of 3+ sessions** in `default` mode: no prompt storm, no
  session hangs.

## 3. Hard stop (CRITICAL — LLM-behavioral, repeat)

- Send `ready`; confirm the session emits the block and then **does not continue** — no
  extra turn, no work started.
- **Repeat ≥5× across models (Opus/Sonnet/Haiku) and modes.** Any run that continues into
  work is a FAIL. The lean design (no `Next:` line, no inference) exists to protect this.
- Confirm the floor (name + model/mode) is emitted **before** the `.git/HEAD` Read — i.e.
  even if the Read errors/denies, the floor still appears (N1). Simulate by pointing at a
  non-git dir and a `.git`-as-file worktree.
- Verify `on_prompt` still no-ops on the literal `Ready?` (tip/notice machinery
  short-circuits; SKELETON invariant intact).

## 4. Auto `ready` degradation matrix

| Case | Setup | Expected |
|---|---|---|
| normal branch | git repo on a branch | floor + `Branch: \`<branch>\`` |
| detached HEAD | `git checkout <sha>` | floor only (branch omitted) |
| worktree / submodule | session in a git worktree (`.git` is a file) | floor only (branch omitted, no error) |
| non-git | no `.git` | floor only == today's greeting + name |

Toggle by renaming `.git` / checking out a SHA / using a real worktree, then re-send
`ready`.

## 5. `what is this session`

- Rich git project: identity sentence + Session/Project/Model·Mode/Branch bullets + 2–4
  "What we've been working on" bullets + "Next step(s)" + one closing question.
- **Memory path:** bullets are sourced from `memory/MEMORY.md` (subdir), verified by
  planting a known entry there and seeing it surface; a project-root `MEMORY.md` is NOT
  read.
- **Purpose line is sourced, not invented:** derives from CLAUDE.md / memory; a project
  with neither degrades to "session in <dir>", not a fabricated purpose.
- Non-git: Branch bullet omitted; rest intact.
- Paraphrases (`what's this session`, `describe this session`) trigger the same block.
- **No drift with `status`:** model/mode phrasing matches the `status` rule; this rule does
  NOT run `claude-mux -l`.

## 6. Edge cases / regressions

- **`home` session:** `ready` names `home`; base dir may be non-git → floor only; home
  management rules unaffected.
- **`/clear` and `/compact` parity:** both still trigger the (now named) handshake,
  consistent with `clear-ready-handshake`.
- **Remote Control:** named greeting reaches RC; `<assistant-must-display>` verbatim rules
  undisturbed.

## 7. Post-build checks

- `dev/SKELETON.md` "Ready trigger" invariant updated to the lean shape, with the hard-stop
  / swallow / `on_prompt`-no-op sub-clauses preserved.
- README "Session System Prompt" matches the built injection.
- New tip in `claude-mux --tip` rotation, teaching `what is this session`.
- CHANGELOG + VERSION (2.4.0) + ISSUES updated.
