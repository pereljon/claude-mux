# Features

## Core

- Launch Claude Code in tmux with Remote Control enabled in any directory
- Conversation resume via `claude -c` when reconnecting
- Multiple terminals can attach to the same session
- Single bash script, no dependencies beyond tmux and Claude Code

## Session Management

- Home session: always-running protected session in base directory, launches at login, defaults to Sonnet (configurable)
- List sessions with status (`-l` for active, `-L` for all including idle)
- Session statuses: active, running, stopped, idle with three-column display (status, name, path)
- Shutdown sessions (single, multiple, or all managed)
- Restart sessions (single, multiple, or all that were running)
- Attach to sessions by name (`-t`)
- Send slash commands to sessions (`-s`)
- Protected sessions marked with `*`, require `--force` to shutdown
- `--restart` bypasses protection (relaunches, not permanent kill)
- `--restart` remembers which sessions were running, only relaunches those
- `--no-attach` for background launches with `-d` and `-n`

## Claude Self-Management

- Sessions injected with structured system prompt containing all claude-mux commands
- Claude can list, start, stop, restart sessions from conversation prompts
- Slash command workaround for Remote Control via `-s` and tmux send-keys
- Auto-approved permissions in `.claude/settings.local.json` per project
- GitHub SSH account awareness from `~/.ssh/config` injected into sessions
- Injection prompt has Rules section (behavioral instructions) and Commands section

## Project Discovery

- Batch mode (`-a`): discover and launch all `.claude/` projects under base directory
- Project discovery by `.claude/` directory at any depth
- Exclusion: directories starting with `-`, hidden directories, `.ignore-claudemux`
- Session name sanitization (spaces to hyphens, special chars stripped, collision detection)
- Stray process migration: non-tmuxed Claude processes pulled into managed sessions

## New Project Creation

- Create new projects with `-n` (git init, .gitignore, permission mode)
- `-p` flag creates directory and parents
- CLAUDE.md template library with `--template NAME` and `--list-templates`
- `--no-git`, `--no-template`, `--no-permission-mode` opt-out flags

## LaunchAgent

- `--autolaunch` dispatches based on `LAUNCHAGENT_MODE` (none/home/batch)
- 45-second startup delay for login auto-start
- Backward compatibility: `LAUNCHAGENT_ENABLED=true` treated as `batch`

## Tmux Quality-of-Life

- Mouse support (scroll, select, resize)
- 50k scrollback buffer
- System clipboard integration (OSC 52)
- 256-color terminal
- Reduced escape delay (10ms vs 500ms default)
- Extended keys (Shift+Enter)
- Activity monitoring
- Terminal/tab titles showing session name
- All options configurable via rc file

## Installer

- Interactive prompts for install location, base directory, home session, model
- `--non-interactive` mode for scripted setups
- Auto-adds `~/bin` to PATH in shell profile if needed
- Config directory at `~/.claude-mux/` with auto-migration from old format
- Creates templates directory with empty default template

## Diagnostics

- `--dry-run` for previewing actions
- Log file at `~/Library/Logs/claude-mux.log` (configurable)
- Error messages include log file path
- Log output mirrored to stdout when running interactively
