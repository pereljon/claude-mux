# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**claude-mux** (Claude Code Multiplexer) - a shell script and macOS LaunchAgent that automatically creates and maintains persistent Claude Code sessions in tmux for every project directory under `~/Claude/`. Persistent sessions enable Claude Code Remote Control, giving full mobile app access to all projects via the Claude iOS/Android app.

### Deliverables

1. `claude-mux` - main script (Bash), installed to a bin directory in `$PATH`
2. `com.user.claude-mux.plist` - LaunchAgent plist, installed to `~/Library/LaunchAgents/`
3. `install.sh` - installer script
4. `claude-mux-rc` - example config file template

## Architecture

The startup script discovers Claude projects under `~/Claude/` by finding directories that contain a `.claude/` subdirectory (at any depth). It migrates stray Claude processes into tmux and creates one tmux session per project with Claude running in RC mode. It attempts `claude -c` to resume a prior session, falling back to a fresh `claude --remote-control` on failure.

The LaunchAgent runs the script at login with a 45-second startup delay for system services to initialize.

### Key behaviors

- **Idempotent**: safe to re-run; skips sessions where claude is already running, relaunches where it has exited
- **Project discovery**: finds directories containing `.claude/` at any depth under BASE_DIR
- **Exclusion**: directories starting with `.` or `-` are skipped; directories with `.ignore-claudemux` are skipped
- **Session migration**: SIGTERMs Claude processes running outside tmux in managed directories; `claude -c` resumes them in the new tmux session
- **Dry run**: `--dry-run` flag prints actions without executing (skips migration)
- **Logging**: all actions appended to `~/Library/Logs/claude-mux.log` (UTC ISO 8601, configurable via `LOG_DIR`)
- **Default permission mode**: optionally sets Claude's `permissions.defaultMode` per project via `.claude/settings.local.json`
- **Tmux-aware sessions**: each session gets `--append-system-prompt` with its tmux session name, so Claude knows how to send slash commands (e.g. `/model`, `/compact`) to itself via `tmux send-keys` (cross-session control available when `ALLOW_CROSS_SESSION_CONTROL=true`)
- **Tmux quality-of-life**: sessions configured with mouse, 50k scrollback, clipboard, 256-color, reduced escape delay, extended keys, activity monitoring, and tab titles - all configurable via rc file
- **Home session**: running `claude-mux` in `$BASE_DIR` (or LaunchAgent with `LAUNCHAGENT_MODE=home`) creates a session named `home`; always protected, requires `--force` to shut down; marked with `*` in status output
- **LaunchAgent modes**: `LAUNCHAGENT_MODE=none` (default) / `home` / `batch`; plist invokes `claude-mux --autolaunch` which dispatches based on mode. Legacy `LAUNCHAGENT_ENABLED=true` treated as `batch` for backward compatibility.

## Dependencies

- macOS (Apple Silicon / arm64)
- `/opt/homebrew/bin/tmux`
- `/opt/homebrew/bin/claude`
- System `/bin/bash`

## Commands

```bash
# Install
./install.sh

# Usage
claude-mux                       # start all sessions
claude-mux DIRECTORY             # use DIRECTORY as base dir (scan for .claude projects)
claude-mux -d DIRECTORY          # launch single session in directory and attach
claude-mux -n DIRECTORY          # create new project (git init, .gitignore) and attach
claude-mux -n DIRECTORY -p       # same, creating directory and parents if needed
claude-mux -s SESSION '/command'  # send a slash command to a session
claude-mux -t SESSION            # attach to a session
claude-mux -l                    # list active sessions (running + stopped)
claude-mux -L                    # list all projects (active + idle)
claude-mux --shutdown            # gracefully exit all Claude sessions
claude-mux --shutdown SESSION...  # shut down specific session(s)
claude-mux --restart             # restart sessions that were running
claude-mux --restart SESSION...  # restart specific session(s)
claude-mux --dry-run             # preview actions without executing

# Verify LaunchAgent
launchctl list | grep claude-mux

# Check logs
tail -f ~/Library/Logs/claude-mux.log

# LaunchAgent debug (stdout/stderr go to macOS unified log, not a file)
log show --predicate 'process == "launchd"' --last 5m | grep claude
```

## Communication standards

When diagnosing issues, distinguish clearly between what you know and what you're guessing. Don't state theories as conclusions. Use language like "this could be", "one possibility is", or "I'm not sure, but" when you lack evidence. If you can't verify something, say so rather than presenting speculation as fact.

Avoid LLM-stereotypical writing in all human-facing content (README, emails, posts, docs). No em dashes, no "delve", "leverage", "streamline", "excited to share", "game-changer", or other overused AI patterns. Write like a developer, not a press release.

## Interactive commands

Commands that attach to a tmux session (`-t`, and `-d`/`-n` without `--no-attach`) are interactive and should only be invoked by the user directly in a terminal - never by Claude from inside a session. From inside a session, attach would trigger `switch-client` on the user's terminal (unpredictable) or fail silently over Remote Control.

When listing or documenting commands that Claude can run from within sessions:
- `-l`, `-L`, `-s`, `--shutdown`, `--restart`, `--list-templates`, `-a` are safe - no attach
- `-d`, `-n` must always include `--no-attach`
- `-t` should be excluded entirely from Claude-callable examples

The injection prompt enforces this with an IMPORTANT note.

## Testing plan

Before beginning any coding session for a new feature or change, review or produce a testing plan with the user. Cover:
- Happy path cases
- Edge cases and error conditions
- Flag conflicts and validation
- Config migration / backward compatibility
- Injection prompt updates
- Display / output changes

Get the user's confirmation on the plan before writing code.

## Change checklist

After any code change, verify whether these also need updating:
- `README.md` - usage, feature descriptions, configuration table, examples
- `claude-mux-rc` - example config template (will move to `config.example`)
- `~/.claude-mux/config` - deployed user config (add new settings)
- `install.sh` - installer-generated config, new flags
- `implentation-spec.md` - startup sequence, settings table, function docs
- `CLAUDE.md` - key behaviors, commands, config summary
- **Injection prompt** - the system prompt injected into Claude sessions must reflect all current commands. Update both the `create_claude_session` and `launch_single_session` injection strings when commands are added, changed, or removed.
- **Session System Prompt section in README** - must match the actual injection

- `ISSUES.md` - log new bugs and known issues; update resolved entries when fixed

Before committing, also check whether the version number needs a bump (`VERSION=` near the top of `claude-mux`). Use semantic versioning: patch for bug fixes, minor for new features, major for breaking changes.

Do not commit until all affected files are updated.

## Development workflow

The script has two locations:
- **Repo**: `~/Claude/development/claude-mux/claude-mux` (version-controlled)
- **Installed**: `~/bin/claude-mux` (what actually runs, created by `install.sh`)

Always edit the repo copy first, then **ask before committing** - do not run `git commit` or `git push` without explicit approval. After committing, deploy to the installed location:

```bash
# After editing and committing in the repo:
cp ~/Claude/development/claude-mux/claude-mux ~/bin/
```

## Configuration

`~/.claude-mux/config` is the user config (not in this repo). A documented template is at `config.example`. Key variables:

- `BASE_DIR` - root directory (default: `~/Claude`)
- `LOG_DIR` - directory for `claude-mux.log` (default: `~/Library/Logs`)
- `DEFAULT_PERMISSION_MODE` - Claude permission mode per project (default: `auto`)
- `ALLOW_CROSS_SESSION_CONTROL` - allow sessions to send commands to each other (default: `false`)
- `TEMPLATES_DIR` - CLAUDE.md template directory (default: `~/.claude-mux/templates`)
- `DEFAULT_TEMPLATE` - default template for new projects (default: `default.md`)
- `LAUNCHAGENT_MODE` - LaunchAgent behavior at login: `none` (default), `home`, or `batch`

## TODO

- `templates/` in repo root: add example CLAUDE.md templates (web, python, etc.) and optionally copy them to `~/.claude-mux/templates/` during install
- `CHANGELOG.md`: create from git history, maintain per tagged version
- Permission mode switching: **done** — `claude-mux --permission-mode MODE SESSION` restarts a session with the given mode (`default`, `acceptEdits`, `plan`, `auto`, `bypassPermissions`, `dontAsk`, `dangerously-skip-permissions`). Injection prompt documents "yolo" as an alias for `dangerously-skip-permissions`.

## Implementation spec

See `implentation-spec.md` for the full specification including pseudocode, edge cases, plist configuration, and open items for the implementer.
