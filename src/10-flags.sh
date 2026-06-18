# ── Flag parsing ───────────────────────────────────────────────────────────────

DRY_RUN=false
COMMAND="launch"
COMMAND_SET=false
TARGET_SESSION=""
AWAIT_SESSION=""
PRINT_PROMPT_SESSION=""
PRINT_PROMPT_MODE=""
SEND_SESSION=""
SEND_COMMAND=""
LAUNCH_DIR=""
NEW_PROJECT_DIR=""
NEW_CREATE_PARENTS=false
TEMPLATE_NAME=""
NO_TEMPLATE=false
NO_GIT=false
NO_MULTI_CODER=false
NO_ATTACH=false
NO_PERMISSION_MODE=false
FORCE=false
SHUTDOWN_SESSIONS=()
RESTART_SESSIONS=()
START_SESSIONS=()
FRESH_START=false
SETMODE_VALUE=""
SETMODE_SESSIONS=()
GETMODE_SESSION=""
HIDE_SESSION=""
PROTECT_SESSION=""
DELETE_SESSION=""
DELETE_YES=false
SAVE_TEMPLATE_NAME=""
SAVE_TEMPLATE_DIR=""
RENAME_SRC=""
RENAME_DST=""
RENAME_MODE=""
INSTALL_ARGS=()

guide() {
    cat << 'EOF'
claude-mux conversational commands:

  help
  status
  list active sessions
  list all sessions
  start session [SESSION]
  stop this session / stop session [NAME]
  stop all sessions
  restart this session / restart session [NAME]
  restart this session fresh / restart [NAME] fresh / kill this session
  restart all sessions
  start new session in [FOLDER] [with model MODEL] [with mode MODE]
  switch this session to [MODE] mode / switch session [NAME] to [MODE] mode
  switch this session to [MODEL] model / switch session [NAME] to [MODEL] model
  compact this session / compact session [NAME]
  clear this session / clear session [NAME]
  list templates
  save this as a template named [NAME]
  rename this project to [NAME]
  move this project to [PATH]
  update claude-mux
  hide this project / show this project
  protect this session / unprotect this session
  tip / tip of the day
  enable tips / disable tips
EOF
}

# When stdout is not a TTY (e.g. captured by Claude's Bash tool), print an
# instruction telling the model to display the output in its response.
echo_hint() {
    if [[ ! -t 1 ]]; then
        echo "<assistant-must-display>"
    fi
}

echo_hint_end() {
    if [[ ! -t 1 ]]; then
        echo "</assistant-must-display>"
    fi
}

# Print the full CLI reference. Replaces the inline Commands block in the
# session injection prompt. Single source of truth for flag syntax.
commands_help() {
    echo_hint
    cat <<'COMMANDSHELP'
claude-mux CLI reference

Self-targeting (works inside sessions):
  -s 'SESSION' '/command'  Send slash command (default scope: yourself)
  -l                       List active sessions
  -L                       List all projects (default: hide ignored)
  -L --status STATUS       Filter by status: idle running protected stopped queued failed hidden
  -L --include-hidden      List all including hidden
  -L --hidden              List only hidden
  -d DIR --no-attach       Launch session in directory
  -n DIR --no-attach       New project (with -p for parent dirs)
  --template NAME          CLAUDE.md template for -n
  --list-templates         Show available templates
  --save-template NAME [SESSION]  Save CLAUDE.md as a template (default: current session)
  --shutdown SESSION...    Shut down sessions (omit SESSION for all)
  --shutdown ... --force   Override protection
  --start SESSION...       Start sessions by name (start if stopped; no-op if already running)
  --restart SESSION...     Restart sessions (resumes prior conversation; also starts a stopped session)
  --restart SESSION... --fresh  Restart fresh — new conversation, no resume (use after installing MCPs)
  --permission-mode MODE SESSION  Restart session with a different mode
                           Modes: default, acceptEdits, plan, auto, dontAsk,
                           bypassPermissions
                           ("yolo" is an alias for bypassPermissions)
  --get-mode [SESSION]     Print current permission mode of a session
  --hide [SESSION]          Hide project from listings (touches .claudemux-ignore)
  --show [SESSION]          Restore project visibility
  --protect [SESSION]       Protect a project's session at launch
                           (touches .claudemux-protected; toggles tmux marker)
  --unprotect [SESSION]     Remove protection
  --delete SESSION          Move project folder to system trash (macOS only).
                           --force overrides protection; --yes skips prompt.
  --rename SESSION NAME     Rename project directory, migrate history and homunculus
  --move SESSION PARENT_DIR Move project into PARENT_DIR (the destination's parent),
                           migrate history and homunculus. If PARENT_DIR's basename
                           matches SESSION, the trailing component is stripped (so
                           both "/path/to" and "/path/to/SESSION" work).
                           Both: --force overrides protection; --dry-run previews steps
  --tip                    Print a tip (standalone; no daily gate)
  --on-compact             Internal: PreCompact hook (reconnects RC after compact)
  --on-prompt              Internal: UserPromptSubmit hook (daily tip + update notice)
  --update-check-bg        Internal: background GitHub release check (refreshes cache)
  --enable-tips            Enable daily tips (registers the on-prompt hook)
  --disable-tips           Disable daily tips
  --install-hooks          Backfill claude-mux hooks (incl. PreCompact RC-reconnect) into all projects
  --config-help            List all valid config options
  --commands               Print this reference
  --guide                  Print conversational commands list
  --update                 Update claude-mux to the latest version
  --install [OPTS...]      Run interactive setup
  --uninstall              Remove hooks, permissions, LaunchAgent, and config
  -a                       Start ALL sessions (use with caution)

Interactive (user-only — never from inside a session):
  -t SESSION               Attach to a running session
COMMANDSHELP
    echo_hint_end
}

# Print all valid config options with defaults, types, and descriptions.
# Single source of truth for "what can I configure?"
config_help() {
    echo_hint
    cat <<'CONFIGHELP'
claude-mux configuration options
File: ~/.claude-mux/config

BASE_DIR                         default: "$HOME/Claude"
  Type: directory path
  Description: Where projects live. Each subdirectory with a .claude/ folder
               is treated as a project. Home session runs here.

LOG_DIR                          default: "$HOME/Library/Logs"
  Type: directory path
  Description: Where claude-mux writes its log file (claude-mux.log).

DEFAULT_PERMISSION_MODE          default: "auto"
  Type: "" | default | acceptEdits | plan | auto | dontAsk | bypassPermissions
  Description: Claude Code permission mode written to .claude/settings.local.json
               in each project on session launch. Empty disables.

ALLOW_CROSS_SESSION_CONTROL      default: false
  Type: true | false
  Description: When true, claude-mux -s can target any session, not just the
               caller. Default false (sessions only message themselves).

LAUNCHAGENT_MODE                 default: "home"
  Type: none | home
  Description: LaunchAgent behavior at login. "none" disables. "home" launches
               a protected home session (controlled by .claudemux-protected
               marker in BASE_DIR).

HOME_SESSION_MODEL               default: "sonnet"
  Type: sonnet | haiku | opus | (empty)
  Description: Model used for the home session at launch. Empty inherits
               Claude's default.

AUTORESTORE                      default: true
  Type: true | false
  Description: Self-healing. When true, the LaunchAgent tick restores sessions
               that should be alive (have a .claudemux-running marker) but whose
               Claude died, after a reboot or a mid-day crash. Markers are
               always written; this only gates whether the tick acts. A clean
               in-pane /exit (or --shutdown) removes the marker and stays down.

STAGGER_CONCURRENCY              default: 3
  Type: integer
  Description: Max sessions the restore tick launches per STARTING_WINDOW, to
               avoid a reboot thundering-herd. Mainly API-burst insurance.

STARTING_WINDOW                  default: 90
  Type: integer (seconds)
  Description: Window over which STAGGER_CONCURRENCY is counted, via each
               session's last restore-attempt timestamp.

MULTI_CODER_FILES                default: "AGENTS.md GEMINI.md"
  Type: space-separated filenames
  Description: Files created as symlinks to CLAUDE.md so other AI CLIs (Codex,
               Gemini, etc.) share the same project instructions. Empty
               disables.

UPDATE_CHECK                     default: true
  Type: true | false
  Description: Check GitHub releases once daily for new versions. Notifies in
               TTY/RC. Set false to disable.

TEMPLATES_DIR                    default: "$HOME/.claude-mux/templates"
  Type: directory path
  Description: Where CLAUDE.md template files (web.md, python.md, etc.) live.
               Used with -n DIR --template NAME.

DEFAULT_TEMPLATE                 default: "default.md"
  Type: filename | ""
  Description: Template applied to new projects (-n) when no --template is
               given. Empty disables auto-templating.

SLEEP_BETWEEN                    default: 5
  Type: integer (seconds)
  Description: Delay between launching sessions during batch start (-a).

TMUX_EXTENDED_KEYS               default: true
TMUX_TITLE_FORMAT                default: "#S"
TMUX_MOUSE                       default: true
TMUX_HISTORY_LIMIT               default: 50000
TMUX_CLIPBOARD                   default: true
TMUX_DEFAULT_TERMINAL            default: "tmux-256color"
TMUX_ESCAPE_TIME                 default: 10
TMUX_MONITOR_ACTIVITY            default: true
  See config.example for descriptions of tmux session options.

TMUX_BIN, CLAUDE_BIN             defaults: resolved via `command -v`
  Type: absolute path
  Description: Override binary paths. Only needed if tmux/claude are not in
               PATH at runtime.

TIP_OF_DAY                       default: true
  Type: true | false
  Description: Inject a tip once per day per session via the UserPromptSubmit
               hook. Say "enable/disable tips" to toggle. Set false to disable.
               --tip always works regardless.

TIP_MODE                         default: "daily"
  Type: daily | random
  Description: How tips are selected. "daily" picks the same tip all day via
               a date hash. "random" picks a random tip each time.

Per-project state lives in .claudemux-* marker files in each project folder
(not in this config). Use claude-mux --hide / --show / --protect / --unprotect
to manage markers. The pattern .claudemux-* is auto-added to .gitignore in
git-tracked projects.
CONFIGHELP
    echo_hint_end
}

usage() {
    cat << EOF
claude-mux — Claude Code Multiplexer
Persistent Claude Code sessions for all your projects.

Usage: claude-mux [DIRECTORY]
       claude-mux -a
       claude-mux -t SESSION

Commands:
  (no args)             Launch a Claude session in the current directory and attach
  DIRECTORY             Launch a Claude session in DIRECTORY and attach
  -d, --directory DIR   Same as above (explicit form)
  -a, --all             Start all managed sessions under \$BASE_DIR
  -n, --new DIR         Create a new Claude project in DIR and attach
  -p                    With -n, create the directory and parents if they don't exist
  --template NAME       With -n, use a specific CLAUDE.md template
  -s SESSION COMMAND    Send a slash command to a running session
  -t, --target SESSION  Attach to an existing tmux session by name
  -l, --list            Show active sessions (active + running + stopped)
  -L                    Show all projects (active sessions + idle projects)
                          With --status STATUS: filter by status (idle, running, protected, stopped, queued, failed, hidden)
                          With --include-hidden: include hidden projects
                          With --hidden: show only hidden projects
  --list-templates      Show available CLAUDE.md templates
  --hide [SESSION]      Hide project from listings (creates .claudemux-ignore)
  --show [SESSION]      Restore project visibility (removes .claudemux-ignore)
  --protect [SESSION]   Protect a project's session at launch (creates .claudemux-protected)
  --unprotect [SESSION] Remove protection (deletes .claudemux-protected)
  --delete SESSION      Move a project folder to the system trash (macOS)
                          Honors protection unless --force; prompts unless --yes.
  --shutdown [SESSION...]  Shut down all managed sessions, or specific session(s)
  --restart [SESSION...]   Restart specific session(s), or all that were running
    --fresh                  With --start, --restart, or -d: start new conversation instead of resuming
  --permission-mode MODE [SESSION...]  Restart session(s) with the given permission mode
  --autolaunch             Invoked by LaunchAgent; dispatches based on LAUNCHAGENT_MODE
  --enable-tips            Enable daily tips (registers the on-prompt hook)
  --disable-tips           Disable daily tips
  --install-hooks          Backfill claude-mux hooks (incl. PreCompact RC-reconnect) into all projects
  --update                 Update claude-mux to the latest version
  --install [OPTS...]      Run interactive setup (config + LaunchAgent)
                           Options: --non-interactive, --base-dir DIR,
                                    --launchagent-mode {none,home},
                                    --home-model {sonnet,haiku,opus},
                                    --no-launchagent
  --uninstall              Remove hooks, permissions, LaunchAgent, and config

Options:
  --no-template         With -n, skip applying CLAUDE.md template
  --no-git              With -n, skip git init and .gitignore
  --no-permission-mode  With -n, skip setting permissions.defaultMode
  --no-multi-coder      With -n, skip creating AGENTS.md/GEMINI.md symlinks
  --no-attach           With -d or -n, launch in background without attaching
  --force               With --shutdown or --delete, override session protection
  --yes, -y             With --delete, skip confirmation prompt
  --dry-run             Print actions without executing
  -v, --version         Print version and exit
  -h, --help            Show this help message
  --guide               Show conversational commands for use within sessions
  --config-help         List all valid config options with defaults and descriptions

Configuration:
  ~/.claude-mux/config  User config file (created automatically on first run)

Logs:
  \$LOG_DIR/claude-mux.log  (default: ~/Library/Logs/claude-mux.log)
EOF
}

set_command() {
    if [[ "$COMMAND_SET" == "true" ]]; then
        echo "ERROR: Conflicting options — cannot combine $1 with previous command" >&2
        exit 1
    fi
    COMMAND="$2"
    COMMAND_SET=true
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)        DRY_RUN=true; shift ;;
        -l|--list)        set_command "-l" "list"; shift ;;
        -L)               set_command "-L" "list-all"; shift ;;
        --include-hidden) LIST_HIDDEN_MODE="include"; shift ;;
        --hidden)         LIST_HIDDEN_MODE="only"; shift ;;
        --status)
            [[ $# -lt 2 ]] && { echo "ERROR: --status requires a STATUS argument" >&2; exit 1; }
            case "$2" in
                idle|running|protected|stopped|queued|failed|hidden) STATUS_FILTER="$2" ;;
                *) echo "ERROR: Unknown --status filter: '$2'. Valid: idle running protected stopped queued failed hidden" >&2; exit 1 ;;
            esac
            shift 2
            ;;
        --shutdown)
            set_command "--shutdown" "shutdown"
            shift
            # Consume all following non-flag args as session names
            while [[ $# -gt 0 && "$1" != -* ]]; do
                SHUTDOWN_SESSIONS+=("$1"); shift
            done
            ;;
        --restart)
            set_command "--restart" "restart"
            shift
            while [[ $# -gt 0 && "$1" != -* ]]; do
                RESTART_SESSIONS+=("$1"); shift
            done
            ;;
        --start)
            set_command "--start" "start-session"
            shift
            while [[ $# -gt 0 && "$1" != -* ]]; do
                START_SESSIONS+=("$1"); shift
            done
            ;;
        --fresh)          FRESH_START=true; shift ;;
        --permission-mode)
            [[ $# -lt 2 ]] && { echo "ERROR: --permission-mode requires a MODE argument" >&2; exit 1; }
            set_command "--permission-mode" "setmode"
            SETMODE_VALUE="$2"; shift 2
            # Normalize aliases to canonical mode names
            [[ "$SETMODE_VALUE" == "yolo" || "$SETMODE_VALUE" == "dangerously-skip-permissions" ]] && SETMODE_VALUE="bypassPermissions"
            while [[ $# -gt 0 && "$1" != -* ]]; do
                SETMODE_SESSIONS+=("$1"); shift
            done
            ;;
        -s|--send)
            [[ $# -lt 3 ]] && { echo "ERROR: -s requires SESSION and COMMAND" >&2; exit 1; }
            set_command "-s" "send"
            SEND_SESSION="$2"; SEND_COMMAND="$3"; shift 3 ;;
        -t|--target)
            [[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR: -t requires a session name" >&2; exit 1; }
            set_command "-t" "attach"
            TARGET_SESSION="$2"; shift 2 ;;
        # NOTE: -a (batch launch of all projects) is under review for removal.
        # Home session + conversational on-demand starts cover most use cases,
        # and running every project simultaneously is costly in RAM/CPU/tokens.
        # Retained for now as a manual escape hatch; revisit after usage review.
        -a|--all)         set_command "-a" "start"; shift ;;
        --update)         set_command "--update" "update"; shift ;;
        --install)
            set_command "--install" "install"
            shift
            # Collect all remaining args for do_install to parse
            INSTALL_ARGS=("$@")
            break
            ;;
        --autolaunch)     set_command "--autolaunch" "autolaunch"; shift ;;
        --force)          FORCE=true; shift ;;
        -d|--directory)
            [[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR: -d requires a directory path" >&2; exit 1; }
            set_command "-d" "launch"
            LAUNCH_DIR="$2"; shift 2 ;;
        -n|--new)
            [[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR: -n requires a directory path" >&2; exit 1; }
            set_command "-n" "new"
            NEW_PROJECT_DIR="$2"; shift 2 ;;
        -p)               NEW_CREATE_PARENTS=true; shift ;;
        --template)
            [[ $# -lt 2 ]] && { echo "ERROR: --template requires a name" >&2; exit 1; }
            TEMPLATE_NAME="$2"; shift 2 ;;
        --list-templates) set_command "--list-templates" "list-templates"; shift ;;
        --hide)
            set_command "--hide" "hide"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                HIDE_SESSION="$1"; shift
            fi
            ;;
        --show)
            set_command "--show" "show"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                HIDE_SESSION="$1"; shift
            fi
            ;;
        --protect)
            set_command "--protect" "protect"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                PROTECT_SESSION="$1"; shift
            fi
            ;;
        --unprotect)
            set_command "--unprotect" "unprotect"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                PROTECT_SESSION="$1"; shift
            fi
            ;;
        --delete)
            set_command "--delete" "delete"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                DELETE_SESSION="$1"; shift
            fi
            ;;
        --save-template)
            set_command "--save-template" "save-template"
            shift
            [[ $# -lt 1 || "$1" == -* ]] && { echo "ERROR: --save-template requires a NAME" >&2; exit 1; }
            SAVE_TEMPLATE_NAME="$1"; shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                SAVE_TEMPLATE_DIR="$1"; shift
            fi
            ;;
        --rename)
            set_command "--rename" "rename"
            shift
            [[ $# -lt 2 || "$1" == -* || "$2" == -* ]] && { echo "ERROR: --rename requires SESSION NAME" >&2; exit 1; }
            RENAME_SRC="$1"; RENAME_DST="$2"; RENAME_MODE="rename"; shift 2
            ;;
        --move)
            set_command "--move" "move"
            shift
            [[ $# -lt 2 || "$1" == -* || "$2" == -* ]] && { echo "ERROR: --move requires SESSION PATH" >&2; exit 1; }
            RENAME_SRC="$1"; RENAME_DST="$2"; RENAME_MODE="move"; shift 2
            ;;
        --yes|-y)        DELETE_YES=true; shift ;;
        --no-template)       NO_TEMPLATE=true; shift ;;
        --no-multi-coder)    NO_MULTI_CODER=true; shift ;;
        --no-git)            NO_GIT=true; shift ;;
        --no-attach)         NO_ATTACH=true; shift ;;
        --no-permission-mode) NO_PERMISSION_MODE=true; shift ;;
        -v|--version)     echo "claude-mux $VERSION"; exit 0 ;;
        -h|--help)        usage; exit 0 ;;
        --tip)            set_command "--tip" "tip"; shift ;;
        --tipotd)         set_command "--tipotd" "tipotd"; shift ;;
        --on-compact)     set_command "--on-compact" "on-compact"; shift ;;
        --await-ready)
            [[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR: --await-ready requires a session name" >&2; exit 1; }
            set_command "--await-ready" "await-ready"
            AWAIT_SESSION="$2"; shift 2 ;;
        --print-system-prompt)
            [[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR: --print-system-prompt requires a session name" >&2; exit 1; }
            set_command "--print-system-prompt" "print-system-prompt"
            PRINT_PROMPT_SESSION="$2"; PRINT_PROMPT_MODE="${3:-auto}"
            [[ "${3:-}" == -* || -z "${3:-}" ]] && shift 2 || shift 3 ;;
        --on-prompt)      set_command "--on-prompt" "on-prompt"; shift ;;
        --update-check-bg) set_command "--update-check-bg" "update-check-bg"; shift ;;
        --enable-tips)    set_command "--enable-tips" "enable-tips"; shift ;;
        --disable-tips)   set_command "--disable-tips" "disable-tips"; shift ;;
        --install-hooks)  set_command "--install-hooks" "install-hooks"; shift ;;
        --uninstall)      set_command "--uninstall" "uninstall"; shift ;;
        --guide)          guide; exit 0 ;;
        --config-help)    config_help; exit 0 ;;
        --commands)       commands_help; exit 0 ;;
        --get-mode)
            set_command "--get-mode" "getmode"
            shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                GETMODE_SESSION="$1"; shift
            fi
            ;;
        -*)               echo "Unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
        *)
            # Positional arg = directory to launch in
            if [[ "$COMMAND_SET" == "true" && "$COMMAND" != "launch" ]]; then
                echo "ERROR: Unexpected argument '$1' — cannot combine with $COMMAND command" >&2
                exit 1
            fi
            if [[ -n "$LAUNCH_DIR" ]]; then
                echo "Unexpected argument: $1" >&2; echo >&2; usage >&2; exit 1
            fi
            LAUNCH_DIR="$1"; shift ;;
    esac
done

# Validate flag combinations
if [[ "$NEW_CREATE_PARENTS" == "true" && "$COMMAND" != "new" ]]; then
    echo "ERROR: -p can only be used with -n" >&2
    exit 1
fi
if [[ "$NO_TEMPLATE" == "true" && "$COMMAND" != "new" ]]; then
    echo "ERROR: --no-template can only be used with -n" >&2
    exit 1
fi
if [[ "$NO_GIT" == "true" && "$COMMAND" != "new" ]]; then
    echo "ERROR: --no-git can only be used with -n" >&2
    exit 1
fi
if [[ "$NO_PERMISSION_MODE" == "true" && "$COMMAND" != "new" ]]; then
    echo "ERROR: --no-permission-mode can only be used with -n" >&2
    exit 1
fi
if [[ "$NO_MULTI_CODER" == "true" && "$COMMAND" != "new" ]]; then
    echo "ERROR: --no-multi-coder can only be used with -n" >&2
    exit 1
fi
if [[ "$NO_ATTACH" == "true" && "$COMMAND" != "launch" && "$COMMAND" != "new" ]]; then
    echo "ERROR: --no-attach can only be used with -d or -n" >&2
    exit 1
fi
if [[ -n "$TEMPLATE_NAME" && "$COMMAND" != "new" ]]; then
    echo "ERROR: --template can only be used with -n" >&2
    exit 1
fi
if [[ -n "$TEMPLATE_NAME" && "$NO_TEMPLATE" == "true" ]]; then
    echo "ERROR: --template and --no-template are mutually exclusive" >&2
    exit 1
fi
if [[ "$FORCE" == "true" && "$COMMAND" != "shutdown" && "$COMMAND" != "delete" && "$COMMAND" != "save-template" && "$COMMAND" != "rename" && "$COMMAND" != "move" ]]; then
    echo "ERROR: --force can only be used with --shutdown, --delete, --save-template, --rename, or --move" >&2
    exit 1
fi
if [[ "$FRESH_START" == "true" && "$COMMAND" != "restart" && "$COMMAND" != "launch" && "$COMMAND" != "start-session" ]]; then
    echo "ERROR: --fresh can only be used with --start, --restart, or -d" >&2
    exit 1
fi

