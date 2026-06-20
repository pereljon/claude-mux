# ── Attach helper ─────────────────────────────────────────────────────────────

attach_to_session() {
    local session_name="$1"
    if ! "$TMUX_BIN" has-session -t "$session_name" 2>/dev/null; then
        echo "No tmux session named '$session_name'" >&2
        echo "Run 'claude-mux -l' to see available sessions." >&2
        exit 1
    fi
    # $TMUX_PANE is set by tmux in child processes — use it to detect if we're inside tmux
    if [[ -n "${TMUX_PANE:-}" ]]; then
        exec "$TMUX_BIN" switch-client -t "$session_name"
    else
        exec "$TMUX_BIN" attach-session -t "$session_name"
    fi
}

if [[ "$COMMAND" == "attach" ]]; then
    attach_to_session "$TARGET_SESSION"
fi

# ── Validate -d / positional directory early ──────────────────────────────────

if [[ "$COMMAND" == "launch" ]]; then
    # Resolve to absolute path
    if [[ "$LAUNCH_DIR" != /* ]]; then
        LAUNCH_DIR="$(cd "$LAUNCH_DIR" 2>/dev/null && pwd)" || {
            echo "ERROR: Cannot resolve directory: $LAUNCH_DIR" >&2
            exit 1
        }
    fi
    if [[ ! -d "$LAUNCH_DIR" ]]; then
        echo "ERROR: No such directory: $LAUNCH_DIR" >&2
        exit 1
    fi
    # Detect home session: LAUNCH_DIR resolves to BASE_DIR
    _resolved_launch="$(cd "$LAUNCH_DIR" 2>/dev/null && pwd -P)"
    _resolved_base="$(cd "$BASE_DIR" 2>/dev/null && pwd -P)"
    if [[ -n "$_resolved_launch" && "$_resolved_launch" == "$_resolved_base" ]]; then
        HOME_LAUNCH=true
        LAUNCH_SESSION_NAME="home"
    else
        LAUNCH_SESSION_NAME="$(sanitize_session_name "$(basename "$LAUNCH_DIR")")"
        if [[ -z "$LAUNCH_SESSION_NAME" ]]; then
            echo "ERROR: Directory name sanitizes to empty: $(basename "$LAUNCH_DIR")" >&2
            exit 1
        fi
    fi
fi

# ── Validate -n directory early ───────────────────────────────────────────────

if [[ "$COMMAND" == "new" ]]; then
    # Resolve to absolute path (directory may not exist yet)
    if [[ "$NEW_PROJECT_DIR" != /* ]]; then
        _parent="$(cd "$(dirname "$NEW_PROJECT_DIR")" 2>/dev/null && pwd)" || {
            echo "ERROR: Cannot resolve parent directory: $(dirname "$NEW_PROJECT_DIR")" >&2
            exit 1
        }
        NEW_PROJECT_DIR="$_parent/$(basename "$NEW_PROJECT_DIR")"
    fi
    NEW_SESSION_NAME="$(sanitize_session_name "$(basename "$NEW_PROJECT_DIR")")"
    if [[ -z "$NEW_SESSION_NAME" ]]; then
        echo "ERROR: Directory name sanitizes to empty: $(basename "$NEW_PROJECT_DIR")" >&2
        exit 1
    fi
fi

# ─�� Startup delay (LaunchAgent only — no terminal attached) ───────────────────

if [[ "$COMMAND" == "autolaunch" && ! -t 1 && "$DRY_RUN" != "true" ]]; then
    # LaunchAgent only — delay for system services to initialize at login.
    # Skip if the system has been up longer than the delay (KeepAlive restart, not initial login).
    _boot_epoch=$(sysctl -n kern.boottime 2>/dev/null | awk '{print $4}' | tr -d ',')
    _uptime_secs=$(( $(date +%s) - ${_boot_epoch:-0} ))
    if [[ $_uptime_secs -le 45 ]]; then
        log "Waiting 45 seconds for system services to initialize..."
        sleep 45
    else
        log "System up ${_uptime_secs}s — skipping startup delay"
    fi
fi

# ── Dependency check ──────────────────────────────────────────────────────────
# tmux + claude are required only for commands that actually create or manage tmux
# sessions. Commands that just read/print or edit on-disk config (templates, tips,
# hooks) need neither, so exempt them — otherwise `claude-mux --list-templates` (or
# --tip / --enable-tips ...) would fail on a host without tmux or claude installed.
# (--guide / --commands / --config-help exit during arg-parse, before this check, so
# they need no entry here. --save-template is intentionally NOT exempt: its default
# form resolves the *current* session via tmux, so it genuinely needs tmux.)
case "$COMMAND" in
    list-templates|tip|enable-tips|disable-tips|install-hooks|update-check-bg)
        : ;;  # no tmux/claude needed
    *)
        if [[ -z "$TMUX_BIN" || ! -x "$TMUX_BIN" ]]; then
            log "ERROR: tmux not found — install with 'brew install tmux' or set TMUX_BIN in ~/.claude-mux/config"
            exit 1
        fi

        if [[ -z "$CLAUDE_BIN" || ! -x "$CLAUDE_BIN" ]]; then
            log "ERROR: claude not found — install with 'brew install claude' or set CLAUDE_BIN in ~/.claude-mux/config"
            exit 1
        fi
        ;;
esac

# ── Managed session names ─────────────────────────────────────────────────────
# Build the set of session names that claude-mux would create, so -l and
# --shutdown only act on sessions we manage (not unrelated tmux sessions).

get_managed_session_names() {
    MANAGED_SESSIONS=()
    # 'home' is always a managed session name (the BASE_DIR session)
    MANAGED_SESSIONS+=("home")
    discover_projects
    for _proj in "${PROJECT_DIRS[@]}"; do
        local _sanitized
        _sanitized="$(sanitize_session_name "$(basename "$_proj")")"
        [[ -n "$_sanitized" ]] && MANAGED_SESSIONS+=("$_sanitized")
    done
}

is_managed_session() {
    local name="$1"
    for managed in "${MANAGED_SESSIONS[@]}"; do
        [[ "$name" == "$managed" ]] && return 0
    done
    return 1
}

