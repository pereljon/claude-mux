# claude-mux — Claude Code Multiplexer

Persistent Claude Code sessions for all your projects — accessible from anywhere via the Claude mobile app.

A shell script that launches Claude Code inside tmux with Remote Control enabled, conversation resume, and session self-management — list sessions, send slash commands, start new projects, shut down or restart. Run `claude-mux` in any directory to get a persistent session accessible from your phone. Use `claude-mux -a` to launch sessions for all your projects at once.

## Quick Start

```bash
./install.sh
claude-mux ~/path/to/your/project
```

Or `cd` into your project directory and run:

```bash
claude-mux
```

That's it — you're in a persistent, session-aware Claude session with Remote Control enabled.

claude-mux is a single bash script with no dependencies beyond tmux and Claude Code.

## What It Does

1. **Persistent tmux sessions with Remote Control** — launches Claude Code inside tmux with `--remote-control` enabled, so every session is accessible from the Claude mobile app
2. **Conversation resume** — if Claude was previously running in the directory, resumes the last conversation (`claude -c`) inside a new tmux session with Remote Control, preserving your context
3. **Session management** — list sessions with status (`claude-mux -l`), shut down (`--shutdown`), restart (`--restart`), attach (`-t`), send commands (`-s`)
4. **Claude self-management** — each session is injected with a system prompt so Claude can run all of the above commands directly from conversation prompts (terminal or mobile app):
   - a. List running sessions and all projects
   - b. Launch new sessions, create new projects
   - c. Send slash commands to itself or other sessions (workaround for [slash commands not working natively over RC](https://github.com/anthropics/claude-code/issues/30674))
   - d. Shut down or restart sessions
5. **Home session** — a lightweight, always-running session in your base directory that launches at login (configurable via `LAUNCHAGENT_MODE`). Keeps Remote Control always available from the Claude mobile app and can manage all your other sessions. Protected from accidental shutdown.
6. **New project creation** — `claude-mux -n DIRECTORY` creates a ready-to-code project with git, `.gitignore`, and permission mode configured (`-p` creates the directory if it doesn't exist). Any running session can create new projects — ask Claude to set up a repo on any of your GitHub accounts and start coding, from anywhere
7. **CLAUDE.md templates** — maintain a library of CLAUDE.md instruction files in `~/.claude-mux/templates/` (e.g. `web.md`, `python.md`, `default.md`) and apply them automatically to new projects. Use `--template NAME` to pick a specific template or let the default apply
8. **SSH account awareness** — injects GitHub SSH host aliases from `~/.ssh/config` so Claude knows which accounts are available for git operations
9. **Auto-approved permissions** — claude-mux adds itself to each project's `.claude/settings.local.json` allow list so Claude can run claude-mux commands without prompting for permission
10. **Stray process migration** — if Claude is already running in the target directory outside tmux, terminates it and relaunches inside a managed tmux session (conversation resumes via `claude -c`)
11. **Tmux quality-of-life** — sessions are configured with mouse support, 50k scrollback buffer, clipboard integration, 256-color, reduced escape delay, extended keys (Shift+Enter), activity monitoring, and terminal tab titles — all configurable in the rc file

> **Note:** This is different from `claude --worktree --tmux`, which creates a tmux session for an isolated git worktree. claude-mux manages persistent sessions for your actual project directories, with Remote Control, system prompt injection, and batch orchestration.

### Home Session

A single general-purpose session living in `$BASE_DIR`. Launched automatically at login when `LAUNCHAGENT_MODE=home`, or manually by running `claude-mux` from `$BASE_DIR`. Gives you one always-ready Claude session accessible from your phone without launching sessions for every project.

The home session is always **protected** — `--shutdown home` refuses to stop it without `--force`, regardless of how it was started. Protected sessions are marked with `*` in `-l`/`-L` output (e.g. `active*`).

### Batch Mode

With `claude-mux -a` (or via the LaunchAgent at login with `LAUNCHAGENT_MODE=batch`), it launches sessions for all your projects at once:

1. Finds all Claude projects under `~/Claude/` — any directory containing a `.claude/` subdirectory, at any depth
2. Skips directories starting with `-`, hidden directories, and directories containing `.ignore-claudemux`
3. Migrates any Claude Code processes already running outside tmux
4. Creates a persistent tmux session per project with Remote Control enabled
5. Resumes the last conversation (`claude -c`), falling back to a fresh start

## Requirements

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) — `brew install tmux`
- [Claude Code](https://claude.ai/code) — `brew install claude`

## Install

```bash
./install.sh
```

The interactive installer asks where your Claude projects live, whether to start a home session at login, and which model to use. It installs `claude-mux` to `~/bin`, creates `~/.claude-mux/config`, and sets up the LaunchAgent.

Use `--non-interactive` to skip prompts and accept defaults.

Options:

```bash
./install.sh --non-interactive                     # skip prompts, use defaults
./install.sh --base-dir ~/work/claude              # use a different base directory
./install.sh --launchagent-mode batch              # launch all sessions at login
./install.sh --launchagent-mode none               # disable LaunchAgent behavior
./install.sh --home-model haiku                    # use Haiku for home session
./install.sh --no-launchagent                      # skip LaunchAgent installation entirely
```

The LaunchAgent runs `claude-mux --autolaunch` at login with a 45-second startup delay to allow system services to initialize.

## Usage

```bash
claude-mux                       # launch Claude in current directory and attach
claude-mux ~/projects/my-app     # launch Claude in a directory and attach
claude-mux -d ~/projects/my-app  # same as above (explicit form)
claude-mux -a                    # start all managed sessions under BASE_DIR
claude-mux -n ~/projects/app     # create a new Claude project and attach
claude-mux -n ~/new/path/app -p  # same, creating the directory and parents
claude-mux -n ~/app --template web  # new project with a specific CLAUDE.md template
claude-mux --list-templates      # show available CLAUDE.md templates
claude-mux -t my-app             # attach to an existing tmux session
claude-mux -s my-app '/model sonnet' # send a slash command to a session
claude-mux -l                    # list active sessions (active + running + stopped)
claude-mux -L                    # list all projects (active + idle)
claude-mux --shutdown            # gracefully exit all managed Claude sessions
claude-mux --shutdown my-app     # shut down a specific session
claude-mux --shutdown a b c      # shut down multiple sessions
claude-mux --shutdown home --force  # shut down protected home session
claude-mux --restart             # restart sessions that were running
claude-mux --restart my-app      # restart a specific session
claude-mux --restart a b c       # restart multiple sessions
claude-mux --dry-run             # preview actions without executing
claude-mux --version             # print version
claude-mux --help                # show all options

# Watch the log
tail -f ~/Library/Logs/claude-mux.log
```

When run from the terminal, output is mirrored to stdout in real time. When run via LaunchAgent, output goes to the log file only.

## Session Statuses

| Status | Meaning |
|--------|---------|
| `active` | tmux session exists, Claude is running, and a local tmux client is attached |
| `running` | tmux session exists and Claude is running (no local client attached) |
| `stopped` | tmux session exists but Claude has exited |
| `idle` | A `.claude/` project exists under `BASE_DIR` but has no claude-mux tmux session running (shown only with `-L`) |

A trailing `*` on any status indicates the session is protected and requires `--force` to shut down (e.g. `active*`, `running*`). The home session is always protected.

## Claude Prompt Examples

Because each session is injected with claude-mux commands, you can manage sessions directly from conversation prompts — in the terminal or via the mobile app:

```
You: "What sessions are running?"
Claude: runs `claude-mux -l` and displays the results

You: "Show me all projects"
Claude: runs `claude-mux -L` and displays the results

You: "Start a session for my api-server work project"
Claude: runs `claude-mux -d ~/Claude/work/api-server --no-attach`

You: "Create a new personal project called mobile-app"
Claude: runs `claude-mux -n ~/Claude/personal/mobile-app -p --no-attach`

You: "What templates do I have?"
Claude: runs `claude-mux --list-templates` and displays the results

You: "Create a new work project called api-server using the web template"
Claude: runs `claude-mux -n ~/Claude/work/api-server -p --template web --no-attach`

You: "Switch all sessions to Sonnet"
Claude: runs `claude-mux -s SESSION '/model sonnet'` for each running session

You: "Shut down the data-pipeline session"
Claude: runs `claude-mux --shutdown data-pipeline`

You: "Restart the stuck web-dashboard session"
Claude: runs `claude-mux --restart web-dashboard`

You: "Launch the data-pipeline session in the background"
Claude: runs `claude-mux -d ~/Claude/work/data-pipeline --no-attach`

You: "Start all my projects"
Claude: runs `claude-mux -a` (after confirming — this starts every managed project)
```

## Configuration

On first run, `~/.claude-mux/config` is created automatically with all settings commented out. Edit it to override any defaults — the script never needs to be modified directly.

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory to scan for Claude projects (directories containing `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directory for the `claude-mux.log` file |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set Claude's `permissions.defaultMode` in each project. Valid: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Set to `""` to disable. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | When `true`, Claude sessions can send slash commands to other sessions — useful for multi-agent orchestration |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directory containing CLAUDE.md template files |
| `DEFAULT_TEMPLATE` | `default.md` | Default template applied to new projects (`-n`). Set to `""` to disable. |
| `SLEEP_BETWEEN` | `5` | Seconds between session launches in batch mode. Increase if RC registration fails. |
| `LAUNCHAGENT_MODE` | `home` | LaunchAgent behavior at login: `none` (do nothing), `home` (launch protected home session), `batch` (launch all managed sessions). Legacy `LAUNCHAGENT_ENABLED=true` is treated as `batch`. |

**Tmux session options** (all configurable, all enabled by default):

| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | Mouse support — scroll, select, resize panes |
| `TMUX_HISTORY_LIMIT` | `50000` | Scrollback buffer size in lines (tmux default is 2000) |
| `TMUX_CLIPBOARD` | `true` | System clipboard integration via OSC 52 |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Terminal type for proper color rendering |
| `TMUX_EXTENDED_KEYS` | `true` | Extended key sequences including Shift+Enter (requires tmux 3.2+) |
| `TMUX_ESCAPE_TIME` | `10` | Escape key delay in milliseconds (tmux default is 500) |
| `TMUX_TITLE_FORMAT` | `#S` | Terminal/tab title format (`#S` = session name, `""` to disable) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Notify when activity occurs in other sessions |

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
claude-mux path: /path/to/claude-mux

Rules:
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session
  via the -s command. Never tell the user you cannot change models or run slash
  commands.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session
- Always display command output to the user
- The 'home' session is a general-purpose session in the base directory, always
  available for managing other sessions. It is protected (* in status):
  --shutdown requires --force, but --restart bypasses protection (it relaunches,
  not permanently kills).
- When asked to shut down sessions, run the command directly — protected sessions
  are skipped automatically, do not ask for confirmation

Commands:
  -s '<session-name>' '/command'  Send slash command to yourself
  -l                          List active sessions
  -L                          List all projects
  -d DIR --no-attach          Launch session in directory
  -n DIR --no-attach          New project
  -n DIR -p --no-attach       New project (create parents)
  --template NAME             CLAUDE.md template (with -n)
  --list-templates            Show available templates
  --shutdown SESSION...       Shut down sessions (omit SESSION to shut down all)
  --shutdown SESSION --force  Shut down protected session
  --restart SESSION...        Restart sessions (omit SESSION to restart all running)
  -a                          Start ALL sessions (use with caution)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

When `ALLOW_CROSS_SESSION_CONTROL=true`, the send command changes to allow targeting any session, not just itself. The path is the absolute path to the script at launch time, so sessions don't depend on `PATH`.

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

### Slash commands over Remote Control

Slash commands (e.g. `/model`, `/clear`) are [not natively supported](https://github.com/anthropics/claude-code/issues/30674) in RC sessions. claude-mux works around this — each session is injected with `claude-mux -s` so Claude can send slash commands to itself via tmux.

## Logs

- `~/Library/Logs/claude-mux.log` — all script actions with UTC timestamps (configurable via `LOG_DIR`)

For low-level LaunchAgent debugging, use Console.app or `log show`.
