# claude-mux Code Map

Navigation reference for the `claude-mux` script. Use this to locate functions and config vars. For logic and control flow, see `dev/SKELETON.md`.

**Current version:** 2.0.9 (~4900 lines, built from `src/*.sh`)

> **The function→`module:line` index is GENERATED**, not hand-maintained: see
> [`CODEMAP.index.md`](CODEMAP.index.md) (run `make codemap` to regenerate). That file is
> the authoritative location map — a module label there can never be mistyped (it's
> src-derived). This file keeps the **prose**: per-function purposes/signatures, config
> vars, dispatch table, marker registry, and the how-to sections. See
> `dev/features/make-codemap.md` for why.

## Source Layout (`src/`)

`claude-mux` is generated from 13 ordered fragments by `make build` (see `dev/IMPLEMENTATION-SPEC.md` → "Build / Source Layout"). The fragments are contiguous slices of the built file, in this order; the built line ranges below let you map any absolute line number to its fragment. **Which functions live in each module is in the generated [`CODEMAP.index.md`](CODEMAP.index.md) ("Functions by module"); the "Contents" column below is a prose summary only.**

| Module | Built lines | Contents |
|---|---|---|
| `src/00-defaults.sh` | 1-112 | shebang, `VERSION`, default config vars |
| `src/10-flags.sh` | 113-684 | flag parsing + `guide`/`commands_help`/`config_help` |
| `src/20-config.sh` | 685-820 | user-config sourcing + migration, constants |
| `src/30-helpers.sh` | 821-1599 | general helpers (`check_for_update`, `do_update`, `get_version_prompt_lines`, `build_system_prompt`) |
| `src/35-validate-deps.sh` | 1600-1718 | attach helper, validate `-d`/`-n`, dep check |
| `src/40-shutdown.sh` | 1719-2048 | shutdown functions |
| `src/50-restore-state.sh` | 2049-2899 | restore-state (`restore_state_*`, `should_be_alive`, `poll_until_ready`) |
| `src/55-session-launch.sh` | 2900-3149 | `await_ready_handshake`, `restart_caller_in_place`, `create_claude_session` |
| `src/60-discovery.sh` | 3150-3250 | migrate stray, discover projects, ensure base dir |
| `src/70-start-launch.sh` | 3251-3517 | `start_sessions`, `launch_single_session` (both *call* `build_system_prompt`, defined in `30-helpers`) |
| `src/75-tip-notices.sh` | 3518-4252 | `tip_of_day`, `detect_claude_upgrade`, `on_prompt`, `on_compact`, update machinery |
| `src/80-templates-restore.sh` | 4253-4515 | `list_templates`, `apply_template`, `autorestore_walk`, `autolaunch_dispatch` |
| `src/90-dispatch.sh` | 4516-4897 | `check_for_update` call (defined in `30-helpers`), first-run guard `case`, dispatch `case` |

## How to Use

- **Finding a function's location**: look it up in the generated [`CODEMAP.index.md`](CODEMAP.index.md) for its `module:within-module-line` (authoritative, src-derived). **Edit the fragment, never `claude-mux` directly** (`make build` regenerates the artifact).
- **Finding a function's purpose**: the Function Reference table below carries the signature + purpose prose (no line numbers — those live in the generated index).
- **Tracing a flag to its handler**: use the Dispatch Table to map a CLI flag to its COMMAND value, then find the handler's purpose below and its location in `CODEMAP.index.md`.

## How to Maintain

Update this file when:
- A function is **added, renamed, or removed** - run `make codemap` to regenerate the location index, then update its purpose row in the Function Reference below
- A **CLI flag** is added or its dispatch changes - update the Dispatch Table
- A **config variable** is added, renamed, or its default changes - update Config Variables
- A **marker file or tmux option** is added - update the Marker File Registry
- The **version or line count** changes significantly - update the header line above

**Locations are generated, not hand-maintained.** `dev/CODEMAP.index.md` is produced by
`make codemap` from `src/*.sh`; never hand-edit it (same inversion as "edit `src/`, not
`claude-mux`"). `make check` / the pre-commit hook / CI fail if it's stale. The Function
Reference below carries only prose (purpose + signature), so it no longer drifts on line
moves — but you must still add a row when you add a function.

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

## Function Reference

| Function | Signature | Purpose |
|---|---|---|
| `guide` | `()` | Print conversational command reference (`--guide`) |
| `echo_hint` | `(text)` | Print a hint line with formatting |
| `echo_hint_end` | `()` | Print hint end marker |
| `commands_help` | `()` | Print full CLI reference (`--commands`) |
| `config_help` | `()` | Print all config vars with defaults and descriptions (`--config-help`) |
| `usage` | `()` | Print short usage summary (`-h`) |
| `set_command` | `(flag_name, command_name)` | Set COMMAND, error on conflict |
| `is_valid_model` | `(value)` | Return 0 if value is empty or a shell-safe model token (`^[A-Za-z0-9._][A-Za-z0-9._-]*$`, no leading dash). Pass-through model validation (format, not membership); the format check is the sole safety layer for the unquoted `--model` interpolation. Defined in `20-config` so the always-runs config chokepoint can call it |
| `log` | `(message)` | Write timestamped entry to LOG_FILE (stdout in --dry-run). Self-healing + non-fatal: `mkdir -p`s the log dir, best-effort write, always `return 0` (never aborts a caller under `set -e`) |
| `version_gt` | `(a, b)` | Return 0 if version a > b |
| `check_for_update` | `()` | Non-blocking daily update check via GitHub API (TTY only); caches result |
| `do_update` | `()` | Download and install latest release; backfill hooks via `update_all_project_hooks` on version change; offer restart |
| `generate_plist` | `()` | Print LaunchAgent plist XML to stdout |
| `write_install_config` | `(base_dir, launchagent_mode, home_model, permission_mode, cross_session)` | Write `~/.claude-mux/config` |
| `do_install` | `()` | Interactive setup wizard; calls `write_install_config`, installs plist |
| `claude_running_in_session` | `(session_name)` | Return 0 if claude process found in session's process tree (2 levels deep) |
| `sanitize_session_name` | `(raw_name)` | Strip non-`[a-zA-Z0-9-]` chars; return sanitized name |
| `apply_tmux_options` | `(session_name)` | Apply TMUX_* config vars to session options |
| `get_version_prompt_lines` | `()` | Return version string + optional update notice for injection |
| `get_session_mode` | `(session_name)` | Read `permissions.defaultMode` from session's settings.local.json |
| `build_system_prompt` | `(session_name, permission_mode)` | Build full injection prompt string (defined in `30-helpers`; called from launch paths) |
| `attach_to_session` | `(session_name)` | Attach or switch-client to a tmux session |
| `get_managed_session_names` | `()` | Populate `MANAGED_SESSIONS` array from tmux user option |
| `is_managed_session` | `(session_name)` | Return 0 if session is in MANAGED_SESSIONS |
| `is_protected_session` | `(session_name)` | Return 0 if `@claude-mux-protected=1` in tmux |
| `is_claude_mux_session` | `(session_name)` | Return 0 if `@claude-mux-managed=1` in tmux |
| `shutdown_single_session` | `(session_name, [force], [preserve_marker])` | Remove `.claudemux-running` marker first (via `session_marker_dir`) unless `preserve_marker=true`, then send /exit, wait, kill-session. Restart callers pass `preserve_marker=true` so a crashed restart stays recoverable |
| `shutdown_claude_sessions` | `()` | Shut down all managed sessions (removing each marker first); skip protected unless FORCE=true |
| `status_claude_sessions` | `([show_all] [status_filter])` | Print session list (`-l` / `-L`) incl. `queued`/`failed` auto-restore statuses; wraps in `<assistant-must-display>` when not TTY; `status_filter` limits rows to a single status value |
| `ensure_git_repo` | `(dir)` | Run `git init` if dir is not already a git repo |
| `setup_gitignore` | `(dir)` | Create `.gitignore` with `.claudemux-*` entry |
| `ensure_gitignore_entry` | `(dir, pattern)` | Add pattern to `.gitignore` if not already present |
| `write_running_marker` | `(dir)` | Write `.claudemux-running` (auto-restore intent); skips home; auto-gitignores |
| `remove_running_marker` | `(dir)` | Remove `.claudemux-running` (intent to stop) |
| `restore_state_last_attempt` | `(session)` | Read `last_attempt_ts` from restore-state JSON (0 if absent) |
| `restore_state_death_count` | `(session)` | Read `death_count` from restore-state JSON (0 if absent) |
| `restore_state_tripped` | `(session)` | Return 0 if session is crash-loop tripped |
| `restore_state_write` | `(session, ts, death_count, tripped)` | Write restore-state JSON (single line) |
| `restore_state_clear` | `(session)` | Delete restore-state (un-trip on user restart) |
| `session_marker_dir` | `(session)` | Resolve a session's launch dir via `@claude-mux-dir` (falls back to pane_current_path) |
| `should_be_alive` | `(session, dir)` | Predicate shared by tick + `-l`: marker + AUTORESTORE + not tripped (or `.claudemux-autostart`) |
| `autorestore_status` | `(name, dir, [fallback])` | Map a non-running session to `queued`/`failed`/`stopped`/fallback |
| `resolve_session_dir` | `(session_name)` | Return working dir for a named session (tmux or PROJECT_DIRS scan). Used by `--start` and by `--restart`'s stopped-session dir fallback (where `session_marker_dir` comes up empty) |
| `hide_command` | `(session_name)` | Create `.claudemux-ignore` marker |
| `session_name_for_dir` | `(dir)` | Return session name that would be assigned to dir |
| `protect_command` | `(session_name)` | Create `.claudemux-protected` marker; set tmux option |
| `unprotect_command` | `(session_name)` | Remove `.claudemux-protected` marker; clear tmux option |
| `move_to_trash` | `(path)` | Move path to system Trash (macOS) |
| `delete_command` | `(session_name, force, yes)` | Shut down session, move folder to Trash |
| `show_command` | `(session_name)` | Remove `.claudemux-ignore` marker |
| `setup_default_mode` | `(project_dir)` | Write `permissions.defaultMode` to `.claude/settings.local.json` |
| `setup_claude_mux_permissions` | `(project_dir, [is_home])` | Add claude-mux to allow list; register UserPromptSubmit `--on-prompt` + PreCompact `--on-compact` hooks, remove legacy Stop `--tipotd` hook. Returns 0=already current, 10=patched/would-patch, 1=error |
| `setup_multi_coder_files` | `(project_dir)` | Create AGENTS.md / GEMINI.md symlinks to CLAUDE.md |
| `detect_github_ssh_accounts` | `()` | Parse `~/.ssh/config` for GitHub accounts; set `GITHUB_SSH_INFO` |
| `poll_until_ready` | `(session, [timeout=120])` | Wait until a session is genuinely ready: busy = "esc to interrupt" in bottom 4 lines; ready = not busy + prompt + quiescent. Handles trust/bypass auto-accept. Returns 0 ready / 1 timeout |
| `await_ready_handshake` | `(session)` | `--await-ready` body: re-capture `@claude-mux-claude-id` (so the upgrade notice self-clears on in-place restart — the only restart path skipping the kill+recreate capture sites), then `poll_until_ready` then send "Ready?". Used by the looped launch wrapper to fire the handshake from OUTSIDE the pane after an in-place restart relaunch (the pane itself is busy relaunching claude) |
| `restart_caller_in_place` | `(session, [fresh])` | Restart the calling session in place: set `@claude-mux-restart` (`resume`/`fresh`) + send `/exit`. Must NOT kill-session the caller (SIGHUP would kill this script). The looped wrapper relaunches in-pane + handshakes |
| `launch_home_session` | `()` | Sets `LAUNCH_DIR=$BASE_DIR`/`HOME_LAUNCH=true`/`LAUNCH_SESSION_NAME=home` then calls `launch_single_session` (preserves `HOME_SESSION_MODEL`, which `create_claude_session` would drop). Callers set `NO_ATTACH=true` first for a non-attaching start. Used by `autolaunch_dispatch` and the stopped-home branches of `--start`/`--restart` |
| `create_claude_session` | `(session_name, working_dir, [mode_override], [fresh_start])` | Core launcher: tmux session, set `@claude-mux-dir`/`@claude-mux-claude-id`, write `.claudemux-running`, write LOOPED launch wrapper (prompt at `<dir>/.claudemux-prompt` via `--append-system-prompt-file`; clean exit with `@claude-mux-restart` set → regenerate prompt via `--print-system-prompt` + relaunch in-pane + background `--await-ready`; clean exit without it → remove marker+prompt and `kill-session`), `poll_until_ready`, send Ready? (prompt NOT deleted - wrapper owns its lifetime) |
| `migrate_stray_sessions` | `()` | Claim existing tmux sessions that have Claude running but lack managed marker |
| `discover_projects` | `()` | Scan BASE_DIR for directories with `.claude/`; return list |
| `ensure_base_dir` | `()` | Create BASE_DIR if it doesn't exist |
| `start_sessions` | `()` | Launch all discovered projects (`-a`) |
| `launch_single_session` | `()` | Home/LaunchAgent/`-d` path: sets `@claude-mux-dir`/`@claude-mux-claude-id`, marker, LOOPED launch wrapper (prompt at `<dir>/.claudemux-prompt`; same restart-in-place loop as `create_claude_session`, regenerating with mode `auto`), backgrounded `poll_until_ready`+Ready? (prompt NOT deleted); uses LAUNCH_DIR, LAUNCH_SESSION_NAME, HOME_LAUNCH |
| `encode_claude_path` | `(path)` | URL-encode a path for Claude's project directory naming |
| `tip_of_day` | `()` | Select and print one tip (no gating; used by `--tip` and `on_prompt`) |
| `claude_binary_id` | `()` | Identity of the `claude` executable: `realpath:mtime` (cask realpath or in-place mtime changes on upgrade) |
| `detect_claude_upgrade` | `()` | Compare `@claude-mux-claude-id` vs current; echo upgrade notice (wrapped in `<assistant-must-display>`) while they differ. persist-while-relevant: NO ack-on-emit — re-injects every prompt until a restart re-captures the id (so a missed relay can't lose it) |
| `on_compact` | `()` | PreCompact hook: spawn disowned monitor that polls for prompt return post-compact, then sends Ready? to reconnect RC (`--on-compact`) |
| `on_prompt` | `()` | UserPromptSubmit hook: single stdin parse (session_id + `is_handshake` + `tip_date`) → no-op on the synthetic `Ready?` handshake → Claude Code upgrade notice (always-on, persist-while-relevant) + per-session daily tip + update notice (persist-while-relevant while `latest > VERSION`); all three wrapped in `<assistant-must-display>` with MUST-relay/once-per-session wording; spawn bg update check (`--on-prompt`) |
| `update_check_bg` | `()` | Disowned background GitHub release check; refresh cache, clear lock (`--update-check-bg`) |
| `set_tip_config` | `(enabled)` | Write TIP_OF_DAY to config |
| `update_all_project_hooks` | `()` | Walk all projects, call `setup_claude_mux_permissions`; tally `HOOKS_SCANNED/PATCHED/CURRENT` globals. Callers: `enable_tips`, `disable_tips`, `install_hooks_command`, `do_update` |
| `install_hooks_command` | `()` | `--install-hooks`: backfill claude-mux hooks (incl. PreCompact `--on-compact`) into all projects; print scanned/patched/current summary |
| `enable_tips` | `()` | Set TIP_OF_DAY=true, update all hooks |
| `disable_tips` | `()` | Set TIP_OF_DAY=false, update all hooks |
| `do_uninstall` | `()` | Remove plist, hooks (Stop + UserPromptSubmit), permissions, optionally config |
| `save_template_command` | `(name, [dir])` | Copy CLAUDE.md from dir (or current project) to templates dir |
| `rename_move_command` | `(src, dst, mode)` | Rename or move a project with history migration |
| `list_templates` | `()` | Print available templates from TEMPLATES_DIR |
| `apply_template` | `(template_name, project_dir)` | Copy template to project's CLAUDE.md |
| `create_new_project` | `()` | `-n` path: mkdir, git init, apply template, launch session |
| `notify_home` | `(msg)` | Best-effort one-line notice to the home session (only if home looks idle) |
| `autorestore_walk` | `()` | Restore tick: relaunch should-be-alive but dead sessions, staggered, with crash-loop guard. Consumes `.claudemux-restarting` on sight (rmdir + skip this tick) so it doesn't race an in-flight `--restart` |
| `autolaunch_dispatch` | `()` | LaunchAgent entry point; starts home (via `launch_home_session`) then calls `autorestore_walk` (mode `home`) |

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
| `--start SESSION...` | `start-session` | inline (start-if-stopped / no-op-if-running, by name) |
| `--restart` | `restart` | inline (also starts a *stopped* session via Change A) |
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
| `tip-state/<session_id>.json` | `on_prompt` | `on_prompt` | Per-session tip gate: `{tip_date}` only (the actionable notices are persist-while-relevant, no per-session state since v2.0.10) |
| `restore-state/<session>.json` | `restore_state_write` (tick) | `autorestore_walk`, `should_be_alive`, `autorestore_status` | Crash-loop/stagger state: `{last_attempt_ts, death_count, tripped}`; cleared by `restore_state_clear` on user restart |

**Internal constants** (set after config; not user-overridable): `RESTORE_STATE_DIR` (`~/.claude-mux/restore-state`), `AUTORESTORE_MIN_HEALTHY` (300s), `AUTORESTORE_TRIP_THRESHOLD` (3).

**tmux user options** (session-runtime, not files):

| Option | Set by | Meaning |
|---|---|---|
| `@claude-mux-managed` | `create_claude_session`, `launch_single_session` | Session is managed by claude-mux |
| `@claude-mux-protected` | `create_claude_session` at launch (if marker present) | Session is protected |
| `@claude-mux-dir` | `create_claude_session`, `launch_single_session` at launch | Recorded launch (project-root) dir; authoritative source for marker removal (`session_marker_dir`) |
| `@claude-mux-claude-id` | `create_claude_session`, `launch_single_session` at launch (kill+recreate); `await_ready_handshake` on in-place restart | `claude` binary identity at launch (`realpath:mtime`) for Claude Code upgrade detection. Re-captured on every restart path so the persist-while-relevant upgrade notice self-clears (no longer acked by `detect_claude_upgrade`) |
| `@claude-mux-restart` | `restart_caller_in_place` (`resume`/`fresh`) | Read + unset by the looped launch wrapper on a clean exit: signals "relaunch claude in this pane" (restart-in-place) instead of teardown. Consumed per relaunch (set-option `-u`) so one restart = one relaunch |

---

## Two Session Launch Paths

| Function | Used for | tmux method | Ready poller |
|---|---|---|---|
| `create_claude_session` | `-n`, `--restart`, setmode | `send-keys "bash launch_script"` into existing pane | Yes, synchronous - `poll_until_ready` (busy + quiescence, ~120s), then Ready? |
| `launch_single_session` | `-d` and home (LaunchAgent) | `new-session ... "bash launch_script"` as initial command | Yes, backgrounded - `poll_until_ready` in a `( ) &`, then Ready? |
