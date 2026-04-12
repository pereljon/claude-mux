# claude-mux — Claude Code Multiplexer

Persistent Claude Code sessions for all your projects — accessible from anywhere via the Claude mobile app.

A shell script that launches Claude Code inside tmux with Remote Control enabled. Run `claude-mux` in any directory to get a persistent, RC-accessible session. Use `claude-mux -a` (or the optional LaunchAgent) to launch sessions for all your projects at once.

## What It Does

By default, `claude-mux` launches a Claude Code session in the current directory inside tmux with Remote Control enabled, and attaches to it. If Claude was previously running in the directory, it resumes the conversation via `claude -c`.

Each Claude session is injected with its tmux session name (so it can send slash commands like `/model` and `/compact` to itself), and any GitHub SSH accounts found in `~/.ssh/config` (so it knows which accounts are available for git operations).

With `claude-mux -a` (or via the LaunchAgent at login), it runs in batch mode:

1. Finds all Claude projects under `~/Claude/` — any directory containing a `.claude/` subdirectory, at any depth
2. Skips directories starting with `-`, hidden directories, and directories containing `.ignore-claudemux`
3. Migrates any Claude Code processes already running outside tmux — SIGTERMs them so they resume cleanly inside tmux via `claude -c`
4. Creates a persistent tmux session per project with Claude Code running, with Remote Control enabled (if you've enabled RC globally via `/config`, the flag is redundant but harmless)
5. Attempts to resume the last conversation (`claude -c`), falling back to a fresh start

You can also create a new project with `claude-mux -n DIRECTORY` (which initializes git, creates a `.gitignore`, sets permission mode, and launches Claude).

## Requirements

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## Install

```bash
./install.sh
```

This installs `claude-mux` to the first writable bin directory in your `PATH`, creates `~/.claude-mux-rc` with your settings, and installs the LaunchAgent (disabled by default — use `--enable-launchagent` to activate batch startup at login).

Options:

```bash
./install.sh --enable-launchagent                  # enable batch startup at login
./install.sh --base-dir ~/work/claude              # use a different base directory
./install.sh --bin-dir ~/.local/bin                # specify bin directory explicitly
./install.sh --permission-mode acceptEdits         # set default Claude permission mode
./install.sh --cross-session-control               # enable multi-agent session control
./install.sh --no-launchagent                      # skip LaunchAgent installation entirely
```

When enabled, the LaunchAgent runs `claude-mux -a` at login with a 45-second startup delay to allow system services to initialize.

## Usage

```bash
claude-mux                       # launch Claude in current directory and attach
claude-mux ~/projects/my-app     # launch Claude in a directory and attach
claude-mux -d ~/projects/my-app  # same as above (explicit form)
claude-mux -a                    # start all managed sessions under BASE_DIR
claude-mux -n ~/projects/app     # create a new Claude project in existing dir and attach
claude-mux -n ~/new/path/app -p  # same, but create the directory and parents first
claude-mux -t my-app             # attach to an existing tmux session
claude-mux -s my-app '/model sonnet' # send a slash command to a session
claude-mux -l                    # list active sessions (running + stopped)
claude-mux -L                    # list all projects (active + idle)
claude-mux --shutdown            # gracefully exit all managed Claude sessions
claude-mux --shutdown my-app     # shut down a specific session
claude-mux --restart             # restart sessions that were running
claude-mux --restart my-app      # restart a specific session
claude-mux --dry-run             # preview actions without executing
claude-mux --version             # print version
claude-mux --help                # show all options

# Watch the log
tail -f ~/Library/Logs/claude-mux.log
```

When run from the terminal, output is mirrored to stdout in real time. When run via LaunchAgent, output goes to the log file only.

## Configuration

On first run, `~/.claude-mux-rc` is created automatically with all settings commented out. Edit it to override any defaults — the script never needs to be modified directly.

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory to scan for Claude projects (directories containing `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directory for the `claude-mux.log` file |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set Claude's `permissions.defaultMode` in each project. Valid: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Set to `""` to disable. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | When `true`, Claude sessions can send slash commands to other sessions via tmux — useful for multi-agent orchestration. When `false`, sessions can only command themselves. |
| `TMUX_EXTENDED_KEYS` | `true` | Enable tmux extended-keys for Shift+Enter and other modified key support (requires tmux 3.2+) |
| `SLEEP_BETWEEN` | `5` | Seconds to wait between launching each session in batch mode. Increase if sessions fail to register with Remote Control. |
| `LAUNCHAGENT_ENABLED` | `true` | When `false`, the LaunchAgent runs but exits without starting sessions. The installer sets this to `false` unless `--enable-launchagent` is passed. |

## Directory Structure

Projects are discovered by the presence of a `.claude/` directory, at any depth:

```
~/Claude/
├── work/
│   ├── project-a/          # ✓ has .claude/ — managed
│   │   └── .claude/
│   ├── project-b/          # ✓ has .claude/ — managed
│   │   └── .claude/
│   └── -archived/          # ✗ excluded (starts with -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ has .claude/ — managed
│   │   └── .claude/
│   ├── .hidden/            # ✗ excluded (hidden directory)
│   │   └── .claude/
│   └── project-d/          # ✗ no .claude/ — not a Claude project
├── deep/nested/project-e/  # ✓ has .claude/ — found at any depth
│   └── .claude/
└── ignored-project/        # ✗ excluded (.ignore-claudemux)
    ├── .claude/
    └── .ignore-claudemux
```

Session names are derived from directory names: spaces become hyphens, non-alphanumeric characters (except hyphens) are replaced, and leading/trailing hyphens are stripped. Directories whose name sanitizes to empty are skipped with a log warning.

## Session System Prompt

Each Claude session is launched with `--append-system-prompt` containing context about its environment:

```
You are running inside tmux session '<session-name>'.
You can send slash commands to yourself via: /path/to/claude-mux -s '<session-name>' '/command args'.
Other claude-mux commands:
  /path/to/claude-mux -l                       (list active sessions)
  /path/to/claude-mux -L                       (list all projects)
  /path/to/claude-mux -t SESSION               (attach to session)
  /path/to/claude-mux -d DIRECTORY             (launch session in directory)
  /path/to/claude-mux -n DIRECTORY             (create new project)
  /path/to/claude-mux -n DIRECTORY -p          (create new project with parents)
  /path/to/claude-mux --shutdown SESSION       (shut down a session)
  /path/to/claude-mux --restart SESSION        (restart a session)
Always display command output to the user — do not run commands silently.
GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

When `ALLOW_CROSS_SESSION_CONTROL=true`, the send command description changes to allow targeting any session, not just itself.

The `/path/to/claude-mux` is the absolute path to the script at launch time, so sessions don't depend on `PATH` being set correctly.

## Troubleshooting

### Sessions show "Not logged in · Run /login"

This happens on first launch if the macOS keychain is locked (common when the script runs before the keychain is unlocked after login). Fix:

```bash
# Unlock the keychain in a regular terminal
security unlock-keychain

# Then complete auth in any one running session
claude-mux -t <any-session>
# Run /login and complete the browser flow
```

After completing auth once, kill and relaunch all sessions — they'll pick up the stored credential automatically.

### Sessions not appearing in Claude Code Remote

Sessions must be authenticated (not showing "Not logged in"). After a clean authenticated launch they should appear in the RC list within a few seconds.

### Multi-line input in tmux

The `/terminal-setup` command cannot run inside tmux. claude-mux enables tmux `extended-keys` by default (`TMUX_EXTENDED_KEYS=true`), which supports Shift+Enter in most modern terminals. If Shift+Enter doesn't work, use `\` + Return to enter newlines in your prompt.

### Slash commands not available over Remote Control

Most slash commands (e.g. `/model`, `/clear`) are not currently supported in RC sessions. This is a [known open issue](https://github.com/anthropics/claude-code/issues/30674).

## Logs

- `~/Library/Logs/claude-mux.log` — all script actions with UTC timestamps (configurable via `LOG_DIR`)

For low-level LaunchAgent debugging, use Console.app or `log show`.
