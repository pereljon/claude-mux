# CLAUDE.md

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
- **Session management is invisible.** Claude should be able to manage sessions without permission prompts interrupting the conversation. Achieved two ways: (1) claude-mux is added to each project's allow list by `setup_claude_mux_permissions()` so Claude can run it freely; (2) the injection instructs Claude to use claude-mux rather than raw shell commands that would trigger prompts. Destructive operations (e.g. `--delete`) may still require confirmation — that's intentional, not a gap.
- **Session names, not paths.** CLI commands operate on session names, not directory paths. The script resolves session names to directories internally via tmux (running sessions) or `PROJECT_DIRS` scanning (idle projects). Exceptions that accept paths (e.g. `--move` destination, `-d`/`-n` launch directory) require explicit approval before adding.

## Documentation Roles

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Conventions, checklists, guardrails for working in this repo |
| `implentation-spec.md` | Product spec: architecture, config reference, design decisions, translation standards, deprecation policy |
| `README.md` | End-user installation, usage, configuration |
| `CHANGELOG.md` | What changed per release |

## Non-Obvious Behaviors

These affect how code changes should be made. Full architecture is in `implentation-spec.md`.

- **Tmux-aware sessions**: each session gets `--append-system-prompt` with its tmux session name for self-referencing slash commands via `send-keys`
- **Multi-coder symlinks**: `AGENTS.md`/`GEMINI.md` created as symlinks to `CLAUDE.md`. Configurable via `MULTI_CODER_FILES`.
- **Ready trigger**: sends `Ready?` after Claude loads; expects "Session ready!" response to confirm session is alive
- **Output display tags**: listing commands wrap output in `<assistant-must-display>` XML tags when stdout is not a TTY
- **Caller-last restart ordering**: `--restart` (all) from inside a session restarts the calling session last
- **Home session**: session named `home` in `$BASE_DIR`, protected by default (via `$BASE_DIR/.claudemux-protected` marker, created by `--install`), requires `--force` to shut down
- **Version injection**: `get_version_prompt_lines()` reads `~/.claude-mux/.update-check`; if a newer version is cached, it appends an update note telling Claude to notify the user and suggest "update claude-mux"
- **Session status**: `>` prefix marks the calling session (via `$TMUX_PANE`); `protected` status for protected+running sessions; `stopped` for protected+not-running

## Project Folder Indicators — Marker-File Philosophy

Per-project state lives in the project folder, not in central config. State files use the prefix `.claudemux-` and are auto-added to `.gitignore` when claude-mux creates them in a git-tracked project.

| Marker | Meaning |
|---|---|
| `.claudemux-ignore` | Hide project from `claude-mux -L` and `discover_projects()` |
| `.claudemux-protected` | Set `@claude-mux-protected = 1` on the tmux session at launch |

**Why marker files, not config:**
- State follows the folder across renames, moves, and machine syncs.
- Discoverable from `ls -la` inside the project.
- One gitignore pattern (`.claudemux-*`) covers all current and future markers.
- No central registry to corrupt or drift.

**Conventions when adding new per-project state:**
- Boolean flags: empty file at `.claudemux-<name>`, presence = on.
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

- **`bypassPermissions` confirmation prompt**: Claude shows a warning with "No, exit" / "Yes, I accept" when launched with `bypassPermissions`. The startup poller detects "Yes, I accept", sends Down (to move from option 1 to option 2), waits 1s for the UI to register the selection, then sends Enter. The 1s pause is critical — without it the keystrokes race and confirm "No, exit" instead.
- **`bypassPermissions` requires restart to enter**: cannot switch a running session to `bypassPermissions` mid-session — must restart with the flag. Once in the Shift+Tab cycle, re-entry from other modes is silent (no prompt). Confirmation prompt only fires on initial launch.

## Working Rules

- **Questions vs. implementation**: answer questions as questions. Don't start coding until explicitly asked.
- **No speculation as fact**: distinguish what you know from what you're guessing. Say "I'm not sure" when you can't verify.
- **No LLM-stereotype writing** in human-facing content: no em dashes, no "delve", "leverage", "streamline", "excited to share". Write like a developer.

## Interactive Commands

Commands that attach (`-t`, `-d`/`-n` without `--no-attach`) are user-only -- never run from inside a session. From inside sessions:
- Safe: `-l`, `-L`, `-s`, `--shutdown`, `--restart`, `--permission-mode`, `--list-templates`, `--guide`
- Must add `--no-attach`: `-d`, `-n`
- Never use: `-t`

## Development Workflow

Edit the repo copy (`claude-mux`), not the installed copy (`~/bin/claude-mux`). Deploy after commit: `cp claude-mux ~/bin/`

### Code Review Before Release

Required scope depends on version bump:

- **Patch (x.y.Z)**: review only the changed functions
- **Minor (x.Y.0)**: review all functions added or modified in the release
- **Major (X.0.0)**: full code review of the entire script

Use the `superpowers:code-reviewer` agent. Address CRITICAL and HIGH issues before committing.

## Git Approvals

Each step requires explicit user approval. Approval for one step does not imply approval for the next.

1. **Commit**: propose the commit message and changed files, wait for approval before running `git commit`
2. **Push**: wait for explicit approval before running `git push`
3. **Release**: only the user can authorize a release. A release requires all three: `git tag vX.Y.Z`, `git push origin vX.Y.Z`, and `gh release create vX.Y.Z`. "Commit" or "push" do not imply release. Pushing a tag alone does NOT create a GitHub Release.
   - **Release order matters**: the Homebrew bump CI triggers on every `gh release create` and blindly sets the formula to that version. Always create releases in ascending version order. If backfilling an older release after a newer one is already live, manually update the tap formula afterward.

After completing work, proactively ask which steps the user wants: "Want to commit, push, or release?"

After a release completes, compact the session: `claude-mux -s SESSION_NAME '/compact'` where SESSION_NAME is the current tmux session name.

## Testing Plan

Before coding a new feature or change, review with the user: happy path, edge cases, flag conflicts, config migration, injection prompt updates, display changes. Get confirmation before writing code.

## Change Checklist

**GATE: Do NOT suggest commit, push, or release until every item below has been checked and all affected files are updated.** This is not optional — it is a prerequisite before proposing any git operation.

After any code change, check whether these need updating:

- `README.md` + `translations/README.*.md` (translation standards in `implentation-spec.md`)
- `config.example` + `~/.claude-mux/config` (new settings)
- `install.sh` (new flags, config generation)
- `implentation-spec.md` (architecture, settings table, function docs)
- `CLAUDE.md` (if key behaviors changed)
- **Injection prompt** in both `create_claude_session` and `launch_single_session`
- **Session System Prompt** section in README (must match injection)
- `ISSUES.md` (new bugs, resolved entries)
- `CHANGELOG.md` (new features, fixes, removals per release)
- `VERSION=` bump if needed (semver: patch/minor/major)
- Deprecation: warn for 1-2 minor versions before removing (details in `implentation-spec.md`)
- **When adding a config var**: update `config_help()` in the script and add an entry to `config.example`
- **When adding a CLI flag**: update `commands_help()` in the script and the compressed feature list in `build_system_prompt()`
- **When adding a new lookup flag** (`--*-help`, `--*-commands`): add it to the Reference lookups meta-block in `build_system_prompt()`
- **When adding a user-facing feature**: add a tip to `internal/tips.md` and embed it in the `tip_of_day()` array in the script

When proposing or making multiple changes, consider logical ordering -- some changes should be performed before others (e.g. move code to a new location before updating references to it, validate inputs before using them).
