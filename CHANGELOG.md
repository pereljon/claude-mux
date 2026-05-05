# Changelog

All notable changes to claude-mux are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.11.1] — 2026-05-05

### Changed
- **Tips rewrite**: all tips now focus on conversational commands instead of CLI flags or internal implementation details. Reduced from 44 to 37 tips.

## [1.11.0] — 2026-05-05

### Changed
- **Session names everywhere**: `--hide`, `--show`, `--protect`, `--unprotect`, `--delete`, `--rename`, and `--move` now accept session names instead of directory paths. No-arg defaults to the calling session. Resolves running sessions via tmux and idle projects via `PROJECT_DIRS` scan. Replaces `resolve_project_dir()` + `resolve_session_to_dir()` with a single `resolve_session_dir()`.

## [1.10.1] — 2026-05-05

### Changed
- **Session list output**: markdown table format when consumed by Claude (non-TTY), printf-aligned columns when in terminal (TTY). Both formats now include row numbers.
- **Session list sorting**: rows sorted by directory path instead of session name. Groups projects by category folder (development, personal, work).
- **Numbered session references**: injection prompt now supports "stop 1-3", "restart 5", "compact 2 and 4" — Claude maps numbers to session names from the most recent list.

## [1.10.0] — 2026-05-05

### Added
- **`--tip`**: prints one tip from the embedded tips array (42 tips). Standalone, ungated, works from any context.
- **Tip of the day**: first session started each day receives a tip via the injection prompt. Daily gate uses `~/.claude-mux/.tip-date`. Subsequent sessions that day skip it. Tips are stored in English; Claude renders them in the user's conversation language.
- **`TIP_OF_DAY` config option** (default: `true`): set to `false` to disable daily tips. `--tip` always works regardless.
- **`TIP_MODE` config option** (default: `daily`): `random` picks a non-deterministic tip each time; `daily` picks the same tip all day via day-of-year hash.
- **`--save-template NAME [DIR]`**: copies `CLAUDE.md` from a project directory to `~/.claude-mux/templates/<name>.md`. Name is lowercased and sanitized (non-alphanumeric → `-`). Refuses if `CLAUDE.md` is absent; warns on overwrite (bypass with `--force`). Supports `--dry-run`.
- **`--rename OLD NEW`**: renames a project directory, migrates `~/.claude/projects/` conversation history to the new encoded path, and updates the homunculus `projects.json` and per-project `project.json` registries. Stops a running session before rename and restarts it in the new location. Requires `--force` if the project is protected. Supports `--dry-run`.
- **`--move SRC DEST`**: moves a project into a new parent directory with the same behavior as `--rename`. `DEST` is the parent; the project keeps its name.
- **curl install**: `install.sh` now works when piped from curl. Detects curl-pipe vs local clone (checks for sibling binary); downloads the binary from GitHub releases when no local copy is found. Platform detection: on Linux, LaunchAgent setup is skipped with a note (full Linux support in v2.0).
- **`release-assets.yml`**: new GitHub Actions workflow uploads `claude-mux` and `install.sh` as release assets on every published release. Enables curl install and `--update` binary download.
- **`encode_claude_path()`**: encodes an absolute path to the format Claude Code uses for `~/.claude/projects/` folder names (every non-alphanumeric character → `-`). Verified empirically against real entries.
- **Conversational triggers**: `rename this project to NAME` → `--rename . NAME`; `move this project to PATH` → `--move . PATH`; `save this as a template named NAME`; `tip / tip of the day`.

### Fixed
- **`delete_command` force isolation** (M3): `shutdown_single_session` now accepts an optional `force` argument rather than reading the global `FORCE`. Prevents unintended global mutation.
- **`move_to_trash` TOCTOU** (M4): name collision suffix uses `$$` (PID) instead of second-granularity timestamp, guaranteeing uniqueness under rapid successive calls.
- **Startup polling loop** (M9/L8): after accepting the workspace trust prompt, the polling loop continues (`continue` not `break`) so a subsequent `bypassPermissions` confirmation prompt is also handled. Fixes session startup in new project dirs with bypassPermissions mode.
- **`bypassPermissions` detection** (L9): `grep -qi "yes.*accept"` replaces `grep "Yes, I accept"` for resilience to UI text changes.
- **`ensure_gitignore_entry` double-append** (L3): skips append if the pattern already appears in `.gitignore`.

### Changed
- **Quick Start** (README): curl one-liner is now the primary install method. Homebrew moved to "macOS alternative".
- **`install.sh` description**: updated to reflect curl-pipe support and platform detection.

## [1.9.1] — 2026-05-04

### Changed
- **Ready trigger**: claude-mux now sends `Ready?` (was `ready`) after a session starts. Expected response is `Session ready!` (was `Ready.`).

### Fixed
- **`--hide` on home directory**: `--hide` now refuses with an error if the target directory is `$BASE_DIR`. Hiding the home session from listings served no useful purpose and removed the always-on anchor from `-L` output.

## [1.9.0] — 2026-05-01

### Added
- **LaunchAgent KeepAlive**: home session is now resilient to crashes, manual shutdowns, and sleep/wake disruption. If home dies, the LaunchAgent relaunches it within ~60 seconds via the idempotent `--autolaunch` path. Note: `--shutdown home --force` will also be reversed by the LaunchAgent. To disable permanently: `claude-mux --install --launchagent-mode none`.
- **Per-project marker files** using the `.claudemux-*` naming convention. State follows the project folder across renames, moves, and syncs. Markers are auto-added to `.gitignore` when created in a git-tracked project.
- **`.claudemux-protected`** — session protected at launch. Created by default in `$BASE_DIR` during `claude-mux --install`.
- **`.claudemux-ignore`** — project hidden from `claude-mux -L` listings.
- **`--hide` / `--show`**: write or remove `.claudemux-ignore` for a project. Defaults to current directory.
- **`--protect` / `--unprotect`**: write or remove `.claudemux-protected` and toggle the runtime tmux marker on running sessions.
- **`--delete DIR`**: trash-safe project deletion (macOS only). Moves the project folder to `~/.Trash/` — never `rm -rf`. Recoverable via Finder. Requires `--yes` or interactive confirmation. Honors protection (requires `--force` to override). Refuses paths outside `$HOME`.
- **`-L --hidden`** / **`-L --include-hidden`**: list only hidden projects, or list all projects including hidden ones.
- **`--config-help`**: prints all valid config options with defaults, types, and descriptions.
- **`--commands`**: prints the full CLI reference. Replaces the inline Commands block in the session injection.
- **Home session permissions for `~/.claude-mux/**`**: home session can now read/edit/write its own config and templates without permission prompts.
- **Conversational triggers**: hide/show/protect/unprotect/delete project; in home session: show/set config, list/add/edit/delete templates.
- **Session ownership marker** (`@claude-mux-managed = 1`): tmux user option set on every session created by claude-mux. Used to detect collision with user-created tmux sessions that share a name.
- **Collision detection**: if a session name already exists but was not created by claude-mux, `--autolaunch` refuses to overwrite it and logs a warning.
- **`bypassPermissions` / `yolo` mode** (formerly broken): switching a session to yolo/bypassPermissions now works without hanging. Every session launches with `--allow-dangerously-skip-permissions`, so bypassPermissions is always in the Shift+Tab cycle. The startup polling loop now detects and auto-accepts the confirmation prompt. Subsequent switches use Shift+Tab navigation — no restart needed.
- **`--get-mode [SESSION]`**: prints the current permission mode of a session (`bypassPermissions`, `acceptEdits`, `plan`, `default`, or `unknown`). Defaults to current session when called from inside a tmux session. Mode is detected from the last few lines of pane content.

### Changed
- **`.ignore-claudemux` renamed to `.claudemux-ignore`**. No automatic migration. Users with the old file should rename:
  ```
  mv .ignore-claudemux .claudemux-ignore
  ```
- **Home session protection** is no longer hardcoded by session name. It is now driven by `$BASE_DIR/.claudemux-protected`, which `claude-mux --install` creates by default. Users can opt out by deleting the marker.
- **Injection prompt slimmed**: removed inline guide expansion and full Commands block. Replaced with a Reference lookups meta-block (`claude-mux --guide`, `--commands`, `--config-help`, `--list-templates`) and a compressed feature list. Saves ~800 tokens per session.
- **`--force` validation** extended: now also required with `--delete` (in addition to `--shutdown`) to override session protection.
- **`setup_claude_mux_permissions()`** now adds `~/.claude-mux/**` access rules and `additionalDirectories` entry for the home session's project.

## [1.8.1] — 2026-04-28

### Added
- **Version in session prompt**: each session now receives the running claude-mux version (`claude-mux version: X.Y.Z`) in its system prompt injection. Claude can report the current version without running shell commands.
- **Update notification in session**: if `~/.claude-mux/.update-check` contains a newer available version, the injection prompt instructs Claude to tell the user and suggest they say "update claude-mux".
- **"update claude-mux" trigger**: new conversational command. Claude warns that all sessions will be restarted, asks for confirmation, then runs `claude-mux --update` followed by `claude-mux --restart`.
- **`--install` and `--update` in session commands block**: both commands are now listed in the injection prompt's Commands reference so Claude knows about them.

## [1.8.0] — 2026-04-28

### Added
- **`claude-mux --install`**: interactive setup command that creates `~/.claude-mux/config` and installs the LaunchAgent. Self-contained — no separate scripts or files needed. Same prompts as the previous `install.sh` flow.
- **First-run prompt**: when a config-requiring command runs without `~/.claude-mux/config`, claude-mux prompts to run setup (TTY) or exits with a hint (non-TTY). No more silent config auto-creation.
- **Install flags**: `--non-interactive`, `--base-dir DIR`, `--launchagent-mode {none,home}`, `--home-model {sonnet,haiku,opus}`, `--no-launchagent`, `--permission-mode MODE`, `--cross-session-control` — all valid only with `--install`.
- **`protected` session status**: protected sessions (home) now show `protected` in the status column instead of `running*`. Clearer and consistent with other status values.
- **Current session marker**: the calling session is marked with `>` in the session name column (e.g. `> home`), making it easy for agents and users to identify which session is running the command.

### Changed
- **`install.sh` simplified**: now copies the binary to `~/bin/`, ensures PATH, and delegates to `claude-mux --install` for config and LaunchAgent setup. All install-flow logic moved into the script itself.
- **Plist template**: now generated by `claude-mux --install` from a heredoc in the script (`generate_plist`), with `${CLAUDE_MUX_BIN}` interpolation. Standalone `com.user.claude-mux.plist` removed from the repo — single source of truth.
- **`--no-launchagent`** is now an alias for `--launchagent-mode none`. Both skip the plist write entirely; no point installing a no-op plist.
- **Config behavior**: explicit `--install` always reconfigures (with confirmation prompt unless `--non-interactive`); first-run prompt only fires if config is absent. Previously, the script silently wrote a default config on every fresh run.
- **Reconfigure-from-home-session warning**: when `--install` is run from inside the home tmux session, prints a note that LaunchAgent changes take effect at next login but the current session continues.
- **First-run exits after setup**: after completing setup via the first-run prompt, claude-mux exits and asks you to re-run your command. Previously it would fall through and execute the original command with stale variable state.
- **`--non-interactive --install` requires `--force` to overwrite existing config**: prevents silent data loss when re-running install scripts against an existing setup.
- **`--permission-mode` validated on install**: accepted values are `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Invalid values now error immediately.
- **`--base-dir` validated on install**: rejects shell metacharacters and requires the parent directory to exist before attempting to create the base directory.
- **Stopped protected sessions**: a protected session where Claude is not running now shows `stopped` rather than `protected`, reflecting actual state.

### Fixed
- **`install.sh` crash on no-arg invocation**: empty `INSTALL_ARGS` array under `set -u` triggered "unbound variable" before `claude-mux --install` was reached. Fixed with safe array expansion.
- **`launchagent_set` not set in interactive branch**: a user who answered "no" to the home session prompt had their choice silently overridden to `home` by the defaults block. Now correctly preserved.
- **`BIN_DIR` shell profile write**: replaced heredoc with `printf` to eliminate heredoc injection risk when writing PATH export to `~/.zshrc`/`~/.bashrc`.
- **Config write robustness**: `write_install_config` now uses `printf '%s\n'` instead of an unquoted heredoc, so user-supplied values cannot affect config file structure.
- **XML escaping in `generate_plist`**: `CLAUDE_MUX_BIN` is now XML-escaped before interpolation into the plist `<string>` element.
- **PATH hint box alignment**: the `source <profile>` line in the post-install PATH hint is now properly padded to align with the box border.

### Removed
- **`com.user.claude-mux.plist`** standalone file: replaced by the `generate_plist` heredoc in the script.

## [1.7.4] — 2026-04-27

### Fixed
- **Bash syntax error in injection prompt**: unescaped double quotes in the start-session confirmation example were terminating the `local prompt="..."` assignment in `build_system_prompt`, causing `--restart` and any other operation that builds the system prompt to fail with `local: ... not a valid identifier`. Reworded the example to avoid nested double quotes.

## [1.7.3] — 2026-04-27

### Fixed
- **`--restart` with `--no-attach`**: injection prompt now explicitly states `--no-attach` must not be added to `--restart` or `--shutdown`. Claude was over-applying the `-d`/`-n` rule, causing `--restart` to fail with exit code 1.
- **Silent command failure**: injection prompt now instructs Claude to report errors when a command fails, not just print verbatim output on success.

## [1.7.2] — 2026-04-27

### Fixed
- **Start session confirmation**: injection prompt now instructs Claude to confirm by session name only (not directory path), since sessions appear by name in Remote Control. Removes hedged "should now be running" wording.
- **`start new session` confirmation**: same name-only confirmation applied to the `start new session in FOLDER` trigger.

### Changed
- **Home session self-identification**: home session injection prompt now includes a line identifying itself as the always-on tmux session in the base directory, its protected status, and its role as the default Remote Control entry point.

## [1.7.1] — 2026-04-27

### Fixed
- **`--update` mv not checked**: installing the downloaded binary now fails loudly if `$install_path` is not writable, instead of printing a false success message.
- **`--update` VERSION validation**: downloaded script must contain `VERSION="<expected>"` exactly, not just any `VERSION=` string.
- **`--update` brew exit code**: `brew upgrade` failure now exits with an error instead of printing a false success message.

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

[Unreleased]: https://github.com/pereljon/claude-mux/compare/v1.9.1...HEAD
[1.9.1]: https://github.com/pereljon/claude-mux/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/pereljon/claude-mux/compare/v1.8.1...v1.9.0
[1.8.1]: https://github.com/pereljon/claude-mux/compare/v1.8.0...v1.8.1
[1.8.0]: https://github.com/pereljon/claude-mux/compare/v1.7.4...v1.8.0
[1.7.4]: https://github.com/pereljon/claude-mux/compare/v1.7.3...v1.7.4
[1.7.3]: https://github.com/pereljon/claude-mux/compare/v1.7.2...v1.7.3
[1.7.2]: https://github.com/pereljon/claude-mux/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/pereljon/claude-mux/compare/v1.7.0...v1.7.1
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
