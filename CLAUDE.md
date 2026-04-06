# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Claude Auto Remote Control** (`claude-autorc`) — a shell script and macOS LaunchAgent that automatically creates persistent tmux sessions running Claude Code with Remote Control for each project directory under `~/Claude/`.

### Deliverables

1. `~/Claude/claude-autorc` — main startup script (Bash)
2. `~/Library/LaunchAgents/com.user.claude-sessions.plist` — triggers script at user login

## Architecture

The startup script dynamically discovers category directories under `~/Claude/` (any subdir not starting with `.` or `-`), migrates stray Claude processes into tmux, initializes git repos where missing, and creates one tmux session per project with Claude running in RC mode. It attempts `claude -c` to resume a prior session, falling back to a fresh `claude --remote-control` on failure.

The LaunchAgent runs the script at login with a 45-second startup delay for system services to initialize.

### Key behaviors

- **Idempotent**: safe to re-run; skips sessions where claude is already running, relaunches where it has exited
- **Exclusion**: directories starting with `.` or `-` are skipped
- **Dynamic categories**: all top-level subdirs of `~/Claude/` (not starting with `.` or `-`) are treated as categories
- **Session migration**: SIGTERMs Claude processes running outside tmux in managed directories; `claude -c` resumes them in the new tmux session
- **Dry run**: `--dry-run` flag prints actions without executing (skips migration)
- **Logging**: all actions appended to `~/Claude/claude-autorc.log` (UTC ISO 8601)
- **Auto-gitignore**: optionally creates `.gitignore` with common dev exclusions (secrets, tokens, .env, IDE, build artifacts)
- **Default permission mode**: optionally sets Claude's `permissions.defaultMode` per project via `.claude/settings.local.json`
- **Tmux-aware sessions**: each session gets `--append-system-prompt` with its tmux session name, so Claude knows how to send slash commands (e.g. `/model`, `/compact`) to itself or other sessions via `tmux send-keys`

## Dependencies

- macOS (Apple Silicon / arm64)
- `/opt/homebrew/bin/tmux`
- `/opt/homebrew/bin/claude`
- System `/bin/bash`

## Commands

```bash
# Dry run
~/Claude/claude-autorc --dry-run

# Full run
~/Claude/claude-autorc

# Check sessions
tmux list-sessions

# Install LaunchAgent
cp com.user.claude-sessions.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-sessions.plist

# Verify LaunchAgent
launchctl list | grep claude-sessions

# Check logs
tail -f ~/Claude/claude-autorc.log

# LaunchAgent debug (stdout/stderr go to macOS unified log, not a file)
log show --predicate 'process == "launchd"' --last 5m | grep claude
```

## Development workflow

The script has two locations:
- **Repo**: `~/Claude/development/claude-code-sessions/claude-autorc` (version-controlled)
- **Active**: `~/Claude/claude-autorc` (what actually runs)

Always edit the repo copy first, commit and push, then deploy to the active location:

```bash
# After editing and committing in the repo:
cp ~/Claude/development/claude-code-sessions/claude-autorc ~/Claude/
```

The plist and `claude-autorc.example` follow the same pattern — edit in repo, copy to deploy.

## Configuration file

`~/.claude-autorc` is the user config (not in this repo). A documented template is at `claude-autorc.example`. Key variables:

- `BASE_DIR` — root directory (default: `~/Claude`)
- `AUTO_GITIGNORE` — create `.gitignore` in each project (default: `true`)
- `DEFAULT_PERMISSION_MODE` — Claude permission mode per project (default: `auto`)
- `ALLOW_CROSS_SESSION_CONTROL` — allow sessions to send commands to each other (default: `false`)

## Implementation spec

See `implentation-spec.md` for the full specification including pseudocode, edge cases, plist configuration, and open items for the implementer.
