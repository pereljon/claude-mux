# claude-mux Code Map

Navigation reference for the `claude-mux` script. Use this to locate functions and config vars. For logic and control flow, see `dev/SKELETON.md`.

**Current version:** 2.0.3 (~4650 lines)

## How to Use

- **Finding a function**: look it up in the Function Index, then jump to that line range in the script.
- **Line numbers are approximate** - the table is accurate when written but drifts as lines are added above a function. Always grep to confirm: `grep -n "^function_name()" claude-mux`.
- **Tracing a flag to its handler**: use the Dispatch Table to map a CLI flag to its COMMAND value, then find the handler in the Function Index.

## How to Maintain

Update this file when:
- A function is **added, renamed, or removed** - update the Function Index (name, line, signature, purpose)
- A **CLI flag** is added or its dispatch changes - update the Dispatch Table
- A **config variable** is added, renamed, or its default changes - update Config Variables
- A **marker file or tmux option** is added - update the Marker File Registry
- The **version or line count** changes significantly - update the header line above

**Line number policy**: re-verify the full Function Index after any release that adds or rearranges large blocks of code. For patch releases touching only a few functions, update only the affected rows. Use `grep -n "^function_name()" claude-mux` to get the current line.

---

## Config Variables

All defined at top of script; any can be overridden in `~/.claude-mux/config`.

| Variable | Default | Description |
|---|---|---|
| `BASE_DIR` | `~/Claude` | Root directory scanned for Claude projects |
| `LOG_DIR` | `~/Library/Logs` | Directory for `claude-mux.log` |
| `DEFAULT_PERMISSION_MODE` | `auto` | Permission mode for new/restarted sessions. Valid: `""`, `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions` |
| `ALLOW_CROSS_SESSION_CONTROL` | `false` | When true, sessions can send keystrokes to other managed sessions |
| `TMUX_EXTENDED_KEYS` | `true` | Enable Shift+Enter and modified keys |
| `TMUX_TITLE_FORMAT` | `#S` | Terminal/tab title format |
| `TMUX_MOUSE` | `true` | Mouse support |
| `TMUX_HISTORY_LIMIT` | `50000` | Scrollback lines |
| `TMUX_CLIPBOARD` | `true` | OSC 52 clipboard integration |
| `TMUX_DEFAULT_TERMINAL` | `tmux-256color` | Terminal type |
| `TMUX_ESCAPE_TIME` | `10` | Escape delay (ms) |
| `TMUX_MONITOR_ACTIVITY` | `true` | Monitor activity in other sessions |
| `TEMPLATES_DIR` | `~/.claude-mux/templates` | CLAUDE.md template files |
| `DEFAULT_TEMPLATE` | `default.md` | Template applied on `-n` |
| `LAUNCHAGENT_MODE` | `home` | LaunchAgent behavior: `none` or `home` |
| `HOME_SESSION_MODEL` | `sonnet` | Model for the home session |
| `AUTORESTORE` | `true` | Self-healing: the `--autolaunch` tick restores marked sessions whose Claude died |
| `STAGGER_CONCURRENCY` | `3` | Max sessions the restore tick launches per `STARTING_WINDOW` |
| `STARTING_WINDOW` | `90` | Seconds over which `STAGGER_CONCURRENCY` is counted (via `last_attempt_ts`) |
| `UPDATE_CHECK` | `true` | Check GitHub for newer versions |
| `MULTI_CODER_FILES` | `"AGENTS.md GEMINI.md"` | Symlinks created alongside CLAUDE.md |
| `TIP_OF_DAY` | `true` | Enable tip-of-the-day |
| `TIP_MODE` | `daily` | Tip selection: `daily` or `random` |
| `SLEEP_BETWEEN` | `5` | Seconds between session launches in `-a` |
| `TMUX_BIN` | `$(command -v tmux)` | tmux binary path |
| `CLAUDE_BIN` | `$(command -v claude)` | Claude binary path |

---

## Function Index

| Function | Line | Signature | Purpose |
|---|---|---|---|
| `guide` | 148 | `()` | Print conversational command reference (`--guide`) |
| `echo_hint` | 181 | `(text)` | Print a hint line with formatting |
| `echo_hint_end` | 187 | `()` | Print hint end marker |
| `commands_help` | 195 | `()` | Print full CLI reference (`--commands`) |
| `config_help` | 254 | `()` | Print all config vars with defaults and descriptions (`--config-help`) |
| `usage` | 367 | `()` | Print short usage summary (`-h`) |
| `set_command` | 434 | `(flag_name, command_name)` | Set COMMAND, error on conflict |
| `log` | 787 | `(message)` | Write timestamped entry to LOG_FILE (stdout in --dry-run) |
| `version_gt` | 806 | `(a, b)` | Return 0 if version a > b |
| `check_for_update` | 819 | `()` | Non-blocking daily update check via GitHub API (TTY only); caches result |
| `do_update` | 882 | `()` | Download and install latest release; backfill hooks via `update_all_project_hooks` on version change; offer restart |
| `generate_plist` | 961 | `()` | Print LaunchAgent plist XML to stdout |
| `write_install_config` | 1003 | `(base_dir, launchagent_mode, home_model, permission_mode, cross_session)` | Write `~/.claude-mux/config` |
| `do_install` | 1070 | `()` | Interactive setup wizard; calls `write_install_config`, installs plist |
| `claude_running_in_session` | 1320 | `(session_name)` | Return 0 if claude process found in session's process tree (2 levels deep) |
| `sanitize_session_name` | 1341 | `(raw_name)` | Strip non-`[a-zA-Z0-9-]` chars; return sanitized name |
| `apply_tmux_options` | 1346 | `(session_name)` | Apply TMUX_* config vars to session options |
| `get_version_prompt_lines` | 1370 | `()` | Return version string + optional update notice for injection |
| `get_session_mode` | 1400 | `(session_name)` | Read `permissions.defaultMode` from session's settings.local.json |
| `build_system_prompt` | 1435 | `(session_name, permission_mode)` | Build full injection prompt string |
| `attach_to_session` | 1549 | `(session_name)` | Attach or switch-client to a tmux session |
| `get_managed_session_names` | 1646 | `()` | Populate `MANAGED_SESSIONS` array from tmux user option |
| `is_managed_session` | 1658 | `(session_name)` | Return 0 if session is in MANAGED_SESSIONS |
| `is_protected_session` | 1669 | `(session_name)` | Return 0 if `@claude-mux-protected=1` in tmux |
| `is_claude_mux_session` | 1679 | `(session_name)` | Return 0 if `@claude-mux-managed=1` in tmux |
| `shutdown_single_session` | 1716 | `(session_name, [force], [preserve_marker])` | Remove `.claudemux-running` marker first (via `session_marker_dir`) unless `preserve_marker=true`, then send /exit, wait, kill-session. Restart callers pass `preserve_marker=true` so a crashed restart stays recoverable |
| `shutdown_claude_sessions` | 1725 | `()` | Shut down all managed sessions (removing each marker first); skip protected unless FORCE=true |
| `status_claude_sessions` | 1813 | `([show_all] [status_filter])` | Print session list (`-l` / `-L`) incl. `queued`/`failed` auto-restore statuses; wraps in `<assistant-must-display>` when not TTY; `status_filter` limits rows to a single status value |
| `ensure_git_repo` | 1980 | `(dir)` | Run `git init` if dir is not already a git repo |
| `setup_gitignore` | 1990 | `(dir)` | Create `.gitignore` with `.claudemux-*` entry |
| `ensure_gitignore_entry` | 2046 | `(dir, pattern)` | Add pattern to `.gitignore` if not already present |
| `write_running_marker` | 2064 | `(dir)` | Write `.claudemux-running` (auto-restore intent); skips home; auto-gitignores |
| `remove_running_marker` | 2074 | `(dir)` | Remove `.claudemux-running` (intent to stop) |
| `restore_state_last_attempt` | 2088 | `(session)` | Read `last_attempt_ts` from restore-state JSON (0 if absent) |
| `restore_state_death_count` | 2095 | `(session)` | Read `death_count` from restore-state JSON (0 if absent) |
| `restore_state_tripped` | 2103 | `(session)` | Return 0 if session is crash-loop tripped |
| `restore_state_write` | 2109 | `(session, ts, death_count, tripped)` | Write restore-state JSON (single line) |
| `restore_state_clear` | 2121 | `(session)` | Delete restore-state (un-trip on user restart) |
| `session_marker_dir` | 2131 | `(session)` | Resolve a session's launch dir via `@claude-mux-dir` (falls back to pane_current_path) |
| `should_be_alive` | 2142 | `(session, dir)` | Predicate shared by tick + `-l`: marker + AUTORESTORE + not tripped (or `.claudemux-autostart`) |
| `autorestore_status` | 2157 | `(name, dir, [fallback])` | Map a non-running session to `queued`/`failed`/`stopped`/fallback |
| `resolve_session_dir` | 2172 | `(session_name)` | Return working dir for a named session (tmux or PROJECT_DIRS scan) |
| `hide_command` | 2209 | `(session_name)` | Create `.claudemux-ignore` marker |
| `session_name_for_dir` | 2249 | `(dir)` | Return session name that would be assigned to dir |
| `protect_command` | 2263 | `(session_name)` | Create `.claudemux-protected` marker; set tmux option |
| `unprotect_command` | 2303 | `(session_name)` | Remove `.claudemux-protected` marker; clear tmux option |
| `move_to_trash` | 2342 | `(path)` | Move path to system Trash (macOS) |
| `delete_command` | 2367 | `(session_name, force, yes)` | Shut down session, move folder to Trash |
| `show_command` | 2450 | `(session_name)` | Remove `.claudemux-ignore` marker |
| `setup_default_mode` | 2475 | `(project_dir)` | Write `permissions.defaultMode` to `.claude/settings.local.json` |
| `setup_claude_mux_permissions` | 2568 | `(project_dir, [is_home])` | Add claude-mux to allow list; register UserPromptSubmit `--on-prompt` + PreCompact `--on-compact` hooks, remove legacy Stop `--tipotd` hook. Returns 0=already current, 10=patched/would-patch, 1=error |
| `setup_multi_coder_files` | 2677 | `(project_dir)` | Create AGENTS.md / GEMINI.md symlinks to CLAUDE.md |
| `detect_github_ssh_accounts` | 2724 | `()` | Parse `~/.ssh/config` for GitHub accounts; set `GITHUB_SSH_INFO` |
| `poll_until_ready` | 2846 | `(session, [timeout=120])` | Wait until a session is genuinely ready: busy = "esc to interrupt" in bottom 4 lines; ready = not busy + prompt + quiescent. Handles trust/bypass auto-accept. Returns 0 ready / 1 timeout |
| `await_ready_handshake` | 2894 | `(session)` | `--await-ready` body: `poll_until_ready` then send "Ready?". Used by the looped launch wrapper to fire the handshake from OUTSIDE the pane after an in-place restart relaunch (the pane itself is busy relaunching claude) |
| `restart_caller_in_place` | 2908 | `(session, [fresh])` | Restart the calling session in place: set `@claude-mux-restart` (`resume`/`fresh`) + send `/exit`. Must NOT kill-session the caller (SIGHUP would kill this script). The looped wrapper relaunches in-pane + handshakes |
| `create_claude_session` | 2920 | `(session_name, working_dir, [mode_override], [fresh_start])` | Core launcher: tmux session, set `@claude-mux-dir`/`@claude-mux-claude-id`, write `.claudemux-running`, write LOOPED launch wrapper (prompt at `<dir>/.claudemux-prompt` via `--append-system-prompt-file`; clean exit with `@claude-mux-restart` set → regenerate prompt via `--print-system-prompt` + relaunch in-pane + background `--await-ready`; clean exit without it → remove marker+prompt and `kill-session`), `poll_until_ready`, send Ready? (prompt NOT deleted - wrapper owns its lifetime) |
| `migrate_stray_sessions` | 2965 | `()` | Claim existing tmux sessions that have Claude running but lack managed marker |
| `discover_projects` | 3021 | `()` | Scan BASE_DIR for directories with `.claude/`; return list |
| `ensure_base_dir` | 3051 | `()` | Create BASE_DIR if it doesn't exist |
| `start_sessions` | 3063 | `()` | Launch all discovered projects (`-a`) |
| `launch_single_session` | 3280 | `()` | Home/LaunchAgent/`-d` path: sets `@claude-mux-dir`/`@claude-mux-claude-id`, marker, LOOPED launch wrapper (prompt at `<dir>/.claudemux-prompt`; same restart-in-place loop as `create_claude_session`, regenerating with mode `auto`), backgrounded `poll_until_ready`+Ready? (prompt NOT deleted); uses LAUNCH_DIR, LAUNCH_SESSION_NAME, HOME_LAUNCH |
| `encode_claude_path` | 3278 | `(path)` | URL-encode a path for Claude's project directory naming |
| `tip_of_day` | 3286 | `()` | Select and print one tip (no gating; used by `--tip` and `on_prompt`) |
| `claude_binary_id` | 3349 | `()` | Identity of the `claude` executable: `realpath:mtime` (cask realpath or in-place mtime changes on upgrade) |
| `detect_claude_upgrade` | 3363 | `()` | Compare `@claude-mux-claude-id` vs current; echo one-shot upgrade notice and ack the option |
| `on_compact` | 3515 | `()` | PreCompact hook: spawn disowned monitor that polls for prompt return post-compact, then sends Ready? to reconnect RC (`--on-compact`) |
| `on_prompt` | 3573 | `()` | UserPromptSubmit hook: Claude Code upgrade notice (always-on) + per-session daily tip + update notice; spawn bg update check (`--on-prompt`) |
| `update_check_bg` | 3698 | `()` | Disowned background GitHub release check; refresh cache, clear lock (`--update-check-bg`) |
| `set_tip_config` | 3536 | `(enabled)` | Write TIP_OF_DAY to config |
| `update_all_project_hooks` | 3669 | `()` | Walk all projects, call `setup_claude_mux_permissions`; tally `HOOKS_SCANNED/PATCHED/CURRENT` globals. Callers: `enable_tips`, `disable_tips`, `install_hooks_command`, `do_update` |
| `install_hooks_command` | 3694 | `()` | `--install-hooks`: backfill claude-mux hooks (incl. PreCompact `--on-compact`) into all projects; print scanned/patched/current summary |
| `enable_tips` | 3569 | `()` | Set TIP_OF_DAY=true, update all hooks |
| `disable_tips` | 3576 | `()` | Set TIP_OF_DAY=false, update all hooks |
| `do_uninstall` | 3588 | `()` | Remove plist, hooks (Stop + UserPromptSubmit), permissions, optionally config |
| `save_template_command` | 3705 | `(name, [dir])` | Copy CLAUDE.md from dir (or current project) to templates dir |
| `rename_move_command` | 3765 | `(src, dst, mode)` | Rename or move a project with history migration |
| `list_templates` | 3946 | `()` | Print available templates from TEMPLATES_DIR |
| `apply_template` | 3971 | `(template_name, project_dir)` | Copy template to project's CLAUDE.md |
| `create_new_project` | 4024 | `()` | `-n` path: mkdir, git init, apply template, launch session |
| `notify_home` | 4082 | `(msg)` | Best-effort one-line notice to the home session (only if home looks idle) |
| `autorestore_walk` | 4240 | `()` | Restore tick: relaunch should-be-alive but dead sessions, staggered, with crash-loop guard. Consumes `.claudemux-restarting` on sight (rmdir + skip this tick) so it doesn't race an in-flight `--restart` |
| `autolaunch_dispatch` | 4177 | `()` | LaunchAgent entry point; starts home then calls `autorestore_walk` (mode `home`) |

---

## Dispatch Table

| Flag | COMMAND value | Entry point |
|---|---|---|
| `-d DIR` or positional arg | `launch` | `launch_single_session` |
| `-n DIR` | `new` | `create_new_project` |
| `-l` | `list` | `status_claude_sessions` |
| `-L` | `list-all` | `status_claude_sessions true "${STATUS_FILTER:-}"` |
| `-L --status STATUS` | `list-all` | `status_claude_sessions true STATUS` |
| `--list-templates` | `list-templates` | `list_templates` |
| `-a` | `start` | `start_sessions` |
| `-t SESSION` | `attach` | `attach_to_session` |
| `-s SESSION CMD` | `send` | inline |
| `--shutdown` | `shutdown` | `shutdown_claude_sessions` |
| `--restart` | `restart` | inline |
| `--permission-mode MODE SESSION` | `setmode` | inline |
| `--get-mode SESSION` | `getmode` | `get_session_mode` |
| `--update` | `update` | `do_update` |
| `--install` | `install` | `do_install` |
| `--autolaunch` | `autolaunch` | `autolaunch_dispatch` |
| `--hide` / `--show` | `hide` / `show` | `hide_command` / `show_command` |
| `--protect` / `--unprotect` | `protect` / `unprotect` | `protect_command` / `unprotect_command` |
| `--delete SESSION` | `delete` | `delete_command` |
| `--rename SRC DST` | `rename` | `rename_move_command` |
| `--move SRC DST` | `move` | `rename_move_command` |
| `--save-template NAME` | `save-template` | `save_template_command` |
| `--tip` | `tip` | `tip_of_day` |
| `--on-compact` | `on-compact` | `on_compact` (PreCompact hook) |
| `--await-ready SESSION` | `await-ready` | `await_ready_handshake` (internal; called by the looped launch wrapper) |
| `--print-system-prompt SESSION [MODE]` | `print-system-prompt` | `build_system_prompt` (internal; wrapper regenerates the prompt on in-place restart) |
| `--on-prompt` | `on-prompt` | `on_prompt` (UserPromptSubmit hook) |
| `--update-check-bg` | `update-check-bg` | `update_check_bg` (background, disowned) |
| `--tipotd` | `tipotd` | legacy no-op (early exit; pre-v1.15.0 Stop hooks) |
| `--enable-tips` / `--disable-tips` | `enable-tips` / `disable-tips` | `enable_tips` / `disable_tips` |
| `--install-hooks` | `install-hooks` | `install_hooks_command` |
| `--uninstall` | `uninstall` | `do_uninstall` |

---

## Marker File Registry

Per-project state files. All use `.claudemux-` prefix. Auto-added to `.gitignore`.

| File | Created by | Removed by | Meaning |
|---|---|---|---|
| `.claudemux-ignore` | `hide_command` | `show_command` | Hide from `-L` and `discover_projects` |
| `.claudemux-protected` | `protect_command`, `--install` (BASE_DIR only) | `unprotect_command` | Protect from `--shutdown`; requires `--force` |
| `.claudemux-running` | `write_running_marker` (at launch; not home) | `remove_running_marker` (`--shutdown`), launch-script clean-exit (rc 0, no restart pending) | Auto-restore intent: session should be alive; tick restores it if Claude died. Preserved through `--restart` (`shutdown_single_session` `preserve_marker=true`) |
| `.claudemux-restarting/` | restart paths: restart-all loop, single-named `--restart` for non-callers (`mkdir`) | same paths after `create_claude_session` (`rmdir`); `autorestore_walk` consume-on-sight (`rmdir`) | Transient restart lock (directory). Presence = restart in flight; auto-restore defers one tick. NOT used for in-place caller restarts (the pane never goes down) |
| `.claudemux-prompt` | `create_claude_session` / `launch_single_session` at launch; regenerated in-pane by the wrapper (`--print-system-prompt`) on each in-place restart | launch-script teardown (clean exit, no restart pending); trap backstop | Per-session system-prompt file passed via `--append-system-prompt-file`. In the project folder (stable, not `$TMPDIR`-reaped) so it survives + regenerates across in-place relaunches. Mode 600 |

**Global state files** (under `~/.claude-mux/`, not per-project):

| File | Written by | Read by | Meaning |
|---|---|---|---|
| `.update-check` | `check_for_update`, `update_check_bg` | `on_prompt`, `get_version_prompt_lines`, `check_for_update` | Cached release info: `<last_check> <latest> <last_notify>` |
| `.update-checking` | `on_prompt` (lock before bg spawn) | `on_prompt` | In-flight update-check lock; 5-min stale guard; cleared by `update_check_bg` |
| `tip-state/<session_id>.json` | `on_prompt` | `on_prompt` | Per-session gate: `{tip_date, update_notify, notify_version}` |
| `restore-state/<session>.json` | `restore_state_write` (tick) | `autorestore_walk`, `should_be_alive`, `autorestore_status` | Crash-loop/stagger state: `{last_attempt_ts, death_count, tripped}`; cleared by `restore_state_clear` on user restart |

**Internal constants** (set after config; not user-overridable): `RESTORE_STATE_DIR` (`~/.claude-mux/restore-state`), `AUTORESTORE_MIN_HEALTHY` (300s), `AUTORESTORE_TRIP_THRESHOLD` (3).

**tmux user options** (session-runtime, not files):

| Option | Set by | Meaning |
|---|---|---|
| `@claude-mux-managed` | `create_claude_session`, `launch_single_session` | Session is managed by claude-mux |
| `@claude-mux-protected` | `create_claude_session` at launch (if marker present) | Session is protected |
| `@claude-mux-dir` | `create_claude_session`, `launch_single_session` at launch | Recorded launch (project-root) dir; authoritative source for marker removal (`session_marker_dir`) |
| `@claude-mux-claude-id` | `create_claude_session`, `launch_single_session` at launch; re-acked by `detect_claude_upgrade` | `claude` binary identity at launch (`realpath:mtime`) for Claude Code upgrade detection |
| `@claude-mux-restart` | `restart_caller_in_place` (`resume`/`fresh`) | Read + unset by the looped launch wrapper on a clean exit: signals "relaunch claude in this pane" (restart-in-place) instead of teardown. Consumed per relaunch (set-option `-u`) so one restart = one relaunch |

---

## Two Session Launch Paths

| Function | Used for | tmux method | Ready poller |
|---|---|---|---|
| `create_claude_session` | `-n`, `--restart`, setmode | `send-keys "bash launch_script"` into existing pane | Yes, synchronous - `poll_until_ready` (busy + quiescence, ~120s), then Ready? |
| `launch_single_session` | `-d` and home (LaunchAgent) | `new-session ... "bash launch_script"` as initial command | Yes, backgrounded - `poll_until_ready` in a `( ) &`, then Ready? |
