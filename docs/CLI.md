# CLI Reference

You rarely need these directly - Claude runs them for you from inside sessions. These are available for scripting, automation, or when you're not inside a session.

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
claude-mux -L --status idle      # list only idle projects
claude-mux -L --status running   # list only running sessions
claude-mux -L --hidden           # list only hidden projects
claude-mux -s my-app '/model sonnet'      # send a slash command to a session
claude-mux --shutdown my-app              # shut down a specific session
claude-mux --shutdown                     # shut down all managed sessions
claude-mux --shutdown home --force        # shut down protected home session
claude-mux --restart my-app              # restart a specific session (resumes conversation)
claude-mux --restart my-app --fresh      # restart fresh - new conversation, no resume
claude-mux --restart                     # restart all running sessions
claude-mux --restart --fresh             # restart all sessions fresh
claude-mux --permission-mode plan my-app  # restart session with plan mode
claude-mux -a                    # start all managed sessions under BASE_DIR

# Project markers (all commands use session names, not paths)
claude-mux --hide                # hide current session's project from -L listings
claude-mux --hide my-project     # hide a specific project by session name
claude-mux --show my-project     # unhide a project
claude-mux --protect             # protect this session from accidental shutdown
claude-mux --unprotect           # remove protection
claude-mux --delete my-project           # move project folder to system trash (macOS)
claude-mux --delete my-project --yes     # same, skip confirmation prompt
claude-mux --rename my-project new-name  # rename project directory
claude-mux --move my-project ~/Claude/work  # move project to a new parent

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
