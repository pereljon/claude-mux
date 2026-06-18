# ── Shutdown ──────────────────────────────────────────────────────────────────

# Gracefully exit Claude and kill a single tmux session
is_protected_session() {
    local session="$1"
    local marker
    marker=$("$TMUX_BIN" show-options -t "$session" -v @claude-mux-protected 2>/dev/null)
    [[ "$marker" == "1" ]]
}

# Returns true if the tmux session is owned by claude-mux. Set at session
# creation via @claude-mux-managed = 1. Distinguishes claude-mux-owned
# sessions from user-created tmux sessions that happen to share a name.
is_claude_mux_session() {
    local session="$1"
    local marker
    marker=$("$TMUX_BIN" show-options -t "$session" -v @claude-mux-managed 2>/dev/null)
    [[ "$marker" == "1" ]]
}

shutdown_single_session() {
    local session="$1"
    # Optional second arg lets callers pass force=true directly without touching the
    # global FORCE. Falls back to $FORCE so dispatch-path callers are unaffected.
    local force="${2:-$FORCE}"
    # Third arg: when "true", keep the .claudemux-running marker in place. Restart
    # callers pass true so a crash mid-restart leaves the marker for auto-restore to
    # recover from. Shutdown callers omit it (intent to stop -> remove the marker).
    local preserve_marker="${3:-false}"
    if ! "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
        log "No tmux session named '$session'"
        echo "See $LOG_FILE for details" >&2
        return 1
    fi
    if is_protected_session "$session" && [[ "$force" != "true" ]]; then
        echo "ERROR: Session '$session' is protected. Use --force to shut down." >&2
        echo "See $LOG_FILE for details" >&2
        return 1
    fi
    # Remove the auto-restore marker first (intent to stop) so the tick can't
    # resurrect a session mid-shutdown. Use the recorded launch dir, not
    # pane_current_path, which can drift from the project root.
    if [[ "$preserve_marker" != "true" ]]; then
        remove_running_marker "$(session_marker_dir "$session")"
    fi
    if claude_running_in_session "$session"; then
        log "Sending /exit to session '$session'"
        [[ "$DRY_RUN" != "true" ]] && "$TMUX_BIN" send-keys -t "$session" -l "/exit" && "$TMUX_BIN" send-keys -t "$session" Enter
        # Poll until Claude exits (max 10s, check every 0.5s)
        if [[ "$DRY_RUN" != "true" ]]; then
            _wait=0
            while [[ $_wait -lt 20 ]]; do
                "$TMUX_BIN" has-session -t "$session" 2>/dev/null && claude_running_in_session "$session" || break
                sleep 0.5
                (( _wait++ ))
            done
            [[ $_wait -ge 20 ]] && log "WARN: Claude in '$session' did not exit within 10s"
        fi
    fi
    if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
        log "Killing tmux session '$session'"
        [[ "$DRY_RUN" != "true" ]] && "$TMUX_BIN" kill-session -t "$session" 2>/dev/null
    fi
}

shutdown_claude_sessions() {
    log "=== claude-mux shutdown starting (dry-run=${DRY_RUN}) ==="

    # Named session(s) shutdown
    if [[ ${#SHUTDOWN_SESSIONS[@]} -gt 0 ]]; then
        get_managed_session_names
        local _shutdown_errors=0
        for _sess in "${SHUTDOWN_SESSIONS[@]}"; do
            if ! is_managed_session "$_sess"; then
                echo "ERROR: '$_sess' is not a claude-mux managed session" >&2
                echo "Run 'claude-mux -l' to see managed sessions." >&2
                (( _shutdown_errors++ ))
                continue
            fi
            shutdown_single_session "$_sess" || (( _shutdown_errors++ ))
        done
        log "=== claude-mux shutdown complete ==="
        return $(( _shutdown_errors > 0 ? 1 : 0 ))
    fi

    # All managed sessions
    get_managed_session_names

    local sessions
    sessions=$("$TMUX_BIN" list-sessions -F '#{session_name}' 2>/dev/null) || {
        log "No tmux sessions found"
        log "=== claude-mux shutdown complete ==="
        return
    }

    # Send /exit to managed sessions where Claude is running
    local exit_count=0
    local protected_skipped=0
    local managed_list=()
    while IFS= read -r session; do
        [[ -z "$session" ]] && continue
        is_managed_session "$session" || continue
        if is_protected_session "$session" && [[ "$FORCE" != "true" ]]; then
            log "Skipping protected session '$session' (use --force to override)"
            (( protected_skipped++ ))
            continue
        fi
        managed_list+=("$session")
        # Remove the auto-restore marker first (intent to stop).
        remove_running_marker "$(session_marker_dir "$session")"
        if claude_running_in_session "$session"; then
            log "Sending /exit to session '$session'"
            [[ "$DRY_RUN" != "true" ]] && "$TMUX_BIN" send-keys -t "$session" -l "/exit" && "$TMUX_BIN" send-keys -t "$session" Enter
            (( exit_count++ ))
        fi
    done <<< "$sessions"

    if [[ $exit_count -gt 0 ]]; then
        log "Sent /exit to $exit_count session(s), waiting for Claude to exit..."
        if [[ "$DRY_RUN" != "true" ]]; then
            _wait=0
            while [[ $_wait -lt 20 ]]; do
                _still_running=false
                for _s in "${managed_list[@]}"; do
                    if "$TMUX_BIN" has-session -t "$_s" 2>/dev/null && claude_running_in_session "$_s"; then
                        _still_running=true
                        break
                    fi
                done
                [[ "$_still_running" != "true" ]] && break
                sleep 0.5
                (( _wait++ ))
            done
            [[ $_wait -ge 20 ]] && log "WARN: Some Claude sessions did not exit within 10s"
        fi
    fi

    # Kill managed tmux sessions
    local kill_count=0
    for session in "${managed_list[@]}"; do
        if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
            log "Killing tmux session '$session'"
            [[ "$DRY_RUN" != "true" ]] && "$TMUX_BIN" kill-session -t "$session" 2>/dev/null
            (( kill_count++ ))
        fi
    done

    log "Shut down $kill_count managed session(s)"
    log "=== claude-mux shutdown complete ==="
}

status_claude_sessions() {
    local show_idle="${1:-false}"
    local status_filter="${2:-}"
    echo_hint
    get_managed_session_names   # also calls discover_projects internally

    local sessions
    sessions=$("$TMUX_BIN" list-sessions -F '#{session_name}' 2>/dev/null) || sessions=""

    # Detect the calling session (for > prefix)
    local calling_session=""
    if [[ -n "${TMUX_PANE:-}" ]]; then
        calling_session="$("$TMUX_BIN" display-message -p '#S' 2>/dev/null)"
    fi

    # Build set of active session names
    local active_sessions=""
    local running=0 protected=0 stopped=0 unmanaged=0 idle=0 queued=0 failed=0

    # Collect all rows, then format as aligned columns
    local rows=""

    if [[ -n "$sessions" ]]; then
        while IFS= read -r session; do
            [[ -z "$session" ]] && continue
            if is_managed_session "$session"; then
                active_sessions="${active_sessions}${session}
"
                local _dir
                _dir=$("$TMUX_BIN" display-message -t "$session" -p '#{pane_current_path}' 2>/dev/null)
                # Shorten home prefix
                _dir="${_dir/#$HOME/~}"

                # Mark calling session with > prefix
                local _display_name="$session"
                [[ "$session" == "$calling_session" ]] && _display_name="> $session"

                local _status
                if claude_running_in_session "$session"; then
                    if is_protected_session "$session"; then
                        _status="protected"
                        (( protected++ ))
                    else
                        _status="running"
                        (( running++ ))
                    fi
                else
                    # Claude not running in a live pane (e.g. a crashed/zombie
                    # session). Derive queued/failed/stopped from the marker state.
                    # Use the raw launch dir (not the ~-shortened display path, which
                    # would never match the on-disk marker).
                    _status=$(autorestore_status "$session" "$(session_marker_dir "$session")" "stopped")
                    case "$_status" in
                        queued) (( queued++ )) ;;
                        failed) (( failed++ )) ;;
                        *) (( stopped++ )) ;;
                    esac
                fi

                rows="${rows}${_status}|${_display_name}|${_dir}
"
            else
                (( unmanaged++ ))
            fi
        done <<< "$sessions"
    fi

    # Show idle projects (have .claude but no tmux session)
    if [[ "$show_idle" == "true" ]]; then
        local hidden_count=0
        # Visible projects (skip when LIST_HIDDEN_MODE=only)
        if [[ "${LIST_HIDDEN_MODE:-none}" != "only" ]]; then
            for _proj in "${PROJECT_DIRS[@]}"; do
                local _name
                _name="$(sanitize_session_name "$(basename "$_proj")")"
                [[ -z "$_name" ]] && continue
                if echo "$active_sessions" | grep -qx "$_name"; then
                    continue
                fi
                local _short="${_proj/#$HOME/~}"
                # A fully-dead project (no tmux) that still carries the marker is
                # queued/failed, not merely idle, so -l agrees with the tick.
                local _istatus
                _istatus=$(autorestore_status "$_name" "$_proj" "idle")
                rows="${rows}${_istatus}|${_name}|${_short}
"
                case "$_istatus" in
                    queued) (( queued++ )) ;;
                    failed) (( failed++ )) ;;
                    *) (( idle++ )) ;;
                esac
            done
        fi
        # Hidden projects (when LIST_HIDDEN_MODE=include or only)
        if [[ "${LIST_HIDDEN_MODE:-none}" != "none" ]]; then
            for _proj in "${HIDDEN_PROJECT_DIRS[@]+"${HIDDEN_PROJECT_DIRS[@]}"}"; do
                local _name
                _name="$(sanitize_session_name "$(basename "$_proj")")"
                [[ -z "$_name" ]] && continue
                if echo "$active_sessions" | grep -qx "$_name"; then
                    continue
                fi
                local _short="${_proj/#$HOME/~}"
                # Hidden sessions are still restored by the tick, so reflect
                # queued/failed when marked; otherwise show the visibility state.
                local _hstatus
                _hstatus=$(autorestore_status "$_name" "$_proj" "hidden")
                rows="${rows}${_hstatus}|${_name}|${_short}
"
                case "$_hstatus" in
                    queued) (( queued++ )) ;;
                    failed) (( failed++ )) ;;
                    *) (( hidden_count++ )) ;;
                esac
            done
        fi
    fi

    # Sort rows by path (3rd field) for logical grouping
    local sorted_rows
    sorted_rows=$(echo "$rows" | sort -t'|' -k3)

    # Apply status filter if provided
    if [[ -n "$status_filter" ]]; then
        sorted_rows=$(printf '%s' "$sorted_rows" | awk -F'|' -v s="$status_filter" '$1 == s')
    fi

    # Print table with row numbers
    if [[ -n "$sorted_rows" ]]; then
        local _n=0
        if [[ -t 1 ]]; then
            # TTY: printf-aligned columns
            printf "  %-3s %-9s %-30s %s\n" "#" "STATUS" "SESSION" "DIRECTORY"
            printf "  %-3s %-9s %-30s %s\n" "---" "------" "-------" "---------"
            while IFS='|' read -r _status _name _path; do
                [[ -z "$_status" ]] && continue
                (( _n++ ))
                printf "  %-3s %-9s %-30s %s\n" "$_n" "$_status" "$_name" "$_path"
            done <<< "$sorted_rows"
        else
            # Non-TTY (Claude): markdown table
            echo "| # | Status | Session | Directory |"
            echo "|---|--------|---------|-----------|"
            while IFS='|' read -r _status _name _path; do
                [[ -z "$_status" ]] && continue
                (( _n++ ))
                echo "| $_n | $_status | $_name | $_path |"
            done <<< "$sorted_rows"
        fi
    fi

    echo ""
    if [[ -n "$status_filter" ]]; then
        local _fcount
        _fcount=$(printf '%s' "$sorted_rows" | grep -cv '^$')
        echo "${status_filter}: ${_fcount}"
    else
        local summary="${running} running, ${protected} protected, ${stopped} stopped"
        [[ $queued -gt 0 ]] && summary="${summary}, ${queued} queued"
        [[ $failed -gt 0 ]] && summary="${summary}, ${failed} failed"
        [[ "$show_idle" == "true" ]] && summary="${summary}, ${idle} idle"
        [[ "$show_idle" == "true" && "${LIST_HIDDEN_MODE:-none}" != "none" ]] && summary="${summary}, ${hidden_count:-0} hidden"
        echo "$summary"
    fi
    [[ $unmanaged -gt 0 ]] && echo "($unmanaged non-managed tmux sessions hidden)"
    if [[ "$show_idle" == "true" && "${LIST_HIDDEN_MODE:-none}" == "none" && ${#HIDDEN_PROJECT_DIRS[@]} -gt 0 ]]; then
        echo "(${#HIDDEN_PROJECT_DIRS[@]} hidden projects — use --include-hidden or --hidden to show)"
    fi
    # Row-count footer (non-TTY only): paired with assistant-must-display tags so
    # the model can self-check that no rows were collapsed or summarized.
    if [[ ! -t 1 && -n "$sorted_rows" ]]; then
        local _total
        _total=$(printf '%s' "$sorted_rows" | grep -cv '^$')
        echo "<!-- ${_total} rows above. Output must contain all ${_total} verbatim. -->"
    fi
    echo_hint_end
    return 0
}

