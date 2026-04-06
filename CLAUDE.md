# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**claude-mux** (Claude Code Multiplexer) — a shell script and macOS LaunchAgent that automatically creates and maintains persistent Claude Code sessions in tmux for every project directory under `~/Claude/`. Persistent sessions enable Claude Code Remote Control, giving full mobile app access to all projects via the Claude iOS/Android app.

### Deliverables

1. `~/Claude/claude-mux` — main startup script (Bash)
2. `~/Library/LaunchAgents/com.user.claude-mux.plist` — triggers script at user login

## Architecture

The startup script dynamically discovers category directories under `~/Claude/` (any subdir not starting with `.` or `-`), migrates stray Claude processes into tmux, optionally initializes git repos (disabled by default), and creates one tmux session per project with Claude running in RC mode. It attempts `claude -c` to resume a prior session, falling back to a fresh `claude --remote-control` on failure.

The LaunchAgent runs the script at login with a 45-second startup delay for system services to initialize.

### Key behaviors

- **Idempotent**: safe to re-run; skips sessions where claude is already running, relaunches where it has exited
- **Exclusion**: directories starting with `.` or `-` are skipped
- **Dynamic categories**: all top-level subdirs of `~/Claude/` (not starting with `.` or `-`) are treated as categories
- **Session migration**: SIGTERMs Claude processes running outside tmux in managed directories; `claude -c` resumes them in the new tmux session
- **Dry run**: `--dry-run` flag prints actions without executing (skips migration)
- **Logging**: all actions appended to `~/Claude/claude-mux.log` (UTC ISO 8601)
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
~/Claude/claude-mux --dry-run

# Full run
~/Claude/claude-mux

# Check sessions
tmux list-sessions

# Install LaunchAgent
cp com.user.claude-mux.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-mux.plist

# Verify LaunchAgent
launchctl list | grep claude-sessions

# Check logs
tail -f ~/Claude/claude-mux.log

# LaunchAgent debug (stdout/stderr go to macOS unified log, not a file)
log show --predicate 'process == "launchd"' --last 5m | grep claude
```

## Development workflow

The script has two locations:
- **Repo**: `~/Claude/development/claude-code-sessions/claude-mux` (version-controlled)
- **Active**: `~/Claude/claude-mux` (what actually runs)

Always edit the repo copy first, then **ask before committing** — do not run `git commit` or `git push` without explicit approval. After committing, deploy to the active location:

```bash
# After editing and committing in the repo:
cp ~/Claude/development/claude-code-sessions/claude-mux ~/Claude/
```

The plist and `claude-mux.example` follow the same pattern — edit in repo, copy to deploy.

## Configuration file

`~/.claude-mux` is the user config (not in this repo). A documented template is at `claude-mux.example`. Key variables:

- `BASE_DIR` — root directory (default: `~/Claude`)
- `AUTO_GIT_INIT` — run `git init` and create `.gitignore` in projects without a repo (default: `false`)
- `DEFAULT_PERMISSION_MODE` — Claude permission mode per project (default: `auto`)
- `ALLOW_CROSS_SESSION_CONTROL` — allow sessions to send commands to each other (default: `false`)

## Implementation spec

See `implentation-spec.md` for the full specification including pseudocode, edge cases, plist configuration, and open items for the implementer.
