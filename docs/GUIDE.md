# Guide

Detailed reference for claude-mux configuration, internals, and troubleshooting.

## Home Session

The home session is a general-purpose session that lives in your base directory (`~/Claude` by default). It launches automatically at login when `LAUNCHAGENT_MODE=home`, giving you one always-ready Claude session accessible from your phone. Use it to manage all your other sessions without launching project-specific ones first.

The home session is **protected** by default - `--shutdown home` refuses to stop it without `--force`. Protection is driven by the `.claudemux-protected` marker in `$BASE_DIR`, created by `claude-mux --install`. Protected sessions show `protected` in the status column; the calling session is marked with `>` in the name column.

## Configuration

`~/.claude-mux/config` is created by `claude-mux --install` (or on first run of any command if no config exists). Edit it to override any defaults - the script never needs to be modified directly.

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

## Session Statuses

| Status | Meaning |
|--------|---------|
| `running` | tmux session exists and Claude is running |
| `protected` | same as `running`, but the session is protected - `--shutdown` requires `--force` to stop it |
| `stopped` | tmux session exists but Claude has exited |
| `idle` | A `.claude/` project exists under `BASE_DIR` but has no claude-mux tmux session running (shown only with `-L`) |

A `>` prefix on the session name (e.g. `> home`) marks the session that ran the list command.

Running `claude-mux` in a directory that already has a running session attaches to it. Multiple terminals can attach to the same session (standard tmux behavior).

## Project Markers

Per-project state lives in marker files at the project root, not in central config. Markers use the `.claudemux-` prefix and are automatically added to `.gitignore` when created in a git-tracked project.

| Marker | Meaning | CLI |
|--------|---------|-----|
| `.claudemux-protected` | Session is protected at launch - `--shutdown` requires `--force` | `--protect` / `--unprotect` |
| `.claudemux-ignore` | Project is hidden from `claude-mux -L` listings | `--hide` / `--show` |

```bash
claude-mux --hide                    # hide current session's project from -L listings
claude-mux --hide my-project         # hide a specific session's project
claude-mux --show my-project         # unhide a project
claude-mux --protect                 # protect this session from accidental shutdown
claude-mux --unprotect               # remove protection
claude-mux -L --hidden               # list only hidden projects
claude-mux --delete my-project       # move project folder to system trash (macOS)
```

Markers travel with the project folder across renames and moves. A single `.gitignore` pattern (`.claudemux-*`) covers all current and future markers.

## Directory Structure

Projects are discovered by the presence of a `.claude/` directory, at any depth:

```
~/Claude/
├── work/
│   ├── project-a/          # has .claude/ - managed
│   │   └── .claude/
│   ├── project-b/          # has .claude/ - managed
│   │   └── .claude/
│   └── -archived/          # excluded (starts with -)
│       └── .claude/
├── personal/
│   ├── project-c/          # has .claude/ - managed
│   │   └── .claude/
│   ├── .hidden/            # excluded (hidden directory)
│   │   └── .claude/
│   └── project-d/          # no .claude/ - not a Claude project
├── deep/nested/project-e/  # has .claude/ - found at any depth
│   └── .claude/
└── ignored-project/        # excluded (.claudemux-ignore)
    ├── .claude/
    └── .claudemux-ignore
```

Session names are derived from directory names: spaces become hyphens, non-alphanumeric characters (except hyphens) are replaced, and leading/trailing hyphens are stripped. Directories whose name sanitizes to empty are skipped with a log warning.

## How It Works

Under the hood, claude-mux handles:

- **Persistent tmux sessions** with Remote Control enabled, so every session is accessible from the Claude mobile app
- **Conversation resume** - resumes the last conversation (`claude -c`) when relaunching, preserving context
- **System prompt injection** - each session gets commands for self-management, slash command routing, and SSH account awareness
- **CLAUDE.md templates** - maintain template files (e.g. `web.md`, `python.md`) in `~/.claude-mux/templates/` and apply them to new projects
- **Multi-CLI-coder support** - creates `AGENTS.md` and `GEMINI.md` as symlinks to `CLAUDE.md` so Codex CLI, Gemini CLI, and other tools share the same instructions
- **Auto-approved permissions** - adds claude-mux to each project's allow list so Claude can run session commands without prompting
- **Stray process migration** - if Claude is already running outside tmux, migrates it into a managed session
- **Tmux quality-of-life** - mouse support, 50k scrollback, clipboard, 256-color, extended keys, activity monitoring, tab titles

> **Note:** This is different from `claude --worktree --tmux`, which creates a tmux session for an isolated git worktree. claude-mux manages persistent sessions for your actual project directories, with Remote Control and system prompt injection.

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
  claude-mux --tip            → print a tip (standalone; no daily gate)

Rules:
- Always run claude-mux using the absolute path shown above (claude-mux path:). The bare command may not be in PATH.
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session via the -s command.
- Always use --no-attach with -d and -n - attach is interactive only
- --shutdown and --restart never attach - safe to run from inside a session; do NOT add --no-attach to these commands
- Always print command output verbatim in your response text - if a command fails, report the error
- When command output contains <assistant-must-display> tags, include the COMPLETE content verbatim
- The 'home' session is the always-available session in the base directory. It is protected (shows 'protected' in status): --shutdown requires --force, but --restart bypasses protection. Protection is driven by the .claudemux-protected marker.
- Disambiguate 'home': 'home session' means the claude-mux session named home; 'home folder' means ~/
- When asked to shut down sessions, run the command directly - protected sessions are skipped automatically
- Use claude-mux for ALL session management. Never use raw tmux, ls, or other shell commands for session management.
- Don't guess at claude-mux flags. If you need information not in the trigger rules, run the relevant lookup.
- When user says: ready - respond with "Session ready!" on the first line, then "Running [model] in [mode] mode." on the second. Nothing else. Do not emit any additional turn after this until the user sends a new message.
- After a resume/compaction continuation with no concrete pending action, do not emit filler text like "No response requested." Stay silent and wait for the next user message.
- When user says: help - run claude-mux --guide and print the output verbatim
- When user says: status - report session name, model, permission mode, context estimate, then run claude-mux -l
- When user says: list active sessions - run claude-mux -l
- When user says: list all sessions - run claude-mux -L
- When user says: list hidden projects - run claude-mux -L --hidden
- When user says: start session SESSION - run claude-mux -d SESSION --no-attach
- When user says: stop this session / stop session NAME - run claude-mux --shutdown
- When user says: stop all sessions - run claude-mux --shutdown
- When user says: restart this session / restart session NAME - run claude-mux --restart
- When user says: restart all sessions - run claude-mux --restart
- When user says: start new session in FOLDER - run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model
- When user says: compact/clear this session / compact/clear session NAME
- When user says: update claude-mux - warn sessions will restart, get confirmation, run --update then --restart
- When user says: hide this project / hide PROJECT - run claude-mux --hide
- When user says: show this project / show PROJECT / unhide PROJECT - run claude-mux --show
- When user says: protect this session / protect SESSION - run claude-mux --protect
- When user says: unprotect this session / unprotect SESSION - run claude-mux --unprotect
- When user says: is this hidden / is this protected - check for .claudemux-ignore or .claudemux-protected
- When user says: delete this project / delete PROJECT - confirm in chat first, then run claude-mux --delete SESSION --yes
- When user says: list templates - run claude-mux --list-templates
- When user says: enable tips / turn on tips - run claude-mux --enable-tips
- When user says: disable tips / turn off tips - run claude-mux --disable-tips
- These trigger phrases work in any language.

Additional capabilities (run claude-mux --commands for full syntax):
  - Attach interactively to a session (-t - user-only, never from inside a session)
  - Start all sessions at once (-a)
  - New project with a CLAUDE.md template (-n DIR --template NAME, -p for parent dirs)
  - Force-shutdown a protected session (--shutdown SESSION --force)
  - Hide/show projects (--hide / --show)
  - Protect/unprotect sessions (--protect / --unprotect)
  - Move a project to trash (--delete SESSION - macOS; honors protection unless --force)
  - Enable/disable tip-of-the-day hook (--enable-tips / --disable-tips)
  - Show all config options (--config-help)
  - Run interactive setup or reconfigure (--install)
  - Remove all hooks and permissions (--uninstall)
  - Update claude-mux (--update)

Self-targeting send: claude-mux -s '<session-name>' '/command' sends slash commands to yourself.
GitHub SSH accounts configured in ~/.ssh/config: <accounts>. For gh CLI operations (repo create, PR create, etc.), run `gh auth switch --user <account>` first to target the correct GitHub account. Before any gh command, check `gh auth status` to verify the active account matches the repo's remote.
```

The home session receives additional context: a description of its role, plus self-management triggers for reading/editing config and templates. When `ALLOW_CROSS_SESSION_CONTROL=true`, the send command can target any session, not just itself. The path is the absolute path to the script at launch time, so sessions don't depend on `PATH`.

## Tips

When `TIP_OF_DAY` is `true` (default), the `UserPromptSubmit` hook (`claude-mux --on-prompt`) injects one usage tip per day into each session, gated per session via `~/.claude-mux/tip-state/<session_id>.json`:

```
[claude-mux tip — share this with the user]: Say "compact this session" instead of typing /compact ...
```

Each active session shows the tip once per calendar day (the first prompt of the day). Because it goes through UserPromptSubmit, the tip is visible in the conversation and in Remote Control - unlike the pre-v1.15.0 Stop-hook delivery, which was never seen. Say "disable tips" to turn it off (the hook stays registered if `UPDATE_CHECK` is still on, to keep delivering update notices), or "tip" for one on demand (`--tip` always works regardless of `TIP_OF_DAY`). `TIP_MODE` (`daily` or `random`) controls selection.

## Updating and upgrading

There are three distinct "upgrades" in play, and they are easy to conflate. They share one rule: **a running session does not change until it is restarted.**

### 1. Upgrading claude-mux itself

Run `update claude-mux` (or `claude-mux --update`; Homebrew users can also `brew upgrade claude-mux`). claude-mux is a shell script read fresh from disk on each call, so the new version takes effect on the next invocation. `--update` restarts running sessions automatically so they pick up the new injected prompt (the conversational trigger warns first). The version-check and notice machinery is detailed in "Update Check" below; the command reference is in `docs/CLI.md`.

### 2. Restarting to activate changes

A session bakes its system prompt in at launch (`--append-system-prompt`), so an upgraded script does not alter a running session until that session is restarted. As of the v2.0 self-healing work, a restart does more than refresh the prompt. At launch it also:

- writes the `.claudemux-running` auto-restore marker and the `@claude-mux-dir` / `@claude-mux-claude-id` session options, and
- installs the current launch wrapper (which removes the marker on a clean `/exit`).

So after upgrading to a version that has auto-restore, **restart your sessions to activate it.** Until a session is restarted it carries no marker and is not protected against a crash or reboot, and the restore tick does not retroactively mark a still-running session. `update claude-mux` does the deploy-and-restart in one step; if you `brew upgrade` (or copy the script) manually, follow it with "restart all sessions". See the FAQ: "Why don't running sessions pick up changes after `brew upgrade`?".

### 3. Upgrading Claude Code (the `claude` binary)

This is separate from claude-mux. The `claude` executable is upgraded out of band (`brew upgrade`, npm, the curl installer). A running session keeps the binary it launched with, so it keeps running the old Claude Code until restarted. claude-mux records each session's `claude` binary identity at launch and, on the next prompt, injects a one-shot notice when it changes:

```
Claude Code was upgraded since this session started; say "restart this session" to load the new binary.
```

It is notify-only: claude-mux never restarts the session or upgrades Claude Code for you. Say "restart this session" to load the new binary.

Note: the first launch of a freshly-upgraded `claude` binary may need a one-time macOS trust approval (Gatekeeper's "downloaded from the internet" dialog), which can stall a non-interactive restart or the auto-restore tick. See the FAQ: "After upgrading Claude Code, a session won't relaunch / seems stuck on first launch?".

## Update Check

claude-mux checks GitHub for a newer release about once a day and surfaces it three ways: a one-line notice in the terminal, an "Update available" line in each session's startup system prompt, and (as of v1.15.0) an in-conversation notice on your next prompt, which is the path that reaches a running session and Remote Control. To update, say "update claude-mux" (or run `claude-mux --update`; Homebrew users `brew upgrade claude-mux`). See "Updating and upgrading" above for the full upgrade flow.

Set `UPDATE_CHECK=false` in `~/.claude-mux/config` to turn the whole thing off; `--update` still works on demand. The repo `pereljon/claude-mux` is hardcoded, so forks should disable the check or edit the relevant functions (see the FAQ).

For the internals (the `~/.claude-mux/.update-check` cache and its fields, the daily TTY check, the disowned background refresh and its atomic lock, the per-session 7-day notice throttle, the launch-time version injection, and how `--update` validates and applies the new script) see `dev/IMPLEMENTATION-SPEC.md`, under "Tip and update delivery: the UserPromptSubmit hook".

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

When a session starts or restarts, claude-mux automatically sends a `Ready?` message after Claude finishes loading. Claude responds with two lines:

```
Session ready!
Running Sonnet 4.6 in auto mode.
```

This confirms the session is alive and reports the active model and permission mode. The mode is passed from the launch command into the injection; the model is self-reported by Claude.

### Slash commands over Remote Control

Slash commands (e.g. `/model`, `/clear`) are [not natively supported](https://github.com/anthropics/claude-code/issues/30674) in RC sessions. claude-mux works around this - each session is injected with `claude-mux -s` so Claude can send slash commands to itself via tmux.

## Logs

- `~/Library/Logs/claude-mux.log` - all script actions with UTC timestamps (configurable via `LOG_DIR`)

For low-level LaunchAgent debugging, use Console.app or `log show`.
