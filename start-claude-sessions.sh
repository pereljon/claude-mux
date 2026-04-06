#!/bin/bash
# claude-autorc — Claude Auto Remote Control
# Automatically creates persistent tmux sessions running Claude Code with
# Remote Control for each project directory under ~/Claude/.

# ── Configuration ─────────────────────────────────────────────────────────────

# Root directory containing category and project directories.
BASE_DIR="$HOME/Claude"

# When true, create a .gitignore with common development exclusions
# if one does not already exist in the project directory
AUTO_GITIGNORE=true

# When set to a valid mode, create/update .claude/settings.local.json
# to set permissions.defaultMode for the project.
# Valid values: "" (disabled), "default", "acceptEdits", "plan", "auto", "dontAsk", "bypassPermissions"
DEFAULT_PERMISSION_MODE="auto"

# When true, each Claude session is told it can send slash commands to OTHER
# sessions via tmux send-keys. When false (default), sessions can only send
# commands to themselves — safer, prevents one session affecting others.
ALLOW_CROSS_SESSION_CONTROL=false

# ── Constants ─────────────────────────────────────────────────────────────────

SLEEP_BETWEEN=5
LOG_FILE="$BASE_DIR/startup.log"

TMUX="/opt/homebrew/bin/tmux"
CLAUDE="/opt/homebrew/bin/claude"

export PATH="/opt/homebrew/bin:$PATH"

# ── Flags ─────────────────────────────────────────────────────────────────────

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# ── Ensure base directory exists ───────────────────────────────────────────────

if [[ ! -d "$BASE_DIR" ]]; then
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] WARN: $BASE_DIR does not exist — nothing to do"
        exit 0
    fi
    mkdir -p "$BASE_DIR"
fi

# ── Discover category directories ─────────────────────────────────────────────
# Any subdir of BASE_DIR not starting with '.' or '-' is treated as a category.

CATEGORIES=()
for _dir in "$BASE_DIR"/*/; do
    _dir="${_dir%/}"
    _name="$(basename "$_dir")"
    if [[ -d "$_dir" && "$_name" != .* && "$_name" != -* ]]; then
        CATEGORIES+=("$_name")
    fi
done

# ── Startup delay (LaunchAgent only, skipped in dry-run) ──────────────────────

if [[ "$DRY_RUN" != "true" ]]; then
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] Waiting 45 seconds for system services to initialize..." >> "$LOG_FILE"
    sleep 45
fi

# ── Helpers ───────────────────────────────────────────────────────────────────

log() {
    local msg="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "$msg"
    else
        echo "$msg" >> "$LOG_FILE"
    fi
}

# ── Dependency check ──────────────────────────────────────────────────────────

if [[ ! -x "$TMUX" ]]; then
    log "ERROR: tmux not found at $TMUX — aborting"
    exit 1
fi

if [[ ! -x "$CLAUDE" ]]; then
    log "ERROR: claude not found at $CLAUDE — aborting"
    exit 1
fi

# ── Functions ─────────────────────────────────────────────────────────────────

ensure_git_repo() {
    local dir="$1"
    if [[ ! -d "$dir/.git" ]]; then
        log "Initializing git repo in $dir"
        if [[ "$DRY_RUN" != "true" ]]; then
            git init "$dir" >> "$LOG_FILE" 2>&1
        fi
    fi
}

setup_gitignore() {
    local dir="$1"
    [[ "$AUTO_GITIGNORE" != "true" ]] && return

    if [[ -f "$dir/.gitignore" ]]; then
        log "Gitignore already exists in $dir, skipping"
        return
    fi

    log "Creating .gitignore in $dir"
    [[ "$DRY_RUN" == "true" ]] && return

    cat > "$dir/.gitignore" << 'GITIGNORE_EOF'
# Secrets and credentials
.env
.env.*
!.env.example
*.pem
*.key
*.p12
*.pfx
tokens.json
credentials.json
secrets.yaml
secrets.yml

# Claude
.claude/settings.local.json

# OS
.DS_Store
Thumbs.db

# IDE
.idea/
.vscode/
*.swp
*.swo

# Dependencies
node_modules/
vendor/
__pycache__/
*.pyc
venv/
.venv/

# Build
dist/
build/
*.o
*.so
*.dylib
GITIGNORE_EOF
}

setup_default_mode() {
    local dir="$1"
    [[ -z "$DEFAULT_PERMISSION_MODE" ]] && return

    local settings_file="$dir/.claude/settings.local.json"
    log "Setting defaultMode=$DEFAULT_PERMISSION_MODE in $dir"
    [[ "$DRY_RUN" == "true" ]] && return

    mkdir -p "$dir/.claude"
    if [[ -f "$settings_file" ]]; then
        if ! /usr/bin/python3 - "$settings_file" "$DEFAULT_PERMISSION_MODE" >> "$LOG_FILE" 2>&1 << 'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f: d = json.load(f)
except (json.JSONDecodeError, OSError) as e:
    print(f"ERROR reading {sys.argv[1]}: {e}", file=sys.stderr)
    sys.exit(1)
d.setdefault('permissions', {})['defaultMode'] = sys.argv[2]
try:
    with open(sys.argv[1], 'w') as f: json.dump(d, f, indent=2)
except OSError as e:
    print(f"ERROR writing {sys.argv[1]}: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
        then
            log "WARN: Failed to merge defaultMode into $settings_file — skipping"
        fi
    else
        printf '{"permissions":{"defaultMode":"%s"}}\n' "$DEFAULT_PERMISSION_MODE" > "$settings_file"
    fi
}

detect_github_ssh_accounts() {
    # Parses ~/.ssh/config for GitHub SSH host aliases (Host github.com-*)
    # and sets GITHUB_SSH_INFO to a prompt-ready string, or empty if none found.
    GITHUB_SSH_INFO=""
    local ssh_config="$HOME/.ssh/config"
    [[ ! -f "$ssh_config" ]] && return

    local accounts=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^[Hh]ost[[:space:]]+github\.com-(.+) ]]; then
            accounts+=("${BASH_REMATCH[1]}")
        fi
    done < "$ssh_config"

    [[ "${#accounts[@]}" -eq 0 ]] && return

    local parts=()
    for account in "${accounts[@]}"; do
        parts+=("${account} (git@github.com-${account})")
    done

    # Join with ", "
    local joined
    printf -v joined '%s, ' "${parts[@]}"
    joined="${joined%, }"

    GITHUB_SSH_INFO=" GitHub SSH accounts configured in ~/.ssh/config: ${joined}. Use the host alias as the git remote, e.g. git clone git@github.com-${accounts[0]}:org/repo.git"
}

create_claude_session() {
    local session_name="$1"
    local working_dir="$2"

    if "$TMUX" has-session -t "$session_name" 2>/dev/null; then
        log "Session '$session_name' already exists, skipping"
        return
    fi

    log "Creating tmux session '$session_name' in $working_dir"

    [[ "$DRY_RUN" == "true" ]] && return

    "$TMUX" new-session -d -s "$session_name" -c "$working_dir"

    # Build system prompt; use a variable to avoid quoting complexity in send-keys
    local tmux_prompt
    if [[ "$ALLOW_CROSS_SESSION_CONTROL" == "true" ]]; then
        tmux_prompt="You are running inside tmux session '${session_name}'. You can send slash commands to yourself or any other Claude session via: /opt/homebrew/bin/tmux send-keys -t <session-name> \"/command args\" Enter. To list all sessions: /opt/homebrew/bin/tmux list-sessions. To find your own session name: /opt/homebrew/bin/tmux display-message -p '#S'.${GITHUB_SSH_INFO}"
    else
        tmux_prompt="You are running inside tmux session '${session_name}'. You can send slash commands to yourself via: /opt/homebrew/bin/tmux send-keys -t '${session_name}' \"/command args\" Enter. To find your own session name: /opt/homebrew/bin/tmux display-message -p '#S'.${GITHUB_SSH_INFO}"
    fi

    # Write the launch command to a temp script to avoid quoting complexity.
    # A trap inside the script guarantees cleanup even if claude exits unexpectedly.
    local launch_script
    launch_script=$(mktemp /tmp/claude-launch-XXXXXX.sh)
    cat > "$launch_script" << LAUNCH_EOF
#!/bin/bash
trap 'rm -f "${launch_script}"' EXIT
export PATH="/opt/homebrew/bin:\$PATH"
claude -c --rc --name '${session_name}' --append-system-prompt "${tmux_prompt}" 2>/dev/null || \
claude --rc --name '${session_name}' --append-system-prompt "${tmux_prompt}"
LAUNCH_EOF
    chmod +x "$launch_script"

    "$TMUX" send-keys -t "$session_name" "bash '${launch_script}'" Enter

    sleep "$SLEEP_BETWEEN"
}

# ── Migrate stray Claude sessions ─────────────────────────────────────────────
# Finds claude CLI processes not running inside tmux whose cwd is under a
# managed category directory, SIGTERMs them, then lets the main loop resume
# them inside tmux via claude -c.

migrate_stray_sessions() {
    [[ "$DRY_RUN" == "true" ]] && return

    local managed_dirs=()
    for cat in "${CATEGORIES[@]}"; do
        managed_dirs+=("$BASE_DIR/$cat")
    done

    local pids
    pids=$(pgrep -f "$CLAUDE" 2>/dev/null) || return 0

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

        # Get working directory — filter for 'n' (name) lines from lsof -Fn output
        local cwd
        cwd=$(lsof -p "$pid" -a -d cwd -Fn 2>/dev/null | grep '^n' | cut -c2-)
        [[ -z "$cwd" ]] && continue

        # Migrate if cwd is at or anywhere under a managed category directory
        local is_managed=false
        for managed in "${managed_dirs[@]}"; do
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

    # Wait for terminated processes to exit cleanly before creating tmux sessions
    [[ "$found_any" == "true" ]] && sleep 2
}

# ── Main ──────────────────────────────────────────────────────────────────────

log "=== start-claude-sessions.sh starting (dry-run=${DRY_RUN}) ==="

detect_github_ssh_accounts
[[ -n "$GITHUB_SSH_INFO" ]] && log "Detected GitHub SSH accounts:${GITHUB_SSH_INFO}"

if [[ "${#CATEGORIES[@]}" -eq 0 ]]; then
    log "WARN: No category directories found under $BASE_DIR — nothing to do"
    log "=== start-claude-sessions.sh complete ==="
    exit 0
fi

migrate_stray_sessions

for CATEGORY in "${CATEGORIES[@]}"; do
    CATEGORY_DIR="$BASE_DIR/$CATEGORY"

    if [[ ! -d "$CATEGORY_DIR" ]]; then
        log "WARN: $CATEGORY_DIR not found, skipping"
        continue
    fi

    ensure_git_repo "$CATEGORY_DIR"
    create_claude_session "$CATEGORY" "$CATEGORY_DIR"

    for SUBDIR in "$CATEGORY_DIR"/*/; do
        # Strip trailing slash and get basename
        SUBDIR="${SUBDIR%/}"
        dir_name="$(basename "$SUBDIR")"

        # Skip hidden dirs and dirs starting with -
        if [[ "$dir_name" == .* ]] || [[ "$dir_name" == -* ]]; then
            log "Skipping excluded directory: $SUBDIR"
            continue
        fi

        ensure_git_repo "$SUBDIR"
        setup_gitignore "$SUBDIR"
        setup_default_mode "$SUBDIR"
        create_claude_session "$dir_name" "$SUBDIR"
    done
done

log "=== start-claude-sessions.sh complete ==="
