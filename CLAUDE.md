# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Claude Auto Remote Control** (`claude-autorc`) — a shell script and macOS LaunchAgent that automatically creates persistent tmux sessions running Claude Code with Remote Control for each project directory under `~/Claude/`.

### Deliverables

1. `~/Claude/start-claude-sessions.sh` — main startup script (Bash)
2. `~/Library/LaunchAgents/com.user.claude-sessions.plist` — triggers script at user login

## Architecture

The startup script dynamically discovers category directories under `~/Claude/` (any subdir not starting with `.` or `-`), migrates stray Claude processes into tmux, initializes git repos where missing (to bypass Claude's trust prompt), and creates one tmux session per project with Claude running in RC mode. It attempts `claude -c` to resume a prior session, falling back to a fresh `claude --rc` on failure.

The LaunchAgent runs the script at login with a 45-second startup delay for system services to initialize.

### Key behaviors

- **Idempotent**: safe to re-run; skips existing tmux sessions
- **Exclusion**: directories starting with `.` or `-` are skipped
- **Dynamic categories**: all top-level subdirs of `~/Claude/` (not starting with `.` or `-`) are treated as categories
- **Session migration**: SIGTERMs Claude processes running outside tmux in managed directories; `claude -c` resumes them in the new tmux session
- **Dry run**: `--dry-run` flag prints actions without executing (skips migration)
- **Logging**: all actions appended to `~/Claude/startup.log` (UTC ISO 8601)
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
~/Claude/start-claude-sessions.sh --dry-run

# Full run
~/Claude/start-claude-sessions.sh

# Check sessions
tmux list-sessions

# Install LaunchAgent
cp com.user.claude-sessions.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-sessions.plist

# Verify LaunchAgent
launchctl list | grep claude-sessions

# Check logs
cat ~/Claude/startup.log
cat ~/Claude/launchagent-stdout.log
```

## Implementation spec

See `implentation-spec.md` for the full specification including pseudocode, edge cases, plist configuration, and open items for the implementer.
