---
feature: restart-in-place
---

# Test Plan: Restart-in-place

Test plan for `restart-in-place.md`. The decisive metric throughout: after a restart, the
session's transcript **continues** (resumes — same conversation) AND RC reconnects (you can send),
with the session's tmux pane **never going down** (no LaunchAgent recovery needed).

Per the locked decisions in the design doc: "flag" = the tmux user option `@claude-mux-restart`
(value `resume`|`fresh`); "set the flag" = `tmux set-option`, "consume" = unset it; the handshake is
the `--await-ready SESSION` subcommand; scope is **caller-only** (non-callers keep the existing
loop). Version: 2.0.6 (patch).

## Pre-build verification (prove the assumptions BEFORE coding the wrapper)

### V0.1 In-place `claude -c` resumes after a clean `/exit`
Manually mimic the loop in a throwaway dir: launch `claude`, seed a codeword, `/exit` it, then
re-run `claude -c` **in the same shell/pane**. Confirm it recalls the codeword (resumes) rather
than forking. (Strongly expected; this is the core assumption.)

### V0.2 A flag-driven clean exit can be detected by a wrapper loop
Prototype the looped wrapper in a throwaway tmux session: `while: claude; if rc==0 && flag: rm
flag; continue; else kill`. Set the flag, send `/exit`, confirm the wrapper relaunches in the same
pane (pane PID of the wrapper unchanged; claude PID changes).

### V0.3 `--await-ready` (or inline poll) fires "Ready?" from the surviving pane
After an in-place relaunch, confirm the backgrounded handshake sends "Ready?" and the session
responds "Session ready!" and RC reconnects.

### V0.4 Confirm current wrapper shape (no regressions to baseline)
```
sed -n '/cat > "$launch_script"/,/LAUNCH_EOF/p' claude-mux   # both functions
```

## Happy path (post-build)

### T1.1 restart this session — resumes in place
From a session, "restart this session". Expect: same transcript continues; the tmux pane is the
**same** pane (never destroyed); "Session ready!" handshake; RC reconnects. No LaunchAgent line in
the log for this session.

### T1.2 restart all sessions FROM HOME — home resumes (THE test)
From home, "restart all sessions". Expect:
- Every non-caller resumes (per scope: via loop or in-place).
- **home resumes in place** — `~/.claude/projects/-Users-jonathan-Claude/<id>.jsonl` continues
  (line count grows, no new transcript); home's pane never goes down; RC reconnects; "Session
  ready!" fires.
- No `LaunchAgent autolaunch: starting home` recovery needed; no `Exit code 137`.

### T1.3 restart all from a NON-home caller
Run "restart all" from a project session (e.g. claude-mux). That caller resumes in place; home and
others resume; the caller's RC reconnects.

### T1.4 single-named `--restart SESSION` (target ≠ caller)
`claude-mux --restart datetime-hook` from home. Target resumes (in place or loop per scope); home
untouched.

### T1.5 `--restart --fresh` / "restart this session fresh"
Flag content = `fresh`. Session relaunches in place **without** `-c` → new conversation
(intentional). Confirm no resume, clean handshake.

## Failure / edge modes

### T2.1 Busy/wedged caller won't honor `/exit`
Wedge the caller so `/exit` doesn't take effect. Expect: flag remains, no relaunch, session stays
as-is (same exposure as today's "restart this session"; not worse). Document; consider clear-on-next-launch.

### T2.2 Resume-fail fallback inside an in-place iteration
Force `claude -c` to fail fast on the in-place relaunch. Expect: the loop's fresh fallback runs
(logged), session comes up fresh, pane survives. No infinite loop (flag already consumed).

### T2.3 Crash (non-zero) during an in-place iteration
Kill `claude` non-zero mid-iteration. Expect: loop breaks, pane + `.claudemux-running` left for the
auto-restore tick (today's crash behavior preserved).

### T2.4 Plain user `/exit` (not a restart)
No flag present → normal teardown (pane killed, marker removed, not auto-restored). Unchanged.

### T2.5 Double / rapid restart
Trigger a restart, then another before the first relaunch completes. Flag is consumed per relaunch;
confirm exactly one relaunch per flag, no loop runaway, no double pane.

### T2.6 Infinite-loop guard
Confirm the flag is removed before each in-place relaunch, so a single restart yields a single
relaunch.

## Side effects / regressions

### T3.1 Normal launch (`-d`, `-n`) unaffected
A fresh `-d` launch still runs once, sends "Ready?", and tears down on a real `/exit`. The loop is
transparent when no flag is ever set.

### T3.2 Auto-restore after a real crash still works
Kill a session's claude hard (non-zero). The tick restores it (the loop's crash branch leaves the
pane + marker). No interference from the in-place path.

### T3.3 `/compact` RC reconnect unaffected
The PreCompact hook path is independent; confirm `/compact` still reconnects RC.

### T3.4 Prompt-file lifetime
Confirm the system-prompt temp file is NOT deleted on an in-place relaunch (the relaunch re-reads
it via `--append-system-prompt-file`), and IS deleted on final teardown / via the trap.

## Verification commands

```bash
# Did the caller resume in place (same transcript grows, no new file, no LaunchAgent recovery)?
D=~/.claude/projects/-Users-jonathan-Claude
ls -t "$D"/*.jsonl | head -2      # newest should be the SAME file as before, with more lines
grep -E "restart|caller|Creating tmux session 'home'|autolaunch: starting home|Exit code 137|await-ready|Ready" \
  ~/Library/Logs/claude-mux.log | tail -25
# Pane identity unchanged across the restart (in-place, not recreated):
tmux display-message -t home -p '#{pane_pid}'   # before vs after a restart: wrapper pane persists
```

## Acceptance

- T1.2 (restart-all from home) resumes home **in place** — same transcript, RC reconnects, no
  LaunchAgent recovery, no `Exit code 137`. This is the bug closed.
- T1.1/T1.3/T1.4/T1.5 cover the other restart shapes.
- T2.x: busy/fresh/crash/double-restart degrade safely; no loop runaway.
- T3.x: normal launches, auto-restore, `/compact`, and prompt-file lifetime unregressed.
