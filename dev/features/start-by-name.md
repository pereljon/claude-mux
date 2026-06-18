---
feature: start-by-name
status: IMPLEMENTED in v2.0.7 (2026-06-17); both open questions resolved 2026-06-17
target_version: 2.0.7 (patch) - user decision 2026-06-17
severity: MEDIUM (UX gap + injection inconsistency)
related: restart-in-place.md, session-target-disambiguation.md
---

# Feature: start a session by name (`--start NAME`) + `--restart` works on stopped sessions

## Problem

Two related gaps, both surfaced 2026-06-17 when the home orchestrator was asked to start a
named subset of idle sessions back up and could not do it cleanly:

1. **No "start an idle session by name" command.** `-d` launches by **directory path**
   (it `cd`s into its arg and derives the session name from the basename); the project's
   own "session names, not paths" principle is violated for the one operation a user most
   naturally expresses by name ("start sylvia-estate"). `-a` starts *all* projects; `-t` is
   *attach* (connect to a running session; cannot start anything). So starting a specific
   idle session requires `-d <full-path> --no-attach`, which the orchestrator has to derive.

2. **`--restart NAME` fails on a stopped session.** It passes `is_managed_session` (which is
   discovery-based, so a stopped project resolves) but then calls `session_marker_dir`, which
   only resolves the working dir from the **live tmux session** (`@claude-mux-dir` option,
   falling back to `pane_current_path`). A stopped session has no live pane → empty dir →
   the restart path errors `"Session 'NAME' not found or cannot determine working directory"`.

The injection compounds #1: the `start session SESSION` trigger currently maps to
`claude-mux -d SESSION --no-attach`, implying name-based start — but `-d` needs a path, so
from home's cwd (`~/Claude`) `-d sylvia-estate` fails (the project is at
`~/Claude/personal/sylvia-estate`). The trigger is misleading.

## Locked decisions (2026-06-17, user-approved)

- **Two distinct commands, NOT a blind alias.** `--start` and `--restart` differ on the
  already-running case; aliasing `--start` to `--restart` would make "start X" kill+recreate
  a *running* X (a footgun). Semantics:
  - **`--restart NAME`**: "bring it up fresh." Running → cycle it (kill+recreate for
    non-callers; in-place for the caller, per restart-in-place). Stopped → just start it.
  - **`--start NAME`**: "ensure it's running, don't disturb it." Stopped → start it.
    Running → no-op (report "already running"); never cycles a live session.
- **Both resolve by name** via the existing `resolve_session_dir()` (basename scan of
  `PROJECT_DIRS` + `HIDDEN_PROJECT_DIRS`; also handles `home`→`BASE_DIR` and running→pane path).
- **Neither touches `-t`.** `-t` stays a pure attach (already session-aware via
  `switch-client`); it is not a launch verb.

## Why this is low-risk / mostly reuse

Verified against the code (2026-06-17):
- `resolve_session_dir()` already resolves a stopped project's dir by basename, including
  hidden projects, and special-cases `home`. Exactly what both commands need.
- `create_claude_session()` **already no-ops when claude is running**: its collision guard
  hits `claude_running_in_session` → logs `"… already running claude, skipping"` → `return`.
  So `--start` = `resolve_session_dir` + `create_claude_session` gives the desired
  start-if-stopped / leave-alone-if-running behavior with no new launch logic.
- `create_claude_session()` already handles apostrophe-containing dirs (the restart-in-place
  escaping), so `--start sylvia-estate` (→ `~/Claude/personal/sylvia-estate`) and the
  `Sylvia's-estate` class are covered for free.

## Design

### Change 0 — `launch_home_session()` helper (no duplication for the home case)

There is no dedicated "launch home" function today: home is brought up by setting three
globals then calling `launch_single_session()` (which reads `LAUNCH_DIR`,
`LAUNCH_SESSION_NAME`, `HOME_LAUNCH`, `HOME_SESSION_MODEL`, `FRESH_START`, `NO_ATTACH`). That
3-line setup is repeated in `autolaunch_dispatch` (~4473) and the `-d`→`BASE_DIR` detection
(~1628). Starting home via `create_claude_session` would lose `HOME_SESSION_MODEL` (the
model_flag is only assembled inside `launch_single_session` under `HOME_LAUNCH`). So:

```bash
launch_home_session() {
    LAUNCH_DIR="$BASE_DIR"
    HOME_LAUNCH=true
    LAUNCH_SESSION_NAME="home"
    launch_single_session
}
```
- Route the new home cases (Change A stopped-branch, Change B) through this helper, with
  `NO_ATTACH=true` set first (so a name-based start/restart never attaches — matching the
  non-attaching `create_claude_session` path used for every other session).
- Consolidate the two existing inline setups (`autolaunch_dispatch`, the `-d` path) onto this
  helper so the home-launch setup lives in exactly one place. (Low-risk refactor; verify the
  `-d $BASE_DIR` path still attaches when the user runs it interactively — that path must NOT
  force `NO_ATTACH`, so set `NO_ATTACH` at the *caller*, not inside the helper.)

### Change A — `--restart NAME` works on stopped sessions

In the named-restart loop (dispatch `restart)`, currently:
```bash
_restart_dir=$(session_marker_dir "$_rs")
if [[ -z "$_restart_dir" ]]; then
    echo "ERROR: Session '$_rs' not found or cannot determine working directory" >&2
    ...
    (( _restart_errors++ )); continue
fi
```
Two edits:
1. **Dir fallback:** when `session_marker_dir` is empty (stopped), fall back to
   `resolve_session_dir`:
   ```bash
   _restart_dir=$(session_marker_dir "$_rs")
   [[ -z "$_restart_dir" ]] && _restart_dir=$(resolve_session_dir "$_rs" 2>/dev/null)
   ```
   (Keep the existing "cannot determine working directory" error if BOTH come up empty.)
2. **Guard the shutdown** so a stopped session skips it. `shutdown_single_session` returns 1
   and prints `"No tmux session named 'NAME'" / "See LOG for details"` to stderr for a
   non-running session, so it must not be called blindly. Branch on running state:
   ```bash
   if claude_running_in_session "$_rs"; then
       mkdir "$_restart_dir/.claudemux-restarting" 2>/dev/null
       shutdown_single_session "$_rs" "$FORCE" true
       create_claude_session "$_rs" "$_restart_dir" "" "$FRESH_START"
       rmdir "$_restart_dir/.claudemux-restarting" 2>/dev/null
   elif [[ "$_rs" == "home" ]]; then
       NO_ATTACH=true; launch_home_session   # stopped home → proper path (keeps model)
   else
       # Stopped non-home: nothing to shut down → just start it (== --start).
       create_claude_session "$_rs" "$_restart_dir" "" "$FRESH_START"
   fi
   ```
   Notes: (a) the in-place caller branch is unaffected — a stopped session can never be the
   caller (the caller is, by definition, running this script). (b) The **running** branch is
   unchanged; `--restart home` *while home is running* from another session still goes through
   `shutdown_single_session` + `create_claude_session` and so loses `HOME_SESSION_MODEL` — a
   PRE-EXISTING issue (same class as "permission mode lost on --restart", `docs/ISSUES.md`),
   explicitly OUT OF SCOPE here. This feature only routes the *stopped* home case correctly.

   Protected-session note: today `--restart NAME` on a *running* protected session honors
   `$FORCE`. A *stopped* protected session has no live `@claude-mux-protected` option to
   check, so the create path just starts it; `--force` is irrelevant when nothing is running.
   Acceptable and consistent (protection guards `--shutdown`, not bring-up).

### Change B — new `--start NAME [NAME...]` command

- **Arg parsing** (mirror `--restart`, collect names until the next flag):
  ```bash
  --start)
      set_command "--start" "start-session"
      shift
      while [[ $# -gt 0 && "$1" != -* ]]; do
          START_SESSIONS+=("$1"); shift
      done
      ;;
  ```
  New global `START_SESSIONS=()` near `RESTART_SESSIONS=()`.
- **Command token is `start-session`, NOT `start`** — `start` is already the dispatch token
  for `-a` (`start) start_sessions`). Add to the config-load skip list only if it needs to
  run pre-config (it does not; it needs config like restart, so leave it OUT of the skip list).
- **Dispatch:**
  ```bash
  start-session)
      if [[ ${#START_SESSIONS[@]} -eq 0 ]]; then
          echo "ERROR: --start requires a session name (use -a to start all)" >&2
          exit 1
      fi
      detect_github_ssh_accounts
      get_managed_session_names
      _start_errors=0
      for _ss in "${START_SESSIONS[@]}"; do
          if ! is_managed_session "$_ss"; then
              echo "ERROR: '$_ss' is not a claude-mux managed session" >&2
              (( _start_errors++ )); continue
          fi
          _start_dir=$(resolve_session_dir "$_ss" 2>/dev/null)
          if [[ -z "$_start_dir" ]]; then
              echo "ERROR: cannot resolve working directory for '$_ss'" >&2
              (( _start_errors++ )); continue
          fi
          if claude_running_in_session "$_ss"; then
              echo "Session '$_ss' is already running."
              continue
          fi
          [[ "$DRY_RUN" == "true" ]] && { log "Would start '$_ss' in $_start_dir"; continue; }
          restore_state_clear "$_ss"   # user-initiated bring-up un-trips crash-loop history
          if [[ "$_ss" == "home" ]]; then
              NO_ATTACH=true; launch_home_session   # proper home path (keeps model)
          else
              create_claude_session "$_ss" "$_start_dir" "" "$FRESH_START"
          fi
      done
      exit $(( _start_errors > 0 ? 1 : 0 ))
      ;;
  ```
  `create_claude_session`'s own collision guard is the safety net if a race makes the session
  appear between the `claude_running_in_session` check and create; it will no-op.

### Change C — injection trigger

Replace the misleading start trigger in `build_system_prompt()`:
- **From:** `start session SESSION — run claude-mux -d SESSION --no-attach`
- **To:** `start session SESSION — run claude-mux --start SESSION` (resolves by name; no path;
  no-op if already running). Keep "start new session in FOLDER" → `-n FOLDER` unchanged
  (that's project *creation* by path, a deliberate path exception).
- Confirm wording: "Started. SESSION is now running." / "SESSION is already running."

`--start` is session-name based, so it composes with the existing v2.0.5 NAME-resolution
governing rule (resolve against the list; ask on ambiguity; never default to current).

## Edge cases

| Case | Behavior |
|---|---|
| `--start NAME` when running | No-op: prints "already running", exit 0. |
| `--start NAME` when stopped | Resolve dir → `create_claude_session` → resumes (`-c`). |
| `--start --fresh NAME` | Start without `-c` (new conversation). `FRESH_START` already parsed. |
| `--start NAME1 NAME2` | Each handled independently; per-name errors don't abort the rest. |
| `--start` (no names) | Error pointing to `-a` (start all). Do NOT silently alias `-a`. |
| `--start unknown` | `is_managed_session` fails → error "not a managed session". |
| `--start home` (stopped) | Routed to `launch_home_session` (`NO_ATTACH=true`) → starts home via `launch_single_session` WITH `HOME_SESSION_MODEL`. Resolved 2026-06-17: route to proper path (not refuse). |
| `--restart NAME` stopped | Change A: dir via `resolve_session_dir`, skip shutdown, create. |
| `--restart NAME` running | Unchanged (cycle; in-place if caller). |
| apostrophe dir (`Sylvia's-estate`) | Handled by `create_claude_session`'s existing escaping. |
| `--start` from inside a session | Works (it's name-based, no attach). Not interactive; safe. |

## Resolved decisions (2026-06-17)

1. **`--start home` / `--restart home`-when-stopped**: ROUTE to the proper home launch path
   (`launch_home_session` → `launch_single_session`, preserving `HOME_SESSION_MODEL`), via the
   new Change 0 helper. Not "refuse". Running-restart-home model loss stays out of scope
   (pre-existing).
2. **Version: 2.0.7 (patch).** Treat Change A as a fix and `--start` as a small add; reserve
   the "2.1 Context discipline" milestone name. (Note: this is a deliberate exception to the
   "new CLI flag → minor" rule, made by the user.)

## Files to update (Change Checklist)

- `claude-mux`: `START_SESSIONS=()` global; `--start` arg parse; `start-session` dispatch;
  Change 0 (`launch_home_session()` helper + consolidate the 2 inline home setups);
  Change A (restart dir fallback + shutdown guard + stopped-home routing);
  `commands_help()` (+`--start`); injection feature list + `start session` trigger in
  `build_system_prompt()`.
- `README.md` + `translations/README.*.md`: capabilities/conversational examples (batch
  translations at end of release per the defer-translations rule).
- `docs/CLI.md`: `--start` reference; note `--restart` now works on stopped sessions.
- `docs/GUIDE.md`: starting sessions by name.
- `dev/CODEMAP.md`: new dispatch case `start-session`; note Change A in the `restart` row /
  named-restart description; `resolve_session_dir` now used by start + restart-stopped.
- `dev/SKELETON.md`: dispatch + restart logic-flow (stopped branch) + start-session flow.
- `dev/IMPLEMENTATION-SPEC.md`: command list, `--start` behavior, restart-on-stopped.
- `docs/ISSUES.md`: resolve the "start idle session by name / --restart can't find stopped"
  gap (this doc).
- `CHANGELOG.md`: Added `--start`; Changed `--restart` works on stopped sessions; injection
  trigger change.
- `VERSION=` bump to **2.0.7**.
- `internal/tips.md` + `tip_of_day()` array: a tip teaching "start session NAME".

## Out of scope

- No change to `-t` (attach), `-a` (start all), `-d`/`-n` (path-based launch/create).
- No multi-name `--restart` semantics change beyond the stopped-session fallback.
