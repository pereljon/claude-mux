# ── Legacy no-op: --tipotd Stop hook ─────────────────────────────────────────
# The tip-of-the-day Stop hook was removed in v1.15.0 (replaced by the
# --on-prompt UserPromptSubmit hook). Sessions launched before the upgrade may
# still call --tipotd on stop until they restart; exit immediately so they do
# not error. setup_claude_mux_permissions() removes the stale Stop hook at the
# next session launch.
if [[ "$COMMAND" == "tipotd" ]]; then
    exit 0
fi

# ── User config (overrides defaults above) ────────────────────────────────────

CLAUDE_MUX_DIR="$HOME/.claude-mux"
CLAUDE_MUX_CONFIG="$CLAUDE_MUX_DIR/config"

# Auto-migrate from old ~/.claude-mux-rc to new location
if [[ -f "$HOME/.claude-mux-rc" && ! -f "$CLAUDE_MUX_CONFIG" ]]; then
    mkdir -p "$CLAUDE_MUX_DIR"
    mv "$HOME/.claude-mux-rc" "$CLAUDE_MUX_CONFIG"
    chmod 600 "$CLAUDE_MUX_CONFIG"
    if [[ -d "$LOG_DIR" ]]; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Migrated config from ~/.claude-mux-rc to ~/.claude-mux/config" >> "$LOG_DIR/claude-mux.log"
    fi
fi

# Ensure config directory exists (idempotent, harmless)
mkdir -p "$CLAUDE_MUX_DIR/templates"

# Create empty default template if it doesn't exist
if [[ ! -f "$CLAUDE_MUX_DIR/templates/default.md" ]]; then
    touch "$CLAUDE_MUX_DIR/templates/default.md"
fi

# Source config if present (otherwise defaults from earlier in the script apply).
# First-run detection happens later, after function definitions, just before dispatch.
if [[ -f "$CLAUDE_MUX_CONFIG" ]]; then
    # shellcheck source=/dev/null
    _cfg_perms=$(stat -f '%A' "$CLAUDE_MUX_CONFIG" 2>/dev/null)
    if [[ -n "$_cfg_perms" && "$_cfg_perms" != "600" && "$_cfg_perms" != "400" ]]; then
        echo "WARN: $CLAUDE_MUX_CONFIG has unsafe permissions ($_cfg_perms) — expected 600" >&2
    fi
    source "$CLAUDE_MUX_CONFIG"
fi

# Backward compat: LAUNCHAGENT_ENABLED=true (legacy) → LAUNCHAGENT_MODE=home
# (Previously mapped to batch, but batch mode has been removed.)
if [[ "$LAUNCHAGENT_MODE" == "none" && "$LAUNCHAGENT_ENABLED" == "true" ]]; then
    LAUNCHAGENT_MODE="home"
fi

# Validate LAUNCHAGENT_MODE
case "$LAUNCHAGENT_MODE" in
    none|home) ;;
    batch)
        echo "WARN: LAUNCHAGENT_MODE=batch has been removed — treating as 'home'" >&2
        LAUNCHAGENT_MODE="home" ;;
    *)
        echo "ERROR: Invalid LAUNCHAGENT_MODE '$LAUNCHAGENT_MODE' — must be none or home" >&2
        exit 1
        ;;
esac

# Validate DEFAULT_PERMISSION_MODE
case "$DEFAULT_PERMISSION_MODE" in
    ""|default|acceptEdits|plan|auto|dontAsk|bypassPermissions) ;;
    *)
        echo "ERROR: Invalid DEFAULT_PERMISSION_MODE '$DEFAULT_PERMISSION_MODE'" >&2
        echo "       Valid values: default, acceptEdits, plan, auto, dontAsk, bypassPermissions" >&2
        exit 1
        ;;
esac

# A model name just needs to be a shell-SAFE TOKEN; *which* tokens are valid models is
# Claude Code's call (it errors at launch on a genuinely bad name), not claude-mux's — so
# we pass the value through instead of maintaining a model allowlist that rots every
# release. The regex forbids a LEADING DASH: the value is interpolated UNQUOTED as
# `claude --model ${HOME_SESSION_MODEL}` in the generated launch wrapper (src/70-start-launch.sh:177,187),
# so a value like `-rm` would be misparsed by `claude` as a separate flag (arg-injection).
# This format check is now the SOLE safety layer for that interpolation. Empty = Claude
# Code default. This runs on every config load (the always-runs chokepoint), so even a
# hand-edited ~/.claude-mux/config is caught here.
MODEL_TOKEN_RE='^[A-Za-z0-9._][A-Za-z0-9._-]*$'
is_valid_model() { [[ -z "$1" || "$1" =~ $MODEL_TOKEN_RE ]]; }

# Validate HOME_SESSION_MODEL (format/pass-through, not membership)
if ! is_valid_model "$HOME_SESSION_MODEL"; then
    echo "ERROR: Invalid HOME_SESSION_MODEL '$HOME_SESSION_MODEL' — must be a model name claude accepts (letters/digits/._-, no leading dash) or empty" >&2
    exit 1
fi

# Validate numeric tmux config values
for _var_name in SLEEP_BETWEEN TMUX_HISTORY_LIMIT TMUX_ESCAPE_TIME STAGGER_CONCURRENCY STARTING_WINDOW; do
    _var_val="${!_var_name}"
    if [[ -n "$_var_val" && ! "$_var_val" =~ ^[0-9]+$ ]]; then
        echo "ERROR: $CLAUDE_MUX_CONFIG: $_var_name must be a non-negative integer (got: '$_var_val')" >&2
        exit 1
    fi
done

# Default LAUNCH_DIR to current directory when command is launch and no dir specified
if [[ "$COMMAND" == "launch" && -z "$LAUNCH_DIR" ]]; then
    LAUNCH_DIR="."
fi

HOME_LAUNCH=false

# ── Constants ─────────────────────────────────────────────────────────────────

# Seconds to wait between launching each session (mitigates RC registration issues).
# Override in ~/.claude-mux/config if needed.
SLEEP_BETWEEN="${SLEEP_BETWEEN:-5}"
TIP_OF_DAY="${TIP_OF_DAY:-true}"
TIP_MODE="${TIP_MODE:-daily}"
AUTORESTORE="${AUTORESTORE:-true}"
STAGGER_CONCURRENCY="${STAGGER_CONCURRENCY:-3}"
STARTING_WINDOW="${STARTING_WINDOW:-90}"
RESTORE_STATE_DIR="$CLAUDE_MUX_DIR/restore-state"
# Crash-loop guard (internal constants, not user config). A session that dies
# within MIN_HEALTHY seconds of a restore attempt counts as a fast death; after
# TRIP_THRESHOLD consecutive fast deaths it is tripped and no longer restored.
AUTORESTORE_MIN_HEALTHY=300
AUTORESTORE_TRIP_THRESHOLD=3
LOG_FILE="$LOG_DIR/claude-mux.log"

# Resolve binary paths: config override → command -v fallback
TMUX_BIN="${TMUX_BIN:-$(command -v tmux 2>/dev/null || true)}"
CLAUDE_BIN="${CLAUDE_BIN:-$(command -v claude 2>/dev/null || true)}"

# Validate TMPDIR is safe for use in shell strings (no quotes, spaces, or shell metacharacters)
if [[ "${TMPDIR:-}" =~ [\'\"\$\`\ \	] ]]; then
    echo "ERROR: TMPDIR contains unsafe characters (quotes, spaces, or shell metacharacters)" >&2
    echo "       Set TMPDIR to a path without special characters." >&2
    exit 1
fi
CLAUDE_MUX_BIN="$(command -v "$0" 2>/dev/null)"
if [[ -z "$CLAUDE_MUX_BIN" ]]; then
    CLAUDE_MUX_BIN="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
fi
GITHUB_SSH_INFO=""

# Warn when cross-session control is enabled — elevated privilege surface
if [[ "$ALLOW_CROSS_SESSION_CONTROL" == "true" ]]; then
    echo "WARN: ALLOW_CROSS_SESSION_CONTROL=true — any session can send keystrokes to any other managed session" >&2
fi

