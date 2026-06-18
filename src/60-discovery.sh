# ── Migrate stray Claude sessions ─────────────────────────────────────────────
# Finds claude CLI processes not running inside tmux whose cwd is under a
# managed project directory, SIGTERMs them, then lets the main loop resume
# them inside tmux via claude -c.

migrate_stray_sessions() {
    [[ "$DRY_RUN" == "true" ]] && return

    local pids
    pids=$(pgrep -f "$CLAUDE_BIN" 2>/dev/null) || return 0

    local found_any=false

    while IFS= read -r pid; do
        [[ -z "$pid" ]] && continue

        # Walk the process ancestor chain looking for tmux
        local check_pid="$pid"
        local in_tmux=false
        while [[ "$check_pid" -gt 1 ]]; do
            local parent_cmd
            parent_cmd=$(ps -o comm= -p "$check_pid" 2>/dev/null) || break
            if [[ "$parent_cmd" == tmux* ]]; then
                in_tmux=true
                break
            fi
            check_pid=$(ps -o ppid= -p "$check_pid" 2>/dev/null | tr -d ' ') || break
        done

        [[ "$in_tmux" == "true" ]] && continue

        # Get working directory
        local cwd
        cwd=$(lsof -p "$pid" -a -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-)
        [[ -z "$cwd" ]] && continue

        # Migrate if cwd matches any discovered project directory
        local is_managed=false
        for managed in "${PROJECT_DIRS[@]}"; do
            if [[ "$cwd" == "$managed" || "$cwd" == "$managed/"* ]]; then
                is_managed=true
                break
            fi
        done

        [[ "$is_managed" != "true" ]] && continue

        log "Migrating stray claude session (pid=$pid, cwd=$cwd) → will resume in tmux"
        kill -TERM "$pid" 2>/dev/null
        found_any=true
    done <<< "$pids"

    [[ "$found_any" == "true" ]] && sleep 2
}

# ── Discover Claude projects ──────────────────────────────────────────────────
# Finds all directories under BASE_DIR that contain a .claude/ subdirectory.
# Skips directories whose name starts with '-' and directories containing
# .claudemux-ignore. Hidden directories (starting with '.') are pruned
# from the search tree.

discover_projects() {
    PROJECT_DIRS=()
    HIDDEN_PROJECT_DIRS=()
    [[ ! -d "$BASE_DIR" ]] && return

    while IFS= read -r claude_dir; do
        [[ -z "$claude_dir" ]] && continue
        local project_dir
        project_dir="$(dirname "$claude_dir")"

        # Skip BASE_DIR itself if it has .claude
        [[ "$project_dir" == "$BASE_DIR" ]] && continue

        # Skip if directory name starts with -
        local dir_name
        dir_name="$(basename "$project_dir")"
        [[ "$dir_name" == -* ]] && continue

        # Hidden via .claudemux-ignore: separated into HIDDEN_PROJECT_DIRS
        if [[ -f "$project_dir/.claudemux-ignore" ]]; then
            HIDDEN_PROJECT_DIRS+=("$project_dir")
            continue
        fi

        PROJECT_DIRS+=("$project_dir")
    done < <(find "$BASE_DIR" -name ".*" -not -name ".claude" -prune -o -name "-*" -prune -o -name ".claude" -type d -print 2>/dev/null | sort)
}

# ── Ensure base directory exists ───────────────────────────────────────────────

ensure_base_dir() {
    if [[ ! -d "$BASE_DIR" ]]; then
        if [[ "$DRY_RUN" == "true" ]]; then
            log "WARN: $BASE_DIR does not exist — nothing to do"
            exit 0
        fi
        mkdir -p "$BASE_DIR"
    fi
}

