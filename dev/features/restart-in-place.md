---
kind: feature
lifecycle: shipped
feature: restart-in-place
status: IMPLEMENTED in v2.0.6 (pending the real restart-all-from-home test)
target_version: 2.0.6 (patch - fixes existing broken behavior, not new functionality)
severity: HIGH (fixes caller-restart context loss)
related: caller-restart-resume-investigation.md (the bug this fixes)
---

## Locked decisions (2026-06-17)
- **Scope: caller-only.** restart-in-place applies to the *caller* of a restart; non-callers keep the existing `shutdown_single_session` + `create_claude_session` loop (its hard-kill is more robust for busy/wedged sessions, and they don't have the teardown-race bug).
- **Flag: tmux user option `@claude-mux-restart`** (value `resume`|`fresh`), NOT a marker file. It is transient session-runtime state, which per CLAUDE.md's marker philosophy belongs in a tmux user option; no disk artifact, auto-resets with the session. The standalone wrapper reads it via `tmux show-option -qv` (it already has `$TMUX_BIN` for kill-session) and clears it after consuming.
- **Handshake: new internal `--await-ready SESSION` subcommand** (wraps `poll_until_ready` + send "Ready?"), backgrounded by the wrapper on an in-place relaunch. Do NOT inline/duplicate `poll_until_ready` (busy/quiescence/trust-accept) inside the security-sensitive heredoc.
- **Version: 2.0.6 (patch).** Fix to existing behavior; `--await-ready` is internal plumbing, not a user-facing feature.
- **Prompt file moves to `<project-dir>/.claudemux-prompt` and is REGENERATED, not re-read.** Replaces the ephemeral `$TMPDIR/claude-prompt-XXXXXX`. Rationale: (1) `$TMPDIR` is OS-reaped (could vanish under a long-lived session, breaking an in-place re-read); (2) re-reading a once-written file gives a **stale injection** (a restart wouldn't pick up claude-mux/trigger-rule updates — defeating a main reason to restart). So: initial launch writes `build_system_prompt` to `<dir>/.claudemux-prompt` (in-process, robust); on an in-place relaunch the wrapper **regenerates** it via a new internal `--print-system-prompt SESSION MODE` before relaunching `claude`, so the injection is always current. Per-session (matches per-session injection), mode-600, auto-gitignored (`.claudemux-*`), removed on clean teardown. The launch *script* (`claude-launch-XXXXXX`) stays in `$TMPDIR` (run once, not re-read).
  - New internal subcommand **`--print-system-prompt SESSION MODE`** → emits `build_system_prompt`. Guard the regenerate (write to temp, `mv` only if non-empty) so a build failure can't blank the injection.
  - Note: the prompt now lives in the project folder (gitignored, 600). It contains claude-mux internals + `GITHUB_SSH_INFO` (account/host aliases — not secrets). Low concern; noted because a cloud-synced folder would carry it.

# Feature: Restart-in-place — relaunch `claude -c` in the same pane instead of tear-down + external recreate

Implementable design spec. Test plan: `restart-in-place-tests.md`.

## Problem (recap)

Restarting the **caller** of a restart (the session that runs the restart command) loses its
conversation, because:
- The caller can only resume by exiting cleanly (`/exit`), but a clean exit makes the launch
  wrapper **tear down the caller's tmux pane**.
- The restart logic that would recreate the session **lives inside that pane**, so the teardown
  kills it before it can recreate (a race the single-session restart usually wins and restart-all
  loses). Recovery then falls to the LaunchAgent, which resumes but is slow and whose "Ready?"
  handshake gets reaped → RC stuck.

Full investigation: `caller-restart-resume-investigation.md`. Every external-relaunch workaround
(handoff, tmux helper, launchd kickstart) hit either a fork or a handshake-reap problem.

## Core idea

Stop recreating the session from outside. Make the **launch wrapper itself loop**: on a clean
exit that is flagged as a *restart*, relaunch `claude -c` **in the same pane** instead of tearing
down. The pane never dies, so:
- there is no in-pane script that must survive a teardown (the wrapper *is* the relauncher, and it
  never exits during a restart);
- the "Ready?"/RC-reconnect handshake is spawned inside the surviving pane, so it isn't reaped;
- it works identically for the caller and any other session — no external process, no launchd, no
  helper, no race.

Every restart path collapses to: **set a per-session "restart-in-place" flag, then send `/exit`.**

## Design

### 1. The restart-in-place flag

A per-session marker file in the session's working dir:

```
.claudemux-restart-inplace        # presence = "on next clean exit, relaunch in place, don't tear down"
```

- **Content encodes mode:** empty or `resume` → relaunch with `-c`; `fresh` → relaunch without `-c`.
- Auto-gitignored by the existing `.claudemux-*` pattern. Consumed (removed) by the wrapper the
  instant it acts on it — a transient signal, not long-lived state.
- Set via `printf '%s' resume|fresh > "$dir/.claudemux-restart-inplace"` by the restart paths.
- Why a file (not a tmux option): the wrapper is a standalone bash script that already references
  the session dir (for `.claudemux-running`); a file check needs no tmux call and no claude-mux
  functions at wrapper runtime.

### 2. The looped wrapper (both `create_claude_session` and `launch_single_session`)

Today the generated launch script runs `claude` once then tears down on clean exit. New shape
(pseudocode; preserves the existing resume-fail fresh fallback and crash behavior):

```bash
#!/bin/bash
trap 'rm -f "<launch_script>" "<prompt_file>"' EXIT
export PATH="<claude dir>:$PATH"
_marker='<.claudemux-running path>'
_flag='<.claudemux-restart-inplace path>'
_resume='-c'                                   # initial mode (empty if FRESH_START)
while true; do
    _start=$(date +%s)
    _err=$(mktemp ...)
    claude ${_resume:+$_resume }--remote-control <perm/model> --name '<session>' \
        --append-system-prompt-file '<prompt_file>' 2>"$_err"
    _rc=$?
    if [[ $_rc -ne 0 && $(( $(date +%s) - _start )) -lt 10 ]]; then
        <log resume-fail + stderr>; claude <same, no -c>; _rc=$?     # existing fresh fallback
    fi
    rm -f "$_err"
    if [[ $_rc -eq 0 ]]; then
        if [[ -e "$_flag" ]]; then
            # RESTART-IN-PLACE: do not tear down; relaunch in the same pane.
            _mode=$(cat "$_flag" 2>/dev/null); rm -f "$_flag"
            _resume='-c'; [[ "$_mode" == fresh ]] && _resume=''
            '<CLAUDE_MUX_BIN>' --await-ready '<session>' &   # handshake from the surviving pane
            continue
        fi
        # normal clean exit (/exit or Ctrl-C x2): tear down as today
        rm -f "$_marker" "<launch_script>" "<prompt_file>"
        '<TMUX_BIN>' kill-session -t '<session>'
        break
    fi
    break    # crash (non-zero): leave pane + marker for the auto-restore tick
done
```

Notes:
- The first iteration's "Ready?" is still sent by the external launcher (`create_claude_session` /
  `launch_single_session`) exactly as today — unchanged for normal launches.
- For *in-place* iterations the wrapper backgrounds the handshake itself (see #4).
- The `--remote-control`/`--name`/prompt-file args are identical each iteration; the prompt file
  must therefore NOT be deleted on an in-place relaunch (only on final teardown). Adjust the
  external launcher's "delete prompt file after ready" accordingly, or have the wrapper keep it
  until teardown.

### 3. Restart paths reduce to "set flag + /exit"

- **restart this session** / **single-named `--restart SESSION`** / **caller in restart-all**:
  `printf resume > "$dir/.claudemux-restart-inplace"`, then `tmux send-keys -t SESSION -l "/exit"`
  + Enter. The session's own wrapper does the relaunch when claude processes the `/exit`.
  - For the **caller**, the restart command then simply returns — claude finishes its turn,
    processes the queued `/exit`, exits, and the wrapper relaunches in place. No recreate, no
    handoff, no partition, no race.
- **`--fresh`**: write `fresh` instead of `resume`.

**Decision needed — scope:**
- **(A) Caller-only (lower risk):** use restart-in-place for the *caller*; keep the existing
  `shutdown_single_session` + `create_claude_session` loop for non-callers (hard-kill is more
  robust for a wedged/busy non-caller that won't honor `/exit`).
- **(B) Uniform (simpler, bigger):** every target restarts via set-flag + `/exit`; drop the
  partition/handoff/create entirely. Cleaner, but relies on `/exit` taking effect (a busy/wedged
  session won't restart without a fallback hard-kill).
- Recommendation: **(A)** first (fixes the actual bug with least surface), consider (B) later.

### 4. Handshake from the surviving pane

In-place relaunches need their own "Ready?" (resume the prompt + reconnect RC). The external
launcher can't do it for the caller (its process is gone). Add a small internal command:

```
claude-mux --await-ready SESSION   # poll_until_ready SESSION; then send "Ready?" + Enter
```

The wrapper backgrounds it (`claude-mux --await-ready '<session>' &`) right before re-running
`claude`. Because the pane stays alive (it's running `claude`), this backgrounded process survives
the full poll (≤120s) and fires the handshake — unlike the launchd/helper paths where the launcher
exited first. Reuses the existing `poll_until_ready`.

(Alternative: inline a minimal busy-poll in the wrapper to avoid a new subcommand. The subcommand
is preferred — it reuses tested code and keeps the wrapper small.)

### 5. Marker / auto-restore interactions

- `.claudemux-running` stays present across an in-place restart (the session is never "stopped"),
  so the auto-restore tick never sees it down. No `.claudemux-restarting` lock needed for the
  in-place path (the pane never goes down → no window for the tick to race). Keep the lock only if
  scope (B) still kills non-callers.
- A crash during a `claude` iteration (non-zero exit) breaks the loop and leaves pane + marker —
  identical to today; the watchdog handles it.

### 6. Edge cases

- **Resume-fail fallback** inside an in-place iteration: same as today (claude `-c` fails fast →
  fresh `claude`), now inside the loop. Logged.
- **Flag set but claude never cleanly exits** (busy/wedged caller): `/exit` doesn't take effect →
  no relaunch. Same exposure as "restart this session" today; acceptable for (A). The flag remains
  until the next clean exit (or is cleared by a subsequent restart). Consider a TTL/clear-on-launch.
- **Infinite loop guard:** the flag is consumed (removed) before each in-place relaunch, so one
  flag = one relaunch.
- **`/exit` typed by the user (not a restart):** no flag present → normal teardown. Unchanged.

## Why this over the alternatives

- **External relaunch (handoff / launchd kickstart / tmux helper):** all relaunch from outside the
  pane and hit either a fork or a reaped handshake; launchd also adds a disabled-state edge and
  ~60s latency. Restart-in-place removes the external relaunch entirely.
- **"Delay the kill-session":** still races and leaves a second/forked session; in-place never
  creates a second session.
- **Don't restart the caller (option A from the investigation):** safe but the caller never picks
  up the update. In-place actually restarts it.

## Verified facts / assumptions to verify BEFORE finalizing

- Current wrappers run `claude` once then `kill-session` on rc 0 (create_claude_session ~2980-3016;
  launch_single_session ~3300-3330). Confirmed.
- The launch script is standalone bash (no claude-mux functions at runtime) — so the handshake must
  be a subcommand or inlined. Confirmed.
- **ASSUMPTION to verify:** an in-place `claude -c` (re-run in the same pane after a clean `/exit`)
  resumes the just-ended conversation. Strongly supported (clean-exit + `claude -c` resumed in the
  LaunchAgent recovery and in restart-this-session) but must be directly tested.
- **ASSUMPTION to verify:** after a restart `/exit`, claude processes the queued `/exit` once the
  restart bash-tool returns, exits rc 0, and the wrapper's loop iterates (the pane survives). Test
  directly.
- **ASSUMPTION to verify:** `claude-mux --await-ready` backgrounded by the wrapper fires "Ready?"
  and reconnects RC. Test.

## Change checklist (per CLAUDE.md)

- [ ] `claude-mux`: looped wrapper in BOTH `create_claude_session` and `launch_single_session`
  (the security-sensitive heredocs — quote-safety review required).
- [ ] `claude-mux`: new `--await-ready SESSION` subcommand (wraps `poll_until_ready` + send Ready?).
- [ ] `claude-mux`: restart paths set the flag + `/exit` (caller path; per scope decision).
- [ ] `claude-mux`: prompt-file lifetime — keep until teardown, not deleted on in-place relaunch.
- [ ] `commands_help()` for `--await-ready`; `build_system_prompt()` feature list if user-facing.
- [ ] Marker registry (CLAUDE.md + CODEMAP): add `.claudemux-restart-inplace`.
- [ ] `dev/CODEMAP.md`: wrapper change, new subcommand, new marker.
- [ ] `dev/SKELETON.md`: launch-wrapper loop + restart-path simplification.
- [ ] `dev/IMPLEMENTATION-SPEC.md`: restart model (in-place) design decision.
- [ ] `CHANGELOG.md`: restart-in-place; resolves the caller-restart context-loss issue.
- [ ] `docs/ISSUES.md`: move the caller-restart investigation entry to Resolved.
- [ ] `VERSION`: significant — propose 2.1.0; full code review of the wrapper.
- [ ] Release: `claude-mux` changed → release.

## Open questions

1. **Scope (A) caller-only vs (B) uniform** — recommend (A) first.
2. **Handshake: `--await-ready` subcommand vs inlined poll** — recommend the subcommand.
3. **Flag: file (proposed) vs tmux option** — recommend file (no runtime tmux/functions needed).
4. **Version bump** — 2.1.0 (core change) vs 2.0.x. Recommend 2.1.0.
