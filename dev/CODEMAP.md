# claude-mux Code Map

Navigation reference for the `claude-mux` script. Use this to locate functions and config vars. For logic and control flow, see `dev/SKELETON.md`.

**Current version:** 2.4.0 (~6000 lines, built from `src/*.sh`)

> **The function→`module:line` index is GENERATED**, not hand-maintained: see
> [`CODEMAP.index.md`](CODEMAP.index.md) (run `make codemap` to regenerate). That file is
> the authoritative location map — a module label there can never be mistyped (it's
> src-derived). This file keeps the **prose**: per-function purposes/signatures, config
> vars, dispatch table, marker registry, and the how-to sections. See
> `dev/features/make-codemap.md` for why.

## Source Layout (`src/`)

`claude-mux` is generated from 14 ordered fragments by `make build` (see `dev/IMPLEMENTATION-SPEC.md` → "Build / Source Layout"). The fragments are contiguous slices of the built file, in this order; the built line ranges below let you map any absolute line number to its fragment. **Which functions live in each module is in the generated [`CODEMAP.index.md`](CODEMAP.index.md) ("Functions by module"); the "Contents" column below is a prose summary only.**

| Module | Built lines | Contents |
|---|---|---|
| `src/00-defaults.sh` | 1-109 | shebang, `VERSION`, `MIN_AGENTS_MD_VERSION`, default config vars |
| `src/10-flags.sh` | 110-696 | flag parsing + `guide`/`commands_help`/`config_help` |
| `src/20-config.sh` | 697-857 | user-config sourcing + migration, constants, deprecated `MULTI_CODER_FILES`/`--no-multi-coder` once-only warning |
| `src/30-helpers.sh` | 858-1750 | general helpers (`migration_lock_active`, `check_for_update`, `do_update`, `get_version_prompt_lines`, `agents_md_*` gate helpers, `build_system_prompt`) |
| `src/35-validate-deps.sh` | 1751-1881 | attach helper, validate `-d`/`-n`, dep check (tmux/claude required only for session-managing commands; dep-free commands like `list-templates`/`tip`/`*-tips`/`install-hooks`/`migrate-agents-md` exempt) |
| `src/40-shutdown.sh` | 1882-2211 | shutdown functions |
| `src/50-restore-state.sh` | 2212-3039 | restore-state (`restore_state_*`, `should_be_alive`, `poll_until_ready`) |
| `src/55-session-launch.sh` | 3040-3455 | `await_ready_handshake`, `restart_caller_in_place`, `restart_sessions_in`, `create_claude_session` |
| `src/60-discovery.sh` | 3456-3556 | migrate stray, discover projects, ensure base dir |
| `src/65-agents-md-migration.sh` | 3557-4364 | `--migrate-agents-md`: scan/classify, report, lock, manifest, apply, verify, drift notice (`migrate_agents_md`, `am_*`, `agents_md_drift_notice`) |
| `src/70-start-launch.sh` | 4365-4639 | `start_sessions`, `launch_single_session` (both *call* `build_system_prompt`, defined in `30-helpers`) |
| `src/75-tip-notices.sh` | 4640-5411 | `tip_of_day`, `detect_claude_upgrade`, `on_prompt`, `spawn_ready_handshake_monitor`, `on_compact`, `on_clear`, update machinery |
| `src/80-templates-restore.sh` | 5412-5696 | `list_templates`, `apply_template`, `autorestore_walk`, `autolaunch_dispatch` |
| `src/90-dispatch.sh` | 5697-6035 | `check_for_update` call (defined in `30-helpers`), first-run guard `case`, dispatch `case` |

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
| `TEMPLATES_DIR` | `~/.claude-mux/templates` | Instructions-file template files (written as AGENTS.md when supported, else CLAUDE.md) |
| `DEFAULT_TEMPLATE` | `default.md` | Template applied on `-n` |
| `LAUNCHAGENT_MODE` | `home` | LaunchAgent behavior: `none` or `home` |
| `HOME_SESSION_MODEL` | `sonnet` | Model for the home session |
| `AUTORESTORE` | `true` | Self-healing: the `--autolaunch` tick restores marked sessions whose Claude died |
| `STAGGER_CONCURRENCY` | `3` | Max sessions the restore tick launches per `STARTING_WINDOW` |
| `STARTING_WINDOW` | `90` | Seconds over which `STAGGER_CONCURRENCY` is counted (via `last_attempt_ts`) |
| `UPDATE_CHECK` | `true` | Check GitHub for newer versions |
| `MULTI_CODER_FILES` | `""` (deprecated, ignored) | Accepted no-op since 2.4.0; claude-mux no longer creates AGENTS.md/GEMINI.md symlinks. Once-only warning (`~/.claude-mux/.deprecated-multi-coder-warned`). `--no-multi-coder` is likewise a no-op. To be removed in a later minor |
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
| `build_system_prompt` | `(session_name, [permission_mode], [project_dir])` | Build full injection prompt string (defined in `30-helpers`; called from launch paths). `project_dir` (resolved from `@claude-mux-dir`/`resolve_session_dir` if omitted) drives the conditional "never create CLAUDE.md" rule: emitted only when `agents_md_supported` && `agents_md_path_clear` && `agents_md_in_walkup`. Also carries the `--migrate-agents-md` feature-list, trigger and lookup lines |
| `migration_lock_active` | `()` | Return 0 if `BASE_DIR/.claudemux-migrating/` is an ACTIVE lock (live pid and < 60 min, or no pid file yet and < 10 s). Read-only: a dead-pid, missing-pid or old lock logs a WARN and returns 1; never deletes it. Honored by `autolaunch_dispatch`, `autorestore_walk`, `create_claude_session`, `launch_home_session` |
| `claude_version_line` | `()` | First line of `"${CLAUDE_BIN:-claude}" --version` |
| `agents_md_supported` | `()` | Return 0 if Claude Code >= `MIN_AGENTS_MD_VERSION` (numeric x.y.z on the first token; pre-release suffix ignored). Fails closed (1) when `claude` is missing or the version is unparseable |
| `agents_md_path_clear` | `(dir)` | Return 0 if no CLAUDE.md / CLAUDE.local.md (case-insensitive; file or symlink) exists in dir or any ancestor to `/` (`~/.claude/CLAUDE.md` exempt); on 1 prints the first offender |
| `agents_md_in_walkup` | `(dir)` | Return 0 if an AGENTS.md (case-insensitive) exists in dir or any ancestor |
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
| `setup_claude_mux_permissions` | `(project_dir, [is_home])` | Add claude-mux to allow list; register UserPromptSubmit `--on-prompt` + PreCompact `--on-compact` + SessionStart(matcher `clear`) `--on-clear` hooks, remove legacy Stop `--tipotd` hook. Returns 0=already current, 10=patched/would-patch, 1=error |
| `detect_github_ssh_accounts` | `()` | Parse `~/.ssh/config` for GitHub accounts; set `GITHUB_SSH_INFO` |
| `poll_until_ready` | `(session, [timeout=120])` | Wait until a session is genuinely ready: busy = "esc to interrupt" in bottom 4 lines; ready = not busy + prompt + quiescent. Handles trust/bypass auto-accept. Returns 0 ready / 1 timeout |
| `await_ready_handshake` | `(session)` | `--await-ready` body: re-capture `@claude-mux-claude-id` (so the upgrade notice self-clears on in-place restart — the only restart path skipping the kill+recreate capture sites), then `poll_until_ready` then send "Ready?". Used by the looped launch wrapper to fire the handshake from OUTSIDE the pane after an in-place restart relaunch (the pane itself is busy relaunching claude) |
| `confirm_model_switch` | `(session)` | `--confirm-model-switch` body: auto-confirm Claude Code's cached "Switch model?" dialog after an in-session `/model <id>` send (backgrounded, detached, from the `send` handler for `/model ` payloads only). Recognize-then-confirm: polls the pane ~30s, positively matches the dialog bottom-anchored (`Switch model?` + `No, go back` + `❯…Yes, switch to` in the last 6 lines) so a scrolled-up transcript quote can't false-fire, then sends a single Enter (option 1 pre-highlighted); never re-keys. Single-confirmer `mkdir` lock (`$TMPDIR/claude-mux-confirm-<session>.lock`, stale-reclaim + EXIT-trap cleanup) so two overlapping sends can't double-key an empty prompt. Dead-session early-exit |
| `restart_caller_in_place` | `(session, [fresh])` | Restart the calling session in place: set `@claude-mux-restart` (`resume`/`fresh`) + send `/exit`. Must NOT kill-session the caller (SIGHUP would kill this script). The looped wrapper relaunches in-pane + handshakes |
| `restart_sessions_in` | `(list, reason)` | Restart running sessions from newline-separated `name|dir` pairs (extracted from the `--restart` restart-all path; also used by `--migrate-agents-md --apply`). Honors `DRY_RUN`/`FRESH_START`; non-callers shut down + recreated one by one under `.claudemux-restarting`, caller last via `restart_caller_in_place`. Sets `RESTART_FAILED_SESSIONS` (reset per call), prints `WARN: failed to restart: ...` before the caller's in-place step, returns 0 if none failed. `--restart` ignores the return value (exit code unchanged) |
| `launch_home_session` | `()` | Sets `LAUNCH_DIR=$BASE_DIR`/`HOME_LAUNCH=true`/`LAUNCH_SESSION_NAME=home` then calls `launch_single_session` (preserves `HOME_SESSION_MODEL`, which `create_claude_session` would drop). Callers set `NO_ATTACH=true` first for a non-attaching start. Refuses (returns 1) while `migration_lock_active`. Used by `autolaunch_dispatch` and the stopped-home branches of `--start`/`--restart` |
| `create_claude_session` | `(session_name, working_dir, [mode_override], [fresh_start])` | Core launcher: refuses (returns 1) while `migration_lock_active`; no longer creates multi-coder symlinks; passes `working_dir` to `build_system_prompt`; tmux session, set `@claude-mux-dir`/`@claude-mux-claude-id`, write `.claudemux-running`, write LOOPED launch wrapper (prompt at `<dir>/.claudemux-prompt` via `--append-system-prompt-file`; clean exit with `@claude-mux-restart` set → regenerate prompt via `--print-system-prompt` + relaunch in-pane + background `--await-ready`; clean exit without it → remove marker+prompt and `kill-session`), `poll_until_ready`, send Ready? (prompt NOT deleted - wrapper owns its lifetime) |
| `migrate_stray_sessions` | `()` | Claim existing tmux sessions that have Claude running but lack managed marker |
| `discover_projects` | `()` | Scan BASE_DIR for directories with `.claude/`; return list |
| `ensure_base_dir` | `()` | Create BASE_DIR if it doesn't exist |
| `start_sessions` | `()` | Launch all discovered projects (`-a`) |
| `launch_single_session` | `()` | Home/LaunchAgent/`-d` path (does NOT check the migration lock: it is the wrapper's in-place relaunch entry; the lock is honored one level up in `launch_home_session`/`autolaunch_dispatch`): sets `@claude-mux-dir`/`@claude-mux-claude-id`, marker, LOOPED launch wrapper (prompt at `<dir>/.claudemux-prompt`; same restart-in-place loop as `create_claude_session`, regenerating with mode `auto`), backgrounded `poll_until_ready`+Ready? (prompt NOT deleted); uses LAUNCH_DIR, LAUNCH_SESSION_NAME, HOME_LAUNCH |
| `encode_claude_path` | `(path)` | URL-encode a path for Claude's project directory naming |
| `tip_of_day` | `()` | Select and print one tip (no gating; used by `--tip` and `on_prompt`) |
| `claude_binary_id` | `()` | Identity of the `claude` executable: `realpath:mtime` (cask realpath or in-place mtime changes on upgrade) |
| `detect_claude_upgrade` | `()` | Compare `@claude-mux-claude-id` vs current; echo upgrade notice (wrapped in `<assistant-must-display>`) while they differ. persist-while-relevant: NO ack-on-emit — re-injects every prompt until a restart re-captures the id (so a missed relay can't lose it) |
| `spawn_ready_handshake_monitor` | `(session, [label])` | Shared: spawn a disowned poller that waits for the prompt to return in `session`, then sends `Ready?`+Enter to trigger the two-line ready handshake. Used by both `on_compact` and `on_clear` so the paths can't drift |
| `on_compact` | `()` | PreCompact hook: call `spawn_ready_handshake_monitor` to reconnect RC after compact (`--on-compact`) |
| `on_clear` | `()` | SessionStart hook, gated to `source == "clear"` (reads hook stdin JSON, no-ops on startup/resume/compact where the launch path already handshakes): call `spawn_ready_handshake_monitor` so the session confirms ready + reports its model after `/clear`, at parity with compact (`--on-clear`) |
| `on_prompt` | `()` | UserPromptSubmit hook: stdin parse for the `is_handshake` flag only → no-op on the synthetic `Ready?` handshake → Claude Code upgrade notice (always-on, persist-while-relevant) + daily tip (**home session only**, once/day via the global `tip-state/tip.json` stamp — no `session_id` key; v2.0.15) + update notice (persist-while-relevant while `latest > VERSION`) + AGENTS.md drift notice (`agents_md_drift_notice`, home only, daily); all three wrapped in `<assistant-must-display>` carrying only the clean user-facing line (relay/once-per-session instruction lives in the standing notice rule in `build_system_prompt`, not the notice text — v2.0.13); spawn bg update check (`--on-prompt`) |
| `update_check_bg` | `()` | Disowned background GitHub release check; refresh cache, clear lock (`--update-check-bg`) |
| `set_tip_config` | `(enabled)` | Write TIP_OF_DAY to config |
| `update_all_project_hooks` | `()` | Walk all projects, call `setup_claude_mux_permissions`; tally `HOOKS_SCANNED/PATCHED/CURRENT` globals. Callers: `enable_tips`, `disable_tips`, `install_hooks_command`, `do_update` |
| `install_hooks_command` | `()` | `--install-hooks`: backfill claude-mux hooks (incl. PreCompact `--on-compact` + SessionStart `--on-clear`) into all projects; print scanned/patched/current summary |
| `enable_tips` | `()` | Set TIP_OF_DAY=true, update all hooks |
| `disable_tips` | `()` | Set TIP_OF_DAY=false, update all hooks |
| `do_uninstall` | `()` | Remove plist, hooks (Stop + UserPromptSubmit), permissions, optionally config |
| `save_template_command` | `(name, [dir])` | Copy AGENTS.md (else CLAUDE.md) from dir (or current project) to templates dir |
| `rename_move_command` | `(src, dst, mode)` | Rename or move a project with history migration |
| `list_templates` | `()` | Print available templates from TEMPLATES_DIR |
| `apply_template` | `(template_name, project_dir)` | Copy template to project's AGENTS.md when `agents_md_supported` and `agents_md_path_clear` on the parent path, else CLAUDE.md (reason logged). Skips when either file already exists (case-insensitive) |
| `create_new_project` | `()` | `-n` path: mkdir, git init, apply template, launch session |
| `notify_home` | `(msg)` | Best-effort one-line notice to the home session (only if home looks idle) |
| `autorestore_walk` | `()` | Restore tick (skips the whole tick while `migration_lock_active`): relaunch should-be-alive but dead sessions, staggered, with crash-loop guard. Consumes `.claudemux-restarting` on sight (rmdir + skip this tick) so it doesn't race an in-flight `--restart` |
| `autolaunch_dispatch` | `()` | LaunchAgent entry point (launches nothing while `migration_lock_active`); starts home (via `launch_home_session`) then calls `autorestore_walk` (mode `home`) |
| `migrate_agents_md` | `()` | `--migrate-agents-md [--apply] [--no-restart]` driver (`65-agents-md-migration`). Scan + report (read-only default); `--dry-run` = report + planned ops only. On `--apply`: gate/abort preflight, lock, post-lock rescan (TOCTOU signature compare), manifest, ops top-down, verify, release lock, marker, restart via `restart_sessions_in` unless `--no-restart`. Returns 1 on any abort/failure |
| `am_scan` | `(base)` | Scan BASE (physical path; prunes `.git`/`node_modules`/`-*`/`worktrees`, not `.claude`), classify each directory in C-locale parent-first order, add UNWRITABLE and ABOVE findings. Fills the parallel `AM_*` record arrays |
| `am_classify_dir` | `(dir)` | Classify one directory from the names the directory listing returned (exact compare; case variants -> CASE-VARIANT); appends records |
| `am_scan_above` | `(base)` | ABOVE findings: CLAUDE.md / CLAUDE.local.md in ancestors of BASE up to `/` |
| `am_set_exempt` | `()` | Set the exempt paths for user-level `~/.claude/CLAUDE.md` (literal + physical) |
| `am_enrich` | `()` | Per action record: repo root, tracked-ness, method (`git mv` / `mv + git add` / `mv` / `git rm --cached + unlink` / `unlink`), sha256, git-state JSON; then `am_preflight_extra` |
| `am_preflight_extra` | `()` | Adds LOCKED-INDEX (git `index.lock` present in a repo a git op touches) and DEST-EXISTS (MIGRATE destination already exists) abort findings |
| `am_signature` | `()` | Plan signature (class, path, dest, link target, method, hash per record); compared between the report scan and the post-lock rescan |
| `am_verify_walkup` | `(base)` | Post-condition/pre-restart check: prints any CLAUDE.md / CLAUDE.local.md under BASE or in an ancestor; returns 1 if any. Also used by the drift notice |
| `am_running_sessions` | `(base)` | Sets `AM_RUN_IN` (`name|dir` under BASE, physical trailing-slash prefix match) and `AM_RUN_OUT` |
| `am_lock_state` / `am_take_lock` / `am_release_lock` / `am_on_signal` | `()` | Lock text for the report; take `BASE_DIR/.claudemux-migrating/` (mkdir mutex, pid then started, takes over a stale one, sets EXIT/INT/TERM/HUP traps); release it; signal handler (manifest status `interrupted`, release, exit 130) |
| `am_write_manifest` | `(status)` | Atomically (temp + `mv`) write `~/.claude-mux/migrations/agents-md-<timestamp>.json` with every operation and its status |
| `am_run_op` | `(index)` | Revalidate the plan's assumption, run one operation by its recorded method (`mv -n` for MIGRATE), post-check (source gone, dest regular file, hash unchanged). Sets `AM_OP_ERR` |
| `am_print_report` | `(gate_ok, version)` | Print the report: version gate, lock, findings, running sessions, CLAUDE.md textual references (listed, never edited), Result line |
| `am_failure_block` | `(done_n, offenders)` | Print the "TREE IS MIXED" block, remove the migrated marker |
| `am_json_str` / `am_json_or_null` / `am_sha256` / `am_git_tracked` / `am_kind` / `am_git_file_json` / `am_add_record` / `am_is_class` / `am_list_names` | | Small helpers: JSON string escaping, sha256, `git ls-files --error-unmatch` test, file kind by exact name, git-state JSON, record append, class-list membership, case-insensitive name listing |
| `agents_md_drift_notice` | `(state_dir)` | Daily home-only drift check called from `on_prompt`: when `.claudemux-agents-migrated` exists and a CLAUDE.md / CLAUDE.local.md reappeared, print an `<assistant-must-display>` notice. Stamp `tip-state/agents-drift`. Always returns 0 |

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
| `--restart` | `restart` | inline (also starts a *stopped* session via Change A); restart-all delegates to `restart_sessions_in` |
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
| `--migrate-agents-md [--apply] [--no-restart]` | `migrate-agents-md` | `migrate_agents_md` (`--apply`/`--no-restart` set `MIGRATE_APPLY`/`MIGRATE_NO_RESTART`; validation error unless COMMAND is `migrate-agents-md`) |
| `--tip` | `tip` | `tip_of_day` |
| `--on-compact` | `on-compact` | `on_compact` (PreCompact hook) |
| `--on-clear` | `on-clear` | `on_clear` (SessionStart hook, gated to source=clear) |
| `--await-ready SESSION` | `await-ready` | `await_ready_handshake` (internal; called by the looped launch wrapper) |
| `--confirm-model-switch SESSION` | `confirm-model-switch` | `confirm_model_switch` (internal; backgrounded by the `-s` send handler for `/model ` payloads) |
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
| `.claudemux-migrating/` (at `BASE_DIR`) | `am_take_lock` (`mkdir`; contains `pid` + `started`) | `am_release_lock` (after verify, on failure, EXIT/signal trap); a stale lock is taken over by the next `--apply` | AGENTS.md migration lock (directory). Read (never consumed) by `migration_lock_active` in `autolaunch_dispatch`, `autorestore_walk`, `create_claude_session`, `launch_home_session`. Stale = dead/missing pid or > 60 min: launchers WARN and continue |
| `.claudemux-agents-migrated` (at `BASE_DIR`) | `migrate_agents_md` after verify (also when `--apply` finds the tree already migrated) | `am_failure_block`; by hand | Record only, not a gate: date, file count, manifest path. Its presence arms the daily drift notice |
| `.claudemux-prompt` | `create_claude_session` / `launch_single_session` at launch; regenerated in-pane by the wrapper (`--print-system-prompt`) on each in-place restart | launch-script teardown (clean exit, no restart pending); trap backstop | Per-session system-prompt file passed via `--append-system-prompt-file`. In the project folder (stable, not `$TMPDIR`-reaped) so it survives + regenerates across in-place relaunches. Mode 600 |

**Global state files** (under `~/.claude-mux/`, not per-project):

| File | Written by | Read by | Meaning |
|---|---|---|---|
| `.update-check` | `check_for_update`, `update_check_bg` | `on_prompt`, `get_version_prompt_lines`, `check_for_update` | Cached release info: `<last_check> <latest> <last_notify>` |
| `.update-checking` | `on_prompt` (lock before bg spawn) | `on_prompt` | In-flight update-check lock; 5-min stale guard; cleared by `update_check_bg` |
| `tip-state/tip.json` | `on_prompt` | `on_prompt` | Global daily tip gate: `{tip_date}` only, written by the `home` session (v2.0.15). Home-only + one global stamp replaced the per-session key, which rotated on every `/clear`/restart and re-showed the tip. |
| `tip-state/<session_id>.json` | (legacy) | — | **Legacy** per-session tip gate (pre-v2.0.15). No longer read or written; swept on the first home tip fire. |
| `tip-state/agents-drift` | `agents_md_drift_notice` | `agents_md_drift_notice` | Daily gate (date stamp) for the AGENTS.md drift scan; written by the `home` session only |
| `.deprecated-multi-coder-warned` | `20-config.sh` (on first `MULTI_CODER_FILES` / `--no-multi-coder` use) | `20-config.sh` | Once-only deprecation warning stamp; not shown for hook/background commands |
| `migrations/agents-md-<timestamp>.json` | `am_write_manifest` | (manual recovery) | Migration manifest: every planned operation, method, hashes, git state, per-op status. Written before the first change |
| `restore-state/<session>.json` | `restore_state_write` (tick) | `autorestore_walk`, `should_be_alive`, `autorestore_status` | Crash-loop/stagger state: `{last_attempt_ts, death_count, tripped}`; cleared by `restore_state_clear` on user restart |

**Internal constants** (set after config; not user-overridable): `MIN_AGENTS_MD_VERSION` (`2.1.277`, min Claude Code with the AGENTS.md fallback; `00-defaults`), `RESTORE_STATE_DIR` (`~/.claude-mux/restore-state`), `AUTORESTORE_MIN_HEALTHY` (300s), `AUTORESTORE_TRIP_THRESHOLD` (3).

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
