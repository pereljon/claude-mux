# ── Functions ─────────────────────────────────────────────────────────────────

ensure_git_repo() {
    local dir="$1"
    if [[ ! -d "$dir/.git" && ! -f "$dir/.git" ]]; then
        log "Initializing git repo in $dir"
        if [[ "$DRY_RUN" != "true" ]]; then
            git init "$dir" >> "$LOG_FILE" 2>&1
        fi
    fi
}

setup_gitignore() {
    local dir="$1"
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

# Append a single line to $dir/.gitignore if missing. Only acts when $dir is
# a git-tracked project. Idempotent.
ensure_gitignore_entry() {
    local dir="$1" pattern="$2"
    [[ -d "$dir/.git" || -f "$dir/.git" ]] || return 0
    local gi="$dir/.gitignore"
    # grep -xF checks for exact literal match of pattern. If individual marker files
    # (e.g. .claudemux-protected) were added manually before the glob, both entries
    # may coexist. That is harmless — gitignore accepts redundant patterns.
    if [[ -f "$gi" ]] && grep -qxF "$pattern" "$gi" 2>/dev/null; then
        return 0
    fi
    [[ "$DRY_RUN" == "true" ]] && { log "Would add '$pattern' to $gi"; return 0; }
    printf '%s\n' "$pattern" >> "$gi"
    log "Added '$pattern' to $gi"
}

# Auto-restore marker: presence of .claudemux-running means "this session should
# be alive." Written before tmux/Claude start; removed first on clean shutdown.
# The home session never gets a marker; the LaunchAgent always starts it.
write_running_marker() {
    local dir="$1"
    [[ -z "$dir" || ! -d "$dir" ]] && return 0
    [[ "$dir" == "$BASE_DIR" ]] && return 0   # home is launch-managed, not marker-managed
    [[ "$DRY_RUN" == "true" ]] && { log "Would write $dir/.claudemux-running"; return 0; }
    touch "$dir/.claudemux-running" 2>/dev/null || return 0
    ensure_gitignore_entry "$dir" ".claudemux-*"
}

# Remove the auto-restore marker (intent to stop). Safe on a missing file.
remove_running_marker() {
    local dir="$1"
    [[ -z "$dir" ]] && return 0
    [[ "$DRY_RUN" == "true" ]] && { log "Would remove $dir/.claudemux-running"; return 0; }
    rm -f "$dir/.claudemux-running" 2>/dev/null || true
}

# ── Restore-state (crash-loop + stagger bookkeeping) ─────────────────────────────
# Central runtime state, keyed by session name, in $RESTORE_STATE_DIR/<name>.json.
# Format is a single compact line we own end-to-end:
#   {"last_attempt_ts":<epoch>,"death_count":<int>,"tripped":<true|false>}
# Reads are tolerant of a missing/garbage file (treated as fresh: ts 0, count 0,
# not tripped) so a corrupt file never crashes the tick.

restore_state_last_attempt() {
    local f="$RESTORE_STATE_DIR/$1.json"
    [[ -f "$f" ]] || { echo 0; return 0; }
    local v; v=$(grep -o '"last_attempt_ts":[0-9]*' "$f" 2>/dev/null | head -1 | cut -d: -f2)
    echo "${v:-0}"
}

restore_state_death_count() {
    local f="$RESTORE_STATE_DIR/$1.json"
    [[ -f "$f" ]] || { echo 0; return 0; }
    local v; v=$(grep -o '"death_count":[0-9]*' "$f" 2>/dev/null | head -1 | cut -d: -f2)
    echo "${v:-0}"
}

# Return 0 (true) only if the session is explicitly tripped.
restore_state_tripped() {
    local f="$RESTORE_STATE_DIR/$1.json"
    [[ -f "$f" ]] && grep -q '"tripped":true' "$f" 2>/dev/null
}

# Write all three fields atomically-ish (single line, single redirect).
restore_state_write() {
    local session="$1" ts="$2" dc="$3" tripped="$4"
    [[ "$DRY_RUN" == "true" ]] && return 0
    mkdir -p "$RESTORE_STATE_DIR" 2>/dev/null || return 0
    printf '{"last_attempt_ts":%s,"death_count":%s,"tripped":%s}\n' \
        "$ts" "$dc" "$tripped" > "$RESTORE_STATE_DIR/$session.json" 2>/dev/null || true
}

# Clear crash-loop/stagger history for a session. Called on any user-initiated
# bring-up (restart, restart fresh, setmode, -d) so a 'restart X fresh' actually
# un-trips a crash-looped session. The autonomous tick never calls this; it must
# preserve death_count to detect loops.
restore_state_clear() {
    [[ "$DRY_RUN" == "true" ]] && return 0
    rm -f "$RESTORE_STATE_DIR/$1.json" 2>/dev/null || true
}

# Resolve the launch (project-root) directory recorded on a session at creation
# via @claude-mux-dir. This is where the .claudemux-running marker lives. Falls
# back to the pane's current path for sessions created before this option existed.
# pane_current_path alone is unreliable (it tracks the foreground process cwd), so
# the stored option is authoritative for marker removal.
session_marker_dir() {
    local s="$1" d
    d=$("$TMUX_BIN" show-options -t "$s" -v @claude-mux-dir 2>/dev/null)
    [[ -n "$d" ]] && { printf '%s\n' "$d"; return 0; }
    "$TMUX_BIN" display-message -t "$s" -p '#{pane_current_path}' 2>/dev/null
}

# Single predicate shared by the restore walk and the -l status logic, so the
# listing never promises a restore the tick won't perform. A session should be
# alive if it has the auto-restore marker (AUTORESTORE on, not crash-tripped),
# or — future extension point — an always-on .claudemux-autostart marker.
should_be_alive() {
    local session="$1" dir="$2"
    [[ -n "$dir" && -f "$dir/.claudemux-autostart" ]] && return 0   # always-on (future)
    [[ "$AUTORESTORE" == "true" ]] || return 1
    [[ -n "$dir" && -f "$dir/.claudemux-running" ]] || return 1
    restore_state_tripped "$session" && return 1
    return 0
}

# Status string for a session whose Claude is NOT running, derived from the same
# state should_be_alive() uses (so -l never promises a restore the tick won't do):
#   marker + tripped            -> failed   (crash-looped, will not restore)
#   marker + AUTORESTORE on      -> queued   (the tick will bring it back)
#   marker + AUTORESTORE off      -> stopped
#   no marker                     -> fallback (stopped for active panes, idle for projects)
autorestore_status() {
    local name="$1" dir="$2" fallback="${3:-stopped}"
    if [[ -n "$dir" && -f "$dir/.claudemux-running" ]]; then
        if restore_state_tripped "$name"; then echo "failed"; return 0; fi
        [[ "$AUTORESTORE" == "true" ]] && { echo "queued"; return 0; }
        echo "stopped"; return 0
    fi
    echo "$fallback"
}

# Resolve a session name to its project directory.
# No arg: uses the calling tmux session.
# "home": always BASE_DIR.
# Running session: directory from tmux.
# Idle project: scans PROJECT_DIRS by basename match.
resolve_session_dir() {
    local name="${1:-}"
    if [[ -z "$name" ]]; then
        if [[ -n "${TMUX_PANE:-}" ]]; then
            name=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null)
        fi
        if [[ -z "$name" ]]; then
            echo "ERROR: Cannot determine current session (not inside tmux)" >&2
            return 1
        fi
    fi
    if [[ "$name" == "home" ]]; then
        echo "$BASE_DIR"
        return 0
    fi
    if "$TMUX_BIN" has-session -t "$name" 2>/dev/null; then
        local _dir
        _dir=$("$TMUX_BIN" display-message -t "$name" -p '#{pane_current_path}' 2>/dev/null)
        if [[ -n "$_dir" && -d "$_dir" ]]; then
            echo "$_dir"
            return 0
        fi
    fi
    discover_projects
    local _proj _sname
    for _proj in "${PROJECT_DIRS[@]}" "${HIDDEN_PROJECT_DIRS[@]+"${HIDDEN_PROJECT_DIRS[@]}"}"; do
        _sname=$(sanitize_session_name "$(basename "$_proj")")
        if [[ "$_sname" == "$name" ]]; then
            echo "$_proj"
            return 0
        fi
    done
    echo "ERROR: Cannot resolve session '$name'" >&2
    return 1
}

# Hide a project from claude-mux listings by creating .claudemux-ignore.
hide_command() {
    local arg="${1:-}"
    local dir
    dir=$(resolve_session_dir "$arg") || return 1

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: '$dir' is not a directory" >&2
        return 1
    fi

    local norm_dir norm_base
    norm_dir=$(cd "$dir" 2>/dev/null && pwd) || norm_dir="$dir"
    norm_base=$(cd "$BASE_DIR" 2>/dev/null && pwd) || norm_base="$BASE_DIR"
    if [[ "$norm_dir" == "$norm_base" ]]; then
        echo "ERROR: Cannot hide the home session directory" >&2
        return 1
    fi

    local marker="$dir/.claudemux-ignore"
    if [[ -f "$marker" ]]; then
        echo "Already hidden: $(basename "$dir")"
        return 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would hide: $(basename "$dir")"
        ensure_gitignore_entry "$dir" ".claudemux-*"  # handles dry-run internally
        return 0
    fi

    if ! touch "$marker"; then
        echo "ERROR: Cannot write $marker" >&2
        return 1
    fi
    ensure_gitignore_entry "$dir" ".claudemux-*"
    echo "Hidden: $(basename "$dir")"
}

# Derive the tmux session name for a given working directory.
# Special-case: $BASE_DIR is the home session. Otherwise, basename of dir.
session_name_for_dir() {
    local dir="$1"
    local norm_dir norm_base
    norm_dir=$(cd "$dir" 2>/dev/null && pwd) || norm_dir="$dir"
    norm_base=$(cd "$BASE_DIR" 2>/dev/null && pwd) || norm_base="$BASE_DIR"
    if [[ "$norm_dir" == "$norm_base" ]]; then
        echo "home"
    else
        sanitize_session_name "$(basename "$dir")"
    fi
}

# Mark a project as protected: create marker file and, if a tmux session
# for the project is currently running, also set the runtime tmux option.
protect_command() {
    local arg="${1:-}"
    local dir
    dir=$(resolve_session_dir "$arg") || return 1

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: '$dir' is not a directory" >&2
        return 1
    fi

    local marker="$dir/.claudemux-protected"
    local session
    session=$(session_name_for_dir "$dir")
    local already_protected=true

    if [[ ! -f "$marker" ]]; then
        already_protected=false
        [[ "$DRY_RUN" == "true" ]] && { echo "Would protect: $session"; return 0; }
        if ! touch "$marker"; then
            echo "ERROR: Cannot write $marker" >&2
            return 1
        fi
        ensure_gitignore_entry "$dir" ".claudemux-*"
    fi

    # Set the runtime tmux marker unconditionally (even if already_protected=true).
    # A session launched before the marker file existed won't have the runtime option set,
    # so running --protect again on an already-protected dir ensures the session is current.
    if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
        "$TMUX_BIN" set-option -t "$session" @claude-mux-protected 1 >/dev/null 2>&1
    fi

    if [[ "$already_protected" == "true" ]]; then
        echo "Already protected: $session"
    else
        echo "Protected: $session"
    fi
}

# Remove protection: delete marker file and unset runtime tmux option if present.
unprotect_command() {
    local arg="${1:-}"
    local dir
    dir=$(resolve_session_dir "$arg") || return 1

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: '$dir' is not a directory" >&2
        return 1
    fi

    local marker="$dir/.claudemux-protected"
    local session
    session=$(session_name_for_dir "$dir")
    local was_protected=false

    if [[ -f "$marker" ]]; then
        was_protected=true
        [[ "$DRY_RUN" == "true" ]] && { echo "Would unprotect: $session"; return 0; }
        if ! rm -f "$marker"; then
            echo "ERROR: Cannot remove $marker" >&2
            return 1
        fi
    fi

    # If a tmux session for this dir is currently running, also unset the runtime marker
    if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
        "$TMUX_BIN" set-option -u -t "$session" @claude-mux-protected >/dev/null 2>&1
    fi

    if [[ "$was_protected" == "true" ]]; then
        echo "Unprotected: $session"
    else
        echo "Already unprotected: $session"
    fi
}

# Move a path to the system trash. Same-filesystem move, atomic.
# Appends timestamp suffix on name collision in trash.
# macOS only in v1.9 — Linux/Windows deferred.
move_to_trash() {
    local path="$1"
    if [[ "$(uname)" != "Darwin" ]]; then
        echo "ERROR: --delete is supported only on macOS in this version" >&2
        return 1
    fi
    local trash="$HOME/.Trash"
    mkdir -p "$trash" 2>/dev/null
    local base
    base="$(basename "$path")"
    local target="$trash/$base"
    if [[ -e "$target" ]]; then
        # Append timestamp + PID to avoid collisions when two projects share a basename
        # or two deletions happen within the same second.
        target="$trash/${base}-$(date +%Y%m%d-%H%M%S)-$$"
    fi
    mv "$path" "$target"
}

# Move a project folder to the system trash. Pre-flight checks:
# - Path must resolve under $HOME (so mv to ~/.Trash is same-filesystem)
# - Refuse $HOME and $BASE_DIR
# - Honor protection unless --force
# - Shut down running session (with --force) before moving
# - Confirm via TTY prompt unless --yes (or non-TTY in conversational use)
delete_command() {
    local arg="${1:-}"
    local force="${2:-false}"
    local yes="${3:-false}"

    if [[ -z "$arg" ]]; then
        echo "ERROR: --delete requires a session name" >&2
        return 1
    fi

    local dir
    dir=$(resolve_session_dir "$arg") || return 1

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: '$dir' is not a directory" >&2
        return 1
    fi

    # Resolve to absolute path with no trailing component issues
    local abs
    abs="$(cd "$dir" && pwd)" || { echo "ERROR: Cannot resolve '$dir'" >&2; return 1; }

    # Refuse $HOME or any path not under $HOME
    if [[ "$abs" == "$HOME" ]]; then
        echo "ERROR: refusing to delete \$HOME" >&2
        return 1
    fi
    case "$abs/" in
        "$HOME"/*) ;;
        *)
            echo "ERROR: --delete supports only projects under \$HOME ($HOME)." >&2
            echo "       Path '$abs' is outside. Use Finder or rm manually." >&2
            return 1 ;;
    esac

    # Refuse $BASE_DIR
    local base_abs
    base_abs="$(cd "$BASE_DIR" 2>/dev/null && pwd)" || base_abs="$BASE_DIR"
    if [[ "$abs" == "$base_abs" ]]; then
        echo "ERROR: refusing to delete base directory ($BASE_DIR)" >&2
        return 1
    fi

    # Honor protection
    local marker="$abs/.claudemux-protected"
    if [[ -f "$marker" && "$force" != "true" ]]; then
        echo "ERROR: Project is protected (.claudemux-protected exists). Use --force to delete." >&2
        return 1
    fi

    local session
    session=$(session_name_for_dir "$abs")

    # Confirm if TTY and not --yes
    if [[ -t 0 && "$yes" != "true" ]]; then
        printf "Move project '%s' to trash? [y/N] " "$(basename "$abs")"
        local response
        read -r response
        case "$response" in
            y|Y|yes|YES) ;;
            *) echo "Aborted."; return 1 ;;
        esac
    fi

    [[ "$DRY_RUN" == "true" ]] && { echo "Would delete: $abs"; return 0; }

    # Shut down running session (force=true, since we're proceeding with destructive action)
    if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
        log "Shutting down session '$session' before deleting project"
        shutdown_single_session "$session" "true" >/dev/null 2>&1 || true
        # Brief wait for tmux to release the path
        sleep 1
    fi

    if move_to_trash "$abs"; then
        echo "Moved to trash: $abs"
    else
        echo "ERROR: Failed to move to trash" >&2
        return 1
    fi
}

# Restore visibility of a project by removing .claudemux-ignore.
show_command() {
    local arg="${1:-}"
    local dir
    dir=$(resolve_session_dir "$arg") || return 1

    if [[ ! -d "$dir" ]]; then
        echo "ERROR: '$dir' is not a directory" >&2
        return 1
    fi

    local marker="$dir/.claudemux-ignore"
    if [[ ! -f "$marker" ]]; then
        echo "Already visible: $(basename "$dir")"
        return 0
    fi

    [[ "$DRY_RUN" == "true" ]] && { echo "Would show: $(basename "$dir")"; return 0; }

    if ! rm -f "$marker"; then
        echo "ERROR: Cannot remove $marker" >&2
        return 1
    fi
    echo "Showing: $(basename "$dir")"
}

setup_default_mode() {
    local dir="$1"
    [[ -z "$DEFAULT_PERMISSION_MODE" ]] && return

    local settings_file="$dir/.claude/settings.local.json"

    # Skip if already set to the desired value (avoid spurious file touches)
    if [[ -f "$settings_file" ]]; then
        local current
        current=$(/usr/bin/python3 -c "
import json, sys
try:
    with open(sys.argv[1]) as f: d = json.load(f)
    print(d.get('permissions', {}).get('defaultMode', ''))
except: pass
" "$settings_file" 2>/dev/null)
        if [[ "$current" == "$DEFAULT_PERMISSION_MODE" ]]; then
            return
        fi
    fi

    log "Setting defaultMode=$DEFAULT_PERMISSION_MODE in $dir"
    [[ "$DRY_RUN" == "true" ]] && return

    if ! mkdir -p "$dir/.claude" 2>/dev/null; then
        log "WARN: Cannot create $dir/.claude — skipping defaultMode setup"
        return
    fi
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

setup_claude_mux_permissions() {
    local dir="$1"
    local is_home="${2:-false}"
    local settings_file="$dir/.claude/settings.local.json"
    local mux_dir="$HOME/.claude-mux"

    # The UserPromptSubmit --on-prompt hook serves both the daily tip and the
    # update notice, so it is registered when either feature is enabled.
    local hook_enabled="false"
    if [[ "${TIP_OF_DAY:-true}" == "true" || "${UPDATE_CHECK:-true}" == "true" ]]; then
        hook_enabled="true"
    fi

    # Check if expected rules and hooks already exist
    if [[ -f "$settings_file" ]]; then
        if /usr/bin/python3 - "$settings_file" "$is_home" "$mux_dir" "$hook_enabled" 2>/dev/null <<'PYEOF'
import json, sys
try:
    with open(sys.argv[1]) as f: d = json.load(f)
except Exception: sys.exit(1)
is_home = sys.argv[2] == 'true'
mux_dir = sys.argv[3]
hook_enabled = sys.argv[4] == 'true'
perms = d.get('permissions', {})
allow = perms.get('allow', [])
if not any('claude-mux' in r for r in allow):
    sys.exit(1)
if is_home:
    expected = [f'Read({mux_dir}/**)', f'Edit({mux_dir}/**)', f'Write({mux_dir}/**)']
    if not all(r in allow for r in expected):
        sys.exit(1)
    if mux_dir not in perms.get('additionalDirectories', []):
        sys.exit(1)
hooks = d.get('hooks', {})
# Legacy Stop --tipotd hook must be gone (replaced in v1.15.0)
if any(
    any(h.get('command', '').endswith('--tipotd') for h in entry.get('hooks', []))
    for entry in hooks.get('Stop', [])
):
    sys.exit(1)
# UserPromptSubmit --on-prompt hook must match desired state
has_hook = any(
    any(h.get('command', '').endswith('--on-prompt') for h in entry.get('hooks', []))
    for entry in hooks.get('UserPromptSubmit', [])
)
if hook_enabled != has_hook:
    sys.exit(1)
# PreCompact --on-compact hook must always be present
has_compact_hook = any(
    any(h.get('command', '').endswith('--on-compact') for h in entry.get('hooks', []))
    for entry in hooks.get('PreCompact', [])
)
if not has_compact_hook:
    sys.exit(1)
sys.exit(0)
PYEOF
        then
            return 0  # already configured for this scope
        fi
    fi

    log "Adding claude-mux permissions to $dir (home=$is_home)"
    # Return 10 = "made (or would make) changes"; 0 = already current; 1 = error.
    # Callers that don't care ignore $?; install_hooks_command tallies on it.
    [[ "$DRY_RUN" == "true" ]] && return 10

    if ! mkdir -p "$dir/.claude" 2>/dev/null; then
        log "WARN: Cannot create $dir/.claude — skipping permissions setup"
        return 1
    fi

    # Build rule set, merge into existing settings (or create fresh).
    # Bash rules: bare name (when Claude runs `claude-mux ...` from PATH) and
    # absolute path (when injection or scripts use the full path).
    # Home rules: file-system access for ~/.claude-mux/** so the home session
    # can manage its own config and templates.
    if ! /usr/bin/python3 - "$settings_file" "$CLAUDE_MUX_BIN" "$is_home" "$mux_dir" "$hook_enabled" >> "$LOG_FILE" 2>&1 <<'PYEOF'
import json, sys, os
path = sys.argv[1]
b = sys.argv[2]
is_home = sys.argv[3] == 'true'
mux_dir = sys.argv[4]
hook_enabled = sys.argv[5] == 'true'

if os.path.exists(path):
    try:
        with open(path) as f: d = json.load(f)
    except Exception as e:
        print(f"ERROR reading {path}: {e}", file=sys.stderr)
        sys.exit(1)
else:
    d = {}

new_rules = ['Bash(claude-mux)', 'Bash(claude-mux *)', f'Bash({b})', f'Bash({b} *)']
if is_home:
    new_rules += [f'Read({mux_dir}/**)', f'Edit({mux_dir}/**)', f'Write({mux_dir}/**)']

perms = d.setdefault('permissions', {})
allow = perms.setdefault('allow', [])
for rule in new_rules:
    if rule not in allow:
        allow.append(rule)

if is_home:
    additional = perms.setdefault('additionalDirectories', [])
    if mux_dir not in additional:
        additional.append(mux_dir)

hooks = d.setdefault('hooks', {})

# Remove the legacy tip-of-the-day Stop hook (replaced in v1.15.0).
stop_hooks = hooks.get('Stop', [])
new_stop = [
    entry for entry in stop_hooks
    if not any(h.get('command', '').endswith('--tipotd') for h in entry.get('hooks', []))
]
if new_stop:
    hooks['Stop'] = new_stop
else:
    hooks.pop('Stop', None)

# UserPromptSubmit --on-prompt hook (daily tip + update notice).
up_hooks = hooks.setdefault('UserPromptSubmit', [])
hook_cmd = f'{b} --on-prompt'
has_hook = any(
    any(h.get('command', '').endswith('--on-prompt') for h in entry.get('hooks', []))
    for entry in up_hooks
)
if hook_enabled and not has_hook:
    up_hooks.append({
        'hooks': [{'type': 'command', 'command': hook_cmd, 'timeout': 5}]
    })
elif not hook_enabled and has_hook:
    hooks['UserPromptSubmit'] = [
        entry for entry in up_hooks
        if not any(h.get('command', '').endswith('--on-prompt') for h in entry.get('hooks', []))
    ]

# PreCompact --on-compact hook (RC reconnect after compact). Always-on.
pc_hooks = hooks.setdefault('PreCompact', [])
compact_cmd = f'{b} --on-compact'
has_compact_hook = any(
    any(h.get('command', '').endswith('--on-compact') for h in entry.get('hooks', []))
    for entry in pc_hooks
)
if not has_compact_hook:
    pc_hooks.append({
        'hooks': [{'type': 'command', 'command': compact_cmd, 'timeout': 10}]
    })

# Drop emptied hook lists / hooks key.
for key in ('Stop', 'UserPromptSubmit', 'PreCompact'):
    if key in hooks and not hooks[key]:
        del hooks[key]
if not hooks:
    del d['hooks']

try:
    with open(path, 'w') as f: json.dump(d, f, indent=2)
except OSError as e:
    print(f"ERROR writing {path}: {e}", file=sys.stderr)
    sys.exit(1)
PYEOF
    then
        log "WARN: Failed to write claude-mux permissions to $settings_file"
        return 1
    fi
    return 10
}

# Create symlinks (e.g. AGENTS.md, GEMINI.md) pointing at CLAUDE.md so other
# AI CLI coders pick up the same project instructions. Idempotent: skips
# targets that already exist (real file or correct symlink). Silent if
# CLAUDE.md is missing or MULTI_CODER_FILES is empty.
setup_multi_coder_files() {
    local dir="$1"

    # Skip if --no-multi-coder was passed for this -n invocation
    [[ "$NO_MULTI_CODER" == "true" ]] && return

    # Skip if user disabled in config
    [[ -z "$MULTI_CODER_FILES" ]] && return

    # Skip if there's no canonical CLAUDE.md to link to
    [[ ! -e "$dir/CLAUDE.md" ]] && return

    local target
    for target in $MULTI_CODER_FILES; do
        local target_path="$dir/$target"

        # Already a symlink pointing at CLAUDE.md — idempotent skip
        if [[ -L "$target_path" ]]; then
            local current_target
            current_target=$(readlink "$target_path")
            if [[ "$current_target" == "CLAUDE.md" ]]; then
                continue
            fi
            # Wrong target or broken symlink — leave alone, don't surprise user
            log "Skipping $target in $dir: existing symlink points elsewhere ($current_target)"
            continue
        fi

        # Real file already exists — don't overwrite
        if [[ -e "$target_path" ]]; then
            continue
        fi

        # Create the symlink
        if [[ "$DRY_RUN" == "true" ]]; then
            log "Would create symlink $target → CLAUDE.md in $dir"
            continue
        fi

        if (cd "$dir" && ln -s CLAUDE.md "$target") 2>/dev/null; then
            log "Created $target → CLAUDE.md symlink in $dir"
        else
            log "WARN: Failed to create $target symlink in $dir"
        fi
    done
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

    GITHUB_SSH_INFO=" GitHub SSH accounts configured in ~/.ssh/config: ${joined}. Use the host alias as the git remote, e.g. git clone git@github.com-${accounts[0]}:org/repo.git. For gh CLI operations (repo create, PR create, etc.), run \`gh auth switch --user <account>\` first to target the correct GitHub account. Before any gh command, check \`gh auth status\` to verify the active account matches the repo's remote."
}

# Wait until a session is genuinely ready for input, not merely showing the ❯
# prompt. A session is BUSY whenever the bottom status lines contain "esc to
# interrupt" — present for a full turn AND a resume-time auto-compaction (which
# can run ~50s with the ❯ already drawn). Ready = not busy, prompt present, and
# quiescent (two captures ≥1.1s apart identical after trailing-whitespace
# normalize). Quiescence is the version-proof backstop: a working screen animates
# (glyph + timer + token counter), so snapshots differ even if the string check
# is ever defeated. Auto-accepts the trust / bypassPermissions prompts, gated to
# before ready. Returns 0 when ready, 1 on timeout (~120s; compaction measured ~50s).
poll_until_ready() {
    local session="$1" timeout="${2:-120}"
    local start pane snap1 snap2
    start=$(date +%s)
    while :; do
        (( $(date +%s) - start >= timeout )) && return 1
        sleep 0.5
        pane=$("$TMUX_BIN" capture-pane -t "$session" -p 2>/dev/null) || continue
        # Pre-ready auto-accepts (the user's own projects). Scope to the bottom of
        # the pane so matching text in transcript history can't trigger a spurious
        # keypress during a long resume.
        local pane_tail
        pane_tail=$(echo "$pane" | tail -6)
        if echo "$pane_tail" | grep -q "Yes, I trust this folder"; then
            log "Auto-accepting trust prompt for '$session'"
            "$TMUX_BIN" send-keys -t "$session" Enter
            sleep 2
            continue   # a bypassPermissions warning may follow immediately
        fi
        # bypassPermissions warning: "No, exit" (selected) + "Yes, I accept". Send
        # Down to option 2, wait 1s for the UI to register, then Enter.
        if echo "$pane_tail" | grep -qi "yes.*accept"; then
            log "Auto-accepting bypassPermissions warning for '$session'"
            "$TMUX_BIN" send-keys -t "$session" Down
            sleep 1
            "$TMUX_BIN" send-keys -t "$session" Enter
            sleep 2
            continue
        fi
        # Busy? Scope the scan to the bottom 4 lines so transcript body can't match.
        echo "$pane" | tail -4 | grep -q "esc to interrupt" && continue
        # Prompt drawn at line start?
        echo "$pane" | grep -qE '^❯|^> ' || continue
        # Quiescence: confirm with a second capture ≥1.1s later, both normalized.
        snap1=$(printf '%s' "$pane" | sed 's/[[:space:]]*$//')
        sleep 1.2
        snap2=$("$TMUX_BIN" capture-pane -t "$session" -p 2>/dev/null) || continue   # capture failed → retry
        snap2=$(printf '%s' "$snap2" | sed 's/[[:space:]]*$//')
        echo "$snap2" | tail -4 | grep -q "esc to interrupt" && continue   # became busy again
        # Require non-empty + identical, so two failed/empty captures can't read as ready.
        [[ -n "$snap1" && "$snap1" == "$snap2" ]] && return 0
    done
}

