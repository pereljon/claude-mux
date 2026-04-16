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
ENABLE_LAUNCHAGENT=false
DEFAULT_PERMISSION_MODE="auto"
ALLOW_CROSS_SESSION_CONTROL=false

usage() {
    cat << EOF
install.sh — Install claude-mux

Usage: install.sh [OPTIONS]

Options:
  --base-dir DIR          Root directory for Claude projects (default: ~/Claude)
  --bin-dir DIR           Directory to install claude-mux binary (default: first writable bin in PATH)
  --permission-mode MODE  Set Claude's default permission mode per project
                          Valid: default, acceptEdits, plan, auto, dontAsk, bypassPermissions, "" (disabled)
                          (default: auto)
  --cross-session-control Enable sessions to send slash commands to each other (multi-agent)
  --enable-launchagent    Enable batch startup at login (disabled by default in config)
  --no-launchagent        Skip LaunchAgent installation entirely
  -h, --help              Show this help message

Examples:
  ./install.sh
  ./install.sh --enable-launchagent
  ./install.sh --base-dir ~/work/claude
  ./install.sh --bin-dir ~/.local/bin --no-launchagent
  ./install.sh --permission-mode acceptEdits
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
        --enable-launchagent)   ENABLE_LAUNCHAGENT=true; shift ;;
        --no-launchagent)       INSTALL_LAUNCHAGENT=false; shift ;;
        -h|--help)              usage; exit 0 ;;
        *)                      echo "Unknown option: $1" >&2; echo >&2; usage >&2; exit 1 ;;
    esac
done

BASE_DIR="${BASE_DIR:-$DEFAULT_BASE_DIR}"

# ── Find bin dir ──────────────────────────────────────────────────────────────

find_bin_dir() {
    # Prefer existing writable user bin directories
    local candidates=("$HOME/bin" "$HOME/.local/bin")
    for dir in "${candidates[@]}"; do
        if [[ -d "$dir" && -w "$dir" ]]; then
            echo "$dir"; return
        fi
    done
    # Fall back to creating ~/bin
    echo "$HOME/bin"
}

if [[ -z "$BIN_DIR" ]]; then
    BIN_DIR="$(find_bin_dir)"
    if [[ -z "$BIN_DIR" ]]; then
        echo "ERROR: No writable bin directory found in PATH." >&2
        echo "Use --bin-dir to specify one (e.g. --bin-dir ~/.local/bin)." >&2
        exit 1
    fi
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
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    # Detect shell profile
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
    else
        PATH_UPDATED=""
    fi
else
    PATH_UPDATED=""
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

    launchagent_line="LAUNCHAGENT_ENABLED=${ENABLE_LAUNCHAGENT}"
    [[ "$ENABLE_LAUNCHAGENT" == "true" ]] && launchagent_line="LAUNCHAGENT_ENABLED=true"

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

# ── Batch mode ────────────────────────────────────────────────────────────────
#SLEEP_BETWEEN=5
${launchagent_line}
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
        # Template the binary path into the plist so it matches --bin-dir
        sed "s|exec \"\\\$HOME/bin/claude-mux\" -a|exec \"$BIN_DIR/claude-mux\" -a|" "$PLIST_SRC" > "$PLIST_DEST"
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
echo "  Binary:    $BIN_DIR/claude-mux"
echo "  Base dir:  $BASE_DIR"
echo "  Config:    $CONFIG_FILE"
[[ "$INSTALL_LAUNCHAGENT" == "true" ]] && echo "  LaunchAgent: com.user.claude-mux (loaded)"
echo ""

if [[ -n "$PATH_UPDATED" ]]; then
    echo "  PATH:      $BIN_DIR added to $PATH_UPDATED"
    echo ""
    echo "┌──────────────────────────────────────────────────────────────────┐"
    echo "│  ACTION REQUIRED: Restart your terminal or run:                 │"
    echo "│                                                                  │"
    echo "│    source $PATH_UPDATED"
    echo "│                                                                  │"
    echo "└──────────────────────────────────────────────────────────────────┘"
else
    echo ""
    echo "Run 'claude-mux --help' to get started."
fi
