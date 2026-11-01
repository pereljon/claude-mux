---
kind: investigation
feature: pane-readiness-gate-tests
status: test plan approved 2026-10-31; run 2026-10-31
related: pane-readiness-gate.md
---

# Test Plan: pane-readiness-gate

This plan tests that claude-mux never sends Enter into an open dialog and still works otherwise. Review findings go at the end.

Use a throwaway managed session under `~/Claude/development/zz-*` in manual mode. A pending `touch marker.txt` shows whether a send approved the prompt.

## Pre-build results (2026-10-31, Claude Code 2.1.312)

- Bug reproduced: `-s zz-gate-test '/status'` with a prompt open returned 0 and created `marker.txt`.
- The prompt hides the input row. The bottom 5 lines have no `^❯` match; the whole pane matches on the echoed user turn.
- A busy session keeps the input row in the bottom lines.

## Must not send (dialog open, marker stays absent)

1. `-s` with a slash command exits 1 and prints an error.
2. `--shutdown SESSION`: Escape dismisses the prompt, and then `/exit` runs.
3. `--restart SESSION`, called from another session and from inside the session.
4. A fresh restart (`/clear` path).
5. The compact and clear `Ready?` monitors skip and log.
6. A launch timeout skips `Ready?` instead of sending it anyway.
7. `notify_home` stays silent with a dialog open in home.
8. The other dialogs: `AskUserQuestion`, plan approval, and the `/model` confirmation.

## Must still send

9. `-s` to an idle session.
10. `-s` to a busy session, including a self-sent `/clear`, `/compact` and `/model <id>` from inside a tool call.
11. Normal launch, restart, compact and clear still complete the `Ready?` handshake.
12. The startup trust and bypass dialogs are still auto-accepted.
13. Shutdown of all sessions with none in a dialog.

## Edge cases

14. A pane too narrow or short to show the full footer.
15. A user draft in the input row: record the behavior; it is unchanged by this gate.
16. The fail-closed case: a pane with no Claude UI sends nothing.

## Regression

17. `make check` is clean, and `--commands` is unchanged apart from any new `-s` error text.

## Results (2026-10-31, branch build, Claude Code 2.1.312)

A pending `touch marker.txt` showed whether a send approved a prompt. The marker stayed absent in every "must not send" case.

| Case | Result |
|------|--------|
| 1 | Pass. `-s` exits 1 and prints the error. |
| 2 | Pass. Escape, then shutdown. |
| 3 | Pass from another session. From inside, in-place restart printed the error and left the prompt open; the exit code was not captured. |
| 4 | Pass. `/clear` refused, the stop warned, Escape dismissed the prompt. |
| 5 | Pass for compact. The monitor timed out and logged. `--on-clear` shares the monitor and was not run with a dialog open. |
| 6 | Pass. `--await-ready` logged the skip, and the monitor sent `Ready?` after the dialog cleared (from the log; the turn was not seen on screen). |
| 7 | Not run. Home was not given a dialog; `notify_home` calls the same helper. |
| 8 | Pass. `AskUserQuestion` at all four cursor positions, plan approval, and the `/resume`, `/config`, `/permissions`, `/model` and `/mcp` pickers are refused. The `/model` confirmation is still auto-confirmed. `/agents` passes because the input row stays on screen. |
| 9 | Pass. |
| 10 | Pass. Busy and self-sent `-s`, using `/status`. `/clear`, `/compact` and `/model` were not sent from inside a tool call. |
| 11 | Partial. Compact monitor sent `Ready?`; launch and restart completed; a successful in-place restart was not run. A full real `/compact` was not run on this build. |
| 12 | Not run. The trust and bypass code is unchanged. |
| 13 | Not run. Bulk shutdown would stop every session; the changed lines are reviewed only. |
| 14 | Pass at 45x14. |
| 15, 16 | Not run. Case 16 fails closed by construction. |
| 17 | Pass. `make check` is clean; no injection or `--commands` change. |

## Review findings

Review 2026-10-31 (sonnet, high effort, static read plus awk and bash 3.2 runs). No Critical findings.

- Important, fixed: a skipped in-place restart was silent with exit 0. It now prints an error and counts in the exit code.
- Important, fixed: a launch with a dialog open at timeout never got `Ready?`. The skip now hands off to the ready monitor. A dialog left open past that window still gets none; recorded in the design doc's limits.
- Minor, fixed: shutdown waited 10 seconds after a skipped `/exit`.
- Minor, fixed: the `poll_until_ready` header comment was separated from its function.
- Minor, fixed: `dev/SKELETON.md` described the removed send-anyway fallback.
- Minor, accepted: the 8-line window can give a false refusal. It fails closed; recorded in the design doc's limits.
- Minor, resolved by test: other cursor lists could look like the input row. The pickers in case 8 are refused.
- Minor, deferred: the loose `yes.*accept` match in `poll_until_ready` is outside this diff; recorded in `docs/ISSUES.md`.
- Not checked: awk on mawk or gawk (not installed; standard syntax).
