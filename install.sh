#!/bin/bash
# install.sh — claude-mux installer

set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
    echo "ERROR: Do not run this installer as root or with sudo." >&2
    echo "claude-mux is a per-user tool — run as your normal user account." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BASE_DIR="$HOME/Claude"
BASE_DIR=""
BIN_DIR=""
INSTALL_LAUNCHAGENT=true
LAUNCHAGENT_MODE="home"
HOME_SESSION_MODEL="sonnet"
DEFAULT_PERMISSION_MODE="auto"
ALLOW_CROSS_SESSION_CONTROL=false
INTERACTIVE=true

usage() {
    cat << EOF
install.sh — Install claude-mux

Usage: install.sh [OPTIONS]

Options:
  --base-dir DIR          Root directory for Claude projects (default: ~/Claude)
  --bin-dir DIR           Directory to install claude-mux binary (default: ~/bin)
  --permission-mode MODE  Set Claude's default permission mode per project
                          Valid: default, acceptEdits, plan, auto, dontAsk, bypassPermissions, "" (disabled)
                          (default: auto)
  --cross-session-control Enable sessions to send slash commands to each other (multi-agent)
  --launchagent-mode MODE Set LaunchAgent behavior at login: none, home (default), batch
  --home-model MODEL      Model for the home session (default: sonnet)
  --no-launchagent        Skip LaunchAgent installation entirely
  --non-interactive       Skip interactive prompts, use defaults/flags only
  -h, --help              Show this help message

Examples:
  ./install.sh
  ./install.sh --non-interactive
  ./install.sh --base-dir ~/work/claude --launchagent-mode batch
  ./install.sh --no-launchagent
EOF
}

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-dir)
            [[ $# -lt 2 ]] && { echo "ERROR: --base-dir requires a value" >&2; exit 1; }
            BASE_DIR="$2"; shift 2 ;;
        --bin-dir)
            [[ $# -lt 2 ]] && { echo "ERROR: --bin-dir requires a value" >&2; exit 1; }
            BIN_DIR="$2"; shift 2 ;;
        --permission-mode)
            [[ $# -lt 2 ]] && { echo "ERROR: --permission-mode requires a value" >&2; exit 1; }
            DEFAULT_PERMISSION_MODE="$2"; shift 2 ;;
        --cross-session-control) ALLOW_CROSS_SESSION_CONTROL=true; shift ;;
        --launchagent-mode)
            [[ $# -lt 2 ]] && { echo "ERROR: --launchagent-mode requires a value" >&2; exit 1; }
            LAUNCHAGENT_MODE="$2"
            case "$LAUNCHAGENT_MODE" in
                none|home|batch) ;;
                *) echo "ERROR: --launchagent-mode must be none, home, or batch" >&2; exit 1 ;;
            esac
            shift 2 ;;
        --home-model)
            [[ $# -lt 2 ]] && { echo "ERROR: --home-model requires a value" >&2; exit 1; }
            HOME_SESSION_MODEL="$2"
            case "$HOME_SESSION_MODEL" in
                sonnet|haiku|opus|"") ;;
                *) echo "ERROR: --home-model must be sonnet, haiku, opus, or \"\" (empty)" >&2; exit 1 ;;
            esac
            shift 2 ;;
        --no-launchagent)       INSTALL_LAUNCHAGENT=false; shift ;;
        --non-interactive)      INTERACTIVE=false; shift ;;
        -h|--help)              usage; exit 0 ;;
        *)                      echo "Unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
    esac
done

# ── Find default bin dir ──────────────────────────────────────────────────────

find_bin_dir() {
    local candidates=("$HOME/bin" "$HOME/.local/bin")
    for dir in "${candidates[@]}"; do
        if [[ -d "$dir" && -w "$dir" ]]; then
            echo "$dir"; return
        fi
    done
    echo "$HOME/bin"
}

DEFAULT_BIN_DIR="$(find_bin_dir)"

# ── Interactive prompts ───────────────────────────────────────────────────────

if [[ "$INTERACTIVE" == "true" && -t 0 ]]; then
    echo "claude-mux installer"
    echo ""

    # BIN_DIR
    if [[ -z "$BIN_DIR" ]]; then
        printf "Install location? [%s]: " "$DEFAULT_BIN_DIR"
        read -r _input
        BIN_DIR="${_input:-$DEFAULT_BIN_DIR}"
        BIN_DIR="${BIN_DIR/#\~/$HOME}"
    fi

    # BASE_DIR
    if [[ -z "$BASE_DIR" ]]; then
        printf "Where are your Claude projects? [%s]: " "$DEFAULT_BASE_DIR"
        read -r _input
        BASE_DIR="${_input:-$DEFAULT_BASE_DIR}"
        # Expand ~ if user typed it
        BASE_DIR="${BASE_DIR/#\~/$HOME}"
    fi

    # Validate BASE_DIR is a reasonable path
    if [[ -z "$BASE_DIR" ]]; then
        echo "ERROR: Base directory cannot be empty." >&2
        exit 1
    fi

    # Check if path is writable (parent must exist for mkdir)
    local _parent
    _parent="$(dirname "$BASE_DIR")"
    if [[ ! -d "$_parent" && ! -w "$(dirname "$_parent")" ]]; then
        echo "ERROR: Cannot create $BASE_DIR — parent directory is not writable." >&2
        exit 1
    fi

    if [[ ! -d "$BASE_DIR" ]]; then
        printf "Directory %s does not exist. Create it? [Y/n]: " "$BASE_DIR"
        read -r _confirm
        if [[ "${_confirm:-y}" =~ ^[Yy] ]]; then
            mkdir -p "$BASE_DIR"
        else
            echo "ERROR: Base directory does not exist." >&2
            exit 1
        fi
    fi

    # LaunchAgent mode
    echo ""
    echo "A home session is a lightweight Claude session that runs in your base"
    echo "directory. It stays running so Remote Control is always available from"
    echo "the Claude mobile app, and can manage all your other sessions."
    echo ""
    printf "Start a home session at login? (none/home/batch) [%s]: " "$LAUNCHAGENT_MODE"
    read -r _input
    if [[ -n "$_input" ]]; then
        case "$_input" in
            none|home|batch) LAUNCHAGENT_MODE="$_input" ;;
            *) echo "Invalid choice, using default: $LAUNCHAGENT_MODE" ;;
        esac
    fi

    # Home session model (only if mode is home)
    if [[ "$LAUNCHAGENT_MODE" == "home" ]]; then
        printf "Home session model? (sonnet/haiku/opus) [%s]: " "$HOME_SESSION_MODEL"
        read -r _input
        if [[ -n "$_input" ]]; then
            case "$_input" in
                sonnet|haiku|opus) HOME_SESSION_MODEL="$_input" ;;
                *) echo "Invalid model, using default: $HOME_SESSION_MODEL" ;;
            esac
        fi
    fi

    echo ""
fi

BASE_DIR="${BASE_DIR:-$DEFAULT_BASE_DIR}"

if [[ -z "$BIN_DIR" ]]; then
    BIN_DIR="$DEFAULT_BIN_DIR"
fi

if [[ ! -d "$BIN_DIR" ]]; then
    echo "Creating $BIN_DIR..."
    mkdir -p "$BIN_DIR"
fi

if [[ ! -w "$BIN_DIR" ]]; then
    echo "ERROR: $BIN_DIR is not writable." >&2
    exit 1
fi

# Add bin dir to PATH in shell profile if not already there
PATH_UPDATED=""
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
        SHELL_PROFILE="$HOME/.zshrc"
    else
        SHELL_PROFILE="$HOME/.bashrc"
    fi

    if ! grep -q "# Added by claude-mux" "$SHELL_PROFILE" 2>/dev/null; then
        echo "Adding $BIN_DIR to PATH in $SHELL_PROFILE..."
        cat >> "$SHELL_PROFILE" << PROFILE_EOF

# Added by claude-mux
export PATH="\$PATH:$BIN_DIR"
# End of claude-mux section
PROFILE_EOF
        PATH_UPDATED="$SHELL_PROFILE"
    fi
fi

# ── Install binary ────────────────────────────────────────────────────────────

echo "Installing claude-mux to $BIN_DIR/claude-mux..."
cp "$SCRIPT_DIR/claude-mux" "$BIN_DIR/claude-mux"
chmod +x "$BIN_DIR/claude-mux"

# ── Create base dir ───────────────────────────────────────────────────────────

if [[ ! -d "$BASE_DIR" ]]; then
    echo "Creating base directory $BASE_DIR..."
    mkdir -p "$BASE_DIR"
fi

# ── Create config directory and files ─────────────────────────────────────────

CLAUDE_MUX_DIR="$HOME/.claude-mux"
CONFIG_FILE="$CLAUDE_MUX_DIR/config"

# Auto-migrate from old location
if [[ -f "$HOME/.claude-mux-rc" && ! -f "$CONFIG_FILE" ]]; then
    echo "Migrating config from ~/.claude-mux-rc to ~/.claude-mux/config..."
    mkdir -p "$CLAUDE_MUX_DIR"
    mv "$HOME/.claude-mux-rc" "$CONFIG_FILE"
fi

# Ensure directories exist
mkdir -p "$CLAUDE_MUX_DIR/templates"

# Create empty default template
if [[ ! -f "$CLAUDE_MUX_DIR/templates/default.md" ]]; then
    touch "$CLAUDE_MUX_DIR/templates/default.md"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Creating $CONFIG_FILE..."

    # Format settings: commented out when at default, active when customized
    base_dir_line="BASE_DIR=\"${BASE_DIR}\""
    [[ "$BASE_DIR" == "$DEFAULT_BASE_DIR" ]] && base_dir_line="#BASE_DIR=\"\$HOME/Claude\""

    permission_line="DEFAULT_PERMISSION_MODE=\"${DEFAULT_PERMISSION_MODE}\""
    [[ "$DEFAULT_PERMISSION_MODE" == "auto" ]] && permission_line="#DEFAULT_PERMISSION_MODE=\"auto\""

    cross_line="ALLOW_CROSS_SESSION_CONTROL=${ALLOW_CROSS_SESSION_CONTROL}"
    [[ "$ALLOW_CROSS_SESSION_CONTROL" == "false" ]] && cross_line="#ALLOW_CROSS_SESSION_CONTROL=false"

    launchagent_line="LAUNCHAGENT_MODE=${LAUNCHAGENT_MODE}"
    [[ "$LAUNCHAGENT_MODE" == "home" ]] && launchagent_line="#LAUNCHAGENT_MODE=home"

    model_line="HOME_SESSION_MODEL=\"${HOME_SESSION_MODEL}\""
    [[ "$HOME_SESSION_MODEL" == "sonnet" ]] && model_line="#HOME_SESSION_MODEL=\"sonnet\""

    cat > "$CONFIG_FILE" << CONFIG_EOF
# ~/.claude-mux/config — claude-mux user configuration
# Generated by install.sh. Uncomment and edit to override defaults.

# Root directory to scan for Claude projects (directories containing .claude/).
# Default: \$HOME/Claude
${base_dir_line}

# Directory for log files.
# Default: \$HOME/Library/Logs
#LOG_DIR="\$HOME/Library/Logs"

# Set Claude's permissions.defaultMode for each project.
# Valid: "" (disabled), "default", "acceptEdits", "plan", "auto", "dontAsk", "bypassPermissions"
# Default: "auto"
${permission_line}

# Allow sessions to send slash commands to other sessions via tmux.
# Default: false
${cross_line}

# ── Templates ─────────────────────────────────────────────────────────────────
#TEMPLATES_DIR="\$HOME/.claude-mux/templates"
#DEFAULT_TEMPLATE="default.md"

# ── LaunchAgent ───────────────────────────────────────────────────────────────
# LaunchAgent mode at login: none, home (default), batch
${launchagent_line}

# Model for the home session. Set to "" to use the default model.
# Default: sonnet
${model_line}

# ── Batch mode ────────────────────────────────────────────────────────────────
#SLEEP_BETWEEN=5
CONFIG_EOF
else
    echo "Config $CONFIG_FILE already exists — skipping."
fi

# ── Install LaunchAgent ───────────────────────────────────────────────────────

if [[ "$INSTALL_LAUNCHAGENT" == "true" ]]; then
    LAUNCHAGENTS_DIR="$HOME/Library/LaunchAgents"
    PLIST_SRC="$SCRIPT_DIR/com.user.claude-mux.plist"
    PLIST_DEST="$LAUNCHAGENTS_DIR/com.user.claude-mux.plist"

    if [[ ! -f "$PLIST_SRC" ]]; then
        echo "WARNING: com.user.claude-mux.plist not found — skipping LaunchAgent install."
    else
        mkdir -p "$LAUNCHAGENTS_DIR"

        if launchctl list | grep -q "com.user.claude-mux" 2>/dev/null; then
            echo "Unloading existing LaunchAgent..."
            launchctl bootout "gui/$(id -u)" "$PLIST_DEST" 2>/dev/null || true
        fi

        echo "Installing LaunchAgent to $PLIST_DEST..."
        sed "s|exec \"\\\$HOME/bin/claude-mux\" --autolaunch|exec \"$BIN_DIR/claude-mux\" --autolaunch|" "$PLIST_SRC" > "$PLIST_DEST"
        if ! grep -q "$BIN_DIR/claude-mux" "$PLIST_DEST" 2>/dev/null; then
            echo "WARNING: Could not template binary path into plist — LaunchAgent may point to wrong location."
            echo "         Manually edit $PLIST_DEST to set the correct path to claude-mux."
        fi
        launchctl bootstrap "gui/$(id -u)" "$PLIST_DEST"
        echo "LaunchAgent installed and loaded."
    fi
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo ""
echo "claude-mux installed successfully."
echo ""
echo "  Binary:       $BIN_DIR/claude-mux"
echo "  Base dir:     $BASE_DIR"
echo "  Config:       $CONFIG_FILE"
echo "  LaunchAgent:  $LAUNCHAGENT_MODE"
[[ "$LAUNCHAGENT_MODE" == "home" ]] && echo "  Home model:   $HOME_SESSION_MODEL"
echo ""

if [[ -n "$PATH_UPDATED" ]]; then
    echo "┌──────────────────────────────────────────────────────────────────┐"
    echo "│  ACTION REQUIRED: Restart your terminal or run:                 │"
    echo "│                                                                  │"
    echo "│    source $PATH_UPDATED"
    echo "│                                                                  │"
    echo "└──────────────────────────────────────────────────────────────────┘"
else
    echo "Run 'claude-mux --help' to get started."
fi
