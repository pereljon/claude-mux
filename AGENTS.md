# AGENTS.md

Guidance for Claude Code when working in this repository.

## Project

**claude-mux** -- persistent Claude Code sessions in tmux. Shell script + macOS LaunchAgent. Deliverables: `claude-mux`, `install.sh`, `config.example`, `com.user.claude-mux.plist`.

This is an open-source project with external users. Treat it accordingly: safety, portability, stability matter.

## Design Principles

Infrastructure, not a framework. Keep sessions alive, get out of the way.

- **Lean over featureful.** Don't duplicate what Claude Code or tmux already handle.
- **Support, don't impose.** Make Claude Code persistent and accessible, not reshaped.
- **Conversational first.** Natural language in-session is the primary interface.
- **Eliminate complexity, don't relocate it.** Every abstraction must remove more burden than it introduces.
- **Session management is invisible.** Claude should be able to manage sessions without permission prompts interrupting the conversation. Achieved two ways: (1) claude-mux is added to each project's allow list by `setup_claude_mux_permissions()` so Claude can run it freely; (2) the injection instructs Claude to use claude-mux rather than raw shell commands that would trigger prompts. Destructive operations (e.g. `--delete`) may still require confirmation - that's intentional, not a gap.
- **Session names, not paths.** CLI commands operate on session names, not directory paths. The script resolves session names to directories internally via tmux (running sessions) or `PROJECT_DIRS` scanning (idle projects). Exceptions that accept paths (e.g. `--move` destination, `-d`/`-n` launch directory) require explicit approval before adding.

## Documentation Roles

| File | Purpose |
|------|---------|
| `AGENTS.md` | Conventions, checklists, guardrails for working in this repo |
| `dev/IMPLEMENTATION-SPEC.md` | Product spec: architecture, config reference, design decisions, translation standards, deprecation policy |
| `docs/GUIDE.md` | Configuration, session details, internals, troubleshooting |
| `docs/ISSUES.md` | Open bugs, planned features, resolved issues |
| `dev/CODEMAP.md` | Function **purposes** (prose), config vars, dispatch table, marker file registry — for locating things in the script. The function→location index is generated (see next row) |
| `dev/CODEMAP.index.md` | **Generated** by `make codemap` — function→`module:within-module-line` index. Never hand-edit; guarded by `make check` |
| `dev/features/INDEX.md` | **Generated** by `make features-index` — the build queue projected from each feature doc's `kind:`/`lifecycle:` frontmatter. Read it after a context clear to see what's `ready` to build |
| `dev/SKELETON.md` | Pseudo-code showing script structure, logic flow, and key invariants — for understanding how the script works |
| `dev/features/<feature>.md` | Per-feature design doc: the implementable spec for a feature, extracted from `docs/ISSUES.md` once it's ready to build. MUST carry `kind:` + (for `kind: feature`) `lifecycle:` frontmatter |
| `dev/features/<feature>-tests.md` | Per-feature test plan: happy path, edge cases, verification steps, pre-build and post-build checks |

**Feature design + test docs convention (decided 2026-06-07):** when a planned feature in `docs/ISSUES.md` matures to "ready to build," lift it into a dedicated design doc at `dev/features/<feature>.md` and a matching test plan at `dev/features/<feature>-tests.md`. `docs/ISSUES.md` stays the planned-features tracker; the `dev/features/` pair is the implementable spec + test plan that the build works from. Verify assumptions the design rests on *before* finalizing the design doc, so the docs reflect verified reality, not assumptions.

**Feature-doc frontmatter (controlled vocab, enforced by `make features-index`):** every `dev/features/<feature>.md` carries `kind:` and, for `kind: feature`, a `lifecycle:`. The feature index FAILs the commit on a missing/unknown value, so these are not optional.
- **`kind:`** — `feature` (default; buildable) or `investigation` (analysis-only, no build lifecycle; excluded from the build queue, like `*-tests.md`).
- **`lifecycle:`** (exactly one of) — `idea` → `designing` → `ready` (design complete **and** architect-reviewed) → `building` → `shipped` (released/implemented; a "pending real-world test" caveat still counts as shipped) → plus `shelved` (parked) and `superseded` (abandoned/replaced). History/transient state goes in the free-text `status:` line, NOT in a new lifecycle value (e.g. reopened-from-shelved → `lifecycle: designing` + `status:` tells the story).
- After adding a feature doc or changing its `lifecycle`/`kind`, run `make features-index` (the pre-commit hook + CI enforce freshness).

## Non-Obvious Behaviors

Behaviors that affect how code changes should be made - session lifecycle, restart ordering, the `Ready?` handshake, injection delivery, upgrade detection - live in `dev/SKELETON.md` (Key Invariants). Read it before touching session launch/restart, the `on_prompt` hook, or the injection prompt - these facts are not derivable from the code. Full architecture is in `dev/IMPLEMENTATION-SPEC.md`; `dev/CODEMAP.md` has the authoritative function→location index.

## Project Folder Indicators - Marker-File Philosophy

Per-project state lives in the project folder, not in central config. State files use the prefix `.claudemux-` and are auto-added to `.gitignore` when claude-mux creates them in a git-tracked project.

Current markers (`.claudemux-ignore`, `-protected`, `-running`, `-restarting/`, `-prompt`), who creates and removes each, and what it means: `dev/CODEMAP.md` "Marker File Registry".

**Why marker files, not config:**
- State follows the folder across renames, moves, and machine syncs.
- Discoverable from `ls -la` inside the project.
- One gitignore pattern (`.claudemux-*`) covers all current and future markers.
- No central registry to corrupt or drift.

**Conventions when adding new per-project state:**
- Boolean flags: empty file at `.claudemux-<name>` (`touch`), presence = on. Long-lived.
- Transient locks: directory at `.claudemux-<name>/` (`mkdir`/`rmdir`). `mkdir` is atomic (claim-this-name fails if it exists), so it doubles as a mutex; `.claudemux-restarting` uses this. Rule of thumb: `mkdir` for locks, `touch` for flags.
- Richer state: JSON file at `.claudemux-<name>.json` (no current cases).
- Always auto-gitignore via `ensure_gitignore_entry()`.
- Folder-name conventions (`-prefix` and `.prefix`) are legacy and still respected by `discover_projects()`, but new features use markers.

**When NOT to use marker files:**
- Truly user-global preferences → `~/.claude-mux/config`.
- Truly session-runtime state → tmux user options (e.g. `@claude-mux-protected`).
- Markers are for state that should travel with the project folder.

## Security Context

Single-user tool on the user's own account. Threat model: accidental footguns (path traversal, injection via user-supplied args), not multi-user or adversarial scenarios.

## Known Issues / Hypotheses

See `lessons/index.md` (entry: bypassPermissions launch behavior).

## Working Rules

- **Consult docs before coding**: before writing any code or starting a debug session, read `dev/SKELETON.md` to understand the logic flow and `dev/CODEMAP.md` to locate the relevant functions. Don't grep blind.
- **Questions vs. implementation**: answer questions as questions. Don't start coding until explicitly asked.
- **No speculation as fact**: distinguish what you know from what you're guessing. Say "I'm not sure" when you can't verify.
- **No LLM-stereotype writing** in human-facing content: no "delve", "leverage", "streamline", "excited to share". Write like a developer.

## Interactive Commands

Commands that attach (`-t`, `-d`/`-n` without `--no-attach`) are user-only -- never run from inside a session. From inside sessions:
- Safe: `-l`, `-L`, `-s`, `--shutdown`, `--restart`, `--permission-mode`, `--list-templates`, `--guide`
- Must add `--no-attach`: `-d`, `-n`
- Never use: `-t`

## Development Workflow

`claude-mux` is a **generated, committed artifact**, built from `src/*.sh` by `make build`. Source of truth is `src/`.

- **Edit `src/*.sh`, never `claude-mux` directly.** A direct edit to `claude-mux` is silently reverted by the next `make build`.
- After editing fragments: `make build`, then `cp claude-mux ~/bin/` to deploy locally (after commit). Smoke-test with `bash ./claude-mux ...`.
- `make check` (`make build && git diff --exit-code claude-mux`) must pass before any commit; the mandatory pre-commit hook enforces this. Install the hook once per clone: `make install-hooks` (sets `core.hooksPath .githooks`).
- Merge conflicts in `claude-mux` are resolved by rebuilding from `src/` (`make build`), never by hand-merging the artifact (`.gitattributes` marks it generated).
- See `dev/IMPLEMENTATION-SPEC.md` "Build / source layout" for the module map.

Before coding any change, apply the **Consult docs before coding** rule (Working Rules) to scope what's affected before editing.

### Worktree Policy

- **Behavior changes** (new command, config var, workflow/injection behavior) get an isolated worktree/branch (per `superpowers:using-git-worktrees`) before landing on `main`. Report when creating one - no need to ask first (it's local and reversible, unlike commit/push/release).
- **Docs-only or trivial fixes** (typos, translation tweaks, one-line ISSUES/CHANGELOG edits) can land directly on `main` - a worktree adds ceremony with no payoff at that size.
- **Code review runs in the same worktree/branch**, not a separate one: review the diff before merging, fix findings there, then merge. A worktree isolates the change from `main`; review is part of finishing that change, not a new one.
- **A major-release review (X.0.0)** gets its own dedicated worktree/branch (e.g. `release/2.0.0-review`), separate from any single feature's branch, since it reviews the accumulated surface across multiple prior features and may collect several fix commits before one merge + tag.
- Solo-maintainer project: default to **merging locally** unless the user asks for a PR - there is no second reviewer requiring one.
- **Testing sequence: merge -> verify -> push.** `make check` must pass before every commit (already enforced by the pre-commit hook). After merging into `main`, re-run `make check` on `main` itself before pushing - a merge changes what's on disk even when it's a fast-forward, so the merged tree, not the pre-merge branch, is what gets pushed and deployed.

### Workflow Pipeline

The canonical 15-step order of a change (define, verify, design docs, worktree, code, review, context files, test, commit, merge, deploy, push, release, clear) is in the `claude-mux-change-pipeline` skill (`.claude/skills/claude-mux-change-pipeline/SKILL.md`). Commit, push, and release remain independent approval gates (see Git Approvals).

### Code Review Before Release

Required scope depends on version bump:

- **Patch (x.y.Z)**: review only the changed functions
- **Minor (x.Y.0)**: review all functions added or modified in the release
- **Major (X.0.0)**: full code review of the entire script

Use `dev/SKELETON.md` to understand the impact on logic flows and `dev/CODEMAP.md` to identify which functions changed and what calls them. Use the `superpowers:code-reviewer` agent. Address CRITICAL and HIGH issues before committing.

## Git Approvals

Each step requires explicit user approval. Approval for one step does not imply approval for the next.

1. **Worktree**: report when creating a new git worktree (e.g. via `superpowers:using-git-worktrees` or an `EnterWorktree`-style tool) - no need to ask first, since the Worktree Policy above already decides when one applies. It's local and reversible, unlike commit/push/release. Ask only when it's genuinely ambiguous whether a change counts as "behavior change" (worktree) vs. "trivial" (main) under that policy.
2. **Commit**: propose the commit message and changed files, wait for approval before running `git commit`
3. **Push**: wait for explicit approval before running `git push`
4. **Release**: only the user can authorize a release. A release requires all three: `git tag vX.Y.Z`, `git push origin vX.Y.Z`, and `gh release create vX.Y.Z`. "Commit" or "push" do not imply release. Pushing a tag alone does NOT create a GitHub Release.
   - **Release gate**: only tag a release if the deliverable script, its installer, or its packaged config/service templates changed since the last release - those are the only assets an install or upgrade actually consumes. Docs-only changes are already available via the repo and don't need a release. (Injection prompt changes count as script changes - they alter session behavior.)
   - **Release order matters**: the Homebrew bump CI triggers on every `gh release create` and blindly sets the formula to that version. Always create releases in ascending version order. If backfilling an older release after a newer one is already live, manually update the tap formula afterward.

After completing work, proactively ask which steps the user wants: "Want to commit, push, or release?"

After a release completes, clear the session: `claude-mux -s SESSION_NAME '/clear'` where SESSION_NAME is the current tmux session name. The next build cycle needs no context from this one (the cross-cycle handoff lives in the feature docs and memory, not the transcript), so clear rather than compact.

## Testing Plan

Before coding a new feature or change, review with the user: happy path, edge cases, flag conflicts, config migration, injection prompt updates, display changes. Get confirmation before writing code.

## Change Checklist

**GATE: Do NOT suggest commit, push, or release until every item below has been checked and all affected files are updated.** This is not optional - it is a prerequisite before proposing any git operation.

After any code change, check whether these need updating:

- **`make build` + `make check`** — code edits go in `src/*.sh`; rebuild the `claude-mux` artifact and confirm `make check` is clean (it now also runs `check-codemap` + `check-features-index`). The pre-commit hook blocks otherwise. (Never edit `claude-mux` directly.)
- **`make codemap`** — after adding/renaming/moving/removing a function in `src/*.sh`, regenerate `dev/CODEMAP.index.md` (the location index; never hand-edit it). Then update the function's **purpose** row in `dev/CODEMAP.md` by hand.
- **`make features-index`** — after adding a feature doc or changing its `kind`/`lifecycle` frontmatter, regenerate `dev/features/INDEX.md`. (`make check` / pre-commit / CI fail if either index is stale.)
- `README.md` + `translations/README.*.md` (translation standards in `dev/IMPLEMENTATION-SPEC.md`)
- `config.example` + `~/.claude-mux/config` (new settings)
- `install.sh` (new flags, config generation)
- `dev/IMPLEMENTATION-SPEC.md` (architecture, settings table, function docs)
- `AGENTS.md` (if key behaviors changed)
- **Injection prompt** in both `create_claude_session` (`src/55-session-launch.sh`) and `launch_single_session` (`src/70-start-launch.sh`)
- **Session System Prompt** section in README (must match injection)
- `dev/CODEMAP.md` (function **purpose** rows, new dispatch cases, new config vars) + `make codemap` for the generated location index
- `dev/features/INDEX.md` via `make features-index` (when a feature doc's `kind`/`lifecycle` changed)
- `dev/SKELETON.md` (logic flow changes: new conditions, changed call sequences, new control paths)
- `ISSUES.md` (new bugs, resolved entries)
- `CHANGELOG.md` (new features, fixes, removals per release)
- `VERSION=` bump if needed (semver: patch/minor/major)
- Deprecation: warn for 1-2 minor versions before removing (details in `dev/IMPLEMENTATION-SPEC.md`)
- **When adding a config var**: update `config_help()` in the script and add an entry to `config.example`
- **When adding a CLI flag**: update `commands_help()` in the script and the compressed feature list in `build_system_prompt()`
- **When adding a new lookup flag** (`--*-help`, `--*-commands`): add it to the Reference lookups meta-block in `build_system_prompt()`
- **When adding a user-facing feature**: add a tip to `internal/tips.md` and embed it in the `tip_of_day()` array in the script. Tips teach users how to use conversational commands (the injection triggers), not CLI flags or internal implementation details.

When proposing or making multiple changes, consider logical ordering -- some changes should be performed before others (e.g. move code to a new location before updating references to it, validate inputs before using them).
