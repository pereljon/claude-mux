---
kind: investigation
feature: pane-readiness-gate-tests
status: test plan draft 2026-10-31; awaits user review
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
