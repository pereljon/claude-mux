# claude-mux - Claude Code Multiplexer

**English** · [Español](translations/README.es.md) · [Français](translations/README.fr.md) · [Deutsch](translations/README.de.md) · [Português](translations/README.pt-BR.md) · [日本語](translations/README.ja.md) · [한국어](translations/README.ko.md) · [Italiano](translations/README.it.md) · [Русский](translations/README.ru.md) · [中文](translations/README.zh-CN.md) · [עברית](translations/README.he.md) · [العربية](translations/README.ar.md) · [हिन्दी](translations/README.hi.md)

Persistent Claude Code sessions for all your projects - accessible from anywhere via the Claude mobile app.

## Why

Remote Control promises Claude Code from anywhere — but without session management, it's a second-class interface even from Claude Desktop:

- Sessions die when you close the terminal, and conversation context doesn't resume automatically
- There's no home base — nothing is running when you pick up your phone unless you left something open
- If a session isn't running, Remote Control is useless — you can't reach a project or start one
- Even in a running RC session, slash commands don't work — no model switching, compacting, or permission mode changes
- Starting a new project requires manually creating a directory, initializing git, writing a CLAUDE.md, setting a permission mode, and picking a model — none of which you can do from RC
- Managing multiple projects means multiple manual terminal launches with no overview of what's running or what state anything is in

claude-mux fixes all of this. It wraps Claude Code in tmux so sessions persist, injects a system prompt so Claude can manage its own sessions, and routes slash commands through tmux so they work over Remote Control. Once a session is running, you manage everything by talking to Claude — in the terminal or the mobile app.

## Quick Start

```bash
brew tap pereljon/tap
brew install claude-mux
claude-mux --install
```

```bash
cd ~/path/to/your/project
claude-mux
```

Or:

```bash
claude-mux ~/path/to/your/project
```

That's it. You're in a persistent, session-aware Claude session with Remote Control enabled. From here, everything is conversational.

## Talking to Claude

This is how you use claude-mux day to day. Every session is injected with commands so Claude can manage sessions, switch models, send slash commands, and create new projects — all from inside the conversation. You don't need to remember CLI flags.

```
You: "status"
Claude: reports session name, model, permission mode, context usage, and lists all sessions

You: "list active sessions"
Claude: shows all running sessions with their status

You: "start a session for my api-server project"
Claude: launches a session in ~/Claude/work/api-server

You: "create a new project called mobile-app using the web template"
Claude: creates the project directory, initializes git, applies the template, launches a session

You: "switch this session to Haiku"
Claude: sends /model haiku to itself via tmux

You: "compact the api-server session"
Claude: sends /compact to the api-server session

You: "restart the web-dashboard session"
Claude: shuts down and relaunches the session, preserving conversation context

You: "switch the api-server session to plan mode"
Claude: restarts the session with plan permission mode

You: "switch this session to yolo mode"
Claude: switches to bypassPermissions mode via Shift+Tab — no restart needed

You: "what mode is this session"
Claude: reports the current permission mode (default, acceptEdits, plan, bypassPermissions)

You: "switch this session to Opus"
Claude: sends /model opus to itself via tmux

You: "clear this session"
Claude: sends /clear to itself, resetting the conversation

You: "hide this project"
Claude: writes .claudemux-ignore so the project is excluded from -L listings

You: "protect this session"
Claude: writes .claudemux-protected and sets the tmux marker — shutdown now requires --force

You: "is this session protected"
Claude: checks for .claudemux-protected in the project folder and reports

You: "delete the old-prototype project"
Claude: confirms in chat, then moves the project folder to system trash

You: "update claude-mux"
Claude: warns that all sessions will restart, asks for confirmation, then updates and restarts

You: "stop all sessions"
Claude: gracefully exits all managed sessions

You: "help"
Claude: prints the full list of conversational commands
```

These commands work in any language. If you type the equivalent in Spanish, Japanese, Hebrew, or any other language, Claude infers the intent and runs the matching command.

Type `help` inside any session to see the full command list.

### Home Session

The home session is a general-purpose session that lives in your base directory (`~/Claude` by default). It launches automatically at login when `LAUNCHAGENT_MODE=home`, giving you one always-ready Claude session accessible from your phone. Use it to manage all your other sessions without launching project-specific ones first.

The home session is **protected** by default — `--shutdown home` refuses to stop it without `--force`. Protection is driven by the `.claudemux-protected` marker in `$BASE_DIR`, created by `claude-mux --install`. Protected sessions show `protected` in the status column; the calling session is marked with `>` in the name column.

## What It Does

Under the hood, claude-mux handles:

- **Persistent tmux sessions** with Remote Control enabled, so every session is accessible from the Claude mobile app
- **Conversation resume** — resumes the last conversation (`claude -c`) when relaunching, preserving context
- **System prompt injection** — each session gets commands for self-management, slash command routing, and SSH account awareness
- **CLAUDE.md templates** — maintain template files (e.g. `web.md`, `python.md`) in `~/.claude-mux/templates/` and apply them to new projects
- **Multi-CLI-coder support** — creates `AGENTS.md` and `GEMINI.md` as symlinks to `CLAUDE.md` so Codex CLI, Gemini CLI, and other tools share the same instructions
- **Auto-approved permissions** — adds claude-mux to each project's allow list so Claude can run session commands without prompting
- **Stray process migration** — if Claude is already running outside tmux, migrates it into a managed session
- **Tmux quality-of-life** — mouse support, 50k scrollback, clipboard, 256-color, extended keys, activity monitoring, tab titles

> **Note:** This is different from `claude --worktree --tmux`, which creates a tmux session for an isolated git worktree. claude-mux manages persistent sessions for your actual project directories, with Remote Control and system prompt injection.

## Requirements

- macOS (Apple Silicon)
- [tmux](https://github.com/tmux/tmux) - `brew install tmux`
- [Claude Code](https://claude.ai/code) - `brew install claude`

## Install

### Homebrew (recommended)

```bash
brew tap pereljon/tap
brew install claude-mux
```

After installing, run the setup command to create your config and optionally install the LaunchAgent (home session at login):

```bash
claude-mux --install
```

To update:

```bash
brew upgrade claude-mux       # or: claude-mux --update  (works from inside any session)
```

### Manual

```bash
./install.sh
```

`install.sh` copies the binary to `~/bin` and adds it to `PATH`. After that, run:

```bash
claude-mux --install
```

The interactive setup asks where your Claude projects live, whether to start a home session at login, and which model to use. It creates `~/.claude-mux/config` and installs the LaunchAgent.

Use `--non-interactive` to skip prompts and accept defaults.

Options:

```bash
claude-mux --install --non-interactive                     # skip prompts, use defaults
claude-mux --install --base-dir ~/work/claude              # use a different base directory
claude-mux --install --launchagent-mode none               # disable LaunchAgent behavior
claude-mux --install --home-model haiku                    # use Haiku for home session
claude-mux --install --no-launchagent                      # skip LaunchAgent installation entirely
```

The LaunchAgent runs `claude-mux --autolaunch` at login with a 45-second startup delay to allow system services to initialize.

## Session Statuses

| Status | Meaning |
|--------|---------|
| `running` | tmux session exists and Claude is running |
| `protected` | same as `running`, but the session is protected — `--shutdown` requires `--force` to stop it |
| `stopped` | tmux session exists but Claude has exited |
| `idle` | A `.claude/` project exists under `BASE_DIR` but has no claude-mux tmux session running (shown only with `-L`) |

A `>` prefix on the session name (e.g. `> home`) marks the session that ran the list command.

Running `claude-mux` in a directory that already has a running session attaches to it. Multiple terminals can attach to the same session (standard tmux behavior).

## Project Markers

Per-project state lives in marker files at the project root, not in central config. Markers use the `.claudemux-` prefix and are automatically added to `.gitignore` when created in a git-tracked project.

| Marker | Meaning | CLI |
|--------|---------|-----|
| `.claudemux-protected` | Session is protected at launch — `--shutdown` requires `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | Project is hidden from `claude-mux -L` listings | `--hide` / `--show` |

```bash
claude-mux --hide                    # hide current project from -L listings
claude-mux --show                    # unhide current project
claude-mux --protect                 # protect this session from accidental shutdown
claude-mux --unprotect               # remove protection
claude-mux -L --hidden               # list only hidden projects
claude-mux --delete ~/projects/old   # move project folder to system trash (macOS)
```

Markers travel with the project folder across renames and moves. A single `.gitignore` pattern (`.claudemux-*`) covers all current and future markers.

## Configuration

`~/.claude-mux/config` is created by `claude-mux --install` (or on first run of any command if no config exists). Edit it to override any defaults — the script never needs to be modified directly.

| Variable | Default | Description |
|----------|---------|-------------|
| `BASE_DIR` | `$HOME/Claude` | Root directory to scan for Claude projects (directories containing `.claude/`) |
| `LOG_DIR` | `$HOME/Library/Logs` | Directory for the `claude-mux.log` file |
| `DEFAULT_PERMISSION_MODE` | `auto` | Set Claude's `permissions.defaultMode` in each project. Valid: `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Set to `""` to disable. |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | When `true`, Claude sessions can send slash commands to other sessions - useful for multi-agent orchestration |
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directory containing CLAUDE.md template files |
| `DEFAULT_TEMPLATE` | `default.md` | Default template applied to new projects (`-n`). Set to `""` to disable. |
| `SLEEP_BETWEEN` | `5` | Seconds between session launches when `-a` is used. Increase if RC registration fails. |
| `HOME_SESSION_MODEL` | `""` | Model for the home session. Valid: `sonnet`, `haiku`, `opus`. Empty inherits Claude's default. |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Space-separated list of files to create as symlinks to `CLAUDE.md` for other AI CLI tools. Set to `""` to disable. |
| `LAUNCHAGENT_MODE` | `home` | LaunchAgent behavior at login: `none` (do nothing) or `home` (launch protected home session). Legacy `LAUNCHAGENT_ENABLED=true` is treated as `home`. |

**Tmux session options** (all configurable, all enabled by default):

| Variable | Default | Description |
|----------|---------|-------------|
| `TMUX_MOUSE` | `true` | Mouse support - scroll, select, resize panes |
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
│   ├── project-a/          # ✓ has .claude/ - managed
│   │   └── .claude/
│   ├── project-b/          # ✓ has .claude/ - managed
│   │   └── .claude/
│   └── -archived/          # ✗ excluded (starts with -)
│       └── .claude/
├── personal/
│   ├── project-c/          # ✓ has .claude/ - managed
│   │   └── .claude/
│   ├── .hidden/            # ✗ excluded (hidden directory)
│   │   └── .claude/
│   └── project-d/          # ✗ no .claude/ - not a Claude project
├── deep/nested/project-e/  # ✓ has .claude/ - found at any depth
│   └── .claude/
└── ignored-project/        # ✗ excluded (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

Session names are derived from directory names: spaces become hyphens, non-alphanumeric characters (except hyphens) are replaced, and leading/trailing hyphens are stripped. Directories whose name sanitizes to empty are skipped with a log warning.

## Session System Prompt

Each Claude session is launched with `--append-system-prompt` containing context about its environment:

```
You are running inside tmux session '<session-name>'. claude-mux path: /path/to/claude-mux
claude-mux version: <version>
[Update available: <new-version> (found <date>). Tell the user and suggest they say "update claude-mux" to update.]

Reference lookups (run on demand if you need information not covered by trigger rules):
  claude-mux --guide          → conversational commands list (used for "help")
  claude-mux --commands       → full CLI reference
  claude-mux --config-help    → config options with defaults, types, descriptions
  claude-mux --list-templates → available CLAUDE.md templates

Rules:
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session via the -s command.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session; do NOT add --no-attach to these commands
- Always print command output verbatim in your response text — if a command fails, report the error
- When command output contains <assistant-must-display> tags, include the COMPLETE content verbatim
- The 'home' session is the always-available session in the base directory. It is protected (shows 'protected' in status): --shutdown requires --force, but --restart bypasses protection. Protection is driven by the .claudemux-protected marker.
- Disambiguate 'home': 'home session' means the claude-mux session named home; 'home folder' means ~/
- When asked to shut down sessions, run the command directly — protected sessions are skipped automatically
- Use claude-mux for ALL session management. Never use raw tmux, ls, or other shell commands for session management.
- Don't guess at claude-mux flags. If you need information not in the trigger rules, run the relevant lookup.
- When user says: ready — respond with "Session ready!" on one line. Nothing else.
- When user says: help — run claude-mux --guide and print the output verbatim
- When user says: status — report session name, model, permission mode, context estimate, then run claude-mux -l
- When user says: list active sessions — run claude-mux -l
- When user says: list all sessions — run claude-mux -L
- When user says: list hidden projects — run claude-mux -L --hidden
- When user says: start session SESSION — run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME — run claude-mux --shutdown
- When user says: stop all sessions — run claude-mux --shutdown
- When user says: restart this session / restart session NAME — run claude-mux --restart
- When user says: restart all sessions — run claude-mux --restart
- When user says: start new session in FOLDER — run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: update claude-mux — warn sessions will restart, get confirmation, run --update then --restart
- When user says: hide this project / hide PROJECT — run claude-mux --hide
- When user says: show this project / show PROJECT / unhide PROJECT — run claude-mux --show
- When user says: protect this session / protect SESSION — run claude-mux --protect
- When user says: unprotect this session / unprotect SESSION — run claude-mux --unprotect
- When user says: is this hidden / is this protected — check for .claudemux-ignore or .claudemux-protected
- When user says: delete this project / delete PROJECT — confirm in chat first, then run claude-mux --delete DIR --yes
- When user says: list templates — run claude-mux --list-templates
- These trigger phrases work in any language.

Additional capabilities (run claude-mux --commands for full syntax):
  - Attach interactively to a session (-t — user-only, never from inside a session)
  - Start all sessions at once (-a)
  - New project with a CLAUDE.md template (-n DIR --template NAME, -p for parent dirs)
  - Force-shutdown a protected session (--shutdown SESSION --force)
  - Hide/show projects (--hide / --show)
  - Protect/unprotect sessions (--protect / --unprotect)
  - Move a project to trash (--delete DIR — macOS; honors protection unless --force)
  - Show all config options (--config-help)
  - Run interactive setup or reconfigure (--install)
  - Update claude-mux (--update)

Self-targeting send: claude-mux -s '<session-name>' '/command' sends slash commands to yourself.
GitHub SSH accounts configured in ~/.ssh/config: <accounts>.
```

The home session receives additional context: a description of its role, plus self-management triggers for reading/editing config and templates. When `ALLOW_CROSS_SESSION_CONTROL=true`, the send command can target any session, not just itself. The path is the absolute path to the script at launch time, so sessions don't depend on `PATH`.

## CLI Reference

You rarely need these directly — Claude runs them for you from inside sessions. These are available for scripting, automation, or when you're not inside a session.

```bash
# Launch and attach
claude-mux                       # launch Claude in current directory and attach
claude-mux ~/projects/my-app     # launch Claude in a directory and attach
claude-mux -d ~/projects/my-app  # same as above (explicit form)
claude-mux -t my-app             # attach to an existing tmux session

# Create new projects
claude-mux -n ~/projects/app     # create a new Claude project and attach
claude-mux -n ~/new/path/app -p  # same, creating the directory and parents
claude-mux -n ~/app --template web        # new project with a specific CLAUDE.md template
claude-mux -n ~/app --no-multi-coder      # new project without AGENTS.md/GEMINI.md symlinks

# Session management
claude-mux -l                    # list sessions by status (active, running, stopped)
claude-mux -L                    # list all projects (active + idle)
claude-mux -L --hidden           # list only hidden projects
claude-mux -s my-app '/model sonnet'      # send a slash command to a session
claude-mux --shutdown my-app              # shut down a specific session
claude-mux --shutdown                     # shut down all managed sessions
claude-mux --shutdown home --force        # shut down protected home session
claude-mux --restart my-app              # restart a specific session
claude-mux --restart                     # restart all running sessions
claude-mux --permission-mode plan my-app  # restart session with plan mode
claude-mux -a                    # start all managed sessions under BASE_DIR

# Project markers
claude-mux --hide                # hide current project from -L listings
claude-mux --hide ~/projects/old # hide a specific project
claude-mux --show                # unhide current project
claude-mux --protect             # protect this session from accidental shutdown
claude-mux --unprotect           # remove protection
claude-mux --delete ~/projects/old       # move project folder to system trash (macOS)
claude-mux --delete ~/projects/old --yes # same, skip confirmation prompt

# Other
claude-mux --list-templates      # show available CLAUDE.md templates
claude-mux --guide               # show conversational commands for use within sessions
claude-mux --commands            # show full CLI reference
claude-mux --config-help         # show all config options with defaults and descriptions
claude-mux --install             # interactive setup: config + LaunchAgent
claude-mux --update              # update to the latest version
claude-mux --dry-run             # preview actions without executing
claude-mux --version             # print version
claude-mux --help                # show all options

# Watch the log
tail -f ~/Library/Logs/claude-mux.log
```

When run from the terminal, output is mirrored to stdout in real time. When run via LaunchAgent, output goes to the log file only.

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

After completing auth once, kill and relaunch all sessions - they'll pick up the stored credential automatically.

### Sessions not appearing in Claude Code Remote

Sessions must be authenticated (not showing "Not logged in"). After a clean authenticated launch they should appear in the RC list within a few seconds.

### Multi-line input in tmux

The `/terminal-setup` command cannot run inside tmux. claude-mux enables tmux `extended-keys` by default (`TMUX_EXTENDED_KEYS=true`), which supports Shift+Enter in most modern terminals. If Shift+Enter doesn't work, use `\` + Return to enter newlines in your prompt.

### "Session ready!" on session start

When a session starts or restarts, claude-mux automatically sends a `Ready?` message after Claude finishes loading. The injection tells Claude to respond with "Session ready!" and nothing else. This confirms the session is alive and the injection is working.

### Slash commands over Remote Control

Slash commands (e.g. `/model`, `/clear`) are [not natively supported](https://github.com/anthropics/claude-code/issues/30674) in RC sessions. claude-mux works around this - each session is injected with `claude-mux -s` so Claude can send slash commands to itself via tmux.

## Logs

- `~/Library/Logs/claude-mux.log` - all script actions with UTC timestamps (configurable via `LOG_DIR`)

For low-level LaunchAgent debugging, use Console.app or `log show`.
