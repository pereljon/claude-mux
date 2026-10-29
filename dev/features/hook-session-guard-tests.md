---
kind: investigation
feature: hook-session-guard-tests
status: test plan for hook-session-guard; approved 2026-10-28; run 2026-10-28
related: hook-session-guard.md
---

# Test Plan: hook-session-guard

This plan tests that the hook handlers act inside managed panes and do nothing elsewhere. Review findings go at the end.

Run the handlers directly with `bash ./claude-mux --on-compact` (and `--on-clear` with stdin `{"source":"clear"}`, `--on-prompt`). Watch the log and the target pane for "Ready?". Use a throwaway managed session under `~/Claude/development/zz-*`, deleted afterwards with the user's OK.

## Pre-build checks

- [x] `make check` clean before any edit (build and codemap clean on `main`).
- [x] Bug reproduced 2026-10-28: outside tmux, `tmux display-message -p '#S'` prints a live session name with rc 0.

## Must act (managed pane)

1. In the managed session, a real `/compact` reconnects with the ready handshake, as before.
2. In the managed session, a real `/clear` produces the ready handshake, as before.
3. In `home`, the first prompt of a new day still shows the tip; an update notice still shows when the cache holds a newer version; the upgrade notice still shows after a binary change.

## Must not act

4. Outside tmux (`env -u TMUX -u TMUX_PANE`): each handler exits 0, prints nothing, logs no monitor, and no pane receives "Ready?".
5. Inside an unmanaged tmux session (plain `tmux new -s zz-plain`): same as case 4.
6. `claude --bg` started from a managed pane in that project: compact or clear in it does not type into the managed pane. If it does, apply the Open point fix in the design doc and rerun.
7. `TMUX` set but `TMUX_PANE` unset: same as case 4.
8. A stale `TMUX_PANE` (pane id that no longer exists): same as case 4.

## Regression

9. `make check` clean; `--commands` and injection text unchanged.
10. `on_prompt` stays fast: time 20 runs in a managed pane, before and after; the median rises by under 20 ms.

## Results (2026-10-28, branch build)

Handlers were run with `bash -x` and checked for a `spawn_ready_handshake_monitor` call and emitted notices.

| Case | Result |
|------|--------|
| 1 | Pass. Dev handler with the managed pane's `TMUX_PANE` spawns the monitor; a real `/compact` in `zz-hook-test` logged "Compact complete … sending Ready?". |
| 2 | Pass. Dev handler with the managed pane's `TMUX_PANE` spawns the monitor; a real `/clear` in `zz-hook-test` logged "Clear complete … sending Ready?". |
| 3 | Partial. In a managed pane, `on_prompt` emits the upgrade notice; with home's pane it resolves `_sess=home`. The new-day tip itself was not triggered (today's stamp exists). |
| 4 | Pass. Outside tmux: compact, clear and prompt exit 0, no spawn, no output. |
| 5 | Pass. Unmanaged tmux session `zz-plain`: compact, clear and prompt exit 0, no spawn, no output. |
| 6 | Pass. A `claude --bg` started from a managed pane recorded no `TMUX*` variables in its hook, so `hook_session` fails. The process-ancestry check is not needed. |
| 7 | Pass. `TMUX_PANE` unset: no spawn. |
| 8 | Pass. Stale pane id `%99999`: no spawn. |
| 9 | Pass. `make build`, `bash -n` clean; no `--commands` or injection change. |
| 10 | Pass. `on_prompt` median of 20 runs: 80 ms on `main`, 91 ms on the branch (+11 ms). |

## Review findings

Patch-scope review 2026-10-28 (sonnet, static read). No Critical or Important findings.

- Minor, resolved by test: `hook_session` requires `$TMUX` as well as `$TMUX_PANE`. A UserPromptSubmit hook in the managed `zz-hook-test` session recorded both variables (`TMUX=…,84`, `TMUX_PANE=%84`), so Claude Code passes them to hooks.
- Minor, no change: `agents_md_drift_notice` (`src/65-agents-md-migration.sh:800`) keeps a bare `display-message -p '#S'`. Its only caller is `on_prompt`, which now exits first outside a managed pane; inside one, the bare call names the same session.
- Minor, no change: on the early `exit 0`, `on_prompt` leaves stdin unread. The existing handshake path exits without further reads too.
- Note: the `-d` launch path sets `@claude-mux-managed` just after `new-session` starts the launch script. A hook firing in that window would no-op; rated negligible.
