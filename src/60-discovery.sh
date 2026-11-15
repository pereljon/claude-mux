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

# ── Ignored folder prefixes ───────────────────────────────────────────────────
# Sets IGNORE_NAME_TESTS to `-o -name 'c*'` per IGNORE_PATH_PREFIXES character,
# for appending inside a find \( ... \) -prune group. Empty when none are set.

build_ignore_name_tests() {
    IGNORE_NAME_TESTS=()
    local i
    for (( i = 0; i < ${#IGNORE_PATH_PREFIXES}; i++ )); do
        IGNORE_NAME_TESTS+=(-o -name "${IGNORE_PATH_PREFIXES:$i:1}*")
    done
}

# ── Discover Claude projects ──────────────────────────────────────────────────
# Finds all directories under BASE_DIR that contain a .claude/ subdirectory.
# Skips directories whose name starts with an IGNORE_PATH_PREFIXES character,
# with everything below them, and directories containing .claudemux-ignore.
# Hidden directories (starting with '.') are pruned from the search tree.

discover_projects() {
    PROJECT_DIRS=()
    HIDDEN_PROJECT_DIRS=()
    [[ ! -d "$BASE_DIR" ]] && return
    build_ignore_name_tests

    while IFS= read -r claude_dir; do
        [[ -z "$claude_dir" ]] && continue
        local project_dir
        project_dir="$(dirname "$claude_dir")"

        # Skip BASE_DIR itself if it has .claude
        [[ "$project_dir" == "$BASE_DIR" ]] && continue

        # Hidden via .claudemux-ignore: separated into HIDDEN_PROJECT_DIRS
        if [[ -f "$project_dir/.claudemux-ignore" ]]; then
            HIDDEN_PROJECT_DIRS+=("$project_dir")
            continue
        fi

        PROJECT_DIRS+=("$project_dir")
    done < <(find "$BASE_DIR" -mindepth 1 -name ".*" -not -name ".claude" -prune -o \( -false "${IGNORE_NAME_TESTS[@]}" \) -prune -o -name ".claude" -type d -print 2>/dev/null | sort)
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

