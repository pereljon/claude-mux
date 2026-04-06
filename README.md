# claude-mux — Claude Code Multiplexer

Persistent Claude Code sessions for all your projects — accessible from anywhere via the Claude mobile app.

A shell script and macOS LaunchAgent that keeps a Claude Code session running for every project directory under `~/Claude/`. Persistent sessions mean Remote Control is always available — giving you access to all your projects from the Claude mobile app, wherever you are.

## What It Does

On login (or manual run), the script:

1. Scans all category directories under `~/Claude/` (any subdir not starting with `.` or `-`)
2. Migrates any Claude Code processes already running outside tmux in managed directories — SIGTERMs them so they resume cleanly inside tmux via `claude -c`
3. Optionally initializes git repos where missing (disabled by default, enable via `AUTO_GIT_INIT`)
4. Optionally creates a `.gitignore` in each project (when `AUTO_GIT_INIT` is enabled) and sets `permissions.defaultMode` to `DEFAULT_PERMISSION_MODE` (default: `auto`)
5. Creates a persistent tmux session per project with Claude Code running, with Remote Control enabled (if you've enabled RC globally via `/config`, the flag is redundant but harmless)
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
cp claude-mux ~/Claude/
chmod +x ~/Claude/claude-mux

cp com.user.claude-mux.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-mux.plist

# Verify
launchctl list | grep claude-sessions
```

## Usage

```bash
~/Claude/claude-mux              # start all sessions
~/Claude/claude-mux --status     # show session status
~/Claude/claude-mux --dry-run    # preview actions without executing
~/Claude/claude-mux --shutdown   # gracefully exit all Claude sessions
~/Claude/claude-mux --restart    # shutdown then restart all sessions
~/Claude/claude-mux --version    # print version
~/Claude/claude-mux --help       # show all options

# Attach to a session
tmux attach -t project-name

# Watch the log
tail -f ~/Claude/claude-mux.log
```

When run from the terminal, output is mirrored to stdout in real time. When run via LaunchAgent, output goes to the log file only.

## Configuration

On first run, `~/.claude-mux` is created automatically with all settings commented out. Edit it to override any defaults — the script never needs to be modified directly.

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory containing category and project subdirectories |
| `AUTO_GIT_INIT` | `false` | Run `git init` and create a `.gitignore` in project directories that don't have a git repo |
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

Session names are derived from directory names: spaces become hyphens, non-alphanumeric characters (except hyphens) are replaced, and leading/trailing hyphens are stripped. Directories whose name sanitizes to empty are skipped with a log warning.

## Troubleshooting

### Sessions show "Not logged in · Run /login"

This happens on first launch if the macOS keychain is locked (common when the script runs before the keychain is unlocked after login). Fix:

```bash
# Unlock the keychain in a regular terminal
security unlock-keychain

# Then complete auth in any one running session
tmux attach -t <any-session>
# Run /login and complete the browser flow
```

After completing auth once, kill and relaunch all sessions — they'll pick up the stored credential automatically.

### Sessions not appearing in Claude Code Remote

Sessions must be authenticated (not showing "Not logged in"). After a clean authenticated launch they should appear in the RC list within a few seconds.

### Slash commands not available over Remote Control

Most slash commands (e.g. `/model`, `/clear`) are not currently supported in RC sessions. This is a [known open issue](https://github.com/anthropics/claude-code/issues/30674).

## Logs

- `~/Claude/claude-mux.log` — all script actions with UTC timestamps

For low-level LaunchAgent debugging, use Console.app or `log show`.
