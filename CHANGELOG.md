# Changelog

All notable changes to claude-mux are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.7.0] — 2026-04-26

### Added
- **Update notifications**: cached daily check against GitHub releases API. Displays one-line notification on interactive TTY when a newer version is available. Re-notifies weekly. Configurable via `UPDATE_CHECK=true/false`.
- **`--update` self-update**: downloads latest release from GitHub (or delegates to `brew upgrade` if installed via Homebrew). Offers to restart running sessions after update.
- **Dynamic path detection**: `tmux` and `claude` resolved via `command -v` at startup instead of hardcoded `/opt/homebrew/bin` paths. Supports Intel Mac, custom installs, and future Linux. Override via `TMUX_BIN`/`CLAUDE_BIN` in config.
- **Installer dependency warnings**: warns (non-blocking) if tmux or claude are not found at install time.
- **Installer upgrade mode**: detects existing `~/.claude-mux/config` and skips interactive prompts on reinstall, preserving user settings.

### Fixed
- **`send-keys` key-name injection**: all `tmux send-keys` calls now use `-l` (literal) flag for content, preventing tmux from interpreting text as key names.
- **`-s` command validation**: slash commands sent via `-s` must start with `/` and cannot contain newlines, preventing accidental or malicious injection into other sessions.
- **`perm_flags` shell injection**: permission mode flags in generated launch scripts are now split into name/value variables, preventing word-splitting or injection from a malformed mode value.
- **TMPDIR guard**: expanded from single-quote check to reject spaces, dollar signs, backticks, and double quotes in TMPDIR.
- **Temp file permissions**: explicit `chmod 600` on launch and prompt temp files after `mktemp`.
- **JSON escaping for `CLAUDE_MUX_BIN`**: permissions.allow entry now passes the path directly to Python instead of interpolating into a JSON string literal, correctly handling backslashes and quotes in the path.
- **Restart caller session**: `--restart` (all) now correctly recreates the calling session via a background handoff process instead of silently dropping it after SIGHUP.

### Changed
- CLI Reference section moved to end of README (before Troubleshooting), reinforcing that conversational usage is primary.

## [1.6.2] — 2026-04-26

### Added
- **`<assistant-must-display>` output tags**: listing commands (`-l`, `-L`, `--list-templates`) wrap output in XML tags when stdout is not a TTY, instructing Claude to display the full output verbatim. Fixes Sonnet summarizing session listings instead of showing them.
- **Table headers on session listings**: `-l` and `-L` output now includes STATUS, SESSION, DIRECTORY column headers.

### Changed
- **README restructured**: "Talking to Claude" section now leads after Quick Start, emphasizing conversational usage as the primary interface. CLI flags moved to "CLI Reference" section. "What It Does" simplified from 12 numbered items to 8 concise bullets.
- **Caller-last restart ordering**: when `--restart` (all) is invoked from inside a session, the calling session restarts last so it can finish restarting the others first.

### Fixed
- **Spanish translation fully regenerated** to match restructured English README.

## [1.6.1] — 2026-04-25

### Added
- **`ready` trigger on session start**: claude-mux sends `ready` after Claude finishes loading; Claude responds with "Ready." confirming the session is alive and the injection is working. Replaces the old "No response requested." behavior.

### Changed
- **Faster session restarts**: reduced typical restart time from ~12s to ~2s by replacing fixed `sleep` waits with 0.5s polling loops that detect Claude's input prompt and send `ready` immediately.
- **Faster shutdown polling**: reduced max shutdown wait from 30s to 10s, polling every 0.5s instead of 1s.

## [1.6.0] — 2026-04-24

### Added
- **Multi-CLI-coder integration**: claude-mux now creates `AGENTS.md` and `GEMINI.md` as symlinks of `CLAUDE.md` so Codex CLI, Gemini CLI, and other AI coders pick up the same project instructions. Auto-applies on every session start (new or existing project), idempotent. Configurable via `MULTI_CODER_FILES`; opt-out per-project with `--no-multi-coder` (with `-n`).
- **"Why" section in README**: short motivation paragraph above Quick Start to help new readers understand the problem solved.
- **CONTRIBUTING.md**: dev workflow, testing requirements, version bump policy, deprecation policy, translation contribution guide.
- **GitHub issue and PR templates**: `.github/ISSUE_TEMPLATE/` for bug, feature, and translation; `.github/PULL_REQUEST_TEMPLATE.md`.
- **CHANGELOG.md** (this file): backfilled from prior releases, maintained going forward.
- **Deprecation policy** documented in `CLAUDE.md`: features deprecated for one or two minor versions before removal, with warnings.

### Changed
- Installer prints clearer warnings about LaunchAgent autostart and auto-approval permissions so new users understand what's being enabled.

## [1.5.0] — Internationalization (2026-04-23)

### Added
- **12 README translations**: Spanish, French, German, Brazilian Portuguese, Japanese, Korean, Italian, Russian, Simplified Chinese, Hebrew, Arabic, Hindi. Files live in `translations/` with a language switcher at the top of each.
- **Language-agnostic injection rule**: trigger phrases like "help", "status", "stop this session", "switch to plan mode" work in any language. Claude infers intent from the user's native language and runs the matching command. Output stays in its original format.
- **Translation standards** documented in `CLAUDE.md`: covers what stays in English (CLI flags, product names, status keywords, system prompt block), what gets translated (prose, headers, conversational labels, inline shell comments, table descriptions), and script-aware placeholder rules.

### Fixed
- **Permission auto-approval matching**: session permission patterns now include both bare-name (`Bash(claude-mux *)`) and absolute-path (`Bash(/path/to/claude-mux *)`) forms so Claude Code's permission matcher recognizes commands regardless of how they're invoked. Migrated all existing project `.claude/settings.local.json` files.

### Removed
- **`LAUNCHAGENT_MODE=batch`**: removed (was deprecated). Existing configs warn and fall back to `home`. Legacy `LAUNCHAGENT_ENABLED=true` now maps to `home` (was `batch`).

### Deprecated
- **`-a` flag**: still functional, marked internally as a candidate for future removal. Home session plus conversational on-demand starts cover most use cases at lower resource cost.

## [1.4.0] (2026-04-19)

### Added
- **`--guide` command**: lists all conversational trigger phrases for use within sessions. Available as both a CLI flag and an in-conversation "help" command.
- **Conversational trigger phrases**: 15 natural-language commands baked into every session injection (help, status, list active/all sessions, start/stop/restart sessions, start new session, switch mode/model, compact, clear, list templates).
- **`--permission-mode MODE SESSION`**: switch a session's Claude permission mode (`plan`, `auto`, `bypassPermissions`, `dontAsk`, `dangerously-skip-permissions`, etc.) without leaving the conversation. Injection prompt teaches Claude that "yolo" is an alias for `dangerously-skip-permissions`.
- **Status injection rule**: saying "status" in any session reports session name, current model, current permission mode, context usage, then runs `-l`.
- **MIT License**.

### Fixed
- Template path traversal: templates are now bounds-checked against `TEMPLATES_DIR` before being applied.
- Installer plist substitution: replaced `sed` with Python to handle paths containing `|`.
- Temp file cleanup: prompt file is now removed on send-keys failure.
- Exit codes: all dispatch paths return explicit `exit 0`.
- Dry-run accuracy for `--restart`: reports "Would restart" instead of simulating kill.

## [1.3.0] (2026-04-15)

### Added
- Slash command rule in injection prompt: explicit instruction that Claude can send slash commands via `-s` and should never claim it cannot.
- `ISSUES.md`: known issues log.

### Fixed
- Multiple commands returned exit code 1 despite success — added explicit `exit 0` to all dispatch paths.
- Communication standards in CLAUDE.md: no LLM-stereotype writing, no em dashes in human-facing content.

## [1.2.0] (2026-04-12)

### Added
- **Home session**: an always-running protected session in `$BASE_DIR` that launches at login. Defaults to Sonnet (configurable via `HOME_SESSION_MODEL`). Always protected from accidental shutdown — `--shutdown home` requires `--force`.
- **`LAUNCHAGENT_MODE`**: configures LaunchAgent at-login behavior (`none`, `home`, `batch` — `batch` later removed in 1.5).
- **Auto-approve claude-mux in project permissions**: `setup_claude_mux_permissions()` adds claude-mux to each project's `.claude/settings.local.json` allow list.
- **Interactive installer**: `install.sh` prompts for install location, base directory, home session, and model. `--non-interactive` mode for scripted setups.
- **Restart improvements**: `--restart` remembers which sessions were running and only relaunches those. Bypasses home protection.
- **`--force` flag**: required to shut down protected sessions.
- **Multiple session arguments**: `--shutdown` and `--restart` accept multiple session names.

### Fixed
- `$TMUX` variable shadowing tmux's environment variable — renamed to `$TMUX_BIN`.
- Bash 3.2 incompatibility with associative arrays — replaced with string-based collision detection.
- `pgrep -P` unreliable on macOS — replaced with `ps -eo` + `awk`.

## [1.1.0] (2026-04-08)

### Added
- **CLAUDE.md template system**: maintain `~/.claude-mux/templates/*.md`, apply to new projects via `--template NAME` or default.
- **`-n DIRECTORY`**: create a new Claude project (git init, .gitignore, permission mode, template).
- **`-p` flag**: with `-n`, create directory and parents if they don't exist.
- **`--no-template`, `--no-git`, `--no-permission-mode`**: opt-out flags for `-n`.
- **Tmux quality-of-life**: mouse, 50k scrollback, clipboard (OSC 52), 256-color, reduced escape delay, extended keys (Shift+Enter), activity monitoring, terminal tab titles. All configurable.
- **`-s SESSION COMMAND`**: send a slash command to a running session via tmux send-keys.
- **`-L`**: list all projects (active + idle).
- **Session statuses**: active, running, stopped, idle.
- **Three-column status display**: status, name, path.
- **`-d DIRECTORY`**: explicit single-directory launch.
- **`-t SESSION`**: attach to a session by name.
- **`-l`**: list active sessions.
- **GitHub SSH account awareness**: detects accounts in `~/.ssh/config`, injects host aliases into the session prompt.

### Changed
- Renamed from `claude-autorc` to `claude-mux`.
- Default behavior changed from batch to single-directory launch; `-a` opt-in for batch mode.

## [1.0.0] (2026-04-05)

### Added
- Initial release as `claude-autorc`: persistent Claude Code sessions in tmux with Remote Control enabled.
- LaunchAgent for auto-start at login.
- Conversation resume via `claude -c`.
- Stray process migration: pulls non-tmuxed Claude processes into managed sessions.
- `--shutdown`, `--restart` flags.
- `--dry-run` for previewing actions.
- User config at `~/.claude-autorc` (later `~/.claude-mux/config`).
- Logging to `~/Library/Logs/claude-autorc.log` (later `claude-mux.log`).

[Unreleased]: https://github.com/pereljon/claude-mux/compare/v1.7.0...HEAD
[1.7.0]: https://github.com/pereljon/claude-mux/compare/v1.6.2...v1.7.0
[1.6.2]: https://github.com/pereljon/claude-mux/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/pereljon/claude-mux/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/pereljon/claude-mux/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/pereljon/claude-mux/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/pereljon/claude-mux/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/pereljon/claude-mux/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/pereljon/claude-mux/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/pereljon/claude-mux/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/pereljon/claude-mux/releases/tag/v1.0.0
