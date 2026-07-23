# ── Helpers ───────────────────────────────────────────────────────────────────

log() {
    local msg="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1"
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "$msg"
    else
        # Logging is best-effort and MUST NOT abort the caller. $LOG_DIR defaults to
        # the macOS log location (~/Library/Logs), which may be absent on Linux/CI or
        # a wiped macOS Logs dir — so ensure the parent dir exists and tolerate any
        # write failure rather than propagating a non-zero exit out of a command.
        mkdir -p "$(dirname "$LOG_FILE")" 2>/dev/null || true
        # Enforce 600 on log file if it is newly created
        if [[ ! -f "$LOG_FILE" ]]; then
            touch "$LOG_FILE" 2>/dev/null && chmod 600 "$LOG_FILE" 2>/dev/null
        fi
        echo "$msg" >> "$LOG_FILE" 2>/dev/null || true
        # Mirror to stdout when running interactively in a terminal
        [[ -t 1 ]] && echo "$msg"
    fi
    # Always succeed: logging must never affect control flow. Without this, the
    # trailing `[[ -t 1 ]] && echo` returns 1 whenever stdout is not a TTY (e.g. CI,
    # pipes), which would abort any caller running under `set -e`.
    return 0
}

# Returns true (0) if $1 > $2 using semantic versioning.
# Only handles numeric MAJOR.MINOR.PATCH. Pre-release suffixes (e.g. 1.7.0-rc.1)
# are not supported and will compare incorrectly — this is acceptable since we
# don't publish pre-release tags to GitHub releases.
version_gt() {
    local IFS=.
    local -a v1=($1) v2=($2)
    local i
    for ((i=0; i<${#v1[@]} || i<${#v2[@]}; i++)); do
        local a="${v1[i]:-0}" b="${v2[i]:-0}"
        if (( a > b )); then return 0; fi
        if (( a < b )); then return 1; fi
    done
    return 1  # equal
}

# Check GitHub releases for a newer version (cached, non-blocking)
check_for_update() {
    [[ "${UPDATE_CHECK:-true}" != "true" ]] && return
    [[ ! -t 1 ]] && return  # only on interactive TTY

    local config_dir="$HOME/.claude-mux"
    local cache="$config_dir/.update-check"
    local now
    now=$(date +%s)
    local last_check=0 latest="" last_notify=0

    if [[ -f "$cache" ]]; then
        read -r last_check latest last_notify < "$cache" 2>/dev/null || true
    fi

    # Check API at most once per day (86400 seconds)
    if (( now - last_check > 86400 )); then
        local prev_latest="$latest"
        local api_response
        api_response=$(curl -sf --max-time 3 \
            "https://api.github.com/repos/pereljon/claude-mux/releases/latest" 2>/dev/null) || return
        latest=$(echo "$api_response" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' | head -1)
        [[ -z "$latest" ]] && return
        last_check=$now
        # Reset notify timer if API returned a different version than what was cached
        if [[ "$latest" != "$prev_latest" ]]; then
            last_notify=0
        fi
        echo "$last_check $latest $last_notify" > "$cache"
    fi

    # Nothing to notify
    [[ -z "$latest" || "$latest" == "$VERSION" ]] && return
    version_gt "$latest" "$VERSION" || return

    # Throttle notifications to once per 7 days per version
    if (( last_notify > 0 && now - last_notify < 604800 )); then
        return
    fi

    # Display notification
    echo "claude-mux $latest available (current: $VERSION). See: github.com/pereljon/claude-mux/releases/tag/v$latest" >&2
    echo "  Update: claude-mux --update" >&2

    # Update notify timestamp
    echo "$last_check $latest $now" > "$cache"
}

# Self-update to the latest release
do_update() {
    local latest api_response
    api_response=$(curl -sf --max-time 10 \
        "https://api.github.com/repos/pereljon/claude-mux/releases/latest" 2>/dev/null) || {
        echo "Error: could not reach GitHub releases API" >&2
        exit 1
    }
    latest=$(echo "$api_response" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' | head -1)

    if [[ -z "$latest" ]]; then
        echo "Error: could not parse latest version from GitHub" >&2
        exit 1
    fi

    if [[ "$latest" == "$VERSION" ]]; then
        echo "Already at latest version ($VERSION)"
        exit 0
    fi

    if ! version_gt "$latest" "$VERSION"; then
        echo "Current version ($VERSION) is newer than latest release ($latest)"
        exit 0
    fi

    # Resolve install path early so both branches can use it for restart
    local install_path
    install_path=$(command -v claude-mux 2>/dev/null) || install_path="$CLAUDE_MUX_BIN"
    if [[ -z "$install_path" ]]; then
        echo "Error: cannot determine install path" >&2
        exit 1
    fi

    # Detect install method
    if command -v brew &>/dev/null && brew list claude-mux &>/dev/null 2>&1; then
        echo "Updating via Homebrew..."
        if ! brew upgrade claude-mux; then
            echo "Error: brew upgrade claude-mux failed" >&2
            exit 1
        fi
    else
        # Direct download
        local download_url="https://github.com/pereljon/claude-mux/releases/download/v${latest}/claude-mux"

        local tmp
        tmp=$(mktemp)
        if ! curl -sfL --max-time 30 -o "$tmp" "$download_url" 2>/dev/null; then
            rm -f "$tmp"
            echo "Error: failed to download v$latest" >&2
            exit 1
        fi

        # Validate downloaded file: must be a script, reasonably sized, and contain a version string
        if ! head -1 "$tmp" | grep -q '^#!'; then
            rm -f "$tmp"
            echo "Error: downloaded file doesn't look like a script" >&2
            exit 1
        fi
        local file_size
        file_size=$(wc -c < "$tmp")
        if (( file_size < 1000 )); then
            rm -f "$tmp"
            echo "Error: downloaded file is too small (${file_size} bytes) — likely not a valid script" >&2
            exit 1
        fi
        if ! grep -q "^VERSION=\"${latest}\"" "$tmp"; then
            rm -f "$tmp"
            echo "Error: downloaded file VERSION does not match expected v$latest — likely corrupt" >&2
            exit 1
        fi

        chmod +x "$tmp"
        if ! mv "$tmp" "$install_path"; then
            rm -f "$tmp"
            echo "Error: failed to install to $install_path — check permissions" >&2
            exit 1
        fi
    fi

    echo "claude-mux updated: $VERSION -> $latest"

    # Clear update cache
    rm -f "$HOME/.claude-mux/.update-check"

    # Backfill claude-mux hooks (incl. the PreCompact --on-compact RC-reconnect
    # hook) into every project's settings.local.json. Reaching here means the
    # version changed (no-op updates exit early above), so this only runs on a
    # real upgrade. Patches on-disk files without forcing a restart.
    if [[ -f "$CLAUDE_MUX_CONFIG" ]]; then
        update_all_project_hooks
        echo "Backfilled hooks into ${HOOKS_PATCHED} project(s) (${HOOKS_CURRENT} already current)."
    fi

    # Offer restart
    if [[ -t 0 ]]; then
        echo ""
        read -rp "Restart running sessions to use the new version? [y/N] " answer
        if [[ "$answer" =~ ^[Yy] ]]; then
            exec "$install_path" --restart
        fi
    fi
}

# Generate the LaunchAgent plist content. Uses ${CLAUDE_MUX_BIN} for the binary path.
generate_plist() {
    local xml_bin
    xml_bin="${CLAUDE_MUX_BIN//&/&amp;}"
    xml_bin="${xml_bin//</&lt;}"
    xml_bin="${xml_bin//>/&gt;}"
    xml_bin="${xml_bin//\"/&quot;}"
    cat << PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.claude-mux</string>

    <key>ProgramArguments</key>
    <array>
        <string>${xml_bin}</string>
        <string>--autolaunch</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>ThrottleInterval</key>
    <integer>60</integer>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
    </dict>
</dict>
</plist>
PLIST_EOF
}

# Write ~/.claude-mux/config from current install settings.
# Args: base_dir launchagent_mode home_model permission_mode cross_session_control
write_install_config() {
    local base_dir="$1"
    local launchagent_mode="$2"
    local home_model="$3"
    local permission_mode="$4"
    local cross_session="$5"

    # Format settings: commented out when at default, active when customized
    local base_dir_line="BASE_DIR=\"${base_dir}\""
    [[ "$base_dir" == "$HOME/Claude" ]] && base_dir_line="#BASE_DIR=\"\$HOME/Claude\""

    local permission_line="DEFAULT_PERMISSION_MODE=\"${permission_mode}\""
    [[ "$permission_mode" == "auto" ]] && permission_line="#DEFAULT_PERMISSION_MODE=\"auto\""

    local cross_line="ALLOW_CROSS_SESSION_CONTROL=${cross_session}"
    [[ "$cross_session" == "false" ]] && cross_line="#ALLOW_CROSS_SESSION_CONTROL=false"

    local launchagent_line="LAUNCHAGENT_MODE=${launchagent_mode}"
    [[ "$launchagent_mode" == "home" ]] && launchagent_line="#LAUNCHAGENT_MODE=home"

    local model_line="HOME_SESSION_MODEL=\"${home_model}\""
    [[ "$home_model" == "sonnet" ]] && model_line="#HOME_SESSION_MODEL=\"sonnet\""

    mkdir -p "$CLAUDE_MUX_DIR"
    # All variable lines are pre-computed above. Use printf to write the config
    # so user-supplied values (base_dir, etc.) cannot break heredoc parsing.
    printf '%s\n' \
        "# ~/.claude-mux/config — claude-mux user configuration" \
        "# Generated by 'claude-mux --install'. Uncomment and edit to override defaults." \
        "" \
        "# Root directory to scan for Claude projects (directories containing .claude/)." \
        "# Default: \$HOME/Claude" \
        "$base_dir_line" \
        "" \
        "# Directory for log files." \
        "# Default: \$HOME/Library/Logs" \
        '#LOG_DIR="$HOME/Library/Logs"' \
        "" \
        "# Set Claude's permissions.defaultMode for each project." \
        '# Valid: "" (disabled), "default", "acceptEdits", "plan", "auto", "dontAsk", "bypassPermissions"' \
        "# Default: \"auto\"" \
        "$permission_line" \
        "" \
        "# Allow sessions to send slash commands to other sessions via tmux." \
        "# Default: false" \
        "$cross_line" \
        "" \
        "# ── Templates ─────────────────────────────────────────────────────────────────" \
        '#TEMPLATES_DIR="$HOME/.claude-mux/templates"' \
        '#DEFAULT_TEMPLATE="default.md"' \
        "" \
        "# ── LaunchAgent ───────────────────────────────────────────────────────────────" \
        "# LaunchAgent mode at login: none, home (default)" \
        "$launchagent_line" \
        "" \
        "# Model for the home session. Set to \"\" to use the default model." \
        "# Default: sonnet" \
        "$model_line" \
        "" \
        "# ── Batch mode ────────────────────────────────────────────────────────────────" \
        "#SLEEP_BETWEEN=5" \
        > "$CLAUDE_MUX_CONFIG"
    chmod 600 "$CLAUDE_MUX_CONFIG"
}

# Interactive setup (config + LaunchAgent). Invoked by --install or first-run prompt.
# Reads INSTALL_ARGS for non-interactive flags.
do_install() {
    local interactive=true
    local base_dir=""
    local launchagent_mode=""
    local home_model=""
    local permission_mode="auto"
    local cross_session="false"
    local launchagent_set=false
    local home_model_set=false

    # Parse install-specific flags from INSTALL_ARGS
    local i=0
    while [[ $i -lt ${#INSTALL_ARGS[@]} ]]; do
        local arg="${INSTALL_ARGS[$i]}"
        case "$arg" in
            --non-interactive) interactive=false; ((i++)) ;;
            --base-dir)
                ((i++))
                if [[ $i -ge ${#INSTALL_ARGS[@]} ]]; then
                    echo "ERROR: --base-dir requires a value" >&2; exit 1
                fi
                base_dir="${INSTALL_ARGS[$i]}"
                ((i++))
                ;;
            --launchagent-mode)
                ((i++))
                if [[ $i -ge ${#INSTALL_ARGS[@]} ]]; then
                    echo "ERROR: --launchagent-mode requires a value" >&2; exit 1
                fi
                launchagent_mode="${INSTALL_ARGS[$i]}"
                case "$launchagent_mode" in
                    none|home) ;;
                    *) echo "ERROR: --launchagent-mode must be 'none' or 'home'" >&2; exit 1 ;;
                esac
                launchagent_set=true
                ((i++))
                ;;
            --home-model)
                ((i++))
                if [[ $i -ge ${#INSTALL_ARGS[@]} ]]; then
                    echo "ERROR: --home-model requires a value" >&2; exit 1
                fi
                home_model="${INSTALL_ARGS[$i]}"
                if ! is_valid_model "$home_model"; then
                    echo "ERROR: --home-model must be a model name claude accepts (letters/digits/._-, no leading dash) or empty" >&2; exit 1
                fi
                home_model_set=true
                ((i++))
                ;;
            --no-launchagent)
                launchagent_mode="none"
                launchagent_set=true
                ((i++))
                ;;
            --permission-mode)
                ((i++))
                if [[ $i -ge ${#INSTALL_ARGS[@]} ]]; then
                    echo "ERROR: --permission-mode requires a value" >&2; exit 1
                fi
                permission_mode="${INSTALL_ARGS[$i]}"
                case "$permission_mode" in
                    ""|default|acceptEdits|plan|auto|dontAsk|bypassPermissions) ;;
                    *) echo "ERROR: --permission-mode must be one of: default, acceptEdits, plan, auto, dontAsk, bypassPermissions" >&2; exit 1 ;;
                esac
                ((i++))
                ;;
            --cross-session-control) cross_session="true"; ((i++)) ;;
            -*) echo "ERROR: Unknown --install option: $arg" >&2; exit 1 ;;
            *) echo "ERROR: --install does not accept positional arguments (got: $arg)" >&2; exit 1 ;;
        esac
    done

    # Interactive prompts
    # When piped (curl | bash), stdin is the pipe so -t 0 is false.
    # Fall back to /dev/tty for user input if available.
    local tty_in="/dev/stdin"
    if [[ ! -t 0 ]] && [[ -r /dev/tty ]]; then
        tty_in="/dev/tty"
    fi

    # Detect existing config
    local has_existing_config=false
    [[ -f "$CLAUDE_MUX_CONFIG" ]] && has_existing_config=true

    if [[ "$has_existing_config" == "true" ]]; then
        if [[ "$interactive" == "true" && ( -t 0 || -r /dev/tty ) ]]; then
            echo "Existing config found at $CLAUDE_MUX_CONFIG"
            printf "Reconfigure? [y/N]: "
            read -r answer < "$tty_in"
            if [[ ! "$answer" =~ ^[Yy] ]]; then
                echo "Setup canceled — existing config kept."
                return 0
            fi
        elif [[ "$interactive" == "false" && "$FORCE" != "true" ]]; then
            echo "ERROR: Config already exists at $CLAUDE_MUX_CONFIG" >&2
            echo "Use --force to overwrite, or run without --non-interactive to reconfigure." >&2
            exit 1
        fi
    fi

    # Warn if reconfiguring from inside the home session
    if [[ -n "${TMUX:-}" ]]; then
        local current_session
        current_session="$("$TMUX_BIN" display-message -p '#S' 2>/dev/null)"
        if [[ "$current_session" == "home" ]]; then
            echo ""
            echo "Note: you are running --install from inside the home session."
            echo "LaunchAgent changes take effect at next login."
            echo "Your current home session will continue running."
            echo ""
        fi
    fi

    if [[ "$interactive" == "true" && ( -t 0 || -r /dev/tty ) ]]; then
        echo "claude-mux setup"
        echo ""

        # BASE_DIR
        if [[ -z "$base_dir" ]]; then
            local default_base="$HOME/Claude"
            printf "Where are your Claude projects? [%s]: " "$default_base"
            read -r _input < "$tty_in"
            base_dir="${_input:-$default_base}"
            base_dir="${base_dir/#\~/$HOME}"
        fi

        # LaunchAgent mode
        if [[ "$launchagent_set" != "true" ]]; then
            echo ""
            echo "A home session is a lightweight Claude session that runs in your base"
            echo "directory. It stays running so Remote Control is always available from"
            echo "the Claude mobile app, and can manage all your other sessions."
            echo ""
            echo "Note: enabling this means a Claude session will start automatically"
            echo "every time you log in."
            echo ""
            printf "Start a home session at login? [Y/n]: "
            read -r _input < "$tty_in"
            case "${_input:-y}" in
                [Yy]|[Yy]es) launchagent_mode="home" ;;
                [Nn]|[Nn]o)  launchagent_mode="none" ;;
                *) echo "Invalid choice, defaulting to yes"; launchagent_mode="home" ;;
            esac
            launchagent_set=true
        fi

        # Home session model (only if mode is home and not preset)
        if [[ "$launchagent_mode" == "home" && "$home_model_set" != "true" ]]; then
            local default_model="sonnet"
            printf "Home session model? (e.g. sonnet, haiku, opus, or a full ID like claude-opus-4-8; blank = Claude Code default) [%s]: " "$default_model"
            read -r _input < "$tty_in"
            if [[ -z "$_input" ]]; then
                home_model="$default_model"
            elif is_valid_model "$_input"; then
                home_model="$_input"
            else
                echo "Invalid model token, using default: $default_model"; home_model="$default_model"
            fi
        fi
        echo ""
    fi

    # Apply defaults for any unset values (non-interactive path)
    base_dir="${base_dir:-$HOME/Claude}"
    [[ "$launchagent_set" != "true" ]] && launchagent_mode="home"
    [[ -z "$home_model" ]] && home_model="sonnet"

    # Validate base_dir: reject characters that would break bash config sourcing
    if [[ "$base_dir" =~ [\'\"\;\`\$\(\)\{\}\|\&\<\>] ]]; then
        echo "ERROR: --base-dir contains characters not allowed in a config path: $base_dir" >&2
        exit 1
    fi

    # Validate parent directory exists before attempting mkdir
    local base_parent
    base_parent="$(dirname "$base_dir")"
    if [[ ! -d "$base_parent" ]]; then
        echo "ERROR: Parent directory does not exist: $base_parent" >&2
        exit 1
    fi

    # Create base dir if missing
    if [[ ! -d "$base_dir" ]]; then
        echo "Creating base directory $base_dir..."
        mkdir -p "$base_dir"
    fi

    # Default home-session protection: create .claudemux-protected marker in base dir
    # so the home session is protected at launch. Only when LaunchAgent will run
    # a home session. Idempotent: don't overwrite if user already removed it later.
    if [[ "$launchagent_mode" == "home" && ! -f "$base_dir/.claudemux-protected" ]]; then
        touch "$base_dir/.claudemux-protected"
        ensure_gitignore_entry "$base_dir" ".claudemux-*"
    fi

    # Ensure templates dir + default template exist
    mkdir -p "$CLAUDE_MUX_DIR/templates"
    if [[ ! -f "$CLAUDE_MUX_DIR/templates/default.md" ]]; then
        touch "$CLAUDE_MUX_DIR/templates/default.md"
    fi

    # Write config
    echo "Writing config to $CLAUDE_MUX_CONFIG..."
    write_install_config "$base_dir" "$launchagent_mode" "$home_model" "$permission_mode" "$cross_session"

    # LaunchAgent handling
    local plist_path="$HOME/Library/LaunchAgents/com.user.claude-mux.plist"
    local launchagents_dir="$HOME/Library/LaunchAgents"

    # Always unload existing agent (silent if not loaded)
    if [[ -f "$plist_path" ]]; then
        launchctl bootout "gui/$(id -u)" "$plist_path" 2>/dev/null || true
    fi

    if [[ "$launchagent_mode" == "none" ]]; then
        # Remove plist if present
        if [[ -f "$plist_path" ]]; then
            echo "Removing LaunchAgent plist..."
            rm -f "$plist_path"
        fi
        echo "LaunchAgent disabled (LAUNCHAGENT_MODE=none)."
    else
        # Write plist and load
        mkdir -p "$launchagents_dir"
        echo "Writing LaunchAgent plist to $plist_path..."
        generate_plist > "$plist_path"
        chmod 644 "$plist_path"
        if launchctl bootstrap "gui/$(id -u)" "$plist_path" 2>/dev/null; then
            echo "LaunchAgent loaded."
        else
            echo "WARNING: launchctl bootstrap failed — you may need to log out and back in." >&2
        fi
    fi

    # Summary
    echo ""
    echo "Setup complete."
    echo ""
    echo "  Binary:       $CLAUDE_MUX_BIN"
    echo "  Base dir:     $base_dir"
    echo "  Config:       $CLAUDE_MUX_CONFIG"
    echo "  LaunchAgent:  $launchagent_mode"
    [[ "$launchagent_mode" == "home" ]] && echo "  Home model:   $home_model"
    echo ""
    echo "Run 'claude-mux' in any project directory to start a session."
}

# Returns true if claude is running anywhere in the process tree rooted at pane_pid
claude_running_in_session() {
    local session_name="$1"
    local pane_pid
    pane_pid=$("$TMUX_BIN" display-message -t "$session_name" -p '#{pane_pid}' 2>/dev/null)
    [[ -z "$pane_pid" ]] && return 1

    # Use ps to find children (pgrep -P is unreliable on macOS for some process types)
    ps -eo pid=,ppid=,comm= 2>/dev/null | awk -v ppid="$pane_pid" '
        $2 == ppid { children[$1] = $3 }
        END { for (pid in children) print children[pid] }
    ' | grep -q "claude" && return 0

    # Check grandchildren too
    local children
    children=$(ps -eo pid=,ppid= 2>/dev/null | awk -v ppid="$pane_pid" '$2 == ppid { print $1 }')
    for child in $children; do
        ps -eo pid=,ppid=,comm= 2>/dev/null | awk -v ppid="$child" '$2 == ppid && $3 ~ /claude/' | grep -q "claude" && return 0
    done
    return 1
}

sanitize_session_name() {
    echo "$1" | tr ' ' '-' | tr -cs 'a-zA-Z0-9-' '-' | sed 's/-\{2,\}/-/g' | sed 's/^-*//' | sed 's/-*$//'
}

# Apply tmux session options from rc settings
apply_tmux_options() {
    local session="$1"
    [[ "$TMUX_EXTENDED_KEYS" == "true" ]] && \
        "$TMUX_BIN" set-option -t "$session" extended-keys on 2>/dev/null
    [[ -n "$TMUX_TITLE_FORMAT" ]] && {
        "$TMUX_BIN" set-option -t "$session" set-titles on 2>/dev/null
        "$TMUX_BIN" set-option -t "$session" set-titles-string "$TMUX_TITLE_FORMAT" 2>/dev/null
    }
    [[ "$TMUX_MOUSE" == "true" ]] && \
        "$TMUX_BIN" set-option -t "$session" mouse on 2>/dev/null
    [[ -n "$TMUX_HISTORY_LIMIT" ]] && \
        "$TMUX_BIN" set-option -t "$session" history-limit "$TMUX_HISTORY_LIMIT" 2>/dev/null
    [[ "$TMUX_CLIPBOARD" == "true" ]] && \
        "$TMUX_BIN" set-option -t "$session" set-clipboard on 2>/dev/null
    [[ -n "$TMUX_DEFAULT_TERMINAL" ]] && \
        "$TMUX_BIN" set-option -t "$session" default-terminal "$TMUX_DEFAULT_TERMINAL" 2>/dev/null
    [[ -n "$TMUX_ESCAPE_TIME" ]] && \
        "$TMUX_BIN" set-option -t "$session" escape-time "$TMUX_ESCAPE_TIME" 2>/dev/null
    [[ "$TMUX_MONITOR_ACTIVITY" == "true" ]] && \
        "$TMUX_BIN" set-option -t "$session" monitor-activity on 2>/dev/null
}

# Returns version line and optional update note for the system prompt.
# Format: "claude-mux version: X.Y.Z" plus update note if a newer version is cached.
get_version_prompt_lines() {
    local version_line="claude-mux version: ${VERSION}"

    local cache="$HOME/.claude-mux/.update-check"
    if [[ ! -f "$cache" ]]; then
        echo "$version_line"
        return
    fi

    local last_check latest last_notify
    read -r last_check latest last_notify < "$cache" 2>/dev/null || true

    if [[ -z "$latest" ]] || ! version_gt "$latest" "$VERSION"; then
        echo "$version_line"
        return
    fi

    # Format check date — macOS (date -r) with Linux fallback (date -d @)
    local check_date
    if ! check_date=$(date -r "$last_check" +%Y-%m-%d 2>/dev/null); then
        check_date=$(date -d "@${last_check}" +%Y-%m-%d 2>/dev/null) || check_date="recently"
    fi

    printf '%s\nUpdate available: %s (found %s). Tell the user and suggest they say "update claude-mux" to update.' \
        "$version_line" "$latest" "$check_date"
}

# Detect the current permission mode of a session from its tmux status bar.
# Outputs one of: bypassPermissions, acceptEdits, plan, default, unknown
# Usage: get_session_mode SESSION
get_session_mode() {
    local session="${1:-}"
    if [[ -z "$session" ]]; then
        if [[ -z "${TMUX_PANE:-}" ]]; then
            echo "ERROR: --get-mode requires a SESSION argument when called outside a tmux session" >&2
            return 1
        fi
        session=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null)
        if [[ -z "$session" ]]; then
            echo "ERROR: Could not determine current session name" >&2
            return 1
        fi
    fi
    if ! "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
        echo "ERROR: Session '$session' not found" >&2
        return 1
    fi
    local pane
    pane=$("$TMUX_BIN" capture-pane -t "$session" -p 2>/dev/null)
    local pane_tail
    pane_tail=$(echo "$pane" | tail -4)
    if echo "$pane_tail" | grep -q "bypass permissions on"; then
        echo "bypassPermissions"
    elif echo "$pane_tail" | grep -q "accept edits on"; then
        echo "acceptEdits"
    elif echo "$pane_tail" | grep -q "plan mode on"; then
        echo "plan"
    elif echo "$pane_tail" | grep -q "? for shortcuts"; then
        echo "default"
    else
        echo "unknown"
    fi
}

# Build the system prompt injected into each Claude session
build_system_prompt() {
    local session_name="$1"
    local permission_mode="${2:-}"   # optional: permission mode to include in ready response
    local mux_bin="${CLAUDE_MUX_BIN}"
    local send_scope="to yourself"
    [[ "$ALLOW_CROSS_SESSION_CONTROL" == "true" ]] && send_scope="to yourself or any other Claude session"

    local home_line=""
    local home_management=""
    if [[ "$session_name" == "home" ]]; then
        home_line="
This is the home session: the always-on tmux session in your base directory, and the session orchestrator. Its purpose is session management and project orchestration via claude-mux, not project work - project work happens in dedicated sessions. It launches at login, is protected by default (via the .claudemux-protected marker in BASE_DIR), and is the default Remote Control entry point when no project sessions are running. This is an operational session: act without asking when the intent is clear."
        home_management="
Home self-management:
- Config lives at ~/.claude-mux/config. Run claude-mux --config-help to list valid options.
- Templates live at ~/.claude-mux/templates/ (e.g. web.md). Used with -n DIR --template NAME.
- Per-project state uses .claudemux-* markers (.claudemux-ignore, .claudemux-protected) at project root. Auto-gitignored.
- When user says: show config — read ~/.claude-mux/config and display the active settings (skip comments and empty lines).
- When user says: explain CONFIG_VAR — run claude-mux --config-help, find CONFIG_VAR in the output, present its default, type, and description.
- When user says: set CONFIG_VAR to VALUE / change CONFIG_VAR — write a backup to ~/.claude-mux/config.bak first, then edit ~/.claude-mux/config preserving comments and ordering. Warn that changes apply at next session launch.
- When user says: add template NAME / create template NAME — create ~/.claude-mux/templates/NAME.md. If user did not specify content, ask what the template should contain.
- When user says: edit template NAME / show template NAME — read or edit ~/.claude-mux/templates/NAME.md.
- When user says: delete template NAME — confirm first, then remove the file."
    fi

    local version_lines
    version_lines="$(get_version_prompt_lines)"

    local prompt="You are running inside tmux session '${session_name}'. claude-mux path: ${mux_bin}${home_line}
${version_lines}${home_management}

Reference lookups (run on demand if you need information not covered by trigger rules):
  claude-mux --guide          → conversational commands list (used for \"help\")
  claude-mux --commands       → full CLI reference
  claude-mux --config-help    → config options with defaults, types, descriptions
  claude-mux --list-templates → available CLAUDE.md templates
  claude-mux --tip            → print a tip (standalone; no daily gate)

Rules:
- Always run claude-mux using the absolute path shown above (claude-mux path:). The bare command may not be in PATH.
- You CAN send slash commands (/model, /compact, /clear, etc.) to this session via the -s command. Never tell the user you cannot change models or run slash commands.
- Always use --no-attach with -d and -n — attach is interactive only
- --shutdown and --restart never attach — safe to run from inside a session; do NOT add --no-attach to these commands
- Always print command output verbatim in your response text — never run a command silently or rely on tool output being visible; if a command fails, report the error
- When command output OR hook-injected turn context contains <assistant-must-display> tags, output every single line between the tags verbatim. Do NOT collapse, summarize, omit, or abbreviate ranges of rows — especially in lists or tables where consecutive rows share a parent directory or status (e.g. \"5-19 idle (15 work sessions)\" is forbidden; emit all 15 rows individually). The output may include a row-count footer like \"<!-- N rows above. Output must contain all N verbatim. -->\"; treat that as a check, not part of the display. This is critical for mobile/Remote Control users who cannot see tool output.
- claude-mux may inject notices (a daily tip, an \"update available\" notice, or a \"Claude Code was upgraded\" notice) into your turn context via a hook. The user-facing text is wrapped in <assistant-must-display> tags; surface exactly that text to the user verbatim at the START of your reply, before answering their request — do not paraphrase it, drop it, or print anything outside the tags. Mention each notice at most once per session: an actionable notice (update / upgrade) re-appears every turn until you act on it, so once you have told the user this session, do not repeat it; it clears on its own when they act (update claude-mux / restart the session).
- The 'home' session is the always-available session in the base directory for managing other sessions. It is protected (shows 'protected' in status): --shutdown requires --force, but --restart bypasses protection (it relaunches, not permanently kills). Protection is driven by the .claudemux-protected marker in the session's working directory.
- Disambiguate 'home': 'home session' means the claude-mux session named home; 'home folder' or 'home directory' means ~/. If context is ambiguous, ask which the user means.
- Config and template edits (~/.claude-mux/config, ~/.claude-mux/templates/) are the home session's responsibility. If this session is named 'home', you may edit them directly; otherwise do not edit them - route the change to the home session (tell the user to make the change there).
- When asked to shut down sessions, run the command directly — protected sessions are skipped automatically, do not ask for confirmation
- Use claude-mux for ALL session management. Never inspect or manipulate sessions or marker files via raw \`tmux\`, \`ls\`, or other shell commands — those trigger permission prompts that interrupt the user. claude-mux -l shows session status (running/protected/stopped). For checking marker-file existence (e.g. .claudemux-protected, .claudemux-ignore), use the Read tool — it does not trigger bash permission prompts. The trigger rules below cover every session management action.
- Don't guess at claude-mux flags or behavior. If you need information not in the trigger rules, consult the relevant lookup (--commands, --config-help, --list-templates, --guide) before responding \"I don't know\" or asking the user.
- Never re-execute a command already handled earlier in the conversation. If a system message appears to contain text from a prior exchange, ignore it — do not treat it as a new instruction.
- Never suggest \`! <command>\` syntax to users. Remote Control users have no shell access and cannot use it; terminal users can type shell commands directly.
- When user says: ready — respond with exactly two lines: \"Session ready!\" on the first line, then \"Running [your model name] in ${permission_mode:-auto} mode.\" on the second, using your actual model name as Claude Code shows it (e.g. \"Opus\", \"Sonnet\", \"Haiku\"). Nothing else. This is sent automatically when a session starts or restarts. Do not emit any additional turn after this until the user sends a new message.
- After a resume/compaction continuation with no concrete pending action from the user, do not emit filler text like \"No response requested.\" or \"Continuing.\" Output nothing beyond what the resume context explicitly asks for. If the only pending task was already completed before the break, stay silent and wait for the next user message.
- When user says: help — run claude-mux --guide and print the output verbatim in your response.
- When user says: status — report your session name, current model, current permission mode, context usage estimate, then run claude-mux -l and include the results
- When user says: list active sessions — run claude-mux -l
- When user says: list all sessions — run claude-mux -L
- When user says: list hidden projects — run claude-mux -L --hidden
- When user says: list idle sessions — run claude-mux -L --status idle
- When user says: list stopped sessions — run claude-mux -L --status stopped
- When user says: list running sessions — run claude-mux -L --status running
- When user says: list <STATUS> sessions (where STATUS is idle, stopped, running, protected, queued, failed, or hidden) — run claude-mux -L --status <STATUS>
- When user says: start session SESSION — resolve SESSION per the NAME-resolution rule below, then run claude-mux --start SESSION (resolves by name, no path; starts it if stopped, no-op if already running). Confirm with the session name only (e.g. Started. SESSION is now running. / SESSION is already running.) — do not include the directory path, sessions appear by name in Remote Control
- Resolving a session/project NAME in the rules below: \"this session\" / \"this project\" / \"the current session\" (explicit) always means the session you are running in — act on it directly (you know your own name from the tmux session name in this prompt's header). For any OTHER phrasing that names a target (\"the X session\", \"session X\", \"restart X\", \"compact X\"), resolve X against the appropriate list: use claude-mux -l for commands that act on a RUNNING session (stop, restart, restart-fresh, switch mode/model, compact, clear, get-mode); use claude-mux -L (add --hidden) for project-level commands that can target an idle, stopped, or hidden project (hide, show/unhide, protect, unprotect, delete). Act ONLY on an exact single match; if X matches zero or is ambiguous, ASK the user which one and offer the closest matches — NEVER fall back to the current session. Number references (e.g. \"restart 5\") already resolve via the list and are safe.
- When user says: stop this session — run claude-mux --shutdown for the current session. When user says: stop session NAME — resolve NAME per the rule above and run claude-mux --shutdown NAME; if NAME does not resolve to exactly one session, ask which session — do not default to the current session
- When user says: stop all sessions — run claude-mux --shutdown
- When user says: restart this session — run claude-mux --restart for the current session. When user says: restart session NAME / restart the NAME session — resolve NAME per the rule above and run claude-mux --restart NAME; if NAME does not resolve to exactly one session, ask which session — do not default to the current session
- When user says: restart this session fresh / kill this session — run claude-mux --restart CURRENT_SESSION --fresh for the current session. When user says: restart SESSION fresh — resolve SESSION per the rule above and run claude-mux --restart SESSION --fresh; if it does not resolve to exactly one session, ask which session — do not default to the current session. In all cases warn the user that the conversation history will not be resumed
- When user says: restart all sessions — run claude-mux --restart
- When user says: start new session in FOLDER — run claude-mux -n FOLDER --no-attach; append --template NAME if provided, use -p if parents needed; model and mode set after via switch commands; confirm with the session name only, not the directory path
- When user says: what mode is this session / what permission mode — run claude-mux --get-mode CURRENT_SESSION and report the result. When user says: what mode is session NAME — resolve NAME per the rule above and run claude-mux --get-mode NAME; if NAME does not resolve to exactly one session, ask which session
- When user says: switch this session to MODE mode — run claude-mux --permission-mode MODE on the current session. When user says: switch session NAME to MODE mode — resolve NAME per the rule above and run it on NAME; if NAME does not resolve to exactly one session, ask which session — do not default to the current session
- When user says: switch this session to MODEL model — resolve MODEL to a concrete model ID (below), then send /model <id> via -s to the current session. When user says: switch session NAME to MODEL model — resolve NAME per the rule above and send to NAME; if NAME does not resolve to exactly one session, ask which session — do not default to the current session. Resolving MODEL (the /model picker silently ignores a bare family name, so you MUST resolve to a concrete ID first): (a) a BARE family (\`opus\`/\`sonnet\`/\`haiku\` or any family) → expand to the latest concrete ID you know for that family, from your own model knowledge plus the model-ID list Claude Code provides in your context, preferring the dateless alias form (e.g. \`sonnet\` → \`claude-sonnet-4-6\`); (b) a family-plus-version shorthand (\"opus 4.8\", \"opus-4-8\", \"opus 4 8\") → the dash-joined, \`claude-\`-prefixed ID \`claude-<family>-<major>-<minor>\` (e.g. \`claude-opus-4-8\`); (c) an already-full ID or a date-suffixed ID (\`claude-opus-4-8\`, \`claude-haiku-4-5-20251001\`) → use as-is. If you cannot confidently map MODEL to a concrete ID (e.g. a model newer than you know), ASK the user for the exact model ID rather than sending a bare family (which the picker silently ignores, leaving the model unchanged). Claude Code validates the final ID.
- When user says: compact this session — send /compact via -s to the current session. When user says: compact session NAME — resolve NAME per the rule above and send it to NAME; if NAME does not resolve to exactly one session, ask which session — do not default to the current session. Inform the user that RC will reconnect automatically after compact completes (~30-60s)
- When user says: clear this session — send /clear via -s to the current session. When user says: clear session NAME — resolve NAME per the rule above and send it to NAME; if NAME does not resolve to exactly one session, ask which session — do not default to the current session
- When user says: update claude-mux — check the installed version and latest available; warn the user that all sessions will be restarted and ask for confirmation before proceeding; if confirmed, run claude-mux --update then claude-mux --restart
- When user says: hide this project — run claude-mux --hide for the current session. When user says: hide PROJECT — resolve PROJECT per the rule above and run claude-mux --hide PROJECT; if it does not resolve to exactly one project, ask which — do not default to the current session. Confirm with the project name.
- When user says: show this project — run claude-mux --show for the current session. When user says: show PROJECT / unhide PROJECT — resolve PROJECT per the rule above (hidden projects appear under claude-mux -L --hidden) and run claude-mux --show PROJECT; if it does not resolve to exactly one project, ask which — do not default to the current session.
- When user says: protect this session — run claude-mux --protect for the current session. When user says: protect SESSION — resolve SESSION per the rule above and run claude-mux --protect SESSION; if it does not resolve to exactly one session, ask which — do not default to the current session.
- When user says: unprotect this session — run claude-mux --unprotect for the current session. When user says: unprotect SESSION — resolve SESSION per the rule above and run claude-mux --unprotect SESSION; if it does not resolve to exactly one session, ask which — do not default to the current session.
- When user says: is this hidden / is this protected — check for .claudemux-ignore or .claudemux-protected in the project folder and report state.
- When user says: delete this project — target the current project. When user says: delete PROJECT — resolve PROJECT per the rule above; if it does not resolve to exactly one project, ask which one (never default to the current project). Then, in both cases, confirm in chat first (\"Move project '<name>' to trash? Yes/No\"). If user confirms, run claude-mux --delete NAME --yes (the chat exchange replaces the TTY prompt). If the project is protected, warn and ask if --force should be used. The folder is moved to the system trash, recoverable via Finder.
- When user says: list templates — run claude-mux --list-templates
- When user says: save this as a template named NAME / make a template from this project called NAME — run claude-mux --save-template NAME (no DIR arg needed; defaults to current project). Confirm with the template filename.
- When user says: rename this project to NAME — run claude-mux --rename CURRENT_SESSION NAME (where CURRENT_SESSION is this tmux session name)
- When user says: move this project to PATH — run claude-mux --move CURRENT_SESSION PARENT_DIR where PARENT_DIR is the destination's PARENT directory (the existing folder the project will be moved INTO), not the new full project path. The command also accepts the full destination path (PARENT_DIR/SESSION) and strips the trailing session name automatically.
- When user says: tip / tip of the day — run claude-mux --tip and display the output. Tips are in English; render in the user's conversation language.
- When user says: enable tips / turn on tips — run claude-mux --enable-tips
- When user says: disable tips / turn off tips — run claude-mux --disable-tips
- When user says: install hooks / backfill hooks / repair hooks — run claude-mux --install-hooks and report the summary. This backfills the PreCompact RC-reconnect hook (and other claude-mux hooks) into projects created before the hook existed, so /compact reconnects RC in those sessions too.
- When user references sessions by number (e.g., stop 1-3, restart 5, compact 2 and 4), map the numbers to session names from the most recent list output, then run the corresponding command for each.
- These trigger phrases work in any language. If the user types the equivalent intent in their native language (Spanish, French, German, Japanese, Hebrew, Arabic, Hindi, etc.), infer the intent and run the corresponding command. Output of claude-mux commands (lists, status, guide) is shown verbatim regardless of input language.

Additional capabilities (run claude-mux --commands for full syntax):
  - Attach interactively to a session (-t — user-only, never from inside a session)
  - Start a stopped session by name (--start SESSION — no-op if already running; --restart also starts a stopped session)
  - Start a session fresh without resuming (--restart SESSION --fresh — use after installing MCPs or global config changes)
  - Start all sessions at once (-a)
  - New project with a CLAUDE.md template (-n DIR --template NAME, -p for parent dirs)
  - Force-shutdown a protected session (--shutdown SESSION --force)
  - Get current permission mode of a session (--get-mode SESSION)
  - Hide/show projects (--hide / --show)
  - Protect/unprotect sessions (--protect / --unprotect)
  - Rename a project (--rename SESSION NAME) or move it (--move SESSION PATH) — migrates history and registry
  - Move a project to trash (--delete SESSION — macOS; honors protection unless --force)
  - Enable/disable tip-of-the-day (--enable-tips / --disable-tips)
  - Backfill claude-mux hooks into all projects (--install-hooks — repairs the PreCompact RC-reconnect hook in pre-existing sessions)
  - Show all config options (--config-help)
  - Run interactive setup or reconfigure (--install)
  - Update claude-mux (--update)
  - Uninstall claude-mux (--uninstall — removes hooks, permissions, LaunchAgent)

Self-targeting send: claude-mux -s '${session_name}' '/command' sends slash commands ${send_scope}.
${GITHUB_SSH_INFO}"

    echo "$prompt"
}

