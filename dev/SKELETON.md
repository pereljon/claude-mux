# claude-mux Script Skeleton

Pseudo-code showing the structure and logic of `claude-mux`. Use this to understand how the script works, trace a bug, or reason about the impact of a change. For function locations and config var details, see `dev/CODEMAP.md`.

## Contents

Read only the section you need - `grep -n "^## <name>" dev/SKELETON.md` for its offset, then Read that range:

- **How to Use** - navigating this file
- **How to Maintain** (+ **Non-Obvious Script Structure** - the interspersed pre-dispatch blocks that are easy to miss)
- **Top-Level Structure** - the 10 phases from shebang to dispatch
- **Main Dispatch** - the command `case` block
- **create_claude_session** - session creation, injection, ready handshake
- **launch_single_session** - direct (non-send-keys) launch path
- **poll_until_ready** - busy/quiescence readiness detector (shared by both launch paths)
- **build_system_prompt** - the injected system prompt
- **create_new_project** - new-project scaffolding
- **autorestore_walk** - the restore tick (relaunch dead-but-marked sessions, staggered, crash-loop guard)
- **autolaunch_dispatch** - LaunchAgent boot path
- **do_update** - self-update
- **shutdown_single_session / shutdown_claude_sessions** - teardown paths
- **rename_move_command** - rename/move with history migration
- **tip_of_day** - tip selection (no gating)
- **on_prompt** - UserPromptSubmit hook: per-session daily tip + persist-while-relevant update/upgrade notices (wrapped in `<assistant-must-display>`) + bg check spawn
- **update_check_bg** - disowned background GitHub release check
- **Key Invariants** - rules that must hold across changes

## How to Use

- **Tracing a bug**: find the relevant section (Top-Level Structure, Main Dispatch, or a function section), follow the pseudo-code to identify which condition or path is wrong, then use `dev/CODEMAP.md` to jump to the exact line.
- **Assessing impact of a change**: read the section for the function you're modifying, check what it calls and what calls it, look for shared state (globals like `FORCE`, `FRESH_START`, `MANAGED_SESSIONS`).
- **Don't use this for line numbers** - use `dev/CODEMAP.md` for that. This file describes logic, not locations.

## Source Layout

`claude-mux` is built from 13 ordered `src/*.sh` fragments by `make build` (byte-identical concat; see `dev/IMPLEMENTATION-SPEC.md` → "Build / Source Layout"). The fragments **are** ordered slices of the linear flow below, so this file's section order already equals the module order. The logic flow is unchanged by the split — the build runs top-to-bottom exactly as before. To open the file behind a given phase:

| Flow phase | Fragment |
|---|---|
| Defaults / config-var declarations (phase 1-2) | `src/00-defaults.sh` |
| Flag parsing (phase 4-5) + guide/commands_help/config_help | `src/10-flags.sh` |
| Legacy `--tipotd` no-op, user config, constants (phase 6-8) | `src/20-config.sh` |
| General helpers (incl. `build_system_prompt`, `check_for_update`, `do_update`) | `src/30-helpers.sh` |
| Attach + validate `-d`/`-n` + dep check (phase 9 pre-dispatch) | `src/35-validate-deps.sh` |
| Shutdown paths | `src/40-shutdown.sh` |
| restore-state / `poll_until_ready` | `src/50-restore-state.sh` |
| `await_ready_handshake` / `restart_caller_in_place` / `create_claude_session` | `src/55-session-launch.sh` |
| migrate / discover projects | `src/60-discovery.sh` |
| `start_sessions` / `launch_single_session` (call `build_system_prompt`, defined in `30-helpers`) | `src/70-start-launch.sh` |
| `tip_of_day` / `on_prompt` / `on_compact` / update machinery | `src/75-tip-notices.sh` |
| templates / `autorestore_walk` / `autolaunch_dispatch` | `src/80-templates-restore.sh` |
| Main dispatch `case` | `src/90-dispatch.sh` |

Edit fragments, never `claude-mux` directly.

## How to Maintain

Update this file when:
- A **condition or branch** is added or removed within a function
- The **call sequence** between functions changes (e.g. a new function is called before an existing one)
- A **timing value** changes (poll intervals, sleep durations, retry counts)
- A **new command** is added to the dispatch
- **Control flow** changes in the pre-dispatch section (step 9)

Do **not** update line numbers here - those belong in `dev/CODEMAP.md`.

### Non-Obvious Script Structure

The script has executable code **interspersed between function definitions**, not just at the top and bottom. There are two pre-dispatch blocks that are easy to miss:

1. **Lines ~1518-1594** (immediately after `attach_to_session()` is defined): handles the `attach` immediate dispatch, resolves `LAUNCH_DIR`/`HOME_LAUNCH`, resolves `NEW_PROJECT_DIR`, applies the autolaunch boot delay, and validates `TMUX_BIN`/`CLAUDE_BIN`. This runs as function definitions above it are parsed.
2. **Lines ~3668-3704** (after all function definitions, before the main `case` block): calls `check_for_update()` and handles the first-run config check.

When verifying this file against the script, read the entire file top-to-bottom - don't assume all executable code is at the bottom after all `function() { }` blocks.

---

## Top-Level Structure

```
#!/bin/bash

# 1. Set defaults (overridable via config)
VERSION="x.y.z"
BASE_DIR, LOG_DIR, DEFAULT_PERMISSION_MODE, TMUX_*, TIP_OF_DAY, ...

# 2. Initialize flag-state vars
COMMAND="launch"
COMMAND_SET=false
LAUNCH_DIR, RESTART_SESSIONS[], FRESH_START, ...

# 3. Define all functions (guide, log, do_install, create_claude_session, ...)

# 4. Parse args
while args remain:
    case arg:
        --restart  → COMMAND=restart, collect session names
        --start    → COMMAND=start-session, collect session names (START_SESSIONS[])
        -d DIR     → COMMAND=launch, LAUNCH_DIR=DIR
        -n DIR     → COMMAND=new, NEW_PROJECT_DIR=DIR
        --shutdown → COMMAND=shutdown, collect session names
        --fresh    → FRESH_START=true
        ...
    set_command() enforces: only one command flag allowed

# 5. Validate flag combinations
    -p, --no-template, --no-git only valid with -n
    --no-attach only valid with -d or -n
    --force only valid with --shutdown, --delete, --save-template, --rename, --move
    --fresh only valid with --start, --restart, or -d

# 6. Legacy no-op: tipotd
    if COMMAND == "tipotd":
        exit 0   # Stop hook retired in v1.15.0; pre-upgrade sessions still call it

# 7. Load user config
    source ~/.claude-mux/config   # overrides defaults
    backward compat: LAUNCHAGENT_ENABLED=true → LAUNCHAGENT_MODE=home
    validate: LAUNCHAGENT_MODE, DEFAULT_PERMISSION_MODE, HOME_SESSION_MODEL, numeric vars

# 8. Resolve runtime constants
    LOG_FILE, TMUX_BIN, CLAUDE_BIN, CLAUDE_MUX_BIN

# 9. Pre-dispatch (runs between function definitions and main dispatch)

    # Attach is handled immediately after attach_to_session() is defined
    # (line ~1518) — not in the main case block below.
    if COMMAND == "attach":
        attach_to_session(TARGET_SESSION)   # exits or falls through to tmux

    # Resolve launch directory and detect home session
    if COMMAND == "launch":
        resolve LAUNCH_DIR to absolute path
        if LAUNCH_DIR == BASE_DIR:
            HOME_LAUNCH=true, LAUNCH_SESSION_NAME="home"
        else:
            LAUNCH_SESSION_NAME = sanitize(basename(LAUNCH_DIR))

    # Resolve new-project directory and derive session name
    if COMMAND == "new":
        resolve NEW_PROJECT_DIR to absolute path
        NEW_SESSION_NAME = sanitize(basename(NEW_PROJECT_DIR))

    # Autolaunch boot delay — avoid races on initial login
    if COMMAND == "autolaunch":
        uptime=$(sysctl kern.boottime)
        if uptime <= 45s → sleep 45   # let system services initialize

    # Dependency check
    if TMUX_BIN missing or not executable → error, exit 1
    if CLAUDE_BIN missing or not executable → error, exit 1

    check_for_update()   # non-blocking, TTY-only, cached daily

    if no config and command needs it:
        if TTY → prompt "run setup now?"
        else   → error, exit 1

# 10. Main dispatch
    case COMMAND: → (see dispatch section below)
```

---

## Main Dispatch

```
case COMMAND:

  launch    → launch_single_session()
  new       → create_new_project()
  list      → status_claude_sessions()
  list-all  → status_claude_sessions(show_all=true, STATUS_FILTER)
  start     → start_sessions()
  # attach is handled in pre-dispatch (step 9), not here
  update    → do_update()
  install   → do_install()
  autolaunch → autolaunch_dispatch()
  uninstall → do_uninstall()
  tip          → tip_of_day()
  on-prompt    → on_prompt()            # UserPromptSubmit hook
  update-check-bg → update_check_bg()   # disowned background curl
  enable-tips  → enable_tips()
  disable-tips → disable_tips()
  install-hooks → install_hooks_command()   # backfill hooks (incl. PreCompact) into all projects
  list-templates → list_templates()
  save-template  → save_template_command(name, dir)
  rename    → rename_move_command(src, dst, "rename")
  move      → rename_move_command(src, dst, "move")
  hide      → hide_command(session)
  show      → show_command(session)
  protect   → protect_command(session)
  unprotect → unprotect_command(session)
  delete    → delete_command(session, force, yes)
  getmode   → get_session_mode(session)

  send:
    validate: session is managed, session is running, command starts with /
    tmux send-keys session command + Enter
    # RC reconnect after /compact is handled universally by the PreCompact hook (on_compact),
    # not by a special case here. The hook fires for all /compact triggers (manual, auto, -s).

  shutdown:
    shutdown_claude_sessions()   # skips protected unless FORCE=true

  setmode:
    validate mode in whitelist
    for each session:
      if bypassPermissions:
        check pane for current mode indicator
        send Shift+Tab × N  (1 if plan, 2 if acceptEdits, 3 otherwise)
        verify via capture-pane
        if not confirmed → fallback to restart with bypassPermissions mode
      else:
        shutdown_single_session(session)
        create_claude_session(session, dir, SETMODE_VALUE)

  restart:
    FORCE=true   # restarts bypass protection by design

    # Caller-only restart-in-place: the session this script runs inside CANNOT be
    # kill-session'd (the SIGHUP kills this script before recreate → the old
    # restart-all-from-home-forks-history bug). The caller instead sets the
    # @claude-mux-restart tmux option + sends /exit; its LOOPED launch wrapper
    # relaunches claude in the same pane. Non-callers keep kill+recreate.

    identify caller session (tmux display-message) if running inside tmux

    if named sessions (RESTART_SESSIONS not empty):
      print "Restarting N session(s) to apply updated injection..."
      for each session:
        validate: is managed session
        dir = session_marker_dir(session)            # live tmux only
        dir = dir or resolve_session_dir(session)    # fallback: STOPPED session → by-name scan
        if session == caller:
          restart_caller_in_place(session, FRESH_START)   # set @claude-mux-restart + /exit
        elif claude running in session:                   # RUNNING non-caller → cycle
          restore_state_clear(session)   # user restart un-trips a crash-looped session
          mkdir .claudemux-restarting    # restart lock: auto-restore defers this tick
          shutdown_single_session(session, FORCE, preserve_marker=true)
          create_claude_session(session, dir, "", FRESH_START)
          rmdir .claudemux-restarting    # release; tick recovers if we crashed mid-restart
        elif session == "home":          # STOPPED home → proper path (keeps model)
          restore_state_clear(session); NO_ATTACH=true; launch_home_session()
        else:                            # STOPPED non-home → nothing to shut down, just start
          restore_state_clear(session); create_claude_session(session, dir, "", FRESH_START)

    else (full restart):
      snapshot: for each managed session where claude is running
        record name + working dir

      if nothing running → done

      print "Restarting N session(s) to apply updated injection..."

      partition: caller session vs others (caller restarted in place, last)

      # CRITICAL: do NOT call shutdown_claude_sessions() here — it walks every
      # managed session including the caller, whose /exit SIGHUPs this script
      # mid-loop and strands the rest. Shut down + recreate each non-caller
      # individually, honoring the caller partition.
      detect_github_ssh_accounts()
      for each non-caller session:
        restore_state_clear(name)   # user restart un-trips crash-loop history
        mkdir .claudemux-restarting
        shutdown_single_session(name, force=true, preserve_marker=true)  # force: recycle protected too
        create_claude_session(name, dir, "", FRESH_START)
        rmdir .claudemux-restarting

      if caller session exists:
        restart_caller_in_place(caller, FRESH_START)
        # set @claude-mux-restart=resume|fresh + send /exit; NO kill-session, NO
        # background handoff. The caller's looped wrapper sees the clean exit + option,
        # relaunches claude in-pane (resume/fresh), and fires --await-ready itself.

## restart_caller_in_place(session, fresh)
```
val = fresh ? "fresh" : "resume"
restore_state_clear(session)            # un-trip crash-loop history
tmux set-option @claude-mux-restart=val on session   # bail if it fails
send-keys "/exit" + Enter to session    # queued; claude exits cleanly after this tool returns
# The looped launch wrapper does the rest (relaunch in-pane + handshake).
```

## COMMAND == "start-session"  (--start NAME...; start-if-stopped, no-op-if-running)
```
if START_SESSIONS empty → error "use -a to start all"; exit 1
detect_github_ssh_accounts(); get_managed_session_names()
for each name in START_SESSIONS:
    is_managed_session(name) or → error, count, continue
    dir = resolve_session_dir(name) or → error, count, continue   # by-name (incl. stopped/hidden/home)
    if claude running in name → print "already running"; continue   # never cycles a live session
    if DRY_RUN → log "Would start..."; continue
    restore_state_clear(name)
    if name == "home": NO_ATTACH=true; launch_home_session()        # proper path (keeps model)
    else: create_claude_session(name, dir, "", FRESH_START)         # own collision-guard = race backstop
exit (1 if any error else 0)
```

## launch_home_session()
```
LAUNCH_DIR=$BASE_DIR; HOME_LAUNCH=true; LAUNCH_SESSION_NAME=home; launch_single_session()
# Home model flag (HOME_SESSION_MODEL) is only assembled inside launch_single_session under
# HOME_LAUNCH, so home must go through here, not create_claude_session. Caller sets NO_ATTACH
# for a non-attaching start; the -d $BASE_DIR path leaves it unset so it still attaches.
```

---

## create_claude_session(name, dir, mode, fresh)

Core launcher for all regular sessions (`-d`, `-n`, `--restart`).

```
# Collision guard
if tmux session exists:
  if not @claude-mux-managed:
    if claude is running → warn, claim (v1.8 upgrade path)
    else → error: session in use by something else, refuse
  if claude is running → backfill @claude-mux-managed/@claude-mux-dir/@claude-mux-claude-id + .claudemux-running marker; skip launch
  else → log "exists but claude not running, relaunching"
else:
  tmux new-session -d -s name -c dir

apply_tmux_options(name)
set @claude-mux-managed = 1
set @claude-mux-dir = working_dir     # authoritative source for marker removal
set @claude-mux-claude-id = claude_binary_id()   # for Claude Code upgrade detection

# Build injection
prompt = build_system_prompt(name, mode or "auto")

# Build launch command flags
perm_flag = "--permission-mode " + (mode or "auto")
resume_flag = "-c"  (omit if fresh=true)

# Write files. Launch script is a $TMPDIR temp (trap-cleaned). The PROMPT lives in
# the project folder (working_dir/.claudemux-prompt, mode 600) — NOT $TMPDIR — so it
# survives reaping and can be regenerated across in-place relaunches.
write prompt → working_dir/.claudemux-prompt
_marker_esc / _prompt_esc = single-quote-escaped paths   # apostrophe-safe (Sylvia's-estate)
_esc_bin = single-quote-escaped CLAUDE_MUX_BIN
write launch script → /tmp/claude-launch-XXXXX:
  #!/bin/bash
  trap 'rm -f launch_script' EXIT          # backstop (launch script only; prompt owned by loop)
  _marker='{_marker_esc}'; _prompt='{_prompt_esc}'; _resume='{resume_flag}'
  while true:                              # LOOP enables restart-in-place
    _start=$(date +%s); _resume_err=$(mktemp ...)   # capture primary stderr
    claude {_resume} --remote-control {perm} --allow-dangerously-skip-permissions \
      --name name --append-system-prompt-file "$_prompt" 2> "$_resume_err"   # path, not text → not in ps
    _rc=$?
    if rc != 0 AND (now - _start) < 10:    # resume failed to start → retry fresh
      log to LOG_FILE: "Primary launch for name failed: rc, elapsed, stderr tail"
      claude (same, without resume) ; _rc=$?
    rm -f "$_resume_err"
    if _rc == 0:                           # clean quit (/exit, Ctrl-C x2)
      _restart = tmux show-option @claude-mux-restart   # set by restart_caller_in_place
      if _restart non-empty:               # RESTART-IN-PLACE: relaunch in THIS pane
        tmux set-option -u @claude-mux-restart          # consume (one restart = one relaunch)
        _resume = (_restart == "fresh") ? "" : "-c"
        regenerate prompt: claude-mux --print-system-prompt name MODE > _prompt.new
          if non-empty → chmod 600 + mv over _prompt  (else keep old prompt)
        claude-mux --await-ready name &    # handshake from OUTSIDE this busy pane;
                                           #   also re-captures @claude-mux-claude-id so the
                                           #   upgrade notice self-clears on in-place restart
        continue                           # loop → relaunch claude, pane never dies
      # no restart pending → intent to stop: teardown
      rm -f "$_marker" "$_prompt" launch_script
      tmux kill-session -t name            # full teardown (no lingering shell pane)
      break
    break                                  # crash (non-zero): leave pane+marker for the tick
  # claude stays a DIRECT child of this script (no subshell) so the
  # 2-level claude_running_in_session check still finds it

write_running_marker(working_dir)     # before launch; skipped for home
tmux send-keys name "bash launch_script" + Enter

# Ready handshake (synchronous): poll_until_ready handles trust/bypass auto-accept
# AND waits out a resume-compaction (busy = "esc to interrupt" in bottom 4 lines;
# ready = not busy + prompt + quiescent). See poll_until_ready section.
poll_until_ready(name)        # returns 0 ready / 1 timeout (~120s); logs WARN on timeout
# prompt file NOT deleted here — the wrapper re-reads/regenerates it on in-place
# relaunch and removes it on teardown.
send "Ready?" + Enter         # sent whether ready or timeout (fallback preserved)

# (Tips are no longer sent here. As of v1.15.0 the daily tip and update notice
#  are injected per-prompt by the on_prompt UserPromptSubmit hook.)

# Protection
if .claudemux-protected exists in dir:
  set @claude-mux-protected = 1 on session
```

---

## launch_single_session()

Home/`-d` path, used by LaunchAgent and `-d`. Ready handshake runs *backgrounded* (`poll_until_ready` in a `( ) &`) so the longer ready-wait never blocks attach.

```
# Read globals: LAUNCH_DIR, LAUNCH_SESSION_NAME, HOME_LAUNCH, FRESH_START

if tmux session exists:
  if not @claude-mux-managed → warn, refuse
  if claude is running → skip
  else → tmux kill-session, fall through to create

prompt = build_system_prompt(LAUNCH_SESSION_NAME, "auto")

model_flag = ""
if HOME_LAUNCH and HOME_SESSION_MODEL set:
  model_flag = "--model " + HOME_SESSION_MODEL

resume_flag = "-c"  (omit if FRESH_START=true)

write prompt → LAUNCH_DIR/.claudemux-prompt   # project folder, mode 600 (not $TMPDIR)
_marker_esc / _prompt_esc / _esc_bin = single-quote-escaped paths
write launch script → tmp file:
  _marker='{_marker_esc}'; _prompt='{_prompt_esc}'; _resume='{resume_flag}'
  while true:                                                  # LOOP → restart-in-place
    _start=$(date +%s) ; _resume_err=$(mktemp ...)
    claude {_resume} --remote-control --permission-mode auto \
      --allow-dangerously-skip-permissions {model_flag} \
      --name session --append-system-prompt-file "$_prompt" 2> "$_resume_err"   # path, not text
    _rc=$?
    if rc != 0 AND (now - _start) < 10:                        # resume-fail → fresh
      log to LOG_FILE: "Primary launch for session failed: rc, elapsed, stderr tail"
      claude (no resume) ; _rc=$?
    rm -f "$_resume_err"
    if _rc == 0:
      if tmux show-option @claude-mux-restart non-empty:       # relaunch in-pane
        consume option; _resume=resume|fresh; regenerate prompt (--print-system-prompt, MODE=auto);
        claude-mux --await-ready session & ; continue
      rm -f "$_marker" "$_prompt" launch_script
      tmux kill-session -t session                             # teardown (home then relaunched by agent)
      break
    break                                                      # crash → leave for tick

restore_state_clear(LAUNCH_SESSION_NAME)   # -d / caller-restart is user-initiated → un-trip
write_running_marker(LAUNCH_DIR)            # no-op for home (BASE_DIR)

# Direct launch (not via send-keys)
tmux new-session -d -s name -c dir "bash launch_script"

set @claude-mux-managed = 1
set @claude-mux-dir = LAUNCH_DIR
set @claude-mux-claude-id = claude_binary_id()

if .claudemux-protected exists in dir:
  set @claude-mux-protected = 1

# Backgrounded ready handshake (does not block attach):
( poll_until_ready(LAUNCH_SESSION_NAME) || true ; rm -f prompt_file ; send "Ready?" + Enter ) &
```

---

## poll_until_ready(session, [timeout=120])

Shared readiness detector for both launch paths. The mere presence of the `❯`
prompt does NOT mean ready (it is drawn during a resume-time auto-compaction that
can run ~50s).

```
start = now
loop:
  if now - start >= timeout: return 1            # caller still sends Ready? (fallback)
  sleep 0.5
  pane = capture-pane(session)  (continue on failure)
  if pane has "Yes, I trust this folder": send Enter; sleep 2; continue   # pre-ready
  if pane has /yes.*accept/i:              send Down; sleep 1; send Enter; sleep 2; continue
  if bottom-4(pane) has "esc to interrupt": continue          # BUSY (turn or compaction)
  if pane lacks ^❯ / "^> ":                continue           # no prompt yet
  snap1 = trailing-ws-normalize(pane)
  sleep 1.2
  snap2 = capture-pane(session) (continue on failure); normalize
  if bottom-4(snap2) has "esc to interrupt": continue          # became busy again
  if snap1 non-empty AND snap1 == snap2: return 0              # ready (quiescent)
```

Quiescence is the version-proof backstop: a working screen animates (glyph + timer
+ token counter), so two snapshots differ even if the "esc to interrupt" string
check is ever defeated.

---

## build_system_prompt(session_name, permission_mode)

```
if session_name == "home":
  home_line = "This is the home session: always-on, protected by default..."
  home_management = rules for editing config, templates, markers

version_lines = get_version_prompt_lines()
  → "claude-mux version: X.Y.Z"
  → if update cached: "Update available: X.Y.Z. Tell user, suggest 'update claude-mux'."

detect_github_ssh_accounts() → GITHUB_SSH_INFO

assemble and return prompt:
  "You are running inside tmux session 'NAME'. claude-mux path: PATH
   {version_lines}
   {home_line if home}
   {home_management if home}

   Reference lookups: --guide, --commands, --config-help, --list-templates, --tip

   Rules:
   - always use absolute claude-mux path
   - always use --no-attach with -d and -n
   - when user says: ready → 'Session ready!\nRunning [model] in {permission_mode} mode.'
   - when user says: help → run --guide, print verbatim
   - when user says: status → report session, model, mode, context, run -l
   - NAME-resolution rule (governs the session-targeting triggers): "this/current session" = self;
     any named target resolves against the live list (claude-mux -l / -L --hidden) → exact single
     match acts, otherwise ASK — never default to the current session
   - when user says: restart this session → run --restart SELF; restart session NAME → resolve, then --restart NAME (else ask)
   - ... (40+ trigger rules total)

   Additional capabilities: (compressed feature list)

   Self-targeting send: claude-mux -s 'NAME' '/command'
   {GITHUB_SSH_INFO}"
```

---

## create_new_project()

```
# Read globals: NEW_PROJECT_DIR, NEW_CREATE_PARENTS, NO_GIT, NO_TEMPLATE,
#               NO_MULTI_CODER, NO_PERMISSION_MODE, TEMPLATE_NAME

validate: dir does not exist, or exists and is empty
if NEW_CREATE_PARENTS: mkdir -p
else: mkdir (parent must exist)

if not NO_GIT:
  ensure_git_repo(dir)    # git init if not already a repo
  setup_gitignore(dir)    # create/update .gitignore with .claudemux-* entry

if not NO_TEMPLATE:
  apply_template(TEMPLATE_NAME or DEFAULT_TEMPLATE, dir)
    # copies template file to dir/CLAUDE.md

if not NO_MULTI_CODER:
  setup_multi_coder_files(dir)
    # create AGENTS.md, GEMINI.md as symlinks to CLAUDE.md

if not NO_PERMISSION_MODE:
  setup_default_mode(dir)
    # write permissions.defaultMode to .claude/settings.local.json

setup_claude_mux_permissions(dir)
  # add claude-mux to .claude/settings.local.json allowlist
  # register UserPromptSubmit --on-prompt hook (if TIP_OF_DAY or UPDATE_CHECK)
  # remove legacy Stop --tipotd hook

create_claude_session(session_name, dir, "", false)
```

---

## autolaunch_dispatch()

Called by LaunchAgent every 60s via KeepAlive.

```
case LAUNCHAGENT_MODE:

  none:
    log "mode is none, nothing to do"
    if plist still installed:
      launchctl unload plist   # self-heal: stop recurring invocations

  home:
    LAUNCH_DIR = BASE_DIR
    HOME_LAUNCH = true
    LAUNCH_SESSION_NAME = "home"
    NO_ATTACH = true
    launch_single_session()
      # if home already running → skip (claude_running_in_session check)
      # if not → create and launch
    autorestore_walk()       # after home is up, restore other dead-but-marked sessions
```

---

## autorestore_walk()

The restore tick. Pure bash, no Claude turn. Called from `autolaunch_dispatch` (home mode) after the home session is up, so launchd's ~60s re-fire makes it both boot recovery and a runtime watchdog.

```
if AUTORESTORE != true: return            # nothing to act on

discover_projects()                        # populates PROJECT_DIRS + HIDDEN_PROJECT_DIRS
now = epoch

candidates = []
in_flight = 0
for proj in PROJECT_DIRS + HIDDEN_PROJECT_DIRS:
    name = sanitize(basename(proj))
    skip if empty or name == "home"
    if proj/.claudemux-restarting exists:                 # restart in flight (or crashed)
        rmdir proj/.claudemux-restarting                  # consume-on-sight
        log "skipping name this tick (restart in flight)"
        continue                                          # next tick: running→noop, or crashed→preserved marker recovers it
    la = restore_state_last_attempt(name)
    if (now - la) < STARTING_WINDOW: in_flight++      # recent attempt occupies a slot
    if should_be_alive(name, proj) AND NOT claude_running_in_session(name):
        candidates += "name|proj|la"                   # carry la to avoid a re-read

if candidates empty: return
slots = STAGGER_CONCURRENCY - in_flight
if slots <= 0: log "deferring"; return

for entry in sort(candidates)[: slots]:               # deterministic order
    name, dir, last = split(entry)
    dc = restore_state_death_count(name)
    # crash-loop guard: judge survival since last attempt
    if last > 0:
        if (now - last) < AUTORESTORE_MIN_HEALTHY: dc++    # fast death
        else: dc = 0                                        # ran healthy → reset
    if dc >= AUTORESTORE_TRIP_THRESHOLD:
        restore_state_write(name, last, dc, tripped=true)  # keep marker, stop restoring
        notify_home("X crash-looped … say 'restart X fresh'")
        continue                                            # should_be_alive false next tick (one notice)
    restore_state_write(name, now, dc, tripped=false)
    create_claude_session(name, dir, "", fresh=false)      # resume
```

**Invariants:** stays one-shot (launchd re-fires it; never loops internally). Uses `claude_running_in_session` (not `has-session`) so zombies are restored. A reboot leaves `last_attempt_ts` stale/large, so nothing trips on boot recovery.

---

## do_update()

```
fetch GitHub releases API → latest version string
if already at latest → exit 0
if current is newer than latest → exit 0  (dev build)

if brew list claude-mux:
  brew upgrade claude-mux
else:
  download binary from GitHub releases
  validate: starts with #!, size > 1000 bytes, VERSION string matches
  replace binary at install path

echo "claude-mux updated: OLD → NEW"
clear ~/.claude-mux/.update-check cache

if config exists:
  update_all_project_hooks()   # backfill PreCompact + on-prompt hooks into all projects (version changed → real upgrade)

if TTY:
  prompt "Restart running sessions? [y/N]"
  if yes → exec claude-mux --restart
```

---

## shutdown_single_session(name, [force], [preserve_marker])

```
if session not running → return
if protected and not force → error, return

if preserve_marker != true:                          # restart paths pass true so a
  remove_running_marker(session_marker_dir(session)) #   crashed restart stays recoverable;
                                                      # shutdown paths drop the marker (intent
                                                      # to stop) BEFORE kill so the tick can't
                                                      # resurrect mid-shutdown

send-keys name "/exit" + Enter
wait up to 10s (20 × 0.5s):
  if claude no longer running → break

if still running → tmux kill-session name   # hard kill
```

---

## shutdown_claude_sessions()

```
# Named sessions path (when --shutdown SESSION [...] is used)
if SHUTDOWN_SESSIONS not empty:
  get_managed_session_names()
  for each named session:
    validate: is managed session
    shutdown_single_session(session)
  return

# All managed sessions path
get_managed_session_names()
for each running tmux session:
  if not managed → skip
  if protected and FORCE != true → skip with log
  collect in managed_list
  remove_running_marker(session_marker_dir(session))   # intent to stop, before kill
  send /exit if claude is running

wait up to 10s (20 × 0.5s) for all claude processes to exit

for each session in managed_list:
  tmux kill-session
```

---

## rename_move_command(src, dst, mode)

```
validate: src is a managed session
get src working dir

if mode == "rename":
  new_dir = parent(src_dir) / dst
  validate: new_dir does not exist (or --force)
  mv src_dir → new_dir
  update tmux session name (kill old, new name picks up on restart)
  migrate Claude history:
    old_encoded = encode_claude_path(src_dir)
    new_encoded = encode_claude_path(new_dir)
    mv ~/.claude/projects/old_encoded → ~/.claude/projects/new_encoded

if mode == "move":
  smart dest: if basename(dst) == src → dst = dirname(dst)  # strip trailing session name
  validate: dst parent exists
  mv src_dir → dst/src_name
  migrate Claude history (same as rename)
```

---

## tip_of_day()

```
tips = [array of ~39 tip strings]

if TIP_MODE == "daily":
  index = hash(today's date) % len(tips)
else:
  index = random % len(tips)

print tips[index]   # no gating; --tip always works, on_prompt gates per-session
```

---

## on_prompt()  (UserPromptSubmit hook)

```
# Injected stdout is seen by Claude (and reaches Remote Control), unlike the
# old Stop hook whose stdout was transcript-only.

# Read stdin JSON ONCE (python3) → session_id, is_handshake, tip_date.
#   session_id: validated [A-Za-z0-9_-]{1,128}, sentinel "_" if missing/invalid
#   is_handshake: prompt.strip() == "Ready?"
#   state = ~/.claude-mux/tip-state/<session_id>.json  # {tip_date} ONLY — the two
#     actionable notices keep no per-session state (persist-while-relevant, v2.0.10).
#   Always prints exactly 3 fields so `read` stays aligned even when session_id absent.
read stdin JSON → session_id, is_handshake, tip_date

# Handshake no-op (v2.0.8): the synthetic "Ready?" claude-mux sends itself after a
# restart / compact-reconnect is NOT a real user turn. Its two-line ready reply
# swallows any injected text. Exit before detect_claude_upgrade so the FIRST REAL
# prompt surfaces all three notices (no state burned either, since the actionable
# notices no longer stamp anything).
if is_handshake → exit 0

# Claude Code upgrade detection (always-on; needs no session_id; runs AFTER the
# handshake check so a "Ready?" turn never consumes the notice).
# detect_claude_upgrade():  (persist-while-relevant, v2.0.10)
#   sess = tmux display-message -p '#S'        (needs $TMUX, inherited by the hook)
#   id0  = tmux show-options -v @claude-mux-claude-id   (empty → skip: not in tmux / pre-feature)
#   id_now = claude_binary_id()  (= realpath(claude):mtime)
#   if id_now != id0:
#     echo "<assistant-must-display>[claude-mux — MUST relay … mention once per session]: Claude Code was upgraded … restart this session</assistant-must-display>"
#     # NO ack-on-emit: re-injects every prompt until a RESTART re-captures the id
#     # (kill+recreate, or in-place via await_ready_handshake). A missed relay retries.
bin_notice = detect_claude_upgrade()

if TIP_OF_DAY != true AND UPDATE_CHECK != true:   # cheap guard
  print bin_notice (if any); exit 0               # still flush the always-on notice

if session_id == "_" (missing/invalid):           # no tip/update work possible
  print bin_notice (if any); exit 0

# Daily tip (per session) — wrapped in <assistant-must-display>, MUST-relay wording
if TIP_OF_DAY and state.tip_date != today:
  out += "<assistant-must-display>[claude-mux tip — MUST relay …]: " + tip_of_day() + "</assistant-must-display>"
  new tip_date = today

# Update notice (persist-while-relevant; cache-gated). NO stamp/throttle: re-inject
# every prompt while latest > VERSION; self-clears when the user updates (VERSION rises).
if UPDATE_CHECK:
  read ~/.claude-mux/.update-check → last_check, latest, _
  if latest > VERSION:
    out += "<assistant-must-display>[claude-mux update available — MUST relay … mention once per session]: ...</assistant-must-display>"
  if cache stale (>24h):
    lock dir = ~/.claude-mux/.update-checking
    if lock dir mtime >5min: rmdir it (orphaned)
    if mkdir lock dir succeeds (atomic):   # loser of the race skips
      spawn disowned: claude-mux --update-check-bg   # never blocks
    # else: in-flight check, skip

if state changed: write state file
out = bin_notice + out   # prepend the always-on upgrade notice
print out   # may be empty
exit 0
```

---

## update_check_bg()  (disowned background)

```
# Spawned by on_prompt when the cache is stale. Never prints anything.
read ~/.claude-mux/.update-check → preserve last_notify
curl GitHub releases/latest (max 5s)
if got a version:
  if version changed → reset last_notify to 0
  write "<now> <latest> <last_notify>" to .update-check
remove ~/.claude-mux/.update-checking   # always clear the lock
exit 0
```

---

## Key Invariants

- `COMMAND` can only be set once — `set_command()` enforces this and exits on conflict.
- Sessions are only touched if `@claude-mux-managed=1` is set in tmux — this prevents accidental collision with non-claude-mux tmux sessions.
- Protected sessions (`@claude-mux-protected=1`) are skipped by `shutdown_claude_sessions()` unless `FORCE=true`. Restart-all does NOT use that blanket path; it calls `shutdown_single_session(name, force=true, ...)` per non-caller, so it recycles protected sessions too (restart ≠ permanent kill). Single-named `--restart SESSION` honors `$FORCE` (protected needs `--force`).
- Restart-all must never call `shutdown_claude_sessions()`: that blanket walk includes the caller, whose `/exit` SIGHUPs the script mid-loop and strands the rest. The caller is partitioned out and restarted last via a `disown`ed background subshell; non-callers are shut-down+recreated individually in a loop, each wrapped in a `.claudemux-restarting` lock (mkdir/rmdir) with `preserve_marker=true`.
- Caller-last ordering in full restart: the session running the restart script cannot kill itself mid-execution — it separates itself from the list and uses a background subshell with `disown` to handle its own restart.
- `poll_until_ready` keys readiness on the `esc to interrupt` busy signal + quiescence, not the mere presence of the `❯` prompt (which is drawn during a resume-time compaction). It still sends `Ready?` on timeout (~120s) so a slow session eventually gets the handshake.
- Temp launch scripts clean themselves up via `trap ... EXIT` — no orphaned files even if claude crashes.
- Auto-restore marker presence ⇒ session should be alive. The marker is cleared exactly two ways, both = intent to stop: `--shutdown` (`remove_running_marker` before kill) or a clean in-pane exit (rc 0, the launch wrapper removes it). A crash/`kill-session`/reboot leaves it, so the tick restores it. A `--restart` deliberately preserves it (`preserve_marker=true`), so a restart that crashes between shutdown and recreate is still recovered by the tick.
- A `.claudemux-restarting` lock (mkdir) means a restart is in flight; the tick consumes it on sight (rmdir + skip one tick) so auto-restore never races the sub-second window between `kill-session` and `new-session`. Self-healing: a stale lock is cleared by the next tick regardless.
- `should_be_alive()` is the single predicate behind both the restore walk and the `-l` status, so the listing never promises a restore the tick won't perform.
- `--autolaunch`/`autorestore_walk` must stay one-shot; launchd re-fires it (~60s via `KeepAlive`+`ThrottleInterval=60`), so an internal loop would break the watchdog.
- The launch wrapper keeps `claude` a direct child of the launch script (no extra subshell), so `claude_running_in_session`'s 2-level process-tree check still finds it.
- The system prompt is delivered via `--append-system-prompt-file <path>` (not `--append-system-prompt "<text>"`), so it never appears in `ps`. The prompt temp file is deleted right after the ready handshake (Claude reads it once at startup); the `trap` is the backstop.
- A clean in-pane `/exit` (rc 0) tears down the tmux session (`kill-session`), matching `--shutdown`; a crash (non-zero) deliberately leaves the pane so the restore tick can relaunch into it.
