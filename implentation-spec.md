# claude-mux — Claude Code Multiplexer: Implementation Spec

## Overview

A shell script and macOS LaunchAgent that automatically creates and maintains persistent Claude Code sessions in tmux for every project directory under `~/Claude/` (configurable).

## Directory Structure (Expected)

Projects are discovered by the presence of a `.claude/` directory, at any depth under BASE_DIR:

```
~/Claude/                          ← BASE_DIR (configurable)
├── work/
│   ├── project-a/                 ← ✓ has .claude/ — managed
│   │   └── .claude/
│   ├── project-b/                 ← ✓ has .claude/ — managed
│   │   └── .claude/
│   └── -archived/                 ← ✗ excluded (starts with -)
├── personal/
│   ├── project-c/                 ← ✓ has .claude/ — managed
│   │   └── .claude/
│   └── project-d/                 ← ✗ no .claude/ — not a project
├── deep/nested/project/           ← ✓ found at any depth
│   └── .claude/
└── ignored/                       ← ✗ excluded (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

Exclusion rules: hidden directories (`.`-prefixed) are pruned from search, directories starting with `-` are skipped, directories containing `.ignore-claudemux` are skipped.

## Deliverables

1. `~/Claude/claude-mux` — main script
2. `com.user.claude-mux.plist` — LaunchAgent plist (user installs to `~/Library/LaunchAgents/`)
3. `config.example` — example user config file
4. `install.sh` — installer script

## User Configuration: ~/.claude-mux/config

On first run, the script creates `~/.claude-mux/config` with all settings commented out. Users edit this file to override defaults without touching the script.

### Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory to scan for Claude projects (directories containing `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directory for the `claude-mux.log` file |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set `permissions.defaultMode` in `.claude/settings.local.json` per project. Valid: `""` (disabled), `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions` |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | When `true`, Claude sessions are told they can send slash commands to other sessions via tmux. When `false`, sessions can only send commands to themselves. |
| `SLEEP_BETWEEN` | `5` | Seconds between session launches in batch mode |
| `LAUNCHAGENT_ENABLED` | `false` | When `true`, the LaunchAgent starts all managed sessions at login |
| `TMUX_MOUSE` | `true` | Mouse support (scroll, select, resize) |
| `TMUX_HISTORY_LIMIT` | `50000` | Scrollback buffer size in lines |
| `TMUX_CLIPBOARD` | `true` | System clipboard integration via OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Terminal type for color rendering |
| `TMUX_EXTENDED_KEYS` | `true` | Extended key sequences including Shift+Enter |
| `TMUX_ESCAPE_TIME` | `10` | Escape key delay in milliseconds |
| `TMUX_TITLE_FORMAT` | `#S` | Terminal/tab title format |
| `TMUX_MONITOR_ACTIVITY` | `true` | Activity notifications from other sessions |

The script sources `~/.claude-mux/config` after setting defaults, so any variable set in the config overrides the default. Tmux session options are applied via `apply_tmux_options()` after session creation.

## Script: claude-mux

### Requirements

- Bash (`/bin/bash`)
- `tmux` at `/opt/homebrew/bin/tmux`
- `claude` at `/opt/homebrew/bin/claude`
- Idempotent: safe to re-run; only creates sessions that don't already exist
- `--dry-run` flag: prints actions without executing (skips session migration)

### Environment

- PATH must include `/opt/homebrew/bin`
- HOME is inherited from the login session via LaunchAgent
- Apple Silicon Mac (arm64)

### Startup Sequence

```
1. Set defaults (BASE_DIR, LOG_DIR, DEFAULT_PERMISSION_MODE, ALLOW_CROSS_SESSION_CONTROL)
2. Parse flags (-d, -n, -p, -s, -t, -l, -L, --shutdown, --restart, --dry-run, -v, -h, positional DIRECTORY)
3. Validate mutual exclusion of commands; validate -p only with -n
4. Create ~/.claude-mux/config with commented defaults if it doesn't exist
5. Source ~/.claude-mux/config (user overrides apply from here on)
6. Apply positional BASE_DIR override if provided
7. Validate -d directory (resolve, check exists, sanitize name)
8. Validate -n directory (resolve, sanitize name)
9. If COMMAND=attach (-t): attach to named tmux session and exit
10. If COMMAND=send (-s): send command to session via tmux send-keys and exit
11. 45-second startup delay (skipped when stdout is a terminal or in dry-run) for LaunchAgent login use
12. Check dependencies (tmux, claude)
13. Dispatch:
    - start: discover_projects → migrate_stray_sessions → create sessions
    - launch (-d): migrate stray in target dir → create session → attach
    - new (-n): create dir (if -p) → git init → .gitignore → create session → attach
    - send (-s): tmux send-keys to named session
    - list (-l): show active sessions (running + stopped)
    - list-all (-L): show all projects (active + idle)
    - shutdown: send /exit → poll → kill tmux sessions (all managed, or specific session(s))
    - restart: remember running sessions → shutdown → relaunch only those (or specific session(s))
```

### Functions

#### migrate_stray_sessions()

Skipped entirely in `--dry-run` mode.

Finds `claude` CLI processes (matched by full path `/opt/homebrew/bin/claude`) not running under a tmux ancestor, whose working directory matches a discovered project directory. SIGTERMs them so the main loop can resume them via `claude -c`. Waits 2 seconds after termination only if any processes were killed.

```
migrate_stray_sessions():
    if DRY_RUN: return

    for each PID matching /opt/homebrew/bin/claude:
        walk ancestor chain via ps -o ppid=
        if any ancestor comm starts with "tmux": skip (already in tmux)

        cwd = lsof -p PID -a -d cwd -Fn | grep ^n | cut -c2-
        if cwd is empty: skip

        if cwd == any managed_dir OR cwd starts with managed_dir + "/":
            log "Migrating stray claude session (pid=PID, cwd=cwd)"
            kill -TERM PID

    if any processes were killed: sleep 2
```

#### detect_github_ssh_accounts()

Parses `~/.ssh/config` for `Host github.com-*` entries. Sets global `GITHUB_SSH_INFO` to a prompt-ready string describing the accounts and how to use them as git remotes. Empty string if no accounts found or no ssh config.

#### ensure_git_repo(dir)

Runs `git init` if `$dir/.git` does not exist. Logged and skipped in dry-run.

#### setup_gitignore(dir)

If no `.gitignore` exists, creates one with common exclusions (secrets, credentials, Claude settings, OS, IDE, dependencies, build artifacts). Skips if file already exists. Called by `-n` (new project) only.

#### setup_default_mode(dir)

If `DEFAULT_PERMISSION_MODE` is non-empty, writes or merges `permissions.defaultMode` into `$dir/.claude/settings.local.json` using Python 3 for safe JSON merge. Logs a warning and skips on JSON parse/write failure.

#### create_claude_session(session_name, working_dir)

Skips if a tmux session with that name already exists AND Claude is running in it. If the session exists but Claude has exited, relaunches Claude into the existing session.

Builds a system prompt based on `ALLOW_CROSS_SESSION_CONTROL`:

- **false (default):** Claude learns its own session name and how to send commands to itself only:
  ```
  You are running inside tmux session '<name>'. You can send slash commands
  to yourself via: /opt/homebrew/bin/tmux send-keys -t '<name>' "/command args" Enter.
  <GITHUB_SSH_INFO>
  ```

- **true:** Claude also learns how to target other sessions, find its own session name, and list all sessions.

Writes the launch command to a temp script (`/tmp/claude-launch-XXXXXX`) and the system prompt to a separate temp file (`/tmp/claude-prompt-XXXXXX`) to avoid quoting complexity. The temp script uses `trap EXIT` to guarantee self-cleanup. Sends the temp script path to the tmux pane via `send-keys`. Sleeps `SLEEP_BETWEEN` seconds after launching.

Launch command inside temp script:
```bash
claude -c --remote-control --permission-mode auto --name '<session_name>' --append-system-prompt '<prompt>' 2>/dev/null || \
claude --remote-control --permission-mode auto --name '<session_name>' --append-system-prompt '<prompt>'
```

After sending the launch command, the script waits 5 seconds and checks for the workspace trust prompt. If found, it sends Enter to accept (option 1 is pre-selected). All managed directories are the user's own projects.

### Gitignore template (used by -n)

```
# Secrets and credentials
.env
.env.*
!.env.example
*.pem
*.key
*.p12
*.pfx
tokens.json
credentials.json
secrets.yaml
secrets.yml

# Claude
.claude/settings.local.json

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo

# Dependencies
node_modules/
vendor/
__pycache__/
*.pyc
venv/
.venv/

# Build
dist/
build/
*.o
*.so
*.dylib
```

### --dry-run Flag

When `--dry-run` is passed as the first argument:

- Print every action that would be taken (git init, tmux session creation, claude command)
- Do not execute any of them
- Log to stdout instead of file
- Skip `migrate_stray_sessions()` entirely
- Exit cleanly if `BASE_DIR` doesn't exist (don't create it)
- Still creates `~/.claude-mux/config` if missing (one-time setup, not an operational action)

### Exclusion Rules

Skip any subdirectory where the directory name:

- Starts with `.` (hidden directories, includes `.claude`)
- Starts with `-` (user convention for excluded/archived folders)

Applies to each discovered project directory.

### Session Name Sanitization

At the project subdir level, the directory name is sanitized to produce a valid tmux session name:

```
session_name = dir_name
    | spaces → hyphens
    | non-alphanumeric (except hyphens) → hyphens
    | collapse consecutive hyphens
    | strip leading/trailing hyphens
```

If the result is empty (e.g. a directory named `*`), the directory is skipped with a log warning. The working directory passed to tmux is always the original (unsanitized) path.

### Logging

All output appended to `$LOG_DIR/claude-mux.log` (default: `~/Library/Logs/claude-mux.log`) with UTC timestamps in ISO 8601 format:
```
[2026-04-06T08:00:00Z] message
```

When stdout is a terminal (`-t 1`), output is also mirrored to stdout in real time. When run via LaunchAgent (no terminal), log file only.

In `--dry-run` mode, output goes to stdout only (not the log file).

## LaunchAgent: com.user.claude-mux.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.claude-mux</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>exec "$HOME/Claude/claude-mux"</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>

</dict>
</plist>
```

### Notes

- `RunAtLoad: true` — executes at user login.
- 45-second startup delay in the script allows networking and Homebrew services to initialize.
- `~` does NOT expand in `ProgramArguments` — use `bash -c 'exec "$HOME/..."'` so bash expands `$HOME` at runtime. No hardcoded username needed.
- stdout/stderr are not redirected to files. LaunchAgent output goes to the macOS unified log. Use Console.app or `log show` for low-level LaunchAgent debugging.
- LaunchAgent runs in the user's login session, inheriting `$USER` and `$HOME`.

## Edge Cases

| Case | Handling |
|------|----------|
| No prior Claude session in directory | `claude -c` fails, `\|\|` falls back to `claude --remote-control --name <name>` |
| Directory has no `.git` | Script runs `git init` before launching Claude |
| tmux session already exists with claude running | Skip, log, continue to next |
| Claude exited but tmux session still alive | Detect via process tree check; relaunch claude into existing session |
| No Claude projects found | Log warning, exit cleanly |
| BASE_DIR does not exist | Created automatically (dry-run: exit cleanly with warning) |
| Folder name starts with `-` | Excluded from discovery |
| Folder name starts with `.` | Excluded from discovery (hidden directories pruned) |
| `.ignore-claudemux` present | Project excluded from discovery |
| Folder name contains spaces or special chars | Session name sanitized (spaces→hyphens, specials stripped); original path used as working dir |
| Folder name sanitizes to empty string (e.g. `*`) | Logged as warning, skipped |
| Script re-run after adding new project | Creates session for new folder, skips existing sessions |
| tmux or claude not installed | Dependency check at startup exits with error |
| Stray claude process outside tmux in managed dir | SIGTERMed; new tmux session resumes via `claude -c` |
| Stray claude process in unmanaged dir | Left untouched |
| Claude Desktop or IDE extension processes | Not matched — filter uses full path `/opt/homebrew/bin/claude` |
| `~/.claude-mux/config` does not exist | Created with commented defaults on first run |
| `.claude` exists as a file (not dir) | `mkdir -p` fails; `setup_default_mode` logs warning and skips |
| `settings.local.json` contains invalid JSON | Python merge fails; logs warning and skips |
| No GitHub SSH accounts in `~/.ssh/config` | `GITHUB_SSH_INFO` is empty; prompt omits the SSH section |
| Multiple GitHub SSH accounts | All injected into system prompt with their host aliases |

## Testing Instructions

### Phase 1: Dry Run

```bash
chmod +x ~/Claude/claude-mux
~/Claude/claude-mux --dry-run
```

Verify output lists correct directories, session names, git init targets, and detected GitHub SSH accounts. Confirm no files are created or modified.

### Phase 2: Single Session

Test with one project directory:

- Verify tmux session is created with correct name
- Verify Claude starts with Remote Control enabled
- Verify `~/.claude-mux/config` was created on first run
- Verify re-running the script skips the existing session

### Phase 3: Full Run

```bash
~/Claude/claude-mux
claude-mux -L
```

Verify all expected sessions are running. Connect via `claude-mux -t <name>` and confirm Claude is running with the correct system prompt (check session name, claude-mux commands, and GitHub SSH accounts).

### Phase 4: Session Migration

With a Claude process running outside tmux in a managed directory, run the script and verify:
- The stray process is terminated
- A new tmux session is created for that directory
- `claude -c` resumes the conversation

### Phase 5: LaunchAgent

```bash
# Install (preferred)
./install.sh

# Or manually:
cp com.user.claude-mux.plist ~/Library/LaunchAgents/
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.user.claude-mux.plist

# Verify
launchctl list | grep claude-mux

# Check logs
tail -f ~/Library/Logs/claude-mux.log

# Unload for debugging
launchctl bootout gui/$(id -u) ~/Library/LaunchAgents/com.user.claude-mux.plist
```

### Phase 6: Reboot Test

Restart the Mac. After login, wait 60 seconds, then verify:

```bash
claude-mux -L
```

All sessions should be running. Check `~/Library/Logs/claude-mux.log` for any errors.

## Resolved Implementation Notes

1. **Plist path expansion**: `~` does not expand in `ProgramArguments` — resolved by using `bash -c 'exec "$HOME/..."'` so bash expands `$HOME` at runtime. No hardcoded username in the repo.
2. **`claude -c` exit code**: Confirmed non-zero on no prior session; `||` fallback works correctly.
3. **tmux send-keys quoting**: Resolved by writing a temp script and sending its path, avoiding shell quoting complexity in `send-keys`.
4. **Rate limiting**: 5-second sleep between launches mitigates simultaneous RC registration issues.
