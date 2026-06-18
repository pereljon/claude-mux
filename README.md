# claude-mux - Claude Code Multiplexer

**English** · [Español](translations/README.es.md) · [Français](translations/README.fr.md) · [Deutsch](translations/README.de.md) · [Português](translations/README.pt-BR.md) · [日本語](translations/README.ja.md) · [한국語](translations/README.ko.md) · [Italiano](translations/README.it.md) · [Русский](translations/README.ru.md) · [中文](translations/README.zh-CN.md) · [עברית](translations/README.he.md) · [العربية](translations/README.ar.md) · [हिन्दी](translations/README.hi.md)

Persistent Claude Code sessions for all your projects - accessible from anywhere via the Claude mobile app. ***Managed by Claude!***

## Install

```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```

Then start a session:

```bash
claude-mux ~/path/to/your/project
```

The installer asks if you want a home session at login. If you accept, a protected Claude session launches automatically every time you log in - always reachable from your phone or any Remote Control client, even if you never open terminal.

That's it! You're in a persistent, session-aware Claude session with Remote Control enabled. **From here, everything is conversational.**

[Homebrew, manual install, and other options](docs/INSTALL.md)

## Why

Remote Control promises Claude Code from anywhere - but without session management, it's a second-class interface even from Claude Desktop:

- **Sessions die** when you close the terminal - and don't come back after a crash or reboot
- **Conversation context** doesn't resume automatically
- **No home base** - nothing is running when you pick up your phone unless you left something open
- **Remote Control requires a running session** - you can't start one from RC
- **Slash commands don't work in RC sessions** - no model switching, compacting, or permission mode changes
- **Starting new projects** - requires manually creating a directory, initializing git, writing a CLAUDE.md, and picking a model
- **No project management** - no way to see idle projects, or rename, move, and delete projects without breaking history

**claude-mux fixes the session management gap.** It wraps Claude Code in tmux so sessions persist, automatically restores them after crashes and reboots (as long as you have auto-login enabled), injects a system prompt so Claude can manage its own sessions, and routes slash commands through tmux so they work over Remote Control. Once a session is running, you manage everything by talking to Claude - in the terminal or the mobile app.

## What You Can Do in a claude-mux Session

- **Survives crashes and reboots** - sessions are automatically restored when you log back in, picking up the last conversation. A clean `/exit` or shutdown keeps a session down; a crash-looping session is stopped and flagged rather than restarted forever.
- **Manage any session from any session** - start, stop, restart, list, and compact projects using natural language
- **Access everything from anywhere** - every session has Remote Control enabled, so the Claude mobile app, desktop app, or any remote client is a full interface
- **Switch models and permission modes** - say "switch to Haiku" or "switch to plan mode" and Claude handles it, even over Remote Control
- **Create new projects** - "create a new project called my-app" sets up the directory, git, CLAUDE.md, and launches a session. CLAUDE.md templates let you reuse instructions across projects.
- **Send slash commands over Remote Control** - Claude routes `/model`, `/compact`, `/clear`, and other slash commands to the running session, working around a [known limitation](https://github.com/anthropics/claude-code/issues/30674). RC reconnects automatically after `/compact` via a `PreCompact` hook.
- **Claude Code upgrade detection** - when the `claude` binary changes (after `brew upgrade` or an npm update), the next prompt in any running session surfaces a one-shot notice to restart and load the new binary
- **Preserve conversation history** - renaming, moving, and restarting projects all preserve conversation history automatically
- **Organize projects** - hide, rename, move, delete, and protect projects from inside any session
- **GitHub multi-account support** - detects SSH aliases in `~/.ssh/config` and injects them into sessions so Claude uses the right account per project
- **Multi-CLI-coder support** - auto-creates `AGENTS.md` and `GEMINI.md` symlinks so Codex CLI, Gemini CLI, and others share instructions
- **Works in any language** - conversational commands are inferred from intent, not keywords

## Talking to Claude

This is how you use claude-mux day to day. Every session is injected with commands so Claude can manage sessions, switch models, send slash commands, and create new projects - all from inside the conversation. You don't need to remember CLI flags.

```
Say: "status"
Reports session name, model, permission mode, context usage, and lists all sessions

Say: "list active sessions"
Shows all running sessions with their status

Say: "list idle sessions"
Shows only idle projects

Say: "list stopped sessions"
Shows only stopped sessions

Say: "start a session for my api-server project"
Starts the session by name; no-op if it is already running

Say: "create a new project called mobile-app using the web template"
Creates the project directory, initializes git, applies the template, launches a session

Say: "switch this session to Haiku"
Sends /model haiku to itself via tmux

Say: "compact the api-server session"
Sends /compact to the api-server session

Say: "restart the web-dashboard session"
Shuts down and relaunches the session, preserving conversation context

Say: "restart this session fresh"
Restarts with a new conversation - no resume, no prior context

Say: "switch the api-server session to plan mode"
Restarts the session with plan permission mode

Say: "switch this session to yolo mode"
Switches to bypassPermissions mode via Shift+Tab - no restart needed

Say: "what mode is this session"
Reports the current permission mode (default, acceptEdits, plan, bypassPermissions)

Say: "switch this session to Opus"
Sends /model opus to itself via tmux

Say: "clear this session"
Sends /clear to itself, resetting the conversation

Say: "hide this project"
Writes .claudemux-ignore so the project is excluded from -L listings

Say: "protect this session"
Writes .claudemux-protected and sets the tmux marker - shutdown now requires --force

Say: "is this session protected"
Checks for .claudemux-protected in the project folder and reports

Say: "delete the old-prototype project"
Confirms in chat, then moves the project folder to system trash

Say: "rename this project to my-new-name"
Stops the session, renames the folder, migrates conversation history, restarts

Say: "save this as a template named web"
Copies CLAUDE.md to ~/.claude-mux/templates/web.md

Say: "tip"
Prints a tip - same tip all day, or random if TIP_MODE=random is set

Say: "enable tips" / "disable tips"
Turns the daily tip on or off across all projects

Say: "update claude-mux"
Warns that all sessions will restart, asks for confirmation, then updates and restarts

Say: "stop all sessions"
Gracefully exits all managed sessions

Say: "help"
Prints the full list of conversational commands
```

**These commands work in any language.** If you type the equivalent in Spanish, Japanese, Hebrew, or any other language, Claude infers the intent and runs the matching command.

**Type `help` inside any session to see the full command list.**

## More

- [CLI Reference](docs/CLI.md) - full command reference for scripting and automation
- [Guide](docs/GUIDE.md) - configuration, session details, internals, and troubleshooting
- [Installation Options](docs/INSTALL.md) - Homebrew, manual install, LaunchAgent setup
- [FAQ](docs/FAQ.md) - common questions about claude-mux
- [Known Issues](docs/ISSUES.md) - open bugs, planned features, and resolved issues
- [Changelog](CHANGELOG.md) - what changed per release
