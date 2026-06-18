
# Check for updates (non-blocking, TTY-only, cached daily)
check_for_update

# First-run detection: if config is missing AND command needs config,
# either prompt for setup (TTY) or exit with hint (non-TTY).
# Commands that don't need config: install, update, list-templates, send,
# shutdown, autolaunch (LaunchAgent context — handled in autolaunch_dispatch).
case "$COMMAND" in
    install|update|list-templates|send|shutdown|autolaunch|uninstall|on-compact|on-prompt|update-check-bg|await-ready|print-system-prompt)
        # Skip config-required check; these can run without config.
        # Hook commands (on-prompt, update-check-bg) must never prompt or error
        # when config is missing — they exit silently in their handlers.
        ;;
    *)
        if [[ ! -f "$CLAUDE_MUX_CONFIG" ]]; then
            if [[ -t 0 && -t 1 ]]; then
                echo "No config found at $CLAUDE_MUX_CONFIG"
                printf "Run setup now? [Y/n]: "
                read -r _setup_answer
                case "${_setup_answer:-y}" in
                    [Yy]|[Yy]es|"")
                        do_install
                        echo ""
                        echo "Setup complete. Re-run your command to continue."
                        exit 0
                        ;;
                    *)
                        echo "Setup canceled. Run 'claude-mux --install' when ready."
                        exit 0
                        ;;
                esac
            else
                echo "ERROR: No config found at $CLAUDE_MUX_CONFIG" >&2
                echo "Run 'claude-mux --install' to set up." >&2
                exit 1
            fi
        fi
        ;;
esac

case "$COMMAND" in
    update)   do_update; exit 0 ;;
    install)  do_install; exit 0 ;;
    autolaunch) autolaunch_dispatch; exit 0 ;;
    start)    start_sessions; exit 0 ;;
    launch)   launch_single_session; exit 0 ;;
    new)      create_new_project; exit 0 ;;
    list)     status_claude_sessions; exit 0 ;;
    list-all) status_claude_sessions true "${STATUS_FILTER:-}"; exit 0 ;;
    list-templates) list_templates; exit 0 ;;
    tip)           tip_of_day; exit 0 ;;
    on-compact)    on_compact; exit 0 ;;
    await-ready)   await_ready_handshake "$AWAIT_SESSION"; exit 0 ;;
    print-system-prompt) build_system_prompt "$PRINT_PROMPT_SESSION" "$PRINT_PROMPT_MODE"; exit 0 ;;
    on-prompt)     on_prompt; exit 0 ;;
    update-check-bg) update_check_bg; exit 0 ;;
    enable-tips)   enable_tips; exit 0 ;;
    disable-tips)  disable_tips; exit 0 ;;
    install-hooks) install_hooks_command; exit $? ;;
    uninstall)     do_uninstall; exit 0 ;;
    save-template) save_template_command "${SAVE_TEMPLATE_NAME:-}" "${SAVE_TEMPLATE_DIR:-}"; exit $? ;;
    rename)     rename_move_command "${RENAME_SRC:-}" "${RENAME_DST:-}" "rename"; exit $? ;;
    move)       rename_move_command "${RENAME_SRC:-}" "${RENAME_DST:-}" "move"; exit $? ;;
    hide)       hide_command "${HIDE_SESSION:-}"; exit $? ;;
    show)       show_command "${HIDE_SESSION:-}"; exit $? ;;
    protect)    protect_command "${PROTECT_SESSION:-}"; exit $? ;;
    unprotect)  unprotect_command "${PROTECT_SESSION:-}"; exit $? ;;
    delete)     delete_command "${DELETE_SESSION:-}" "$FORCE" "${DELETE_YES:-false}"; exit $? ;;
    send)
        get_managed_session_names
        if ! is_managed_session "$SEND_SESSION"; then
            echo "ERROR: '$SEND_SESSION' is not a claude-mux managed session" >&2
            echo "Run 'claude-mux -l' to see managed sessions." >&2
            exit 1
        fi
        if ! "$TMUX_BIN" has-session -t "$SEND_SESSION" 2>/dev/null; then
            echo "No active tmux session named '$SEND_SESSION'" >&2
            echo "Run 'claude-mux -l' to see available sessions." >&2
            exit 1
        fi
        if [[ "$SEND_COMMAND" != /* ]]; then
            echo "ERROR: -s only accepts slash commands (must start with /)" >&2
            exit 1
        fi
        if [[ "$SEND_COMMAND" == *$'\n'* ]]; then
            echo "ERROR: -s command cannot contain newlines" >&2
            exit 1
        fi
        "$TMUX_BIN" send-keys -t "$SEND_SESSION" -l "$SEND_COMMAND" && "$TMUX_BIN" send-keys -t "$SEND_SESSION" Enter
        exit 0
        ;;
    shutdown) shutdown_claude_sessions; exit $? ;;
    start-session)
        # Start one or more sessions by NAME (start-if-stopped, no-op-if-running).
        # Distinct from --restart: never cycles a live session. Distinct from -a:
        # targets named sessions, not all projects.
        if [[ ${#START_SESSIONS[@]} -eq 0 ]]; then
            echo "ERROR: --start requires a session name (use -a to start all)" >&2
            exit 1
        fi
        detect_github_ssh_accounts
        get_managed_session_names
        _start_errors=0
        for _ss in "${START_SESSIONS[@]}"; do
            if ! is_managed_session "$_ss"; then
                echo "ERROR: '$_ss' is not a claude-mux managed session" >&2
                echo "Run 'claude-mux -l' to see managed sessions." >&2
                (( _start_errors++ )); continue
            fi
            _start_dir=$(resolve_session_dir "$_ss" 2>/dev/null)
            if [[ -z "$_start_dir" ]]; then
                echo "ERROR: cannot resolve working directory for '$_ss'" >&2
                (( _start_errors++ )); continue
            fi
            if claude_running_in_session "$_ss"; then
                echo "Session '$_ss' is already running."
                continue
            fi
            if [[ "$DRY_RUN" == "true" ]]; then
                log "Would start '$_ss' in $_start_dir${FRESH_START:+ (fresh start)}"
                continue
            fi
            restore_state_clear "$_ss"   # user-initiated bring-up un-trips crash-loop history
            if [[ "$_ss" == "home" ]]; then
                NO_ATTACH=true
                launch_home_session   # proper home path (keeps HOME_SESSION_MODEL)
            else
                # create_claude_session's own collision guard is the race backstop:
                # if the session appears between the check above and now, it no-ops.
                create_claude_session "$_ss" "$_start_dir" "" "$FRESH_START"
            fi
        done
        exit $(( _start_errors > 0 ? 1 : 0 ))
        ;;
    restart)
        # --restart bypasses home session protection by design: it relaunches rather
        # than permanently kills, so the session comes back. Use --shutdown --force
        # if you want to permanently stop a protected session.
        FORCE=true
        _restart_errors=0

        if [[ ${#RESTART_SESSIONS[@]} -gt 0 ]]; then
            # Named session(s) restart
            log "=== claude-mux restart: ${RESTART_SESSIONS[*]} ==="
            detect_github_ssh_accounts
            get_managed_session_names
            _restart_errors=0
            # If we're restarting the session we're running inside, it must restart
            # in place (we can't kill our own pane) — see restart_caller_in_place.
            _restart_caller=""
            if [[ -n "${TMUX:-}" ]]; then
                _restart_caller=$("$TMUX_BIN" display-message -p '#{session_name}' 2>/dev/null) || _restart_caller=""
            fi
            [[ "$DRY_RUN" != "true" ]] && echo "Restarting ${#RESTART_SESSIONS[@]} session(s) to apply updated injection. RC will need to reconnect in ~10s."
            for _rs in "${RESTART_SESSIONS[@]}"; do
                if ! is_managed_session "$_rs"; then
                    echo "ERROR: '$_rs' is not a claude-mux managed session" >&2
                    echo "Run 'claude-mux -l' to see managed sessions." >&2
                    (( _restart_errors++ ))
                    continue
                fi
                # session_marker_dir resolves only from the LIVE tmux session, so a
                # STOPPED session comes up empty. Fall back to resolve_session_dir
                # (basename scan of PROJECT_DIRS) so --restart works on stopped sessions.
                _restart_dir=$(session_marker_dir "$_rs")
                [[ -z "$_restart_dir" ]] && _restart_dir=$(resolve_session_dir "$_rs" 2>/dev/null)
                if [[ -z "$_restart_dir" ]]; then
                    echo "ERROR: Session '$_rs' not found or cannot determine working directory" >&2
                    echo "Run 'claude-mux -l' to see available sessions." >&2
                    echo "See $LOG_FILE for details" >&2
                    (( _restart_errors++ ))
                    continue
                fi
                if [[ "$DRY_RUN" == "true" ]]; then
                    log "Would restart session '$_rs' in $_restart_dir${FRESH_START:+ (fresh start)}"
                elif [[ -n "$_restart_caller" && "$_rs" == "$_restart_caller" ]]; then
                    # The caller is restarting itself → in place (can't SIGHUP our own
                    # pane). The looped wrapper relaunches + handshakes; no recreate here.
                    restart_caller_in_place "$_rs" "$FRESH_START"
                elif claude_running_in_session "$_rs"; then
                    restore_state_clear "$_rs"   # user restart un-trips a crash-looped session
                    # Restart marker + preserve_marker: a crash between shutdown and
                    # create leaves the session recoverable by the auto-restore tick.
                    mkdir "$_restart_dir/.claudemux-restarting" 2>/dev/null
                    # Named restart honors $FORCE (user must pass --force for a
                    # protected session), unlike restart-all which forces through.
                    shutdown_single_session "$_rs" "$FORCE" true   # preserve_marker
                    create_claude_session "$_rs" "$_restart_dir" "" "$FRESH_START"
                    rmdir "$_restart_dir/.claudemux-restarting" 2>/dev/null
                elif [[ "$_rs" == "home" ]]; then
                    # Stopped home → proper home path (keeps HOME_SESSION_MODEL). No
                    # shutdown needed (nothing running); never attach for a name-based op.
                    restore_state_clear "$_rs"
                    NO_ATTACH=true
                    launch_home_session
                else
                    # Stopped non-home → nothing to shut down; just start it (== --start).
                    restore_state_clear "$_rs"
                    create_claude_session "$_rs" "$_restart_dir" "" "$FRESH_START"
                fi
            done
            if [[ $_restart_errors -gt 0 ]]; then
                log "=== claude-mux restart complete ($_restart_errors error(s)) ==="
            else
                log "=== claude-mux restart complete ==="
            fi
        else
            # Full restart — remember which sessions had Claude running
            log "=== claude-mux restart starting ==="
            get_managed_session_names

            # Capture running sessions and their working directories
            _restart_list=""
            _sessions=$("$TMUX_BIN" list-sessions -F '#{session_name}' 2>/dev/null) || _sessions=""
            while IFS= read -r _s; do
                [[ -z "$_s" ]] && continue
                is_managed_session "$_s" || continue
                if claude_running_in_session "$_s"; then
                    _dir=$(session_marker_dir "$_s")
                    [[ -n "$_dir" ]] && _restart_list="${_restart_list}${_s}|${_dir}
"
                fi
            done <<< "$_sessions"

            if [[ -z "$_restart_list" ]]; then
                log "No running Claude sessions to restart"
                log "=== claude-mux restart complete ==="
            else
                _count=$(echo "$_restart_list" | grep -c '|')
                log "Remembering $_count running session(s) for restart"

                if [[ "$DRY_RUN" == "true" ]]; then
                    while IFS='|' read -r _name _dir; do
                        [[ -z "$_name" ]] && continue
                        log "Would restart session '$_name' in $_dir${FRESH_START:+ (fresh start)}"
                    done <<< "$_restart_list"
                else
                    echo "Restarting $_count session(s) to apply updated injection. RC will need to reconnect in ~10s."

                    # If running inside a session that's in the restart list,
                    # separate it out. We can't kill-session on the caller because
                    # this script is running in that pane (SIGHUP would kill us).
                    _caller_session=""
                    if [[ -n "${TMUX:-}" ]]; then
                        _caller_session=$("$TMUX_BIN" display-message -p '#{session_name}' 2>/dev/null) || _caller_session=""
                    fi
                    _other_list=""
                    _caller_entry=""
                    while IFS='|' read -r _name _dir; do
                        [[ -z "$_name" ]] && continue
                        if [[ "$_name" == "$_caller_session" ]]; then
                            _caller_entry="${_name}|${_dir}"
                        else
                            _other_list="${_other_list}${_name}|${_dir}
"
                        fi
                    done <<< "$_restart_list"

                    # Shut down and recreate non-caller sessions individually.
                    # CRITICAL: must NOT call shutdown_claude_sessions here - it walks
                    # every managed session including the caller, whose /exit SIGHUPs
                    # this script mid-loop and strands the rest. The partition above
                    # split the caller out for exactly this reason; honor it.
                    detect_github_ssh_accounts
                    while IFS='|' read -r _name _dir; do
                        [[ -z "$_name" ]] && continue
                        log "Restarting session '$_name' in $_dir"
                        restore_state_clear "$_name"   # user restart un-trips crash-loop history
                        # Restart marker: defer auto-restore for one tick. preserve_marker
                        # keeps .claudemux-running so a crash mid-restart is recoverable.
                        mkdir "$_dir/.claudemux-restarting" 2>/dev/null
                        # force=true: restart-all recycles protected non-callers too
                        # (protection guards --shutdown accidents, not --restart).
                        shutdown_single_session "$_name" true true   # force, preserve_marker
                        create_claude_session "$_name" "$_dir" "" "$FRESH_START"
                        rmdir "$_dir/.claudemux-restarting" 2>/dev/null
                    done <<< "$_other_list"

                    # Restart the caller LAST, IN PLACE. We can't kill the caller's pane
                    # (this script runs in it; the SIGHUP would kill us before recreate —
                    # that stranded home and forked its conversation: the bug this fixes).
                    # restart_caller_in_place sets @claude-mux-restart + sends /exit; the
                    # looped wrapper relaunches claude in the same pane and handshakes.
                    # See dev/features/restart-in-place.md.
                    if [[ -n "$_caller_entry" ]]; then
                        IFS='|' read -r _caller_name _caller_dir <<< "$_caller_entry"
                        restart_caller_in_place "$_caller_name" "$FRESH_START"
                    fi
                fi

                log "=== claude-mux restart complete ==="
            fi
        fi
        exit $(( _restart_errors > 0 ? 1 : 0 ))
        ;;
    setmode)
        case "$SETMODE_VALUE" in
            default|acceptEdits|plan|auto|bypassPermissions|dontAsk) ;;
            *)
                echo "ERROR: Invalid permission mode '$SETMODE_VALUE'" >&2
                echo "Valid modes: default, acceptEdits, plan, auto, bypassPermissions, dontAsk (\"yolo\" is an alias for bypassPermissions)" >&2
                exit 1
                ;;
        esac
        if [[ ${#SETMODE_SESSIONS[@]} -eq 0 ]]; then
            echo "ERROR: --permission-mode requires at least one SESSION argument" >&2
            echo "Usage: claude-mux --permission-mode MODE SESSION [SESSION...]" >&2
            exit 1
        fi
        log "=== claude-mux setmode: $SETMODE_VALUE for ${SETMODE_SESSIONS[*]} ==="
        detect_github_ssh_accounts
        get_managed_session_names
        FORCE=true
        _setmode_errors=0
        for _sm in "${SETMODE_SESSIONS[@]}"; do
            if ! is_managed_session "$_sm"; then
                echo "ERROR: '$_sm' is not a claude-mux managed session" >&2
                echo "Run 'claude-mux -l' to see managed sessions." >&2
                (( _setmode_errors++ ))
                continue
            fi
            _sm_dir=$(session_marker_dir "$_sm")
            if [[ -z "$_sm_dir" ]]; then
                echo "ERROR: Session '$_sm' not found or cannot determine working directory" >&2
                (( _setmode_errors++ ))
                continue
            fi
            if [[ "$DRY_RUN" == "true" ]]; then
                log "Would set session '$_sm' to mode '$SETMODE_VALUE'"
            elif [[ "$SETMODE_VALUE" == "bypassPermissions" ]]; then
                # bypassPermissions: navigate via Shift+Tab instead of restarting.
                # Every session is launched with --allow-dangerously-skip-permissions,
                # so bypassPermissions is always in the Shift+Tab cycle.
                _sm_pane=$("$TMUX_BIN" capture-pane -t "$_sm" -p 2>/dev/null)
                _sm_pane_tail=$(echo "$_sm_pane" | tail -4)
                if echo "$_sm_pane_tail" | grep -q "bypass permissions on"; then
                    log "Session '$_sm' is already in bypassPermissions"
                else
                    if echo "$_sm_pane_tail" | grep -q "plan mode on"; then
                        _btab_count=1
                    elif echo "$_sm_pane_tail" | grep -q "accept edits on"; then
                        _btab_count=2
                    else
                        # 3 presses covers default, auto, dontAsk, and any unrecognized mode.
                        # bypassPermissions is always the 3rd entry in the Shift+Tab cycle
                        # since every session launches with --allow-dangerously-skip-permissions.
                        _btab_count=3
                    fi
                    log "Switching '$_sm' to bypassPermissions via $_btab_count Shift+Tab"
                    for (( _i=0; _i<_btab_count; _i++ )); do
                        "$TMUX_BIN" send-keys -t "$_sm" BTab
                        sleep 0.3
                    done
                    sleep 0.5
                    _sm_pane=$("$TMUX_BIN" capture-pane -t "$_sm" -p 2>/dev/null)
                    if ! echo "$_sm_pane" | tail -4 | grep -q "bypass permissions on"; then
                        log "WARN: bypassPermissions not confirmed for '$_sm', falling back to restart"
                        restore_state_clear "$_sm"
                        shutdown_single_session "$_sm"
                        create_claude_session "$_sm" "$_sm_dir" "$SETMODE_VALUE"
                    fi
                fi
            else
                log "Restarting session '$_sm' in $_sm_dir with mode '$SETMODE_VALUE'"
                restore_state_clear "$_sm"
                shutdown_single_session "$_sm"
                create_claude_session "$_sm" "$_sm_dir" "$SETMODE_VALUE"
            fi
        done
        if [[ $_setmode_errors -gt 0 ]]; then
            log "=== claude-mux setmode complete ($_setmode_errors error(s)) ==="
        else
            log "=== claude-mux setmode complete ==="
        fi
        exit $(( _setmode_errors > 0 ? 1 : 0 ))
        ;;
    getmode)
        get_session_mode "$GETMODE_SESSION"
        exit $?
        ;;
esac
