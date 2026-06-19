# ── Main ──────────────────────────────────────────────────────────────────────

start_sessions() {
    log "=== claude-mux starting (dry-run=${DRY_RUN}) ==="
    _seen_sessions=""  # newline-delimited "name|dir" pairs for collision detection

    ensure_base_dir
    discover_projects
    detect_github_ssh_accounts
    [[ -n "$GITHUB_SSH_INFO" ]] && log "Detected GitHub SSH accounts:${GITHUB_SSH_INFO}"

    if [[ "${#PROJECT_DIRS[@]}" -eq 0 ]]; then
        log "WARN: No Claude projects found under $BASE_DIR (no .claude directories) — nothing to do"
        log "=== claude-mux complete ==="
        return
    fi

    log "Found ${#PROJECT_DIRS[@]} Claude project(s)"
    migrate_stray_sessions

    for PROJECT_DIR in "${PROJECT_DIRS[@]}"; do
        dir_name="$(basename "$PROJECT_DIR")"

        session_name="$(sanitize_session_name "$dir_name")"
        if [[ "$session_name" != "$dir_name" ]]; then
            log "Sanitized session name: '$dir_name' → '$session_name'"
        fi
        if [[ -z "$session_name" ]]; then
            log "Skipping '$dir_name': name is empty after sanitization"
            continue
        fi

        _existing=$(echo "$_seen_sessions" | grep "^${session_name}|" | head -1)
        if [[ -n "$_existing" ]]; then
            log "WARN: Session name '$session_name' collision — '$PROJECT_DIR' conflicts with '${_existing#*|}', skipping"
            echo "WARN: Session name collision '$session_name' — skipping '$PROJECT_DIR' (conflicts with '${_existing#*|}')" >&2
            continue
        fi
        _seen_sessions="${_seen_sessions}${session_name}|${PROJECT_DIR}
"

        setup_default_mode "$PROJECT_DIR"
        local _is_home_proj=false
        [[ "$PROJECT_DIR" == "$BASE_DIR" ]] && _is_home_proj=true
        setup_claude_mux_permissions "$PROJECT_DIR" "$_is_home_proj"
        create_claude_session "$session_name" "$PROJECT_DIR"
    done

    log "=== claude-mux complete ==="
}

launch_single_session() {
    log "=== claude-mux launch: $LAUNCH_DIR ==="

    # Migrate stray Claude running in this directory (not in tmux)
    _stray_pids=$(pgrep -f "$CLAUDE_BIN" 2>/dev/null) || _stray_pids=""
    while IFS= read -r _pid; do
        [[ -z "$_pid" ]] && continue
        _check_pid="$_pid"
        _in_tmux=false
        while [[ "$_check_pid" -gt 1 ]]; do
            _parent_cmd=$(ps -o comm= -p "$_check_pid" 2>/dev/null) || break
            if [[ "$_parent_cmd" == tmux* ]]; then _in_tmux=true; break; fi
            _check_pid=$(ps -o ppid= -p "$_check_pid" 2>/dev/null | tr -d ' ') || break
        done
        [[ "$_in_tmux" == "true" ]] && continue
        _cwd=$(lsof -p "$_pid" -a -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-)
        if [[ "$_cwd" == "$LAUNCH_DIR" ]]; then
            log "Migrating stray Claude (pid=$_pid) from $LAUNCH_DIR into tmux"
            kill -TERM "$_pid" 2>/dev/null
            sleep 2
        fi
    done <<< "$_stray_pids"

    detect_github_ssh_accounts
    setup_default_mode "$LAUNCH_DIR"
    local _launch_is_home=false
    [[ "$HOME_LAUNCH" == "true" || "$LAUNCH_DIR" == "$BASE_DIR" ]] && _launch_is_home=true
    setup_claude_mux_permissions "$LAUNCH_DIR" "$_launch_is_home"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Creating tmux session '$LAUNCH_SESSION_NAME' in $LAUNCH_DIR"
        log "Dry run — skipping session creation and attach for '$LAUNCH_SESSION_NAME'"
        return
    fi

    # If session already exists with Claude running, just attach
    if "$TMUX_BIN" has-session -t "$LAUNCH_SESSION_NAME" 2>/dev/null; then
        if claude_running_in_session "$LAUNCH_SESSION_NAME"; then
            if ! is_claude_mux_session "$LAUNCH_SESSION_NAME"; then
                log "WARN: Claiming non-managed session '$LAUNCH_SESSION_NAME' — Claude is running; assuming v1.8 upgrade"
            fi
            # Mark as claude-mux-managed (idempotent — handles v1.8 upgrades)
            "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-managed 1 2>/dev/null
            "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-dir "$LAUNCH_DIR" 2>/dev/null
            "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-claude-id "$(claude_binary_id)" 2>/dev/null
            write_running_marker "$LAUNCH_DIR"   # backfill auto-restore marker for live sessions
            # Re-apply protection if marker exists (handles in-place upgrade and idempotent --autolaunch)
            if [[ -f "$LAUNCH_DIR/.claudemux-protected" ]]; then
                "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-protected 1 2>/dev/null
            fi
            if [[ "$NO_ATTACH" == "true" ]]; then
                log "Session '$LAUNCH_SESSION_NAME' already running claude (--no-attach)"
                return
            fi
            log "Session '$LAUNCH_SESSION_NAME' already running claude — attaching"
            attach_to_session "$LAUNCH_SESSION_NAME"
            return
        fi
        # Claude not running — but is this our session? Refuse if not.
        if ! is_claude_mux_session "$LAUNCH_SESSION_NAME"; then
            log "WARN: tmux session '$LAUNCH_SESSION_NAME' exists but is not claude-mux-managed — refusing to overwrite"
            echo "WARN: tmux session '$LAUNCH_SESSION_NAME' is in use by something else." >&2
            echo "      Resolve manually: 'tmux kill-session -t $LAUNCH_SESSION_NAME' if you want claude-mux to take over." >&2
            return 1
        fi
        # Claude exited from a session we own — kill, recreate
        log "Session '$LAUNCH_SESSION_NAME' exists but claude is not running — recreating"
        "$TMUX_BIN" kill-session -t "$LAUNCH_SESSION_NAME" 2>/dev/null
    fi

    # Build system prompt — home session always uses auto mode
    local tmux_prompt
    tmux_prompt="$(build_system_prompt "$LAUNCH_SESSION_NAME" "auto")"

    # Create tmux session that runs Claude directly (no send-keys)
    log "Creating tmux session '$LAUNCH_SESSION_NAME' in $LAUNCH_DIR"

    # Build model flag for home sessions
    local model_flag=""
    if [[ "$HOME_LAUNCH" == "true" && -n "$HOME_SESSION_MODEL" ]]; then
        # Defense-in-depth: re-validate at the interpolation boundary. The config
        # chokepoint already format-checks HOME_SESSION_MODEL on every load, but this
        # is the one site that bakes it unquoted into the generated script, so guard it
        # here too in case a future path ever sets the value without re-validating.
        is_valid_model "$HOME_SESSION_MODEL" || { echo "ERROR: HOME_SESSION_MODEL '$HOME_SESSION_MODEL' is not a valid model token" >&2; return 1; }
        model_flag="--model ${HOME_SESSION_MODEL}"
    fi

    # Write prompt and launch script to per-user temp dir (not world-readable /tmp)
    # NOTE: model_flag and LAUNCH_SESSION_NAME are interpolated as text into this generated
    # script. They are safe because HOME_SESSION_MODEL is validated to
    # ^[A-Za-z0-9._][A-Za-z0-9._-]*$ (shell-safe token, no leading dash → cannot inject a
    # separate claude flag) at every set-boundary (config/flag/install), and
    # LAUNCH_SESSION_NAME is sanitized to [a-zA-Z0-9-]. This is the sole model-interpolation
    # site. Any future use of additional variables here must apply the same validation — the
    # heredoc provides no further protection.
    #
    # FRESH_START=true omits -c so Claude Code starts a new conversation instead of resuming.
    local resume_flag="-c"
    [[ "$FRESH_START" == "true" ]] && resume_flag=""
    local _launch_kind="resume"; [[ -z "$resume_flag" ]] && _launch_kind="fresh"
    local prompt_file launch_script
    # Prompt lives in the session's folder (stable — not $TMPDIR-reaped) so a
    # restart-in-place can regenerate + re-read it (see create_claude_session).
    prompt_file="$LAUNCH_DIR/.claudemux-prompt"
    launch_script=$(mktemp "${TMPDIR:-/tmp}/claude-launch-XXXXXX")
    chmod 600 "$launch_script"
    printf '%s' "$tmux_prompt" > "$prompt_file"
    chmod 600 "$prompt_file" 2>/dev/null
    # Single-quote-escape the marker/prompt paths (see create_claude_session).
    local _esc_dir; _esc_dir=${LAUNCH_DIR//\'/\'\\\'\'}
    local _marker_esc="${_esc_dir}/.claudemux-running"
    local _prompt_esc="${_esc_dir}/.claudemux-prompt"
    local _esc_bin; _esc_bin=${CLAUDE_MUX_BIN//\'/\'\\\'\'}   # apostrophe-safe binary path (see create_claude_session)
    # Exit-code wrapper + prompt-file delivery + clean-exit teardown, same as
    # create_claude_session. For the home session LAUNCH_DIR is BASE_DIR (no marker
    # written), so the marker rm is a harmless no-op; the kill-session means a clean
    # /exit of home tears it down (the LaunchAgent then restarts it, as home is always-on).
    cat > "$launch_script" << LAUNCH_EOF
#!/bin/bash
trap 'rm -f "${launch_script}"' EXIT
export PATH="$(dirname "$CLAUDE_BIN"):\$PATH"
_marker='${_marker_esc}'
_prompt='${_prompt_esc}'
_resume='${resume_flag}'
# Loop for restart-in-place (see create_claude_session): a clean exit with the
# @claude-mux-restart option set relaunches claude in THIS pane rather than tearing
# it down. This closes the restart-all-from-home bug (home's pane never goes down).
while true; do
    _start=\$(date +%s)
    _resume_err=\$(mktemp "\${TMPDIR:-/tmp}/claude-resume-err-XXXXXX")
    # Primary launch: capture stderr to a temp file so a failed resume can be
    # diagnosed from the log (was 2>/dev/null). The pane sees no stderr either way.
    claude \${_resume:+\$_resume }--remote-control --permission-mode auto --allow-dangerously-skip-permissions ${model_flag} --name '${LAUNCH_SESSION_NAME}' --append-system-prompt-file "\$_prompt" 2>"\$_resume_err"
    _rc=\$?
    _elapsed=\$(( \$(date +%s) - _start ))
    if [[ \$_rc -ne 0 && \$_elapsed -lt 10 ]]; then
        # Primary launch failed fast → log why, then fall back to a fresh session.
        # stderr left visible below so a real failure also shows in the pane.
        {
            printf '[%s] Primary launch for %s failed: rc=%s after %ss; falling back to fresh session\n' "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" "'${LAUNCH_SESSION_NAME}'" "\$_rc" "\$_elapsed"
            printf '  primary stderr (last 800 chars): %s\n' "\$(tr '\\n' ' ' < "\$_resume_err" | tail -c 800)"
        } >> '${LOG_FILE}'
        claude --remote-control --permission-mode auto --allow-dangerously-skip-permissions ${model_flag} --name '${LAUNCH_SESSION_NAME}' --append-system-prompt-file "\$_prompt"
        _rc=\$?
    fi
    rm -f "\$_resume_err"
    if [[ \$_rc -eq 0 ]]; then
        # Clean exit. If a restart is pending, relaunch in place (consume the option,
        # pick resume/fresh, regenerate the prompt, fire the handshake from OUTSIDE
        # this pane, loop). Home always uses auto mode.
        _restart=\$('${TMUX_BIN}' show-option -t '${LAUNCH_SESSION_NAME}' -qv @claude-mux-restart 2>/dev/null)
        if [[ -n "\$_restart" ]]; then
            '${TMUX_BIN}' set-option -t '${LAUNCH_SESSION_NAME}' -u @claude-mux-restart 2>/dev/null
            _resume='-c'; [[ "\$_restart" == fresh ]] && _resume=''
            if '${_esc_bin}' --print-system-prompt '${LAUNCH_SESSION_NAME}' 'auto' > "\$_prompt.new" 2>/dev/null && [[ -s "\$_prompt.new" ]]; then
                chmod 600 "\$_prompt.new" 2>/dev/null
                mv -f "\$_prompt.new" "\$_prompt"
            else
                rm -f "\$_prompt.new"
            fi
            '${_esc_bin}' --await-ready '${LAUNCH_SESSION_NAME}' >/dev/null 2>&1 &
            continue
        fi
        # No restart pending: clean stop. Remove marker (no-op for home/BASE_DIR) +
        # prompt + launch script BEFORE kill-session, so SIGHUP can't interrupt cleanup
        # mid-way (trap EXIT is a backstop). For home the LaunchAgent then restarts it.
        rm -f "\$_marker" "\$_prompt" '${launch_script}'
        '${TMUX_BIN}' kill-session -t '${LAUNCH_SESSION_NAME}' 2>/dev/null
        break
    fi
    # Non-zero exit (crash): leave the pane + marker (+ prompt) for the restore tick.
    break
done
LAUNCH_EOF
    chmod +x "$launch_script"

    # A -d launch (and the caller-last restart handoff, which re-execs -d) is
    # user-initiated, so clear any crash-loop history before bringing it up.
    restore_state_clear "$LAUNCH_SESSION_NAME"

    # Write the auto-restore marker before launching (no-op for the home session,
    # which is launch-managed). A crash before the first clean exit keeps intent.
    write_running_marker "$LAUNCH_DIR"

    # Create session using the script file — avoids shell injection via model_flag or session name
    "$TMUX_BIN" new-session -d -s "$LAUNCH_SESSION_NAME" -c "$LAUNCH_DIR" "bash '${launch_script}'"

    apply_tmux_options "$LAUNCH_SESSION_NAME"
    "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-managed 1 2>/dev/null
    "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-dir "$LAUNCH_DIR" 2>/dev/null
    "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-claude-id "$(claude_binary_id)" 2>/dev/null

    # Protect at launch if .claudemux-protected marker exists in working dir
    if [[ -f "$LAUNCH_DIR/.claudemux-protected" ]]; then
        "$TMUX_BIN" set-option -t "$LAUNCH_SESSION_NAME" @claude-mux-protected 1 2>/dev/null
        log "Session '$LAUNCH_SESSION_NAME' is protected (marker: $LAUNCH_DIR/.claudemux-protected)"
    fi

    # Background: wait until Claude is ready (same detector as create_claude_session,
    # incl. trust/bypass auto-accept and the busy/quiescence check), then send
    # "Ready?". Backgrounded so the longer ready-wait never blocks attach.
    (
        poll_until_ready "$LAUNCH_SESSION_NAME" || true
        # Prompt file (.claudemux-prompt) is NOT deleted here: the wrapper re-reads and
        # regenerates it on every in-place restart relaunch, and removes it on teardown.
        "$TMUX_BIN" send-keys -t "$LAUNCH_SESSION_NAME" -l "Ready?" 2>/dev/null && "$TMUX_BIN" send-keys -t "$LAUNCH_SESSION_NAME" Enter 2>/dev/null
    ) &

    if [[ "$NO_ATTACH" == "true" ]]; then
        log "Session '$LAUNCH_SESSION_NAME' created (--no-attach)"
    else
        attach_to_session "$LAUNCH_SESSION_NAME"
    fi
}

# Encode an absolute path to the format Claude Code uses for ~/.claude/projects/ folders.
# Every non-alphanumeric character (/, -, spaces, dots, etc.) becomes '-'.
# Verified empirically against real ~/.claude/projects/ entries.
encode_claude_path() {
    [[ -z "$1" ]] && return 1
    printf '%s' "$1" | tr -c '[:alnum:]' '-'
}

