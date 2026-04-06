# Claude Auto Remote Control (`claude-autorc`)

A shell script and macOS LaunchAgent that automatically creates persistent tmux sessions running Claude Code with Remote Control for each project directory under `~/Claude/`.

## What It Does

On login (or manual run), the script:

1. Scans all category directories under `~/Claude/` (any subdir not starting with `.` or `-`)
2. Migrates any Claude Code processes already running outside tmux in managed directories — SIGTERMs them so they resume cleanly inside tmux
3. Initializes git repos where missing (bypasses Claude's trust prompt)
4. Configures each project with a `.gitignore` and `permissions.defaultMode` if not already set
5. Creates a tmux session per project with Claude running in RC mode
6. Attempts to resume the last session (`claude -c`), falling back to a fresh start

Each Claude session receives a system prompt at startup telling it:
- Its own tmux session name
- How to send slash commands to itself or other sessions via `tmux send-keys`
- Which GitHub SSH accounts are configured in `~/.ssh/config`

## Requirements

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## Usage

```bash
# Preview what would happen (no changes made)
~/Claude/start-claude-sessions.sh --dry-run

# Run it
~/Claude/start-claude-sessions.sh

# Check running sessions
tmux list-sessions

# Attach to a session
tmux attach -t project-name
```

## Install as LaunchAgent

The LaunchAgent runs the script automatically at login with a 45-second startup delay to allow system services to initialize.

**Before installing**, edit `com.user.claude-sessions.plist` and replace `/Users/jonathan` with your actual home directory path — `~` does not expand in `ProgramArguments`.

```bash
# Copy the script to ~/Claude/
cp start-claude-sessions.sh ~/Claude/
chmod +x ~/Claude/start-claude-sessions.sh

# Edit the plist to replace /Users/jonathan with your home path, then:
cp com.user.claude-sessions.plist ~/Library/LaunchAgents/

# Load it now (or it will load automatically on next login)
launchctl load ~/Library/LaunchAgents/com.user.claude-sessions.plist

# Verify
launchctl list | grep claude-sessions
```

## Configuration

Edit the variables at the top of `start-claude-sessions.sh`:

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory containing category and project subdirectories |
| `AUTO_GITIGNORE` | `true` | Create `.gitignore` with common dev exclusions (secrets, tokens, .env, IDE files, build artifacts) if one doesn't exist |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set Claude's `permissions.defaultMode` in each project. Valid: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Set to `""` to disable. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | Allow Claude sessions to send slash commands to other sessions via tmux. When `false`, sessions can only send commands to themselves. Enable for multi-agent orchestration workflows. |

`AUTO_GITIGNORE` and `DEFAULT_PERMISSION_MODE` are idempotent — they skip projects that already have the relevant files configured.

## Session Awareness

Each Claude session is launched with `--append-system-prompt` giving it context about its environment:

**Tmux identity** — Claude knows its session name and can send slash commands to itself:

```bash
# Claude can run this to switch its own model:
/opt/homebrew/bin/tmux send-keys -t project-a "/model sonnet" Enter

# Or compact itself:
/opt/homebrew/bin/tmux send-keys -t project-a "/compact" Enter
```

By default, sessions can only send commands to themselves. Set `ALLOW_CROSS_SESSION_CONTROL=true` to let sessions send commands to other sessions — useful for multi-agent orchestration but increases blast radius:

```bash
# With cross-session control enabled, one session can instruct another:
/opt/homebrew/bin/tmux send-keys -t project-b "/compact" Enter

# List all sessions:
/opt/homebrew/bin/tmux list-sessions
```

**GitHub SSH accounts** — The script reads `~/.ssh/config` at startup and injects any `Host github.com-*` entries into each session's system prompt. Claude will know which accounts are available and use the correct SSH host alias for git operations:

```
# Example of what Claude learns:
GitHub SSH accounts: pereljon (git@github.com-pereljon), work (git@github.com-work)
Use the host alias as the git remote, e.g. git clone git@github.com-pereljon:org/repo.git
```

## Session Migration

When the script runs, it finds any Claude Code CLI processes already running outside of tmux whose working directory is under a managed category. It SIGTERMs them gracefully — conversation state is persisted to disk, so `claude -c` in the new tmux session resumes exactly where the session left off. The old terminal window will show Claude exited; attach to the tmux session to continue:

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
