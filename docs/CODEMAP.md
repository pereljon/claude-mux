# claude-mux Code Map

Navigation reference for the `claude-mux` script. Use this to locate functions and config vars. For logic and control flow, see `docs/SKELETON.md`.

**Current version:** 1.15.0 (~4135 lines)

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
| `guide` | 130 | `()` | Print conversational command reference (`--guide`) |
| `echo_hint` | 163 | `(text)` | Print a hint line with formatting |
| `echo_hint_end` | 169 | `()` | Print hint end marker |
| `commands_help` | 177 | `()` | Print full CLI reference (`--commands`) |
| `config_help` | 236 | `()` | Print all config vars with defaults and descriptions (`--config-help`) |
| `usage` | 331 | `()` | Print short usage summary (`-h`) |
| `set_command` | 398 | `(flag_name, command_name)` | Set COMMAND, error on conflict |
| `log` | 742 | `(message)` | Write timestamped entry to LOG_FILE (stdout in --dry-run) |
| `version_gt` | 761 | `(a, b)` | Return 0 if version a > b |
| `check_for_update` | 774 | `()` | Non-blocking daily update check via GitHub API (TTY only); caches result |
| `do_update` | 822 | `()` | Download and install latest release; offer restart |
| `generate_plist` | 916 | `()` | Print LaunchAgent plist XML to stdout |
| `write_install_config` | 958 | `(base_dir, launchagent_mode, home_model, permission_mode, cross_session)` | Write `~/.claude-mux/config` |
| `do_install` | 1025 | `()` | Interactive setup wizard; calls `write_install_config`, installs plist |
| `claude_running_in_session` | 1275 | `(session_name)` | Return 0 if claude process found in session's process tree (2 levels deep) |
| `sanitize_session_name` | 1296 | `(raw_name)` | Strip non-`[a-zA-Z0-9-]` chars; return sanitized name |
| `apply_tmux_options` | 1301 | `(session_name)` | Apply TMUX_* config vars to session options |
| `get_version_prompt_lines` | 1325 | `()` | Return version string + optional update notice for injection |
| `get_session_mode` | 1355 | `(session_name)` | Read `permissions.defaultMode` from session's settings.local.json |
| `build_system_prompt` | 1390 | `(session_name, permission_mode)` | Build full injection prompt string |
| `attach_to_session` | 1504 | `(session_name)` | Attach or switch-client to a tmux session |
| `get_managed_session_names` | 1601 | `()` | Populate `MANAGED_SESSIONS` array from tmux user option |
| `is_managed_session` | 1613 | `(session_name)` | Return 0 if session is in MANAGED_SESSIONS |
| `is_protected_session` | 1624 | `(session_name)` | Return 0 if `@claude-mux-protected=1` in tmux |
| `is_claude_mux_session` | 1634 | `(session_name)` | Return 0 if `@claude-mux-managed=1` in tmux |
| `shutdown_single_session` | 1641 | `(session_name)` | Send /exit, wait 30s, kill-session |
| `shutdown_claude_sessions` | 1676 | `()` | Shut down all managed sessions; skip protected unless FORCE=true |
| `status_claude_sessions` | 1760 | `([show_all])` | Print session list (`-l` / `-L`); wraps in `<assistant-must-display>` when not TTY |
| `ensure_git_repo` | 1903 | `(dir)` | Run `git init` if dir is not already a git repo |
| `setup_gitignore` | 1913 | `(dir)` | Create `.gitignore` with `.claudemux-*` entry |
| `ensure_gitignore_entry` | 1969 | `(dir, pattern)` | Add pattern to `.gitignore` if not already present |
| `resolve_session_dir` | 1989 | `(session_name)` | Return working dir for a named session (tmux or PROJECT_DIRS scan) |
| `hide_command` | 2026 | `(session_name)` | Create `.claudemux-ignore` marker |
| `session_name_for_dir` | 2066 | `(dir)` | Return session name that would be assigned to dir |
| `protect_command` | 2080 | `(session_name)` | Create `.claudemux-protected` marker; set tmux option |
| `unprotect_command` | 2120 | `(session_name)` | Remove `.claudemux-protected` marker; clear tmux option |
| `move_to_trash` | 2159 | `(path)` | Move path to system Trash (macOS) |
| `delete_command` | 2184 | `(session_name, force, yes)` | Shut down session, move folder to Trash |
| `show_command` | 2267 | `(session_name)` | Remove `.claudemux-ignore` marker |
| `setup_default_mode` | 2292 | `(project_dir)` | Write `permissions.defaultMode` to `.claude/settings.local.json` |
| `setup_claude_mux_permissions` | 2343 | `(project_dir)` | Add claude-mux to allow list; register UserPromptSubmit `--on-prompt` hook, remove legacy Stop `--tipotd` hook |
| `setup_multi_coder_files` | 2494 | `(project_dir)` | Create AGENTS.md / GEMINI.md symlinks to CLAUDE.md |
| `detect_github_ssh_accounts` | 2541 | `()` | Parse `~/.ssh/config` for GitHub accounts; set `GITHUB_SSH_INFO` |
| `create_claude_session` | 2570 | `(session_name, working_dir, [mode_override], [fresh_start])` | Core session launcher: create tmux session, write launch script, poll for ready, send Ready? |
| `migrate_stray_sessions` | 2724 | `()` | Claim existing tmux sessions that have Claude running but lack managed marker |
| `discover_projects` | 2780 | `()` | Scan BASE_DIR for directories with `.claude/`; return list |
| `ensure_base_dir` | 2810 | `()` | Create BASE_DIR if it doesn't exist |
| `start_sessions` | 2822 | `()` | Launch all discovered projects (`-a`) |
| `launch_single_session` | 2871 | `()` | Home/LaunchAgent session path: uses LAUNCH_DIR, LAUNCH_SESSION_NAME, HOME_LAUNCH |
| `encode_claude_path` | 3025 | `(path)` | URL-encode a path for Claude's project directory naming |
| `tip_of_day` | 3033 | `()` | Select and print one tip (no gating; used by `--tip` and `on_prompt`) |
| `on_prompt` | 3096 | `()` | UserPromptSubmit hook: inject per-session daily tip + update notice; spawn background update check (`--on-prompt`) |
| `update_check_bg` | 3204 | `()` | Disowned background GitHub release check; refresh cache, clear lock (`--update-check-bg`) |
| `set_tip_config` | 3234 | `(enabled)` | Write TIP_OF_DAY to config |
| `update_all_project_hooks` | 3251 | `()` | Walk all projects and call `setup_claude_mux_permissions` |
| `enable_tips` | 3267 | `()` | Set TIP_OF_DAY=true, update all hooks |
| `disable_tips` | 3274 | `()` | Set TIP_OF_DAY=false, update all hooks |
| `do_uninstall` | 3286 | `()` | Remove plist, hooks (Stop + UserPromptSubmit), permissions, optionally config |
| `save_template_command` | 3403 | `(name, [dir])` | Copy CLAUDE.md from dir (or current project) to templates dir |
| `rename_move_command` | 3463 | `(src, dst, mode)` | Rename or move a project with history migration |
| `list_templates` | 3644 | `()` | Print available templates from TEMPLATES_DIR |
| `apply_template` | 3669 | `(template_name, project_dir)` | Copy template to project's CLAUDE.md |
| `create_new_project` | 3722 | `()` | `-n` path: mkdir, git init, apply template, launch session |
| `autolaunch_dispatch` | 3778 | `()` | LaunchAgent entry point; dispatches based on LAUNCHAGENT_MODE |

---

## Dispatch Table

| Flag | COMMAND value | Entry point |
|---|---|---|
| `-d DIR` or positional arg | `launch` | `launch_single_session` |
| `-n DIR` | `new` | `create_new_project` |
| `-l` | `list` | `status_claude_sessions` |
| `-L` | `list-all` | `status_claude_sessions true` |
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
| `--on-prompt` | `on-prompt` | `on_prompt` (UserPromptSubmit hook) |
| `--update-check-bg` | `update-check-bg` | `update_check_bg` (background, disowned) |
| `--tipotd` | `tipotd` | legacy no-op (early exit; pre-v1.15.0 Stop hooks) |
| `--enable-tips` / `--disable-tips` | `enable-tips` / `disable-tips` | `enable_tips` / `disable_tips` |
| `--uninstall` | `uninstall` | `do_uninstall` |

---

## Marker File Registry

Per-project state files. All use `.claudemux-` prefix. Auto-added to `.gitignore`.

| File | Created by | Removed by | Meaning |
|---|---|---|---|
| `.claudemux-ignore` | `hide_command` | `show_command` | Hide from `-L` and `discover_projects` |
| `.claudemux-protected` | `protect_command`, `--install` (BASE_DIR only) | `unprotect_command` | Protect from `--shutdown`; requires `--force` |

**Global state files** (under `~/.claude-mux/`, not per-project):

| File | Written by | Read by | Meaning |
|---|---|---|---|
| `.update-check` | `check_for_update`, `update_check_bg` | `on_prompt`, `get_version_prompt_lines`, `check_for_update` | Cached release info: `<last_check> <latest> <last_notify>` |
| `.update-checking` | `on_prompt` (lock before bg spawn) | `on_prompt` | In-flight update-check lock; 5-min stale guard; cleared by `update_check_bg` |
| `tip-state/<session_id>.json` | `on_prompt` | `on_prompt` | Per-session gate: `{tip_date, update_notify, notify_version}` |

**tmux user options** (session-runtime, not files):

| Option | Set by | Meaning |
|---|---|---|
| `@claude-mux-managed` | `create_claude_session`, `launch_single_session` | Session is managed by claude-mux |
| `@claude-mux-protected` | `create_claude_session` at launch (if marker present) | Session is protected |

---

## Two Session Launch Paths

| Function | Used for | tmux method | Ready poller |
|---|---|---|---|
| `create_claude_session` | All regular sessions (`-d`, `-n`, `--restart`) | `send-keys "bash launch_script"` into existing pane | Yes - polls pane 20×0.5s, sends Ready? |
| `launch_single_session` | Home session (LaunchAgent, `-d` with HOME_LAUNCH=true) | `new-session ... "bash launch_script"` as initial command | No - Claude starts directly |
