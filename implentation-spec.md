# Claude Auto Remote Control (`claude-autorc`): Implementation Spec

## Overview

A shell script and macOS LaunchAgent that automatically creates persistent tmux sessions running Claude Code with Remote Control for each project directory under `~/Claude/` (configurable).

## Directory Structure (Expected)

```
~/Claude/                          ← BASE_DIR (configurable)
├── work/                          ← category (any top-level dir not starting with . or -)
│   ├── project-a/
│   ├── project-b/
│   └── -archived-thing/           ← excluded (starts with -)
├── personal/                      ← category
│   ├── project-c/
│   └── project-d/
└── -old/                          ← excluded (starts with -)
```

Categories are discovered dynamically — any subdirectory of `BASE_DIR` not starting with `.` or `-`.

## Deliverables

1. `~/Claude/start-claude-sessions.sh` — main script
2. `com.user.claude-sessions.plist` — LaunchAgent plist (user installs to `~/Library/LaunchAgents/`)
3. `claude-autorc.example` — example user config file

## User Configuration: ~/.claude-autorc

On first run, the script creates `~/.claude-autorc` with all settings commented out. Users edit this file to override defaults without touching the script.

### Settings

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory containing category and project directories |
| `AUTO_GITIGNORE` | `true` | Create `.gitignore` with common dev exclusions if one doesn't exist |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set `permissions.defaultMode` in `.claude/settings.local.json` per project. Valid: `""` (disabled), `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions` |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | When `true`, Claude sessions are told they can send slash commands to other sessions via tmux. When `false`, sessions can only send commands to themselves. |

The script sources `~/.claude-autorc` after setting defaults, so any variable set in the config overrides the default.

## Script: start-claude-sessions.sh

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
1. Set defaults (BASE_DIR, AUTO_GITIGNORE, DEFAULT_PERMISSION_MODE, ALLOW_CROSS_SESSION_CONTROL)
2. Create ~/.claude-autorc with commented defaults if it doesn't exist
3. Source ~/.claude-autorc (user overrides apply from here on)
4. Parse --dry-run flag
5. Create BASE_DIR if it doesn't exist (exit cleanly in dry-run if missing)
6. Discover CATEGORIES (subdirs of BASE_DIR not starting with . or -)
7. 45-second startup delay (skipped in dry-run) for LaunchAgent login use
8. Check dependencies (tmux, claude)
9. Detect GitHub SSH accounts from ~/.ssh/config
10. migrate_stray_sessions()
11. For each CATEGORY: ensure_git_repo, create_claude_session
12. For each project SUBDIR: ensure_git_repo, setup_gitignore, setup_default_mode, create_claude_session
```

### Functions

#### migrate_stray_sessions()

Skipped entirely in `--dry-run` mode.

Finds `claude` CLI processes (matched by full path `/opt/homebrew/bin/claude`) not running under a tmux ancestor, whose working directory is at or under a managed category directory. SIGTERMs them so the main loop can resume them via `claude -c`. Waits 2 seconds after termination only if any processes were killed.

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

If `AUTO_GITIGNORE=true` and no `.gitignore` exists, creates one with common exclusions (secrets, credentials, Claude settings, OS, IDE, dependencies, build artifacts). Skips if file already exists.

#### setup_default_mode(dir)

If `DEFAULT_PERMISSION_MODE` is non-empty, writes or merges `permissions.defaultMode` into `$dir/.claude/settings.local.json` using Python 3 for safe JSON merge. Logs a warning and skips on JSON parse/write failure.

#### create_claude_session(session_name, working_dir)

Skips if a tmux session with that name already exists.

Builds a system prompt based on `ALLOW_CROSS_SESSION_CONTROL`:

- **false (default):** Claude learns its own session name and how to send commands to itself only:
  ```
  You are running inside tmux session '<name>'. You can send slash commands
  to yourself via: /opt/homebrew/bin/tmux send-keys -t '<name>' "/command args" Enter.
  <GITHUB_SSH_INFO>
  ```

- **true:** Claude also learns how to target other sessions, find its own session name, and list all sessions.

Writes the launch command to a temp script (`/tmp/claude-launch-XXXXXX.sh`) to avoid quoting complexity. The temp script uses `trap EXIT` to guarantee self-cleanup. Sends the temp script path to the tmux pane via `send-keys`. Sleeps `SLEEP_BETWEEN` seconds after launching.

Launch command inside temp script:
```bash
claude -c --rc --name '<session_name>' --append-system-prompt '<prompt>' 2>/dev/null || \
claude --rc --name '<session_name>' --append-system-prompt '<prompt>'
```

### AUTO_GITIGNORE template

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
- Still creates `~/.claude-autorc` if missing (one-time setup, not an operational action)

### Exclusion Rules

Skip any subdirectory where the directory name:

- Starts with `.` (hidden directories, includes `.claude`)
- Starts with `-` (user convention for excluded/archived folders)

Applies at both the category level (subdirs of `BASE_DIR`) and project level (subdirs of each category).

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

All output appended to `$BASE_DIR/claude-autorc.log` with UTC timestamps in ISO 8601 format:
```
[2026-04-06T08:00:00Z] message
```

When stdout is a terminal (`-t 1`), output is also mirrored to stdout in real time. When run via LaunchAgent (no terminal), log file only.

In `--dry-run` mode, output goes to stdout only (not the log file).

## LaunchAgent: com.user.claude-sessions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.claude-sessions</string>

    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>exec "$HOME/Claude/start-claude-sessions.sh"</string>
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
| No prior Claude session in directory | `claude -c` fails, `\|\|` falls back to `claude --rc --name <name>` |
| Directory has no `.git` | Script runs `git init` before launching Claude (bypasses trust prompt) |
| tmux session already exists | Skip, log, continue to next |
| Claude exited but tmux session still alive | Script skips (tmux session exists); Claude is not re-launched |
| Category directory missing | Log warning, skip to next category |
| No category directories found | Log warning, exit cleanly |
| BASE_DIR does not exist | Created automatically (dry-run: exit cleanly with warning) |
| Folder name starts with `-` | Excluded at category and project level |
| Folder name starts with `.` | Excluded at category and project level |
| Folder name contains spaces or special chars | Session name sanitized (spaces→hyphens, specials stripped); original path used as working dir |
| Folder name sanitizes to empty string (e.g. `*`) | Logged as warning, skipped |
| Script re-run after adding new project | Creates session for new folder, skips existing sessions |
| tmux or claude not installed | Dependency check at startup exits with error |
| Stray claude process outside tmux in managed dir | SIGTERMed; new tmux session resumes via `claude -c` |
| Stray claude process in unmanaged dir | Left untouched |
| Claude Desktop or IDE extension processes | Not matched — filter uses full path `/opt/homebrew/bin/claude` |
| `~/.claude-autorc` does not exist | Created with commented defaults on first run |
| `.claude` exists as a file (not dir) | `mkdir -p` fails; `setup_default_mode` logs warning and skips |
| `settings.local.json` contains invalid JSON | Python merge fails; logs warning and skips |
| No GitHub SSH accounts in `~/.ssh/config` | `GITHUB_SSH_INFO` is empty; prompt omits the SSH section |
| Multiple GitHub SSH accounts | All injected into system prompt with their host aliases |

## Testing Instructions

### Phase 1: Dry Run

```bash
chmod +x ~/Claude/start-claude-sessions.sh
~/Claude/start-claude-sessions.sh --dry-run
```

Verify output lists correct directories, session names, git init targets, and detected GitHub SSH accounts. Confirm no files are created or modified.

### Phase 2: Single Session

Test with one project directory:

- Verify tmux session is created with correct name
- Verify Claude starts with Remote Control enabled
- Verify `~/.claude-autorc` was created on first run
- Verify re-running the script skips the existing session

### Phase 3: Full Run

```bash
~/Claude/start-claude-sessions.sh
tmux list-sessions
```

Verify all expected sessions exist. Connect via `tmux attach -t <name>` and confirm Claude is running with the correct system prompt (check session name and GitHub SSH accounts).

### Phase 4: Session Migration

With a Claude process running outside tmux in a managed directory, run the script and verify:
- The stray process is terminated
- A new tmux session is created for that directory
- `claude -c` resumes the conversation

### Phase 5: LaunchAgent

```bash
# Install
cp com.user.claude-sessions.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.user.claude-sessions.plist

# Verify
launchctl list | grep claude-sessions

# Check logs
cat ~/Claude/launchagent-stdout.log
cat ~/Claude/startup.log

# Unload for debugging
launchctl unload ~/Library/LaunchAgents/com.user.claude-sessions.plist
```

### Phase 6: Reboot Test

Restart the Mac. After login, wait 60 seconds, then verify:

```bash
tmux list-sessions
```

All sessions should be present. Check `~/Claude/startup.log` for any errors.

## Resolved Implementation Notes

1. **Plist path expansion**: `~` does not expand in `ProgramArguments` — resolved by using `bash -c 'exec "$HOME/..."'` so bash expands `$HOME` at runtime. No hardcoded username in the repo.
2. **`claude -c` exit code**: Confirmed non-zero on no prior session; `||` fallback works correctly.
3. **tmux send-keys quoting**: Resolved by writing a temp script and sending its path, avoiding shell quoting complexity in `send-keys`.
4. **Rate limiting**: 5-second sleep between launches mitigates simultaneous RC registration issues.
