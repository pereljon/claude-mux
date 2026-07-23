# Print one tip from the embedded tips array. No gating — selects a tip and
# prints it. Used by --tip (on demand) and by on_prompt (which applies its own
# home-only, once-per-day-global gate). --tip always works regardless of TIP_OF_DAY.
tip_of_day() {
    # Tips array — sourced from internal/tips.md. Keep in sync.
    local tips=(
        "Say \"status\" in any session to see your session name, current model, permission mode, and context usage — all at once."
        "Say \"list all sessions\" to see every project claude-mux knows about, including ones that aren't currently running."
        "Say \"switch this session to plan mode\" to enable Plan permission mode without restarting. Claude handles the Shift+Tab navigation itself."
        "Say \"switch this session to yolo\" to enable bypassPermissions mode. No restart needed — Claude navigates the mode cycle automatically."
        "Say \"switch the api-server session to Haiku\" to change the model in another session without leaving your current one."
        "Say \"compact this session\" instead of typing /compact — works from Remote Control on mobile where slash commands aren't available."
        "Say \"start a new session in ~/projects/foo\" and Claude will launch it, set up permissions, and confirm by session name. Works from any session including your phone."
        "Say \"restart the web-dashboard session\" to restart a specific session without affecting others. The session picks up where it left off."
        "The home session launches at login and is always protected from accidental shutdown. It's your default Remote Control entry point when nothing else is running."
        "If the home session crashes or gets shut down, the LaunchAgent relaunches it automatically within about 60 seconds."
        "Say \"update claude-mux\" from any session. Claude warns you that all sessions will restart, asks for confirmation, then handles the update."
        "Say \"tip\" in any session to get a usage tip on demand."
        "Say \"protect this session\" to prevent accidental shutdown. The protection marker travels with the folder if you move or rename the project."
        "Say \"hide this project\" to remove it from session listings. Useful for archived or inactive projects you don't want cluttering the list."
        "Say \"show this project\" or \"unprotect this session\" to reverse hiding or protection."
        "Say \"what mode is this session\" to check your current permission mode: bypassPermissions, acceptEdits, plan, or default."
        "Every session gets \`AGENTS.md\` and \`GEMINI.md\` created as symlinks to \`CLAUDE.md\`. Codex CLI, Gemini CLI, and other AI coders pick up your project instructions automatically."
        "Trigger phrases work in any language. \"Cambia esta sesión a plan mode\" and \"このセッションをHaikuに切り替えて\" both work — Claude infers the intent."
        "Say \"help\" in any session to see all available conversational commands. Say \"list active sessions\" vs \"list all sessions\" for different levels of detail."
        "Say \"start new session in ~/projects/new-thing\" with a template name to create a project with git init, permissions, and a CLAUDE.md from your template library."
        "Templates live in \`~/.claude-mux/templates/\`. Say \"list templates\" to see what's available, or \"save this as a template named NAME\" to add one."
        "Config lives in \`~/.claude-mux/config\`. Run \`claude-mux --config-help\` to see every option with its default value, type, and description."
        "Say \"show config\" from the home session to see your current settings. Say \"set BASE_DIR to ~/work\" to change a value."
        "Say \"list all sessions\" to see all projects including inactive ones. Say \"list hidden projects\" to see only hidden ones."
        "The current session is marked with \`>\` in session listings, so you always know which session ran the command."
        "Protected sessions show \`protected\` status in listings. A protected session that isn't running shows \`stopped\` — so you can see at a glance that something that should be running isn't."
        "Say \"delete this project\" or \"delete old-thing\" to move a project folder to the Trash. Recoverable from Finder if you change your mind."
        "If you have multiple GitHub SSH accounts configured in \`~/.ssh/config\`, claude-mux injects the host aliases into every session. Claude knows which account to use for each remote without being told."
        "Say \"stop all sessions\" to shut everything down at once. Protected sessions are skipped automatically — you won't accidentally kill the home session."
        "Say \"restart all sessions\" from inside a session. All other sessions restart first, then yours restarts last — so it can finish coordinating before its own context resets."
        "Say \"update claude-mux\" to update to the latest release. All sessions restart automatically after the update."
        "Say \"rename this project to NAME\" to rename the project folder and migrate conversation history automatically."
        "Say \"move this project to ~/work\" to relocate the project and migrate conversation history to match."
        "Session lists show row numbers. Say \"stop 1-3\" or \"restart 5\" to target sessions by number instead of typing names."
        "All project commands work with session names. \"Hide my-project\", \"protect my-project\", \"delete my-project\". No name means the current session."
        "Say \"clear this session\" to wipe context and start fresh without restarting. Say \"compact this session\" to summarize and reduce context usage instead."
        "Say \"send /model opus to the api-server session\" to run any slash command in another session from where you are."
        "Say \"disable tips\" to turn off tip-of-the-day across all sessions. Say \"enable tips\" to turn it back on. Both update every project at once."
        "Say \"restart this session fresh\" or \"kill this session\" after installing a new MCP. The session restarts without resuming — new MCPs and config changes are picked up immediately."
        "claude-mux checks for new releases in the background and tells you right in the conversation when an update is available. Say \"update claude-mux\" when you see the notice."
        "Say \"start the api-server session\" to bring an idle project back online by name. Only brand-new projects need a path."
    )

    local num_tips=${#tips[@]}
    local idx

    if [[ "${TIP_MODE:-daily}" == "random" ]]; then
        idx=$(( RANDOM % num_tips ))
    else
        local day_of_year
        day_of_year=$(date +%j)
        idx=$(( (10#$day_of_year - 1) % num_tips ))
    fi

    printf '%s\n' "${tips[$idx]}"
}

# Identity of the claude executable: resolved path + mtime. Changes on a cask
# upgrade (versioned realpath repoints) and on an in-place npm/curl upgrade (mtime
# bumps), so one signal covers both. No macOS process introspection needed.
claude_binary_id() {
    local rp
    rp=$(realpath "$CLAUDE_BIN" 2>/dev/null || readlink -f "$CLAUDE_BIN" 2>/dev/null || echo "$CLAUDE_BIN")
    local mt
    mt=$(stat -f %m "$rp" 2>/dev/null || stat -c %Y "$rp" 2>/dev/null || echo 0)
    printf '%s:%s' "$rp" "$mt"
}

# Claude Code upgrade detection (always-on). Compares the session's launch-time
# binary id (@claude-mux-claude-id) against the current one; on change, echoes a
# notice. persist-while-relevant: it does NOT ack/overwrite the option on emit, so
# the notice re-appears every prompt until a RESTART re-captures the id (kill+recreate
# via create_claude_session/launch_single_session, or in-place relaunch via
# await_ready_handshake) — a single missed relay can no longer silently lose it.
# Claude de-dups within the session via the once-per-session instruction in the standing
# notice rule (build_system_prompt), not the notice text — the notice text is the clean
# user-facing line only. Uses the tmux session (inherited $TMUX in the hook), not stdin, so it runs even
# when tips/update notices are off. Silent no-op if not in tmux or the option is unset
# (pre-feature session).
detect_claude_upgrade() {
    local _sess
    _sess=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null) || return 0
    [[ -z "$_sess" ]] && return 0
    local _id0
    _id0=$("$TMUX_BIN" show-options -t "$_sess" -v @claude-mux-claude-id 2>/dev/null)
    [[ -z "$_id0" ]] && return 0
    local _id_now
    _id_now=$(claude_binary_id)
    if [[ "$_id_now" != "$_id0" ]]; then
        echo "<assistant-must-display>claude-mux: Claude Code was upgraded since this session started. Say \"restart this session\" to load the new binary.</assistant-must-display>"
    fi
}

# UserPromptSubmit hook handler. Injects (via stdout) a daily tip and the two
# actionable notices (update available, Claude Code upgraded) into the conversation
# context, the only delivery path proven to surface in Remote Control. The tip fires
# once per day GLOBALLY (a single stamp tip-state/tip.json) and only in the "home"
# session; the actionable notices are persist-while-relevant (re-injected every prompt
# while their condition holds, no burn-on-emit gate). Must return fast and never block
# on the network: the GitHub API call is delegated to a disowned --update-check-bg process.
on_prompt() {
    local _state_dir="$CLAUDE_MUX_DIR/tip-state"

    # Parse the hook's stdin JSON for just the synthetic "Ready?" handshake flag. The
    # tip is now gated on the home session + a global daily stamp (no session_id key),
    # and the actionable notices keep no per-session state, so session_id is not read.
    local _is_handshake
    _is_handshake=$(/usr/bin/python3 -c '
import json, sys
try: obj = json.load(sys.stdin)
except Exception: obj = {}
print("1" if (obj.get("prompt", "") or "").strip() == "Ready?" else "0")' 2>/dev/null)

    # The "Ready?" handshake is a synthetic prompt claude-mux sends itself after a
    # restart / compact-reconnect, not a real user turn. The session's two-line ready
    # reply suppresses any injected text, so a tip / update / upgrade notice here is
    # swallowed AND burns its once-per-day / throttle / once-per-change budget. No-op
    # so the first REAL prompt surfaces them.
    [[ "$_is_handshake" == "1" ]] && exit 0

    # Claude Code upgrade detection is always-on and needs no session_id; runs after
    # the handshake check so a "Ready?" turn never consumes the one-shot notice.
    local _bin_notice
    _bin_notice=$(detect_claude_upgrade)

    # Cheap guard: if both features are off there is nothing else to inject — flush
    # any upgrade notice and stop.
    if [[ "${TIP_OF_DAY:-true}" != "true" && "${UPDATE_CHECK:-true}" != "true" ]]; then
        [[ -n "$_bin_notice" ]] && printf '%s\n' "$_bin_notice"
        exit 0
    fi

    local _today _now
    _today=$(date +%Y-%m-%d)
    _now=$(date +%s)

    local _out=""

    # ── Daily tip: HOME session only, once per day GLOBALLY ──────────────────
    # No longer keyed on session_id (that UUID rotates on every /clear and restart,
    # which re-showed the tip constantly). Only the always-on "home" session emits
    # tips (they are orchestration-themed), gated by a single global stamp tip.json:
    # the first home prompt of a new day shows the tip and writes today's date; every
    # later prompt that day — any conversation, any restart — finds it and stays silent.
    # The read-modify-write on tip.json is intentionally unlocked: only one "home"
    # session exists and its prompts serialize, so the sole race (a queued -s message
    # vs a typed prompt in the same instant) can at worst print the tip twice — cosmetic,
    # accepted, not worth a lock.
    if [[ "${TIP_OF_DAY:-true}" == "true" ]]; then
        local _sess
        _sess=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null)
        if [[ "$_sess" == "home" ]]; then
            local _tip_file="$_state_dir/tip.json" _tip_date
            _tip_date=$(/usr/bin/python3 -c '
import json, sys
try: print(json.load(open(sys.argv[1])).get("tip_date", "") or "_")
except Exception: print("_")' "$_tip_file" 2>/dev/null)
            [[ -z "$_tip_date" ]] && _tip_date="_"
            if [[ "$_tip_date" != "$_today" ]]; then
                local _tip
                _tip=$(tip_of_day 2>/dev/null || true)
                if [[ -n "$_tip" ]]; then
                    _out+="<assistant-must-display>claude-mux tip: $_tip</assistant-must-display>"$'\n'
                    mkdir -p "$_state_dir" 2>/dev/null
                    /usr/bin/python3 -c 'import json,sys
json.dump({"tip_date": sys.argv[2]}, open(sys.argv[1],"w"))' \
                        "$_tip_file" "$_today" 2>/dev/null || true
                    # One-time sweep of orphaned per-session <uuid>.json stamps left by
                    # the old gate (8-4-4-4-12 UUID shape). Explicitly exclude tip.json.
                    find "$_state_dir" -maxdepth 1 -name '*-*-*-*-*.json' ! -name tip.json -delete 2>/dev/null || true
                fi
            fi
        fi
    fi

    # ── Update notice (persist-while-relevant; cache-gated) ──────────────────
    if [[ "${UPDATE_CHECK:-true}" == "true" ]]; then
        local _cache="$CLAUDE_MUX_DIR/.update-check"
        local _last_check=0 _latest="" _gnotify=0
        if [[ -f "$_cache" ]]; then
            read -r _last_check _latest _gnotify < "$_cache" 2>/dev/null || true
        fi
        [[ -z "$_last_check" ]] && _last_check=0

        # persist-while-relevant: re-inject every prompt while a newer version is
        # cached. The condition self-clears when the user updates (VERSION rises past
        # _latest), so there is no per-session stamp to burn — a missed relay just
        # retries next turn. Claude de-dups within the conversation via the
        # once-per-session instruction in the standing notice rule (build_system_prompt).
        if [[ -n "$_latest" ]] && version_gt "$_latest" "$VERSION"; then
            _out+="<assistant-must-display>claude-mux: update available — version $_latest is out (current: $VERSION). Say \"update claude-mux\" to update.</assistant-must-display>"$'\n'
        fi

        # Refresh the cache in the background if it is stale (>24h). Never block.
        if (( _now - _last_check > 86400 )); then
            # The lock is a directory: mkdir is atomic on POSIX, so it doubles as
            # a test-and-set. Only the process that creates it spawns the check;
            # concurrent prompts that lose the race simply skip.
            local _lock="$CLAUDE_MUX_DIR/.update-checking"
            # Stale guard: a lock older than 5 minutes means the prior background
            # check died before clearing it; remove it so a fresh one can acquire.
            if [[ -d "$_lock" ]]; then
                local _lock_mtime
                _lock_mtime=$(stat -f '%m' "$_lock" 2>/dev/null || stat -c '%Y' "$_lock" 2>/dev/null || echo 0)
                (( _now - _lock_mtime >= 300 )) && rmdir "$_lock" 2>/dev/null
            fi
            if mkdir "$_lock" 2>/dev/null; then
                ( "$CLAUDE_MUX_BIN" --update-check-bg >/dev/null 2>&1 & )
            fi
        fi
    fi

    # Prepend the always-on upgrade notice (computed before the cheap-guard).
    [[ -n "$_bin_notice" ]] && _out="${_bin_notice}"$'\n'"${_out}"

    # Emit accumulated notices; UserPromptSubmit injects stdout into context.
    [[ -n "$_out" ]] && printf '%s' "$_out"
    exit 0
}

# Shared ready-handshake monitor. Spawns a disowned background poller that waits
# for the shell prompt to return in session $1, then sends "Ready?" + Enter to
# trigger the two-line ready handshake (reconnects Remote Control and makes the
# session confirm ready + report its model/mode). $2 is a short label for log
# lines ("Compact" / "Clear"). Used by both on_compact and on_clear so the two
# paths cannot drift. Returns immediately.
spawn_ready_handshake_monitor() {
    local _sess="$1" _label="${2:-Handshake}"
    [[ -z "$_sess" ]] && return 0
    (
        # Lead-in: wait for the triggering command to clear the prompt before polling.
        sleep 5
        # Poll every 0.5s, up to 120s (240 iterations) for prompt to return.
        _hpoll=0; _found=false; _hpane=""
        while [[ $_hpoll -lt 240 ]]; do
            sleep 0.5
            _hpane=$("$TMUX_BIN" capture-pane -t "$_sess" -p 2>/dev/null) || break
            echo "$_hpane" | grep -qE '^❯|^> ' && { _found=true; break; }
            (( _hpoll++ ))
        done
        if [[ "$_found" != "true" ]]; then
            log "$_label monitor timed out for '$_sess'; skipping ready handshake"
            exit 0
        fi
        # Guard: don't ping a session that was intentionally killed.
        "$TMUX_BIN" has-session -t "$_sess" 2>/dev/null || exit 0
        sleep 2
        log "$_label complete in '$_sess'; sending Ready? to trigger handshake"
        "$TMUX_BIN" send-keys -t "$_sess" -l "Ready?" 2>/dev/null \
            && "$TMUX_BIN" send-keys -t "$_sess" Enter 2>/dev/null
    ) &
    disown
}

# PreCompact hook handler. Fires for every /compact regardless of how it was
# triggered (manual, auto, or via -s). Spawns the shared monitor to reconnect
# Remote Control once compact completes. Returns immediately — Claude Code waits
# for the hook to exit before starting the compact.
on_compact() {
    local _sess
    _sess=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null) || return 0
    [[ -z "$_sess" ]] && return 0
    spawn_ready_handshake_monitor "$_sess" "Compact"
}

# SessionStart hook handler, gated to source == "clear". After /clear (in-pane or
# via -s), makes the session confirm ready and report its model, at parity with
# compact. SessionStart also fires on startup/resume/compact, where the launch
# path already handshakes — a duplicate Ready? there would race the launch
# handshake at the most fragile moment — so we fail closed: read the hook stdin
# JSON and no-op unless source is exactly "clear". The installed hook also carries
# matcher "clear" (Claude Code invokes it only on clear); this stdin check is the
# belt-and-suspenders guard against a hand-edited settings file that drops it.
on_clear() {
    local _src
    _src=$(/usr/bin/python3 -c '
import json, sys
try: obj = json.load(sys.stdin)
except Exception: obj = {}
print((obj.get("source", "") or "").strip())' 2>/dev/null)
    [[ "$_src" == "clear" ]] || return 0
    local _sess
    _sess=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null) || return 0
    [[ -z "$_sess" ]] && return 0
    spawn_ready_handshake_monitor "$_sess" "Clear"
}

# Background update check spawned (disowned) by on_prompt. Performs the GitHub
# API call, refreshes the update cache, and clears the in-flight lock. Produces
# no output and always exits 0 — it must never disturb the session.
update_check_bg() {
    local _cache="$CLAUDE_MUX_DIR/.update-check"
    local _lock="$CLAUDE_MUX_DIR/.update-checking"
    local _now _last_check=0 _latest="" _gnotify=0
    _now=$(date +%s)
    if [[ -f "$_cache" ]]; then
        read -r _last_check _latest _gnotify < "$_cache" 2>/dev/null || true
    fi
    [[ -z "$_gnotify" ]] && _gnotify=0

    local _api _new_latest
    # 5s timeout (vs check_for_update's 3s): this runs disowned in the background,
    # so a slightly longer wait costs nothing and tolerates a slow network.
    _api=$(curl -sf --max-time 5 \
        "https://api.github.com/repos/pereljon/claude-mux/releases/latest" 2>/dev/null)
    if [[ -n "$_api" ]]; then
        _new_latest=$(echo "$_api" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' | head -1)
        if [[ -n "$_new_latest" ]]; then
            # Reset the global notify timer if the version changed (keeps the TTY
            # check_for_update path's throttle honest).
            [[ "$_new_latest" != "$_latest" ]] && _gnotify=0
            echo "$_now $_new_latest $_gnotify" > "$_cache" 2>/dev/null || true
        fi
    fi
    # Clear the lock (a directory; rm -rf also tolerates a legacy file lock).
    rm -rf "$_lock" 2>/dev/null
    exit 0
}

# Update TIP_OF_DAY in ~/.claude-mux/config. Creates the line if missing.
set_tip_config() {
    local value="$1"  # true or false
    local config="$CLAUDE_MUX_CONFIG"
    [[ ! -f "$config" ]] && return
    if grep -q '^TIP_OF_DAY=' "$config" 2>/dev/null; then
        local tmp
        tmp=$(mktemp "${TMPDIR:-/tmp}/claude-mux-tip-XXXXXX") || return
        sed "s/^TIP_OF_DAY=.*/TIP_OF_DAY=$value/" "$config" > "$tmp" && mv "$tmp" "$config" || rm -f "$tmp"
    else
        printf '\nTIP_OF_DAY=%s\n' "$value" >> "$config"
    fi
}

# Walk all known project dirs and call setup_claude_mux_permissions() on each.
# This re-runs the idempotent permission+hook setup, which adds or removes the
# UserPromptSubmit --on-prompt hook based on the current TIP_OF_DAY / UPDATE_CHECK
# values, and backfills the always-on PreCompact --on-compact hook.
# Tallies outcomes into globals so install_hooks_command can report a summary;
# callers that don't care (enable_tips/disable_tips) simply ignore them.
HOOKS_SCANNED=0
HOOKS_PATCHED=0
HOOKS_CURRENT=0
HOOKS_FAILED=0
update_all_project_hooks() {
    discover_projects
    local dirs=("$BASE_DIR")
    dirs+=("${PROJECT_DIRS[@]}")
    if [[ ${#HIDDEN_PROJECT_DIRS[@]} -gt 0 ]]; then
        dirs+=("${HIDDEN_PROJECT_DIRS[@]}")
    fi
    HOOKS_SCANNED=0; HOOKS_PATCHED=0; HOOKS_CURRENT=0; HOOKS_FAILED=0
    local _dir _is_home _rc
    for _dir in "${dirs[@]}"; do
        [[ ! -d "$_dir/.claude" ]] && continue
        _is_home=false
        [[ "$_dir" == "$BASE_DIR" ]] && _is_home=true
        (( HOOKS_SCANNED++ ))
        setup_claude_mux_permissions "$_dir" "$_is_home"; _rc=$?
        case "$_rc" in
            10) (( HOOKS_PATCHED++ )) ;;
            0)  (( HOOKS_CURRENT++ )) ;;
            *)  (( HOOKS_FAILED++ )) ;;
        esac
    done
}

# --install-hooks: backfill the claude-mux hooks (incl. the v2.0.1 PreCompact
# --on-compact RC-reconnect hook) into every project's settings.local.json that
# is missing them. Idempotent; edits on-disk files only (no session restart).
install_hooks_command() {
    update_all_project_hooks
    local verb="patched"
    [[ "$DRY_RUN" == "true" ]] && verb="would patch"
    echo "Scanned ${HOOKS_SCANNED} project(s): ${verb} ${HOOKS_PATCHED}, ${HOOKS_CURRENT} already current."
    (( HOOKS_FAILED > 0 )) && echo "${HOOKS_FAILED} project(s) could not be updated — see $LOG_FILE."
    return 0
}

enable_tips() {
    TIP_OF_DAY=true
    set_tip_config "true"
    update_all_project_hooks
    echo "Tips enabled. A daily tip will appear once per day in the home session."
}

disable_tips() {
    TIP_OF_DAY=false
    set_tip_config "false"
    update_all_project_hooks
    if [[ "${UPDATE_CHECK:-true}" == "true" ]]; then
        echo "Tips disabled. (The on-prompt hook stays active to deliver update notices.)"
    else
        echo "Tips disabled. The on-prompt hook has been removed from all projects."
    fi
}

# Remove all claude-mux artifacts: hooks, permissions, LaunchAgent, and optionally config.
do_uninstall() {
    echo "Uninstalling claude-mux..."
    echo ""

    # 1. Remove tip hooks from all projects
    TIP_OF_DAY=false
    discover_projects
    local dirs=("$BASE_DIR")
    dirs+=("${PROJECT_DIRS[@]}")
    if [[ ${#HIDDEN_PROJECT_DIRS[@]} -gt 0 ]]; then
        dirs+=("${HIDDEN_PROJECT_DIRS[@]}")
    fi

    local _dir _settings _count=0
    for _dir in "${dirs[@]}"; do
        _settings="$_dir/.claude/settings.local.json"
        [[ ! -f "$_settings" ]] && continue
        # Remove claude-mux hooks and permission rules
        if /usr/bin/python3 - "$_settings" 2>/dev/null <<'PYEOF'
import json, sys
path = sys.argv[1]
try:
    with open(path) as f: d = json.load(f)
except Exception: sys.exit(1)

changed = False

# Remove claude-mux hooks: legacy Stop --tipotd, UserPromptSubmit --on-prompt,
# PreCompact --on-compact, SessionStart --on-clear
hooks = d.get('hooks', {})
for key, suffix in (('Stop', '--tipotd'), ('UserPromptSubmit', '--on-prompt'), ('PreCompact', '--on-compact'), ('SessionStart', '--on-clear')):
    entries = hooks.get(key, [])
    kept = [
        entry for entry in entries
        if not any(h.get('command', '').endswith(suffix) for h in entry.get('hooks', []))
    ]
    if len(kept) != len(entries):
        changed = True
        if kept:
            hooks[key] = kept
        else:
            hooks.pop(key, None)
if changed and not hooks:
    d.pop('hooks', None)

# Remove claude-mux permission rules
perms = d.get('permissions', {})
allow = perms.get('allow', [])
new_allow = [r for r in allow if 'claude-mux' not in r]
if len(new_allow) != len(allow):
    changed = True
    perms['allow'] = new_allow

# Remove claude-mux additionalDirectories entry
additional = perms.get('additionalDirectories', [])
new_additional = [p for p in additional if 'claude-mux' not in p]
if len(new_additional) != len(additional):
    changed = True
    if new_additional:
        perms['additionalDirectories'] = new_additional
    else:
        perms.pop('additionalDirectories', None)

# Clean up empty structures
if not perms.get('allow'):
    perms.pop('allow', None)
if not perms.get('additionalDirectories'):
    perms.pop('additionalDirectories', None)
if not perms:
    d.pop('permissions', None)

if not changed:
    sys.exit(2)

if d:
    with open(path, 'w') as f: json.dump(d, f, indent=2)
else:
    import os
    os.remove(path)
PYEOF
        then
            (( _count++ ))
        fi
    done
    echo "  Cleaned settings.local.json in $_count project(s)"

    # 2. Unload and remove LaunchAgent
    local _plist="$HOME/Library/LaunchAgents/com.user.claude-mux.plist"
    if [[ -f "$_plist" ]]; then
        launchctl unload "$_plist" 2>/dev/null || true
        rm -f "$_plist"
        echo "  Removed LaunchAgent"
    else
        echo "  LaunchAgent not found (skipped)"
    fi

    # 3. Optionally remove config directory
    echo ""
    if [[ -t 0 && -t 1 ]]; then
        printf "Remove %s? (config, templates, logs) [y/N]: " "$CLAUDE_MUX_DIR"
        read -r _answer
        case "${_answer:-n}" in
            [Yy]|[Yy]es)
                rm -rf "$CLAUDE_MUX_DIR"
                echo "  Removed $CLAUDE_MUX_DIR"
                ;;
            *)
                echo "  Kept $CLAUDE_MUX_DIR"
                ;;
        esac
    else
        echo "  Kept $CLAUDE_MUX_DIR (non-interactive; remove manually if desired)"
    fi

    echo ""
    echo "claude-mux uninstalled. The claude-mux binary is still at $CLAUDE_MUX_BIN — remove it manually if desired."
}

save_template_command() {
    local name="$1"
    local dir="${2:-}"

    if [[ -z "$name" ]]; then
        echo "ERROR: --save-template requires a NAME" >&2
        return 1
    fi

    # Resolve source directory (session name or current session)
    local src_dir
    src_dir=$(resolve_session_dir "$dir") || return 1

    if [[ ! -d "$src_dir" ]]; then
        echo "ERROR: '$src_dir' is not a directory" >&2
        return 1
    fi

    local src_claude="$src_dir/CLAUDE.md"
    if [[ ! -f "$src_claude" ]]; then
        echo "ERROR: No CLAUDE.md found in $src_dir" >&2
        return 1
    fi

    # Transform name: lowercase, non-alphanumeric → '-', add .md
    local safe_name
    safe_name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]' | tr -c '[:alnum:]' '-')
    local tpl_path="$TEMPLATES_DIR/${safe_name}.md"

    # Guard against path traversal
    local _real_tpl _real_tmpldir
    _real_tmpldir="$(cd "$TEMPLATES_DIR" 2>/dev/null && pwd -P)"
    if [[ -z "$_real_tmpldir" ]]; then
        echo "ERROR: Templates directory '$TEMPLATES_DIR' not found" >&2
        return 1
    fi
    _real_tpl="${_real_tmpldir}/${safe_name}.md"
    if [[ "$_real_tpl" != "$_real_tmpldir/"* ]]; then
        echo "ERROR: Template name resolves outside templates directory" >&2
        return 1
    fi

    # Warn on overwrite unless --force
    if [[ -f "$tpl_path" && "$FORCE" != "true" ]]; then
        echo "ERROR: Template '${safe_name}.md' already exists. Use --force to overwrite." >&2
        return 1
    fi

    [[ "$DRY_RUN" == "true" ]] && { echo "Would save: $src_claude → $tpl_path"; return 0; }

    mkdir -p "$TEMPLATES_DIR"
    cp "$src_claude" "$tpl_path"
    echo "Saved: ${safe_name}.md"
}

# Rename or move a project directory, migrating Claude Code history and
# homunculus registry entries to the new path.
#
# mode=rename: RENAME_DST is a plain name (no slash); renamed inside same parent.
# mode=move:   RENAME_DST is a parent directory; project moves there keeping its name.
rename_move_command() {
    local src_arg="$1"
    local dst_arg="$2"
    local mode="$3"   # "rename" or "move"

    if [[ -z "$src_arg" || -z "$dst_arg" ]]; then
        echo "ERROR: --${mode} requires two arguments" >&2
        return 1
    fi

    # Resolve and validate source (session name)
    local src_abs
    src_abs=$(resolve_session_dir "$src_arg") || return 1
    if [[ ! -d "$src_abs" ]]; then
        echo "ERROR: '$src_abs' is not a directory" >&2
        return 1
    fi
    src_abs=$(cd "$src_abs" && pwd -P)

    # Guard: refuse BASE_DIR
    local norm_base
    norm_base=$(cd "$BASE_DIR" 2>/dev/null && pwd -P) || norm_base="$BASE_DIR"
    if [[ "$src_abs" == "$norm_base" ]]; then
        echo "ERROR: Cannot rename or move the home session directory" >&2
        return 1
    fi

    # Compute destination absolute path
    local dst_abs
    if [[ "$mode" == "rename" ]]; then
        if [[ "$dst_arg" == */* ]]; then
            echo "ERROR: --rename NEW should be a name only (no path separators). Use --move to change the parent directory." >&2
            return 1
        fi
        dst_abs="$(dirname "$src_abs")/$dst_arg"
    else
        # Destination for --move is the parent directory the project moves INTO.
        # Smart detection: if the user passed the full destination path
        # (PARENT_DIR/SESSION) instead of just PARENT_DIR, strip the trailing
        # SESSION component so both forms work.
        local src_basename
        src_basename=$(basename "$src_abs")
        local dst_parent="$dst_arg"
        if [[ "$(basename "$dst_parent")" == "$src_basename" && ! -d "$dst_parent" ]]; then
            # Looks like a full destination path; use its parent
            dst_parent=$(dirname "$dst_parent")
        fi
        if [[ ! -d "$dst_parent" ]]; then
            echo "ERROR: Destination parent '$dst_parent' is not a directory" >&2
            echo "Hint: --move expects the PARENT directory the project moves into (must already exist), not the new full project path." >&2
            return 1
        fi
        dst_parent=$(cd "$dst_parent" && pwd -P)
        dst_abs="$dst_parent/$src_basename"
    fi

    # Guard: destination must not exist
    if [[ -e "$dst_abs" ]]; then
        echo "ERROR: Destination '$dst_abs' already exists" >&2
        return 1
    fi

    # Guard: protected session requires --force
    local session
    session=$(session_name_for_dir "$src_abs")
    if [[ -f "$src_abs/.claudemux-protected" && "$FORCE" != "true" ]]; then
        echo "ERROR: '$session' is protected. Use --force to rename/move." >&2
        return 1
    fi

    local old_enc new_enc
    old_enc=$(encode_claude_path "$src_abs")
    new_enc=$(encode_claude_path "$dst_abs")

    # Dry run: show what would happen
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would ${mode}: $src_abs → $dst_abs"
        local old_hist="$HOME/.claude/projects/$old_enc"
        if [[ -d "$old_hist" ]]; then
            echo "Would rename history: $old_enc → $new_enc"
        else
            echo "No history to migrate (never had a session)"
        fi
        if [[ -f "$HOME/.claude/homunculus/projects.json" ]]; then
            echo "Would update homunculus registry"
        fi
        if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
            echo "Would stop session '$session' and restart as '$(basename "$dst_abs")'"
        fi
        return 0
    fi

    # Stop session if running
    local was_running=false
    if "$TMUX_BIN" has-session -t "$session" 2>/dev/null; then
        was_running=true
        echo "Stopping session '$session'..."
        shutdown_single_session "$session" "true"
    fi

    # Move the directory
    if ! mv "$src_abs" "$dst_abs"; then
        echo "ERROR: Failed to move '$src_abs' to '$dst_abs'" >&2
        return 1
    fi

    # Rename ~/.claude/projects/ history folder
    local old_hist="$HOME/.claude/projects/$old_enc"
    local new_hist="$HOME/.claude/projects/$new_enc"
    if [[ -d "$old_hist" ]]; then
        if mv "$old_hist" "$new_hist" 2>/dev/null; then
            echo "Migrated history: $old_enc → $new_enc"
        else
            echo "WARNING: Could not rename history folder '$old_hist' (non-fatal)" >&2
        fi
    fi

    # Update homunculus projects.json
    # Paths are passed via env vars to avoid single-quote injection in Python literals.
    local hom_projects="$HOME/.claude/homunculus/projects.json"
    if [[ -f "$hom_projects" ]]; then
        _RENAME_FILE="$hom_projects" _RENAME_SRC="$src_abs" _RENAME_DST="$dst_abs" \
        python3 -c "
import json, sys, os
try:
    fpath = os.environ['_RENAME_FILE']
    src = os.environ['_RENAME_SRC']
    dst = os.environ['_RENAME_DST']
    with open(fpath, 'r') as f:
        data = json.load(f)
    updated = 0
    for v in data.values():
        if isinstance(v, dict) and v.get('root') == src:
            v['root'] = dst
            updated += 1
    with open(fpath, 'w') as f:
        json.dump(data, f, indent=2)
    if updated:
        print('Updated homunculus projects.json (' + str(updated) + ' entr' + ('y' if updated == 1 else 'ies') + ')')
except Exception as e:
    print('WARNING: homunculus projects.json update failed: ' + str(e), file=sys.stderr)
" 2>&1 || true

        # Update per-project project.json files
        local hom_dir="$HOME/.claude/homunculus/projects"
        if [[ -d "$hom_dir" ]]; then
            while IFS= read -r -d '' proj_json; do
                _RENAME_FILE="$proj_json" _RENAME_SRC="$src_abs" _RENAME_DST="$dst_abs" \
                python3 -c "
import json, os
try:
    fpath = os.environ['_RENAME_FILE']
    src = os.environ['_RENAME_SRC']
    dst = os.environ['_RENAME_DST']
    with open(fpath, 'r') as f:
        data = json.load(f)
    if isinstance(data, dict) and data.get('root') == src:
        data['root'] = dst
        with open(fpath, 'w') as f:
            json.dump(data, f, indent=2)
except Exception:
    pass
" 2>/dev/null
            done < <(find "$hom_dir" -name "project.json" -print0 2>/dev/null)
        fi
    fi

    local src_name dst_name
    src_name=$(basename "$src_abs")
    dst_name=$(basename "$dst_abs")
    echo "Done: $src_name → $dst_name"

    # Restart session in new location if it was running
    if [[ "$was_running" == "true" ]]; then
        echo "Restarting session as '$dst_name'..."
        local mux_bin
        mux_bin=$(command -v claude-mux 2>/dev/null) || mux_bin="${BASH_SOURCE[0]}"
        "$mux_bin" -d "$dst_abs" --no-attach 2>&1
    fi
}

