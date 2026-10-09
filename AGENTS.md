# AGENTS.md

Guidance for Claude Code when working in this repository. Shared workflow rules (working rules, testing, design docs, branches and approvals, Change Checklist gate, releases, session hygiene) live in `../AGENTS.md`; this file adds claude-mux specifics.

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
| `dev/CODEMAP.index.md` | **Generated** by `make codemap` — function→`module:within-module-line` index. Guarded by `make check` |
| `dev/features/INDEX.md` | **Generated** by `make features-index` — the build queue projected from each feature doc's `kind:`/`lifecycle:` frontmatter. Read it after a context clear to see what's `ready` to build |
| `dev/SKELETON.md` | Pseudo-code showing script structure, logic flow, and key invariants — for understanding how the script works |
| `dev/features/<feature>.md` | Per-feature design doc, lifted from `docs/ISSUES.md` once the feature is ready to build |
| `dev/features/<feature>-tests.md` | Per-feature test plan: happy path, edge cases, verification steps, pre-build and post-build checks |

**Feature-doc frontmatter is mandatory here** (the optional convention in `../AGENTS.md`, enforced): `make features-index` FAILs the commit on a missing or unknown `kind:`/`lifecycle:`. `ready` means design complete **and** architect-reviewed; "pending real-world test" still counts as `shipped`. After adding a feature doc or changing its `lifecycle`/`kind`, run `make features-index`.

## Non-Obvious Behaviors

Session lifecycle, restart ordering, the `Ready?` handshake, injection delivery, upgrade detection: see `dev/SKELETON.md` (Key Invariants). Read it before touching session launch/restart, the `on_prompt` hook, or the injection prompt. Before any code or debug session, read `dev/SKELETON.md` for the logic flow and `dev/CODEMAP.md` to locate functions. Don't grep blind.

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

Single-user tool on the user's own account. Threat model: accidental self-inflicted mistakes (path traversal, injection via user-supplied args), not multi-user or adversarial scenarios.

## Known Issues / Hypotheses

See `lessons/index.md` (entry: bypassPermissions launch behavior).

## Interactive Commands

Commands that attach (`-t`, `-d`/`-n` without `--no-attach`) are user-only -- never run from inside a session. From inside sessions:
- Safe: `-l`, `-L`, `-s`, `--shutdown`, `--restart`, `--permission-mode`, `--list-templates`, `--guide`
- Must add `--no-attach`: `-d`, `-n`
- Never use: `-t`

## Development Workflow

`claude-mux` is a **generated, committed artifact**, built from `src/*.sh` by `make build`. Source of truth is `src/`.

- **Edit `src/*.sh`, never `claude-mux` directly.** A direct edit is silently reverted by the next `make build`.
- After editing fragments: `make build`, then `cp claude-mux ~/bin/` to deploy locally (after commit). Smoke-test with `bash ./claude-mux ...`.
- `make check` (`make build && git diff --exit-code claude-mux`) is this project's test run: it must pass before any commit, and on `main` after a merge. The pre-commit hook enforces it; install once per clone with `make install-hooks`.
- `.gitattributes` marks `claude-mux` generated.
- Module map: `dev/IMPLEMENTATION-SPEC.md` "Build / source layout".

The canonical order of a change is in the `claude-mux-change-pipeline` skill.

## Testing Plan

In addition to the shared test-plan review: config migration, injection prompt updates, display changes.

## Code Review

Use `dev/SKELETON.md` to understand the impact on logic flows and `dev/CODEMAP.md` to identify which functions changed and what calls them. Major (X.0.0) review covers the entire script.

## Releases

- **Release gate**: the deliverables are the script, `install.sh`, and the packaged config/service templates. Injection prompt changes count as script changes - they alter session behavior.
- Immediately before `git tag`, `make check` must pass clean.
- **Release order matters**: the Homebrew bump CI triggers on every `gh release create` and blindly sets the formula to that version. Always create releases in ascending version order. If backfilling an older release after a newer one is already live, manually update the tap formula afterward.
- After a release, clear the session (`../AGENTS.md` Session hygiene).

## Change Checklist

Project rows, in addition to the shared gate and generic items in `../AGENTS.md`:

- **`make build` + `make check`** — code edits go in `src/*.sh`; rebuild and confirm `make check` is clean (it also runs `check-codemap` + `check-features-index`).
- **`make codemap`** — after adding/renaming/moving/removing a function in `src/*.sh`, regenerate `dev/CODEMAP.index.md`, then update the function's **purpose** row in `dev/CODEMAP.md` by hand.
- **`make features-index`** — after adding a feature doc or changing its `kind`/`lifecycle`.
- `translations/README.*.md` alongside `README.md` (translation standards in `dev/IMPLEMENTATION-SPEC.md`)
- `config.example` + `~/.claude-mux/config` (new settings)
- `install.sh` (new flags, config generation)
- `dev/IMPLEMENTATION-SPEC.md` (architecture, settings table, function docs)
- **Injection prompt** in both `create_claude_session` (`src/55-session-launch.sh`) and `launch_single_session` (`src/70-start-launch.sh`)
- **Session System Prompt** section in README (must match injection)
- `dev/CODEMAP.md`: new dispatch cases, new config vars
- `VERSION=` (semver)
- Deprecation: warn for 1-2 minor versions before removing (details in `dev/IMPLEMENTATION-SPEC.md`)
- **When adding a config var**: update `config_help()` and add an entry to `config.example`
- **When adding a CLI flag**: update `commands_help()` and the compressed feature list in `build_system_prompt()`
- **When adding a new lookup flag** (`--*-help`, `--*-commands`): add it to the Reference lookups meta-block in `build_system_prompt()`
- **When adding a user-facing feature**: add a tip to `internal/tips.md` and embed it in the `tip_of_day()` array. Tips teach conversational commands (the injection triggers), not CLI flags or internals.
