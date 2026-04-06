# Claude Auto Remote Control (`claude-autorc`)

A shell script and macOS LaunchAgent that automatically creates persistent tmux sessions running Claude Code with Remote Control for each project directory under `~/Claude/`.

## What It Does

On login (or manual run), the script:

1. Scans all category directories under `~/Claude/` (any subdir not starting with `.` or `-`)
2. Migrates any Claude Code processes already running outside tmux in managed directories — SIGTERMs them so they resume cleanly inside tmux
3. Initializes git repos where missing (bypasses Claude's trust prompt)
4. Creates a tmux session per project with Claude running in RC mode
5. Attempts to resume the last session (`claude -c`), falling back to a fresh start

## Requirements

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## Usage

```bash
# Preview what would happen
./start-claude-sessions.sh --dry-run

# Run it
./start-claude-sessions.sh

# Check running sessions
tmux list-sessions
```

## Install as LaunchAgent

```bash
# Copy the plist (runs automatically at login)
cp com.user.claude-sessions.plist ~/Library/LaunchAgents/

# Load it now
launchctl load ~/Library/LaunchAgents/com.user.claude-sessions.plist

# Verify
launchctl list | grep claude-sessions
```

## Configuration

Edit the variables at the top of `start-claude-sessions.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `AUTO_GITIGNORE` | `true` | Create `.gitignore` with common dev exclusions (secrets, tokens, .env, IDE files, build artifacts) if one doesn't exist |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set Claude's `permissions.defaultMode` in each project. Valid: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Set to `""` to disable. |

Both settings are idempotent — they skip projects that already have the relevant files configured.

## Cross-Session Control

Each Claude session is launched with `--append-system-prompt` containing its tmux session name. This means any session can send slash commands to itself or other sessions:

```bash
# From any Claude session (or terminal):
/opt/homebrew/bin/tmux send-keys -t project-a "/model sonnet" Enter
/opt/homebrew/bin/tmux send-keys -t project-b "/compact" Enter

# List all sessions
/opt/homebrew/bin/tmux list-sessions
```

Claude sessions are aware of this capability and can use it autonomously when asked.

## Session Migration

When the script runs, it finds any Claude Code CLI processes already running outside of tmux whose working directory is under a managed category. It SIGTERMs them gracefully — conversation state is persisted to disk, so `claude -c` in the new tmux session resumes exactly where the session left off. Any terminal window where Claude was running will show it exited; attach to the tmux session to continue:

```bash
tmux attach -t project-name
```

## Directory Structure

```
~/Claude/
├── work/              # category (any top-level dir not starting with . or -)
│   ├── project-a/
│   ├── project-b/
│   └── -archived/     # excluded (starts with -)
├── personal/          # category
│   ├── project-c/
│   └── .hidden/       # excluded (starts with .)
└── -old/              # excluded (starts with -)
```

## Logs

- `~/Claude/startup.log` — script actions (UTC timestamps)
- `~/Claude/launchagent-stdout.log` — LaunchAgent stdout
- `~/Claude/launchagent-stderr.log` — LaunchAgent stderr
