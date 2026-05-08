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

That's it. You're in a persistent, session-aware Claude session with Remote Control enabled. From here, everything is conversational.

The installer asks if you want a home session at login. If you accept, a protected Claude session launches automatically every time you log in - always reachable from your phone or any Remote Control client, even if you never open a terminal.

[Homebrew, manual install, and other options](docs/INSTALL.md)

## Why

Remote Control promises Claude Code from anywhere - but without session management, it's a second-class interface even from Claude Desktop:

- **Sessions die** when you close the terminal
- **Conversation context** doesn't resume automatically
- **No home base** - nothing is running when you pick up your phone unless you left something open
- **Remote Control requires a running session** - you can't start one from RC
- **Slash commands don't work in RC sessions** - no model switching, compacting, or permission mode changes
- **Starting new projects** - requires manually creating a directory, initializing git, writing a CLAUDE.md, and picking a model
- **No project management** - no way to see idle projects, or rename, move, and delete projects without breaking history

**claude-mux fixes the session management gap.** It wraps Claude Code in tmux so sessions persist, injects a system prompt so Claude can manage its own sessions, and routes slash commands through tmux so they work over Remote Control. Once a session is running, you manage everything by talking to Claude - in the terminal or the mobile app.

## What You Can Do in a claude-mux Session

- **Manage any session from any session** - start, stop, restart, list, and compact projects using natural language
- **Access everything from anywhere** - every session has Remote Control enabled, so the Claude mobile app, desktop app, or any remote client is a full interface
- **Switch models and permission modes** - say "switch to Haiku" or "switch to plan mode" and Claude handles it, even over Remote Control
- **Create new projects** - "create a new project called my-app" sets up the directory, git, CLAUDE.md, and launches a session. CLAUDE.md templates let you reuse instructions across projects.
- **Keep sessions alive across reboots** - an optional home session launches at login and stays running; all sessions resume their last conversation automatically
- **Send slash commands over Remote Control** - Claude routes `/model`, `/compact`, `/clear`, and other slash commands to the running session, working around a [known limitation](https://github.com/anthropics/claude-code/issues/30674)
- **Preserve conversation history** - renaming, moving, and restarting projects all preserve conversation history automatically
- **Organize projects** - hide, rename, move, delete, and protect projects from inside any session
- **GitHub multi-account support** - detects SSH aliases in `~/.ssh/config` and injects them into sessions so Claude uses the right account per project
- **Multi-CLI-coder support** - auto-creates `AGENTS.md` and `GEMINI.md` symlinks so Codex CLI, Gemini CLI, and others share instructions
- **Works in any language** - conversational commands are inferred from intent, not keywords

## Talking to Claude

This is how you use claude-mux day to day. Every session is injected with commands so Claude can manage sessions, switch models, send slash commands, and create new projects - all from inside the conversation. You don't need to remember CLI flags.

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
Claude: switches to bypassPermissions mode via Shift+Tab - no restart needed

You: "what mode is this session"
Claude: reports the current permission mode (default, acceptEdits, plan, bypassPermissions)

You: "switch this session to Opus"
Claude: sends /model opus to itself via tmux

You: "clear this session"
Claude: sends /clear to itself, resetting the conversation

You: "hide this project"
Claude: writes .claudemux-ignore so the project is excluded from -L listings

You: "protect this session"
Claude: writes .claudemux-protected and sets the tmux marker - shutdown now requires --force

You: "is this session protected"
Claude: checks for .claudemux-protected in the project folder and reports

You: "delete the old-prototype project"
Claude: confirms in chat, then moves the project folder to system trash

You: "rename this project to my-new-name"
Claude: stops the session, renames the folder, migrates conversation history, restarts

You: "save this as a template named web"
Claude: copies CLAUDE.md to ~/.claude-mux/templates/web.md

You: "tip"
Claude: prints a tip - same tip all day, or random if TIP_MODE=random is set

You: "enable tips" / "disable tips"
Claude: registers or removes the tip-of-the-day hook across all projects

You: "update claude-mux"
Claude: warns that all sessions will restart, asks for confirmation, then updates and restarts

You: "stop all sessions"
Claude: gracefully exits all managed sessions

You: "help"
Claude: prints the full list of conversational commands
```

These commands work in any language. If you type the equivalent in Spanish, Japanese, Hebrew, or any other language, Claude infers the intent and runs the matching command.

Type `help` inside any session to see the full command list.

## More

- [CLI Reference](docs/CLI.md) - full command reference for scripting and automation
- [Guide](docs/guide.md) - configuration, session details, internals, and troubleshooting
- [Installation Options](docs/INSTALL.md) - Homebrew, manual install, LaunchAgent setup
- [FAQ](docs/FAQ.md) - common questions about claude-mux
- [Known Issues](docs/ISSUES.md) - open bugs, planned features, and resolved issues
- [Changelog](CHANGELOG.md) - what changed per release
