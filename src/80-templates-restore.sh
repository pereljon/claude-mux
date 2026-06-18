list_templates() {
    echo_hint
    if [[ ! -d "$TEMPLATES_DIR" ]]; then
        echo "No templates directory at $TEMPLATES_DIR"
        return
    fi
    local found=false
    for tpl in "$TEMPLATES_DIR"/*.md; do
        [[ ! -f "$tpl" ]] && continue
        local name
        name="$(basename "$tpl")"
        [[ "$name" == "none.md" ]] && continue
        found=true
        if [[ "$name" == "$DEFAULT_TEMPLATE" ]]; then
            printf "  * %s  (default)\n" "$name"
        else
            printf "    %s\n" "$name"
        fi
    done
    if [[ "$found" != "true" ]]; then
        echo "No templates found in $TEMPLATES_DIR"
    fi
    echo_hint_end
}

apply_template() {
    local dir="$1"

    # Skip if --no-template
    [[ "$NO_TEMPLATE" == "true" ]] && return

    # Skip if CLAUDE.md already exists
    if [[ -f "$dir/CLAUDE.md" ]]; then
        log "CLAUDE.md already exists in $dir, skipping template"
        return
    fi

    # Determine which template to use
    local tpl_name="${TEMPLATE_NAME:-$DEFAULT_TEMPLATE}"
    [[ -z "$tpl_name" ]] && return

    local tpl_path="$TEMPLATES_DIR/$tpl_name"

    # Ensure .md extension
    [[ "$tpl_name" != *.md ]] && tpl_path="${tpl_path}.md"
    [[ "$tpl_name" != *.md ]] && tpl_name="${tpl_name}.md"

    # Guard against path traversal (e.g. --template ../../sensitive-file)
    local _real_tpl _real_tmpldir
    _real_tmpldir="$(cd "$TEMPLATES_DIR" 2>/dev/null && pwd -P)"
    _real_tpl="$(cd "$(dirname "$tpl_path")" 2>/dev/null && pwd -P)/$(basename "$tpl_path")"
    if [[ -z "$_real_tmpldir" || "$_real_tpl" != "$_real_tmpldir/"* ]]; then
        if [[ -n "$TEMPLATE_NAME" ]]; then
            echo "ERROR: Template '$tpl_name' resolves outside templates directory" >&2
            exit 1
        fi
        log "WARN: Template '$tpl_name' resolves outside TEMPLATES_DIR — skipping"
        return
    fi

    if [[ ! -f "$tpl_path" ]]; then
        if [[ -n "$TEMPLATE_NAME" ]]; then
            echo "ERROR: Template '$tpl_name' not found. Run --list-templates to see available templates." >&2
            exit 1
        fi
        log "WARN: Template '$tpl_name' not found at $tpl_path — skipping"
        return
    fi

    # Skip empty templates
    if [[ ! -s "$tpl_path" ]]; then
        return
    fi

    log "Applying template '$tpl_name' to $dir/CLAUDE.md"
    [[ "$DRY_RUN" != "true" ]] && cp "$tpl_path" "$dir/CLAUDE.md"
}

create_new_project() {
    log "=== claude-mux new project: $NEW_PROJECT_DIR ==="

    # Create directory or error
    if [[ ! -d "$NEW_PROJECT_DIR" ]]; then
        if [[ "$NEW_CREATE_PARENTS" != "true" ]]; then
            echo "ERROR: Directory does not exist: $NEW_PROJECT_DIR" >&2
            echo "Use -p to create the directory and any missing parents." >&2
            exit 1
        fi
        log "Creating directory $NEW_PROJECT_DIR"
        if [[ "$DRY_RUN" != "true" ]]; then
            mkdir -p "$NEW_PROJECT_DIR"
        fi
    fi

    # Initialize git repo and gitignore (unless --no-git)
    if [[ "$NO_GIT" != "true" ]]; then
        ensure_git_repo "$NEW_PROJECT_DIR"
        setup_gitignore "$NEW_PROJECT_DIR"
    else
        log "Skipping git init (--no-git)"
    fi

    # Apply CLAUDE.md template
    apply_template "$NEW_PROJECT_DIR"

    # Set permission mode (unless --no-permission-mode)
    if [[ "$NO_PERMISSION_MODE" != "true" ]]; then
        setup_default_mode "$NEW_PROJECT_DIR"
    else
        log "Skipping permission mode (--no-permission-mode)"
    fi

    # Always set claude-mux permissions regardless of --no-permission-mode
    local _new_is_home=false
    [[ "$NEW_PROJECT_DIR" == "$BASE_DIR" ]] && _new_is_home=true
    setup_claude_mux_permissions "$NEW_PROJECT_DIR" "$_new_is_home"

    if [[ "$DRY_RUN" == "true" ]]; then
        log "Dry run — skipping session creation and attach for '$NEW_SESSION_NAME'"
        return
    fi

    detect_github_ssh_accounts
    create_claude_session "$NEW_SESSION_NAME" "$NEW_PROJECT_DIR"

    if [[ "$NO_ATTACH" == "true" ]]; then
        log "Session '$NEW_SESSION_NAME' created (--no-attach)"
    else
        attach_to_session "$NEW_SESSION_NAME"
    fi
}

# Best-effort one-line notice to the home session. Only injected when home is at
# an input prompt, so a busy home session is never interrupted; otherwise the log
# (and the 'failed' status in -l) is the durable surface. Robust delivery is a
# v2.2 (inter-agent messaging) concern; this is the lean v2.0 stand-in.
notify_home() {
    local msg="$1"
    log "NOTICE (home): $msg"
    [[ "$DRY_RUN" == "true" ]] && return 0
    "$TMUX_BIN" has-session -t home 2>/dev/null || return 0
    local _pane
    _pane=$("$TMUX_BIN" capture-pane -t home -p 2>/dev/null | tail -5)
    echo "$_pane" | grep -qE '^❯|^> ' || return 0   # only if home looks idle
    "$TMUX_BIN" send-keys -t home -l "[claude-mux] $msg" 2>/dev/null \
        && "$TMUX_BIN" send-keys -t home Enter 2>/dev/null
}

# Restore walk: relaunch sessions that should be alive but whose Claude has died
# (reboot recovery and mid-day-crash watchdog are the same mechanism, differing
# only in when the tick fires). Pure bash; runs after the home session is up.
# Staggered so a reboot doesn't relaunch everything at once.
autorestore_walk() {
    [[ "$AUTORESTORE" == "true" ]] || return 0   # nothing to act on

    discover_projects
    local now; now=$(date +%s)

    local candidates=() in_flight=0
    local _proj _name _la
    for _proj in "${PROJECT_DIRS[@]}" "${HIDDEN_PROJECT_DIRS[@]+"${HIDDEN_PROJECT_DIRS[@]}"}"; do
        _name=$(sanitize_session_name "$(basename "$_proj")")
        [[ -z "$_name" || "$_name" == "home" ]] && continue

        # Restart-in-flight marker: an intentional restart is mid-flight (or crashed).
        # Consume-on-sight: remove the marker and defer this session for one tick. If
        # the restart finished, next tick sees Claude running and does nothing; if it
        # crashed, the preserved .claudemux-running marker lets next tick recover it.
        if [[ -d "$_proj/.claudemux-restarting" ]]; then
            rmdir "$_proj/.claudemux-restarting" 2>/dev/null
            log "Auto-restore: skipping '$_name' this tick (restart in flight)"
            continue
        fi

        # In-flight: any tracked session attempted within the window counts toward
        # the concurrency cap, so successive ticks drain the backlog gradually.
        _la=$(restore_state_last_attempt "$_name")
        (( now - _la < STARTING_WINDOW )) && (( in_flight++ ))

        # Carry last_attempt in the entry so the launch loop need not re-read it.
        # name is sanitized [a-zA-Z0-9-] and _la is numeric, so '|' only delimits
        # those two; the project dir is the middle field.
        if should_be_alive "$_name" "$_proj" && ! claude_running_in_session "$_name"; then
            candidates+=("${_name}|${_proj}|${_la}")
        fi
    done

    [[ ${#candidates[@]} -eq 0 ]] && return 0

    local slots=$(( STAGGER_CONCURRENCY - in_flight ))
    (( slots <= 0 )) && { log "Auto-restore: ${#candidates[@]} session(s) down, all stagger slots in flight, deferring"; return 0; }

    # Deterministic (sorted) order so behavior is reproducible across ticks.
    local sorted
    sorted=$(printf '%s\n' "${candidates[@]}" | sort)

    local launched=0 entry name rest dir last dc uptime
    while IFS= read -r entry; do
        [[ -z "$entry" ]] && continue
        (( launched >= slots )) && break
        name="${entry%%|*}"
        rest="${entry#*|}"
        dir="${rest%|*}"
        last="${rest##*|}"

        # Crash-loop guard: judge survival since our last attempt. A death within
        # MIN_HEALTHY of the last launch is a fast death (count it); surviving
        # longer resets the counter. After a reboot last_attempt is stale (large
        # uptime), and on a first-ever attempt there's no state file (0), so
        # neither case trips on legitimate boot recovery.
        dc=$(restore_state_death_count "$name")
        if (( last > 0 )); then
            uptime=$(( now - last ))
            if (( uptime < AUTORESTORE_MIN_HEALTHY )); then
                dc=$(( dc + 1 ))
            else
                dc=0
            fi
        fi

        if (( dc >= AUTORESTORE_TRIP_THRESHOLD )); then
            # Trip: stop restoring, keep the marker, surface it. should_be_alive()
            # now returns false for this session, so it drops out next tick (one
            # notice only). last_attempt is preserved for diagnostics.
            restore_state_write "$name" "$last" "$dc" "true"
            log "Auto-restore: '$name' crash-looped ${dc}x — tripped, will not relaunch"
            notify_home "Session '$name' crash-looped ${dc}x and was stopped. Likely a poisoned transcript; say 'restart $name fresh' to recover."
            continue
        fi

        restore_state_write "$name" "$now" "$dc" "false"
        log "Auto-restore: relaunching '$name' ($dir)"
        create_claude_session "$name" "$dir" "" false
        (( launched++ ))
    done <<< "$sorted"

    log "Auto-restore: launched $launched of ${#candidates[@]} down session(s) this tick"
}

# Autolaunch dispatches to the appropriate command based on LAUNCHAGENT_MODE.
# This is invoked by the LaunchAgent plist at login.
autolaunch_dispatch() {
    case "$LAUNCHAGENT_MODE" in
        none)
            log "LaunchAgent autolaunch: LAUNCHAGENT_MODE=none — exiting"
            # Self-healing: if the plist is still installed with KeepAlive, unload it to
            # stop recurring invocations. User can re-enable by running claude-mux --install.
            local _plist="$HOME/Library/LaunchAgents/com.user.claude-mux.plist"
            if [[ -f "$_plist" ]]; then
                log "LAUNCHAGENT_MODE=none but plist still installed — unloading to stop recurring invocations"
                launchctl unload "$_plist" 2>/dev/null || true
            fi
            ;;
        home)
            log "LaunchAgent autolaunch: starting home session"
            NO_ATTACH=true
            launch_home_session
            # After home is up, restore any other sessions that should be alive
            # but whose Claude has died (reboot recovery + mid-day watchdog).
            autorestore_walk
            ;;
    esac
}
