# Claude Auto Remote Control (`claude-autorc`)

A shell script and macOS LaunchAgent that automatically creates persistent tmux sessions running Claude Code with Remote Control for each project directory under `~/Claude/` (configurable via `~/.claude-autorc`).

## What It Does

On login (or manual run), the script:

1. Scans all category directories under `~/Claude/` (any subdir not starting with `.` or `-`)
2. Migrates any Claude Code processes already running outside tmux in managed directories — SIGTERMs them so they resume cleanly inside tmux via `claude -c`
3. Initializes git repos where missing — bypasses the trust prompt Claude Code shows for directories without one
4. Configures each project with a `.gitignore` and `permissions.defaultMode` if not already set
5. Creates a tmux session per project with Claude running in RC mode
6. Attempts to resume the last conversation (`claude -c`), falling back to a fresh start

Each Claude session is injected with its tmux session name (so it can send slash commands like `/model` and `/compact` to itself), and any GitHub SSH accounts found in `~/.ssh/config` (so it knows which accounts are available for git operations).

## Requirements

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## Install as LaunchAgent

The LaunchAgent runs the script automatically at login with a 45-second startup delay to allow system services to initialize.

```bash
# Copy the script to ~/Claude/
cp start-claude-sessions.sh ~/Claude/
chmod +x ~/Claude/start-claude-sessions.sh

cp com.user.claude-sessions.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-sessions.plist

# Verify
launchctl list | grep claude-sessions
```

## Usage

```bash
# Preview what would happen (no changes made)
~/Claude/start-claude-sessions.sh --dry-run

# Run manually
~/Claude/start-claude-sessions.sh

# Check running sessions
tmux list-sessions

# Attach to a session
tmux attach -t project-name

# Watch the log
tail -f ~/Claude/claude-autorc.log
```

When run from the terminal, output is mirrored to stdout in real time. When run via LaunchAgent, output goes to the log file only.

## Configuration

On first run, `~/.claude-autorc` is created automatically with all settings commented out. Edit it to override any defaults — the script never needs to be modified directly.

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory containing category and project subdirectories |
| `AUTO_GITIGNORE` | `true` | Create `.gitignore` with common dev exclusions (secrets, tokens, .env, IDE files, build artifacts) if one doesn't exist |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set Claude's `permissions.defaultMode` in each project. Valid: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Set to `""` to disable. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | When `true`, Claude sessions can send slash commands to other sessions via tmux — useful for multi-agent orchestration. When `false`, sessions can only command themselves. |

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

- `~/Claude/claude-autorc.log` — all script actions with UTC timestamps

For low-level LaunchAgent debugging, use Console.app or `log show`.
