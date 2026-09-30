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
| `TEMPLATES_DIR` | `$HOME/.claude-mux/templates` | Directory containing instructions-file template files (AGENTS.md when supported, else CLAUDE.md) |
| `DEFAULT_TEMPLATE` | `default.md` | Default template applied to new projects (`-n`). Set to `""` to disable. |
| `SLEEP_BETWEEN` | `5` | Seconds between session launches when `-a` is used. Increase if RC registration fails. |
| `HOME_SESSION_MODEL` | `sonnet` | Model for the home session. Any model alias or ID `claude --model` accepts (e.g. `sonnet`, `haiku`, `opus`, or a full ID like `claude-opus-4-8`); passed through and validated by `claude` at launch. Empty inherits Claude's default. |
| `MULTI_CODER_FILES` | `""` (deprecated) | Ignored since 2.4.0: claude-mux no longer creates `AGENTS.md`/`GEMINI.md` symlinks. A once-only warning is printed if it is still set; remove it from your config. `--no-multi-coder` is likewise a no-op. |
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
- **Instructions-file templates** - maintain template files (e.g. `web.md`, `python.md`) in `~/.claude-mux/templates/` and apply them to new projects (written as `AGENTS.md` when Claude Code >= 2.1.277 and no `CLAUDE.md` sits in a parent directory, else `CLAUDE.md`)
- **AGENTS.md as the canonical instructions file** - one real file for Claude Code and Codex CLI; `--migrate-agents-md` converts an existing tree (see "AGENTS.md migration")
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
  claude-mux --list-templates → available project-instructions templates
  claude-mux --migrate-agents-md → AGENTS.md migration report (read-only without --apply)
  claude-mux --tip            → print a tip (standalone; no daily gate)

Rules:
- Always run claude-mux using the absolute path shown above (claude-mux path:). The bare command may not be in PATH.
- You CAN send slash commands (/model, /compact, /clear, etc.) into any managed session via -s: claude-mux -s SESSION '/command' (your own name for this session, another managed session's name to operate it).
- Peer sessions: your other claude-mux sessions are peer agents, addressable by their managed session names (as in claude-mux -l), which are their native cross-session-messaging agent names. Two channels, don't conflate: -s SESSION '/command' pushes a slash command (/model, /compact, /clear, etc.; slash commands only) into a session to operate it; native SendMessage (peers via ListAgents) delivers a natural-language message the peer processes on its next turn, to converse with or delegate to it.
- Always use --no-attach with -d and -n - attach is interactive only
- --shutdown and --restart never attach - safe to run from inside a session; do NOT add --no-attach to these commands
- Always print command output verbatim in your response text - if a command fails, report the error
- When command output contains <assistant-must-display> tags, include the COMPLETE content verbatim
- The 'home' session is the always-available session in the base directory. It is protected (shows 'protected' in status): --shutdown requires --force, but --restart bypasses protection. Protection is driven by the .claudemux-protected marker.
- Disambiguate 'home': 'home session' means the claude-mux session named home; 'home folder' means ~/
- Config and template edits (~/.claude-mux/config, ~/.claude-mux/templates/) are the home session's responsibility. If this session is named 'home', you may edit them directly; otherwise do not edit them - route the change to the home session (tell the user to make the change there).
- (Only when the project uses AGENTS.md: supported Claude Code, no CLAUDE.md in the path, an AGENTS.md in the project or a parent) This project uses AGENTS.md for project instructions. Never create or edit a CLAUDE.md or CLAUDE.local.md: any CLAUDE.md in the directory path makes Claude Code ignore every AGENTS.md, including in parent directories.
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
- When user says: start session SESSION - run claude-mux --start SESSION (by name; starts if stopped, no-op if already running)
- When user says: stop this session / stop session NAME - run claude-mux --shutdown SESSION (always pass the session name; bare --shutdown targets ALL sessions)
- When user says: stop all sessions - run claude-mux --shutdown
- When user says: restart this session / restart session NAME - run claude-mux --restart SESSION (also starts the session if it is stopped; bare --restart targets ALL sessions)
- When user says: restart all sessions - run claude-mux --restart
- When user says: start new session in FOLDER - run claude-mux -n FOLDER --no-attach
- When user says: switch this session to MODE mode / switch session NAME to MODE mode
- When user says: switch this session to MODEL model / switch session NAME to MODEL model (MODEL is resolved to a concrete ID before sending `/model`: a bare family like `sonnet` expands to the latest known ID `claude-sonnet-4-6`, a versioned shorthand like "opus 4.8" becomes `claude-opus-4-8`, and a full ID passes through; the `/model` picker silently ignores a bare family, so resolution is required)
- When user says: compact/clear this session / compact/clear session NAME
- When user says: update claude-mux - warn sessions will restart, get confirmation, run --update then --restart
- When user says: hide this project / hide PROJECT - run claude-mux --hide
- When user says: show this project / show PROJECT / unhide PROJECT - run claude-mux --show
- When user says: protect this session / protect SESSION - run claude-mux --protect
- When user says: unprotect this session / unprotect SESSION - run claude-mux --unprotect
- When user says: is this hidden / is this protected - check for .claudemux-ignore or .claudemux-protected
- When user says: delete this project / delete PROJECT - confirm in chat first, then run claude-mux --delete SESSION --yes
- When user says: list templates - run claude-mux --list-templates
- When user says: check agents migration / migrate to AGENTS.md - run claude-mux --migrate-agents-md (no --apply) and show the report verbatim. Confirm with the user (files to migrate, running sessions to restart) before running claude-mux --migrate-agents-md --apply; add --no-restart if the user does not want sessions restarted.
- When user says: enable tips / turn on tips - run claude-mux --enable-tips
- When user says: disable tips / turn off tips - run claude-mux --disable-tips
- These trigger phrases work in any language.

Additional capabilities (run claude-mux --commands for full syntax):
  - Attach interactively to a session (-t - user-only, never from inside a session)
  - Start a stopped session by name (--start SESSION - no-op if already running; --restart also starts a stopped session)
  - Start all sessions at once (-a)
  - New project with an instructions-file template (-n DIR --template NAME, -p for parent dirs; writes AGENTS.md when supported, else CLAUDE.md)
  - Force-shutdown a protected session (--shutdown SESSION --force)
  - Hide/show projects (--hide / --show)
  - Protect/unprotect sessions (--protect / --unprotect)
  - Move a project to trash (--delete SESSION - macOS; honors protection unless --force)
  - Enable/disable tip-of-the-day hook (--enable-tips / --disable-tips)
  - Migrate a project tree from CLAUDE.md to AGENTS.md (--migrate-agents-md [--apply] [--no-restart]; report only unless --apply)
  - Show all config options (--config-help)
  - Run interactive setup or reconfigure (--install)
  - Remove all hooks and permissions (--uninstall)
  - Update claude-mux (--update)

GitHub SSH accounts configured in ~/.ssh/config: <accounts>. For gh CLI operations (repo create, PR create, etc.), prefix each command with `GH_TOKEN=$(gh auth token --user <account>)` to target the correct GitHub account, e.g. `GH_TOKEN=$(gh auth token --user <account>) gh pr create`. Never run `gh auth switch`: the active gh account is one machine-wide setting, so switching it changes the account for every running session. Use the account that owns the repo's remote.
```

The home session receives additional context: its identity as the session orchestrator (session management and project orchestration, not project work; an operational session that acts without asking when intent is clear), plus self-management triggers for reading/editing config and templates. As of v2.1.0 this identity ships in the injection itself, so it does not need to live in an ancestor `CLAUDE.md` (where it would leak into every project session under the base directory). Config/template edit authority is the role-neutral rule above, injected into every session. The `-s` send command can target any managed session (used by the "compact/clear/switch the X session" triggers and home orchestration). The path is the absolute path to the script at launch time, so sessions don't depend on `PATH`.

## AGENTS.md migration

`AGENTS.md` is the canonical project-instructions file. Claude Code 2.1.277 and later reads it when no `CLAUDE.md` is present, and Codex CLI reads it natively, so claude-mux no longer creates `AGENTS.md`/`GEMINI.md` symlinks. Gemini CLI reads `AGENTS.md` only if `~/.gemini/settings.json` lists it (`"context": {"fileName": ["AGENTS.md"]}`); whether the upstream default has changed is unverified.

The catch: Claude Code ignores every `AGENTS.md` if a `CLAUDE.md` or `CLAUDE.local.md` exists in the working directory or any ancestor (a symlink or an `@AGENTS.md` stub counts; `~/.claude/CLAUDE.md` does not). A half-migrated tree silently drops instructions, so migration is tree-wide.

```
claude-mux --migrate-agents-md                 # report only, changes nothing
claude-mux --migrate-agents-md --apply         # migrate BASE_DIR, then restart running sessions under it
claude-mux --migrate-agents-md --apply --no-restart
```

In a session, say "check agents migration" or "migrate to AGENTS.md"; Claude shows the report and confirms once before running `--apply`.

**Report classes.** Actions: `DONE`, `MIGRATE` (rename CLAUDE.md), `LINK` and `IDENTICAL` (replace AGENTS.md with the file), `INVERSE` (CLAUDE.md symlink to AGENTS.md: removed), `STUB` (CLAUDE.md containing only `@AGENTS.md`: removed), `GEMINI-LINK` (GEMINI.md symlink: deleted; a real GEMINI.md is never touched). Blocking classes, each of which aborts `--apply` before anything changes: `CONFLICT` (both files exist, contents differ), `LOCAL` (`CLAUDE.local.md` suppresses AGENTS.md and has no equivalent), `ANOMALY` (`.claude/CLAUDE.md` or `.claude/AGENTS.md`), `EXT-LINK`, `BROKEN-LINK`, `NOT-A-FILE`, `CASE-VARIANT` (CLAUDE-family names only, such as `claude.md` or `CLAUDE.MD`; a lowercase `agents.md` is harmless) (`claude.md`), `ABOVE` (a CLAUDE.md above `BASE_DIR`, out of reach: remove or merge it, or the tree keeps CLAUDE.md), `UNWRITABLE`, `LOCKED-INDEX` (a git `index.lock`), `DEST-EXISTS`. The report also lists running sessions, the Claude Code version gate (minimum 2.1.277; fails closed), and textual references to `CLAUDE.md` in the tree, which are listed and never edited.

**What `--apply` does.** Takes the lock `BASE_DIR/.claudemux-migrating/`, rescans, writes a manifest to `~/.claude-mux/migrations/agents-md-<timestamp>.json`, applies the operations top-down (`git mv` for tracked files, `mv` otherwise), verifies that no `CLAUDE.md`/`CLAUDE.local.md` remains in any path, releases the lock, writes `BASE_DIR/.claudemux-agents-migrated`, and restarts running managed sessions under `BASE_DIR` (the calling session last, in place). It never commits: repos are left with uncommitted changes to review. There is no `--undo`; the manifest is a log for manual recovery.

After a migration, once a day the home session tells you if a `CLAUDE.md` reappears (for example from `/init` or an old branch checkout).

## Tips

When `TIP_OF_DAY` is `true` (default), the `UserPromptSubmit` hook (`claude-mux --on-prompt`) injects one usage tip per day into the `home` session, gated by a single global date file `~/.claude-mux/tip-state/tip.json` (v2.0.15; before that it was keyed per conversation, which re-showed the tip on every `/clear`/restart):

```
<assistant-must-display>claude-mux tip: Say "compact this session" instead of typing /compact ...</assistant-must-display>
```

The notice carries only the clean user-facing line inside `<assistant-must-display>` tags; the instruction to surface it lives in the session's standing notice rule (so the relay wording is not printed to the user).

The tip shows once per calendar day, in the home session only (the first home prompt of the day); project sessions never show it. Because it goes through UserPromptSubmit, the tip is visible in the conversation and in Remote Control - unlike the pre-v1.15.0 Stop-hook delivery, which was never seen. Say "disable tips" to turn it off (the hook stays registered if `UPDATE_CHECK` is still on, to keep delivering update notices), or "tip" for one on demand (`--tip` always works regardless of `TIP_OF_DAY`). `TIP_MODE` (`daily` or `random`) controls selection.

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

### AGENTS.md migration problems

- **"another migration holds ..." or launches refused with "migration in progress".** The lock `BASE_DIR/.claudemux-migrating/` is held by a running `--apply`. Wait for it. A lock whose pid is dead, or that is older than 60 minutes, is stale: launches and the restore tick ignore it (a WARN is logged), and the next `--apply` takes it over. To clear it by hand: `rm -rf "$BASE_DIR/.claudemux-migrating"`.
- **"TREE IS MIXED".** An operation or the final verification failed partway. Some paths are migrated and some still hold a `CLAUDE.md`, so sessions under the latter ignore `AGENTS.md`. The block lists completed and pending paths and the manifest. Fix the cause named in the `FAILED:` line, then re-run `--migrate-agents-md --apply` (completed paths report `DONE`), or reverse the recorded operations by hand. There is no automatic rollback and the migrated marker is removed.
- **`--apply` aborts with a blocking class.** Resolve the paths the report names: merge or delete a `CONFLICT` or `LOCAL` file, remove `.claude/CLAUDE.md`, rename a case variant, remove a stale `.git/index.lock`, and so on. A `CLAUDE.md` above `BASE_DIR` cannot be migrated by claude-mux.
- **"the tree changed between the scan and the lock".** Something edited a `CLAUDE.md`/`AGENTS.md` after the report. Nothing was changed; re-run to see the current plan.
- **Version gate.** Claude Code below 2.1.277, or an unparseable `claude --version`, blocks the migration and keeps `CLAUDE.md` canonical.

### Slash commands over Remote Control

Slash commands (e.g. `/model`, `/clear`) are [not natively supported](https://github.com/anthropics/claude-code/issues/30674) in RC sessions. claude-mux works around this - each session is injected with `claude-mux -s` so Claude can send slash commands to itself via tmux.

`/compact` gets additional handling: a `PreCompact` hook spawns a background monitor that detects when the compaction finishes and sends `Ready?` to reconnect the RC WebSocket. This fires for every `/compact` regardless of trigger - manual, auto-compact, or RC-sent.

## Logs

- `~/Library/Logs/claude-mux.log` - all script actions with UTC timestamps (configurable via `LOG_DIR`)

For low-level LaunchAgent debugging, use Console.app or `log show`.
