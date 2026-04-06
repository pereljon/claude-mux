# Claude Auto Remote Control (`claude-autorc`)

A shell script and macOS LaunchAgent that automatically creates persistent tmux sessions running Claude Code with Remote Control for each project directory under `~/Claude/` (configurable via `~/.claude-autorc`).

## What It Does

On login (or manual run), the script:

1. Scans all category directories under `~/Claude/` (any subdir not starting with `.` or `-`)
2. Migrates any Claude Code processes already running outside tmux in managed directories — SIGTERMs them so they resume cleanly inside tmux via `claude -c`
3. Initializes git repos where missing
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
cp claude-autorc ~/Claude/
chmod +x ~/Claude/claude-autorc

cp com.user.claude-sessions.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-sessions.plist

# Verify
launchctl list | grep claude-sessions
```

## Usage

```bash
# Preview what would happen (no changes made)
~/Claude/claude-autorc --dry-run

# Run manually
~/Claude/claude-autorc

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

Sessions must be authenticated (not showing "Not logged in") and launched with `--remote-control`. After a clean authenticated launch, they should appear in the RC list within a few seconds.

**Alternative:** Instead of passing `--remote-control` per session, you can enable RC globally for all interactive Claude Code sessions via `/config` inside any session. If you do this, the `--remote-control` flag in the script becomes redundant (but harmless).

### Slash commands not available over Remote Control

Most slash commands (e.g. `/model`, `/clear`) are currently not supported in RC sessions — they either fail with "not available over Remote Control" or get sent as plain text. This is a [known open issue](https://github.com/anthropics/claude-code/issues/30674).

**Possible fix (unofficial, wiped on `claude` updates):** The feature is built and functional behind a flag called `tengu_bridge_slash_commands` that defaults to off. To enable it:

```bash
sed -i 's/tengu_bridge_slash_commands",!1/tengu_bridge_slash_commands",!0/g' "$(readlink -f $(which claude))"
```

This patches the bundled JS in the `claude` binary directly. Re-apply after each `brew upgrade claude`.

## Logs

- `~/Claude/claude-autorc.log` — all script actions with UTC timestamps

For low-level LaunchAgent debugging, use Console.app or `log show`.
