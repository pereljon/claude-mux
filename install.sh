#!/bin/bash
# install.sh — claude-mux installer
# Works two ways:
#   curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
#   ./install.sh  (from a local clone)

set -euo pipefail

if [[ "$(id -u)" -eq 0 ]]; then
    echo "ERROR: Do not run this installer as root or with sudo." >&2
    echo "claude-mux is a per-user tool — run as your normal user account." >&2
    exit 1
fi

PLATFORM=$(uname -s)

# Check dependencies (warn, don't block — user may install them after)
if ! command -v tmux &>/dev/null; then
    if [[ "$PLATFORM" == "Darwin" ]]; then
        echo "WARNING: tmux not found. Install with: brew install tmux" >&2
    else
        echo "WARNING: tmux not found. Install with your package manager (apt install tmux, etc.)" >&2
    fi
fi
if ! command -v claude &>/dev/null; then
    if [[ "$PLATFORM" == "Darwin" ]]; then
        echo "WARNING: Claude Code CLI not found. Install with: brew install claude" >&2
    else
        echo "WARNING: Claude Code CLI not found. See: https://claude.ai/code" >&2
    fi
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-/dev/stdin}")" && pwd)"
BIN_DIR=""
INSTALL_ARGS=()
CLEANUP_TMP=""

# On Linux: full support is v2.0. Binary installs, LaunchAgent skipped.
if [[ "$PLATFORM" != "Darwin" ]]; then
    echo "NOTE: Linux support is planned for v2.0. The binary will be installed but"
    echo "      LaunchAgent setup will be skipped. For automatic startup, configure"
    echo "      a systemd user service after installation."
    INSTALL_ARGS+=(--no-launchagent)
fi

usage() {
    cat << EOF
install.sh — Install claude-mux

Usage: install.sh [OPTIONS]

Options:
  --bin-dir DIR             Directory to install claude-mux binary (default: ~/bin or ~/.local/bin)
  -h, --help                Show this help message

All other options (--base-dir, --launchagent-mode, --home-model, --no-launchagent,
--non-interactive, --permission-mode, --cross-session-control) are forwarded to
'claude-mux --install', which handles config and LaunchAgent setup.

Examples:
  ./install.sh
  ./install.sh --non-interactive
  ./install.sh --base-dir ~/work/claude --launchagent-mode none
  ./install.sh --no-launchagent
EOF
}

# ── Parse args ────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --bin-dir)
            [[ $# -lt 2 ]] && { echo "ERROR: --bin-dir requires a value" >&2; exit 1; }
            BIN_DIR="$2"; shift 2 ;;
        -h|--help)
            usage; exit 0 ;;
        -*)
            # Forward flag + its value (if next arg is not another flag) to claude-mux --install
            INSTALL_ARGS+=("$1"); shift
            if [[ $# -gt 0 && "$1" != -* ]]; then
                INSTALL_ARGS+=("$1"); shift
            fi
            ;;
        *)
            echo "ERROR: Unexpected argument '$1'. Use --help for usage." >&2
            exit 1 ;;
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

# ── Resolve binary source (local clone vs curl-piped) ─────────────────────────
# When run as a curl pipe, BASH_SOURCE[0] is /dev/stdin so SCRIPT_DIR
# resolves to the current directory. Check if the binary is actually there.

cleanup() {
    [[ -n "$CLEANUP_TMP" ]] && rm -f "$CLEANUP_TMP"
}
trap cleanup EXIT

BINARY_SOURCE="$SCRIPT_DIR/claude-mux"
if [[ ! -f "$BINARY_SOURCE" ]]; then
    # Curl-piped install: fetch binary from GitHub releases
    echo "Downloading claude-mux binary..."
    api_response=$(curl -sf --max-time 10 \
        "https://api.github.com/repos/pereljon/claude-mux/releases/latest" 2>/dev/null) || {
        echo "ERROR: could not reach GitHub releases API" >&2
        exit 1
    }
    latest=$(echo "$api_response" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' | head -1)
    if [[ -z "$latest" ]]; then
        echo "ERROR: could not determine latest version from GitHub" >&2
        exit 1
    fi
    download_url="https://github.com/pereljon/claude-mux/releases/download/v${latest}/claude-mux"
    tmp_binary=$(mktemp)
    CLEANUP_TMP="$tmp_binary"
    if ! curl -sfL --max-time 30 -o "$tmp_binary" "$download_url"; then
        echo "ERROR: failed to download v$latest from $download_url" >&2
        exit 1
    fi
    if ! head -1 "$tmp_binary" | grep -q '^#!'; then
        echo "ERROR: downloaded file doesn't look like a script — release may not have binary assets yet" >&2
        exit 1
    fi
    chmod +x "$tmp_binary"
    BINARY_SOURCE="$tmp_binary"
    echo "Downloaded v$latest"
fi

# ── Install binary ────────────────────────────────────────────────────────────

echo "Installing claude-mux to $BIN_DIR/claude-mux..."
cp "$BINARY_SOURCE" "$BIN_DIR/claude-mux"
chmod +x "$BIN_DIR/claude-mux"

# ── Add bin dir to PATH if needed ─────────────────────────────────────────────

PATH_UPDATED=""
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
        SHELL_PROFILE="$HOME/.zshrc"
    else
        SHELL_PROFILE="$HOME/.bashrc"
    fi

    if ! grep -q "# Added by claude-mux" "$SHELL_PROFILE" 2>/dev/null; then
        echo "Adding $BIN_DIR to PATH in $SHELL_PROFILE..."
        {
            printf '\n# Added by claude-mux\n'
            printf 'export PATH="$PATH:%s"\n' "$BIN_DIR"
            printf '# End of claude-mux section\n'
        } >> "$SHELL_PROFILE"
        PATH_UPDATED="$SHELL_PROFILE"
    fi
fi

# ── Delegate to claude-mux --install for config + LaunchAgent ─────────────────

echo ""
"$BIN_DIR/claude-mux" --install "${INSTALL_ARGS[@]+"${INSTALL_ARGS[@]}"}"

# ── Final PATH hint ───────────────────────────────────────────────────────────

if [[ -n "$PATH_UPDATED" ]]; then
    echo ""
    echo "┌──────────────────────────────────────────────────────────────────┐"
    echo "│  ACTION REQUIRED: Restart your terminal or run:                  │"
    echo "│                                                                  │"
    printf "│  %-64s│\n" "source $PATH_UPDATED"
    echo "│                                                                  │"
    echo "└──────────────────────────────────────────────────────────────────┘"
fi
