# Wait until a session's Claude is ready, then send "Ready?" (which also reconnects RC).
# Internal: backgrounded by the looped launch wrapper after a restart-in-place relaunch, so
# the handshake fires from inside the surviving pane (the external launcher's process is gone
# by then). Reuses poll_until_ready (busy/quiescence + trust auto-accept).
#
# Re-capture @claude-mux-claude-id here: the in-place relaunch path (the wrapper loop) is the
# ONLY restart path that does not pass through create_claude_session / launch_single_session,
# so it is the only one that would otherwise leave a stale binary id. detect_claude_upgrade
# is persist-while-relevant (no ack-on-emit), so the upgrade notice self-clears ONLY when a
# restart re-captures the id — re-capturing on the in-place relaunch (which has just loaded
# the current binary) is what makes "restart this session" actually clear the notice. This is
# the claude-mux-process home for the re-capture the wrapper heredoc can't do (no functions).
await_ready_handshake() {
    local session="$1"
    [[ -z "$session" ]] && return 1
    "$TMUX_BIN" set-option -t "$session" @claude-mux-claude-id "$(claude_binary_id)" 2>/dev/null
    poll_until_ready "$session" || true
    "$TMUX_BIN" send-keys -t "$session" -l "Ready?" 2>/dev/null && "$TMUX_BIN" send-keys -t "$session" Enter 2>/dev/null
}

# Auto-confirm Claude Code's cached "Switch model?" dialog after an in-session
# `/model <id>` send. Backgrounded (detached) from the `send` handler for /model
# payloads only. Recognize-then-confirm: keys Enter ONLY when the specific dialog
# is positively matched (bottom-anchored), never a blind Enter. The dialog appears
# only on a cached CROSS-model switch, and on a self-switch only AFTER the caller's
# turn ends (the /model input is queued until the turn completes, 5-15s+), so the
# poll window is ~30s, not a few seconds. No dialog (uncached / same-model / bad id)
# → no match → exits silently having sent nothing. See dev/features/model-switch-confirm.md.
confirm_model_switch() {
    local session="$1"
    [[ -z "$session" ]] && return 0
    # Dead-session early-exit so a missing pane doesn't spin the full window.
    "$TMUX_BIN" has-session -t "$session" 2>/dev/null || return 0
    # Single-confirmer lock: only ONE confirmer per session may run at a time.
    # Two overlapping `/model <id>` sends to the same session would otherwise
    # spawn two confirmers that both match the dialog before either keys Enter;
    # the second, orphaned Enter would submit an empty prompt into Claude (the
    # exact thing the never-re-key design forbids). mkdir is atomic, so it doubles
    # as the mutex (per marker-file convention). A confirmer killed without cleanup
    # leaves a stale dir; it self-clears once older than the ~30s window.
    local lock
    lock="${TMPDIR:-/tmp}/claude-mux-confirm-$(printf '%s' "$session" | tr -c 'A-Za-z0-9_.-' '_').lock"
    if ! mkdir "$lock" 2>/dev/null; then
        # Reclaim a stale lock (older than the poll window); else another
        # confirmer owns it → exit without keying.
        find "$lock" -maxdepth 0 -mmin +1 -exec rmdir {} \; 2>/dev/null
        mkdir "$lock" 2>/dev/null || return 0
    fi
    trap 'rmdir "$lock" 2>/dev/null' EXIT
    local start pane tail12 vstart
    start=$(date +%s)
    while (( $(date +%s) - start < 30 )); do
        sleep 0.4
        pane=$("$TMUX_BIN" capture-pane -t "$session" -p 2>/dev/null) || {
            "$TMUX_BIN" has-session -t "$session" 2>/dev/null || return 0
            continue
        }
        tail12=$(printf '%s\n' "$pane" | tail -12)
        # Recognize the SPECIFIC dialog, bottom-anchored so a scrolled-up transcript
        # quote of the dialog text (this very repo quotes it in docs/replies) can't
        # trigger a keypress: require "Switch model?" + option 2 "No, go back" + the
        # affirmative "Yes, switch to" with the ❯ cursor on the SAME line within the
        # last 6 lines (the live dialog is pinned to the pane bottom).
        [[ "$tail12" == *"Switch model?"* ]] || continue
        [[ "$tail12" == *"No, go back"* ]] || continue
        printf '%s\n' "$tail12" | tail -6 | grep -q '❯.*Yes, switch to' || continue
        # Positive match: option 1 ("Yes, switch to …") is pre-highlighted, so a single
        # Enter confirms it. Send exactly ONCE.
        "$TMUX_BIN" send-keys -t "$session" Enter
        # Best-effort verify it cleared (~2s). Never re-key regardless of the result:
        # on a slow redraw (or a lingering transcript quote) we still exit, never a
        # second Enter (which would submit an empty prompt).
        vstart=$(date +%s)
        while (( $(date +%s) - vstart < 2 )); do
            sleep 0.4
            pane=$("$TMUX_BIN" capture-pane -t "$session" -p 2>/dev/null) || break
            printf '%s\n' "$pane" | tail -12 | grep -q "Switch model?" || break
        done
        return 0
    done
    return 0
}

# Restart the session this script is running INSIDE (the caller), in place.
# We can't kill-session the caller — the SIGHUP would kill this very script before
# it could recreate, which strands the caller (the home-restart-from-home bug).
# Instead, set the @claude-mux-restart option and send /exit: the looped launch
# wrapper sees a clean exit with the option set and relaunches claude in this same
# pane (resume or fresh), then fires its own --await-ready handshake. The pane and
# its wrapper never go down, so RC reconnects without LaunchAgent/auto-restore.
restart_caller_in_place() {
    local session="$1" fresh="${2:-false}"
    local _val="resume"; [[ "$fresh" == "true" ]] && _val="fresh"
    restore_state_clear "$session"   # user restart un-trips crash-loop history
    if ! "$TMUX_BIN" set-option -t "$session" @claude-mux-restart "$_val" 2>/dev/null; then
        log "WARN: could not set @claude-mux-restart on caller '$session'; skipping in-place restart"
        return 1
    fi
    log "Restarting caller session '$session' in place (@claude-mux-restart=$_val); sending /exit"
    "$TMUX_BIN" send-keys -t "$session" -l "/exit" 2>/dev/null && "$TMUX_BIN" send-keys -t "$session" Enter 2>/dev/null
}

# Launch the home session via the proper path. Home is special: its model flag
# (HOME_SESSION_MODEL) is only assembled inside launch_single_session under
# HOME_LAUNCH, so home must NOT be started via create_claude_session (which would
# drop the model). Callers that want a non-attaching start set NO_ATTACH=true first
# (the -d $BASE_DIR path leaves NO_ATTACH unset so an interactive run still attaches).
launch_home_session() {
    LAUNCH_DIR="$BASE_DIR"
    HOME_LAUNCH=true
    LAUNCH_SESSION_NAME="home"
    launch_single_session
}

create_claude_session() {
    local session_name="$1"
    local working_dir="$2"
    local mode_override="${3:-}"   # optional: permission mode override
    local fresh_start="${4:-false}" # optional: skip -c to start new conversation instead of resuming

    # Create multi-coder symlinks (AGENTS.md, GEMINI.md → CLAUDE.md) so other
    # AI CLI tools see the same project instructions. Idempotent and silent
    # when not applicable. Runs before session creation so a restart picks up
    # missing symlinks too.
    setup_multi_coder_files "$working_dir"

    if "$TMUX_BIN" has-session -t "$session_name" 2>/dev/null; then
        # Collision guard: refuse to touch sessions not created by claude-mux.
        # Exception: unmanaged sessions with Claude running are claimed with a warning (v1.8 upgrade path).
        if ! is_claude_mux_session "$session_name"; then
            if claude_running_in_session "$session_name"; then
                log "WARN: Claiming non-managed session '$session_name' — Claude is running; assuming v1.8 upgrade"
            else
                log "WARN: tmux session '$session_name' exists but is not claude-mux-managed — refusing to overwrite"
                echo "WARN: tmux session '$session_name' is in use by something else." >&2
                echo "      Resolve manually: 'tmux kill-session -t $session_name' if you want claude-mux to take over." >&2
                return 1
            fi
        fi
        # Session exists — check if claude is still running inside it.
        # If the pane is at a shell prompt (claude exited), relaunch.
        if claude_running_in_session "$session_name"; then
            # Mark as claude-mux-managed (idempotent — handles v1.8 upgrades)
            [[ "$DRY_RUN" != "true" ]] && "$TMUX_BIN" set-option -t "$session_name" @claude-mux-managed 1 2>/dev/null
            [[ "$DRY_RUN" != "true" ]] && "$TMUX_BIN" set-option -t "$session_name" @claude-mux-dir "$working_dir" 2>/dev/null
            [[ "$DRY_RUN" != "true" ]] && "$TMUX_BIN" set-option -t "$session_name" @claude-mux-claude-id "$(claude_binary_id)" 2>/dev/null
            write_running_marker "$working_dir"   # backfill auto-restore marker for live sessions
            log "Session '$session_name' already running claude, skipping"
            return
        fi
        log "Session '$session_name' exists but claude is not running — relaunching"
    else
        log "Creating tmux session '$session_name' in $working_dir"
    fi

    [[ "$DRY_RUN" == "true" ]] && return

    if ! "$TMUX_BIN" has-session -t "$session_name" 2>/dev/null; then
        "$TMUX_BIN" new-session -d -s "$session_name" -c "$working_dir"
    fi

    apply_tmux_options "$session_name"
    "$TMUX_BIN" set-option -t "$session_name" @claude-mux-managed 1 2>/dev/null
    "$TMUX_BIN" set-option -t "$session_name" @claude-mux-dir "$working_dir" 2>/dev/null
    "$TMUX_BIN" set-option -t "$session_name" @claude-mux-claude-id "$(claude_binary_id)" 2>/dev/null

    # Build system prompt — pass permission mode so Claude reports it in the ready response
    local tmux_prompt
    tmux_prompt="$(build_system_prompt "$session_name" "${mode_override:-auto}")"

    # Build permission mode flags for the launch command.
    # perm_flag_name and perm_flag_value are interpolated into the generated script below.
    # They are safe because mode_override is validated against a whitelist by all callers
    # (setmode dispatch at line ~2033, DEFAULT_PERMISSION_MODE at line ~427).
    local perm_flag_name perm_flag_value
    if [[ -n "$mode_override" ]]; then
        perm_flag_name="--permission-mode"
        perm_flag_value="$mode_override"
    else
        perm_flag_name="--permission-mode"
        perm_flag_value="auto"
    fi

    # Write the launch command to a temp script to avoid quoting complexity.
    # A trap inside the script guarantees cleanup even if claude exits unexpectedly.
    # The prompt is written to a separate file to avoid any quoting issues in the heredoc.
    #
    # NOTE: session_name is stripped to [a-zA-Z0-9-] by sanitize_session_name and
    # perm_flag_value comes from a validated whitelist. (This function does not assemble or
    # interpolate the model flag — that happens only in launch_single_session; see :32. The
    # model value, when used there, is format-validated to a shell-safe token at set-time.)
    #
    # fresh_start=true omits -c so Claude Code starts a new conversation instead of resuming.
    local resume_flag="-c"
    [[ "$fresh_start" == "true" ]] && resume_flag=""
    local _launch_kind="resume"; [[ -z "$resume_flag" ]] && _launch_kind="fresh"
    local launch_script prompt_file
    launch_script=$(mktemp "${TMPDIR:-/tmp}/claude-launch-XXXXXX")
    # Prompt lives in the project folder (stable — not $TMPDIR-reaped) so a restart-in-place
    # can regenerate + re-read it; the wrapper regenerates it with the current injection on
    # each in-place relaunch (see restart-in-place). Mode 600; .claudemux-* is gitignored.
    prompt_file="$working_dir/.claudemux-prompt"
    chmod 600 "$launch_script"
    printf '%s' "$tmux_prompt" > "$prompt_file"
    chmod 600 "$prompt_file" 2>/dev/null
    # Single-quote-escape the marker/prompt paths so a project dir containing an apostrophe
    # (e.g. "Sylvia's-estate") can't break the generated single-quoted assignment.
    # Escape in a plain (unquoted) assignment: the \' pattern needs unquoted
    # parsing, and standalone assignment is not word-split, so spaces are safe too.
    local _esc_dir; _esc_dir=${working_dir//\'/\'\\\'\'}
    local _marker_esc="${_esc_dir}/.claudemux-running"
    local _prompt_esc="${_esc_dir}/.claudemux-prompt"
    # Same apostrophe-escape for the claude-mux binary path (install path could
    # contain a quote, e.g. /Users/Jon's-Mac/bin) — it's interpolated single-quoted.
    local _esc_bin; _esc_bin=${CLAUDE_MUX_BIN//\'/\'\\\'\'}
    # The launch wrapper distinguishes a resume-that-failed-to-start (retry fresh)
    # from a session that ran then crashed (leave the marker for the tick). A
    # non-zero exit within the first ~10s means resume never came up → fresh
    # fallback; a non-zero exit after that is a real crash. A clean exit (rc 0,
    # i.e. /exit or Ctrl-C ×2) removes the marker and tears down the tmux session.
    # The system prompt is passed via --append-system-prompt-file (path, not the
    # expanded text) so it is not visible in `ps`; the file is deleted after the
    # ready handshake (caller) with this trap as a backstop.
    # Keep claude a direct child of this script (no extra subshell) so
    # claude_running_in_session's 2-level check still finds it.
    cat > "$launch_script" << LAUNCH_EOF
#!/bin/bash
trap 'rm -f "${launch_script}"' EXIT
export PATH="$(dirname "$CLAUDE_BIN"):\$PATH"
_marker='${_marker_esc}'
_prompt='${_prompt_esc}'
_resume='${resume_flag}'
# Loop so a restart can relaunch claude IN THIS PANE (restart-in-place): a clean
# exit (rc 0) with the @claude-mux-restart option set means "relaunch here", not
# "tear down". This lets a restart's caller resume without an external recreate,
# which would race the pane teardown (the home-restart-from-home bug). See
# restart-in-place. The prompt is regenerated each relaunch so the injection stays current.
while true; do
    _start=\$(date +%s)
    _resume_err=\$(mktemp "\${TMPDIR:-/tmp}/claude-resume-err-XXXXXX")
    # Primary launch: capture stderr to a temp file so a failed resume can be
    # diagnosed from the log (was 2>/dev/null). The pane sees no stderr either way.
    claude \${_resume:+\$_resume }--remote-control ${perm_flag_name}${perm_flag_value:+ ${perm_flag_value}} --allow-dangerously-skip-permissions --name '${session_name}' --append-system-prompt-file "\$_prompt" 2>"\$_resume_err"
    _rc=\$?
    _elapsed=\$(( \$(date +%s) - _start ))
    if [[ \$_rc -ne 0 && \$_elapsed -lt 10 ]]; then
        # Primary launch failed fast → log why, then fall back to a fresh session.
        # stderr left visible below so a real failure also shows in the pane.
        {
            printf '[%s] Primary launch for %s failed: rc=%s after %ss; falling back to fresh session\n' "\$(date -u +%Y-%m-%dT%H:%M:%SZ)" "'${session_name}'" "\$_rc" "\$_elapsed"
            printf '  primary stderr (last 800 chars): %s\n' "\$(tr '\\n' ' ' < "\$_resume_err" | tail -c 800)"
        } >> '${LOG_FILE}'
        claude --remote-control ${perm_flag_name}${perm_flag_value:+ ${perm_flag_value}} --allow-dangerously-skip-permissions --name '${session_name}' --append-system-prompt-file "\$_prompt"
        _rc=\$?
    fi
    rm -f "\$_resume_err"
    if [[ \$_rc -eq 0 ]]; then
        # Clean exit. If a restart is pending (@claude-mux-restart set), relaunch in
        # place instead of tearing down: consume the option, pick resume/fresh,
        # regenerate the prompt with the current injection, fire the ready handshake
        # from OUTSIDE this pane (this pane is busy relaunching claude), and loop.
        _restart=\$('${TMUX_BIN}' show-option -t '${session_name}' -qv @claude-mux-restart 2>/dev/null)
        if [[ -n "\$_restart" ]]; then
            '${TMUX_BIN}' set-option -t '${session_name}' -u @claude-mux-restart 2>/dev/null
            _resume='-c'; [[ "\$_restart" == fresh ]] && _resume=''
            if '${_esc_bin}' --print-system-prompt '${session_name}' '${perm_flag_value}' > "\$_prompt.new" 2>/dev/null && [[ -s "\$_prompt.new" ]]; then
                chmod 600 "\$_prompt.new" 2>/dev/null
                mv -f "\$_prompt.new" "\$_prompt"
            else
                rm -f "\$_prompt.new"
            fi
            '${_esc_bin}' --await-ready '${session_name}' >/dev/null 2>&1 &
            continue
        fi
        # No restart pending (/exit or Ctrl-C x2): intent to stop. Remove the marker +
        # prompt + launch script BEFORE kill-session, so SIGHUP can't interrupt cleanup
        # mid-way (rm runs sequentially first; trap EXIT is a harmless backstop). Then
        # tear down the tmux session so it does not linger as a shell prompt.
        rm -f "\$_marker" "\$_prompt" '${launch_script}'
        '${TMUX_BIN}' kill-session -t '${session_name}' 2>/dev/null
        break
    fi
    # Non-zero exit (crash): leave the pane + marker (+ prompt) so the restore tick
    # resurrects it. Do not loop here — a wedged resume must not spin.
    break
done
LAUNCH_EOF
    chmod +x "$launch_script"

    # Write the auto-restore marker before launching so a crash before the first
    # clean exit still leaves intent-to-be-alive recorded.
    write_running_marker "$working_dir"

    if ! { "$TMUX_BIN" send-keys -t "$session_name" -l "bash '${launch_script}'" && "$TMUX_BIN" send-keys -t "$session_name" Enter; } 2>/dev/null; then
        log "WARN: send-keys failed for '$session_name', cleaning up temp script"
        rm -f "$launch_script" "$prompt_file"
        return
    fi

    # Wait until Claude is genuinely ready (handles the trust / bypassPermissions
    # prompts and waits out a resume-time compaction), then send "Ready?". The
    # detector keys on the "esc to interrupt" busy signal + quiescence, not the
    # mere presence of the ❯ prompt (which is drawn during compaction).
    log "Waiting for Claude to be ready in '$session_name'..."
    if ! poll_until_ready "$session_name"; then
        log "WARN: '$session_name' not confirmed ready within timeout, sending Ready? anyway"
    fi
    # The prompt file (.claudemux-prompt in the project folder) is NOT deleted here:
    # the wrapper re-reads it on every in-place restart relaunch and regenerates it
    # with the current injection. The wrapper removes it on final teardown (clean
    # /exit with no restart pending).
    "$TMUX_BIN" send-keys -t "$session_name" -l "Ready?" 2>/dev/null && "$TMUX_BIN" send-keys -t "$session_name" Enter 2>/dev/null

    # Protect at launch if .claudemux-protected marker exists in working dir
    if [[ -f "$working_dir/.claudemux-protected" ]]; then
        "$TMUX_BIN" set-option -t "$session_name" @claude-mux-protected 1 2>/dev/null
    fi

    # Delay between sessions during -a launches to avoid RC registration issues
    if [[ "$COMMAND" == "start" ]]; then
        sleep "$SLEEP_BETWEEN"
    fi
}

