---
feature: start-by-name
---

# Test Plan: start-by-name (`--start NAME` + `--restart` on stopped sessions)

Tests for `start-by-name.md`. Decisive metrics:
- `--start NAME` starts a **stopped** session by name (resumes), and is a **no-op** on a
  running one (never cycles it).
- `--restart NAME` now also works on a **stopped** session (starts it), while running-session
  restart (incl. caller in-place) is unregressed.
- No behavior change to `-t`, `-a`, `-d`, `-n`.

## Pre-build verification (confirm assumptions before coding)

### V0.1 `resolve_session_dir` resolves a stopped project by name
`bash ./claude-mux` can't be run for this directly; instead source-check: confirm
`resolve_session_dir "<idle-project-basename>"` prints its dir (scans `PROJECT_DIRS` +
`HIDDEN_PROJECT_DIRS`, special-cases `home`). Already read 2026-06-17; re-confirm if the
function changed.

### V0.2 `create_claude_session` no-ops when claude is running
Confirm the collision-guard branch (`claude_running_in_session` → `log "... already running
claude, skipping"; return`) is intact. This is the safety net `--start` relies on.

### V0.3 `shutdown_single_session` returns 1 + stderr on a non-running session
Confirm the early `has-session` guard still `return 1`s with the "No tmux session" log — this
is *why* Change A must guard the shutdown behind a running-check.

### V0.4 dispatch token `start` is taken by `-a`
`grep -n 'start)' claude-mux` → confirm `start) start_sessions` exists, so `--start` must use
a distinct token (`start-session`).

## Static / generation checks (post-build, no live sessions)

### T0.1 `bash -n claude-mux` passes.
### T0.2 `claude-mux --help` / `commands_help` lists `--start`.
### T0.3 `claude-mux --start` (no args) → error mentioning `-a`, exit 1.
### T0.4 `claude-mux --start not-a-real-session` → "not a claude-mux managed session", exit 1.
### T0.5 `--dry-run`:
- `claude-mux --start <idle> --dry-run` → logs "Would start '<idle>' in <dir>", creates nothing.
- `claude-mux --restart <idle> --dry-run` → logs "Would restart … (fresh start)" as applicable, creates nothing.
### T0.6 Injection: `--print-system-prompt test auto` shows the `start session SESSION` trigger
now mapping to `claude-mux --start SESSION` (NOT `-d SESSION`).

## Happy path (live)

Use a disposable managed project (e.g. `datetime-hook`) — NOT home.

### T1.1 `--start` a stopped session by name → starts + resumes
1. Stop it: `claude-mux --shutdown datetime-hook`. Confirm idle in `-L`.
2. `claude-mux --start datetime-hook --no-attach` (note: `-d`/`-t` attach; `--start` does not
   attach, so no `--no-attach` needed — confirm it returns without attaching).
3. Expect: tmux session created, claude running, transcript **resumed** (`-c`), `-l` shows it
   running, "Ready?" handshake fires. Pane is a fresh in-place launch (new looped wrapper).

### T1.2 `--start` a running session → no-op
With it running, `claude-mux --start datetime-hook`. Expect: prints "Session 'datetime-hook'
is already running.", exit 0, **claude PID unchanged** (not cycled), transcript untouched.

### T1.3 `--restart` a stopped session → starts it (Change A)
1. Stop it. 2. `claude-mux --restart datetime-hook`. Expect: starts + resumes; no spurious
   "No tmux session named …" stderr (shutdown was guarded/skipped); `-l` shows running.

### T1.4 `--restart --fresh` a stopped session → starts fresh
`claude-mux --restart datetime-hook --fresh` while stopped → new conversation (no `-c`),
clean handshake.

### T1.5 `--start --fresh` a stopped session → starts fresh
Same as T1.4 via `--start`.

### T1.6 `--start NAME1 NAME2` (mixed states)
One stopped, one running. Expect: stopped one starts; running one reports "already running";
both exit paths independent; overall exit 0.

### T1.7 `--start` a hidden project by name
Hide a project, stop it, `--start <name>`. `resolve_session_dir` includes
`HIDDEN_PROJECT_DIRS`, so it should start.

## Regression (unchanged behavior)

### T2.1 `--restart` a RUNNING non-caller → cycle (unchanged)
`claude-mux --restart datetime-hook` from the claude-mux session, datetime-hook running →
kill+recreate, resumes. The new looped wrapper tears down correctly on the external `/exit`
(no infinite loop, single recreate).

### T2.2 `--restart` (all) from a caller → caller in-place, others kill+recreate (unchanged)
Restart-in-place path untouched by Change A (stopped ≠ caller). Confirm caller resumes in
place, others resume.

### T2.3 `-a` still starts all; `-t` still attaches; `-d`/`-n` still path-based
No token/behavior collision with the new `start-session` command.

### T2.4 `--restart` a RUNNING protected session still honors `--force`
Unchanged for the running case.

## Edge / failure

### T3.1 `--start home` / `--restart home`-when-stopped → proper home path (keeps model)
Resolved: routes through `launch_home_session` → `launch_single_session`. With home stopped,
`claude-mux --start home`:
- Starts home, and the running `claude` process includes `--model <HOME_SESSION_MODEL>` (e.g.
  `--model sonnet`) — verify via the process args (NOT a bare `create_claude_session` launch,
  which would omit the model).
- Does NOT attach (`NO_ATTACH=true` forced for the name-based path).
Also (Change 0 regression): `claude-mux -d "$BASE_DIR"` run interactively still ATTACHES
(the helper must not force `NO_ATTACH` for the `-d` path — it's set at the caller).

### T3.2 apostrophe dir
`--start` a stopped project whose dir contains an apostrophe (e.g. a `Sylvia's-estate`-style
path). Confirm it launches (relies on `create_claude_session` escaping). If no such project
exists, generate the wrapper for that dir and `bash -n` it (as in restart-in-place tests).

### T3.3 race: session appears between check and create
Not easily forced; rely on `create_claude_session`'s collision guard (no-op if running) as
the backstop. Confirm by code inspection that `--start`'s pre-check + create-guard are both present.

### T3.4 `--start` from inside the target's own session
Edge: starting the session you're in (it's already running) → "already running" no-op. Not a
self-kill. Confirm.

## Verification commands

```bash
bash -n claude-mux && echo OK
claude-mux --shutdown datetime-hook        # set up: stop it
claude-mux -L --status stopped             # confirm idle/stopped
claude-mux --start datetime-hook           # T1.1
claude-mux -l | grep datetime-hook         # running?
claude-mux --start datetime-hook           # T1.2 → "already running", PID unchanged
# resume check: transcript continues (no new jsonl), e.g.
D=~/.claude/projects/-Users-jonathan-Claude-development-datetime-hook
ls -t "$D"/*.jsonl | head -1               # same file, grows
grep -E "start|restart|already running|Creating|Ready" ~/Library/Logs/claude-mux.log | tail -20
```

## Acceptance

- T1.1–T1.7: `--start` starts stopped sessions by name (resume + handshake), no-ops on running.
- T1.3–T1.5: `--restart` works on stopped sessions; no spurious shutdown error.
- T2.x: running-restart (incl. caller in-place), `-a`, `-t`, `-d`, `-n` all unregressed.
- T3.1: `home` handled per the design decision (no model-less home launch).
- T0.x: dispatch/parse/dry-run/injection-trigger all correct; `bash -n` clean.
