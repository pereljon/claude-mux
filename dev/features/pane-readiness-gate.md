---
kind: feature
lifecycle: designing
feature: pane-readiness-gate
status: DESIGN DRAFT 2026-10-31 on branch readiness-gate; live test confirmed the bug; test plan awaits user review; not built
severity: High (a claude-mux send can run a pending command with no user action)
related: cross-cli-coders.md, clear-ready-handshake.md
---

# Feature: never send Enter into an open dialog

This doc adds one check that claude-mux runs before it sends Enter to a Claude pane. Today an open permission prompt can take that Enter as "Yes", so a command runs without the user. Investigated against Claude Code 2.1.312 and claude-mux 2.4.4.

## Problem

Claude Code's permission prompt highlights "Yes" by default, so any Enter accepts it. On 2026-10-31, in a throwaway manual-mode session with a prompt open for `touch marker.txt`, `claude-mux -s zz-gate-test '/status'` returned 0 and the file was created.

Paths that send Enter, and what each checks first:

| Path | Location | Check today |
|------|----------|-------------|
| `-s` | `src/90-dispatch.sh` | None |
| `/exit` on shutdown | `src/40-shutdown.sh` (two sites) | Claude is running |
| `/exit` for in-place restart | `src/55-session-launch.sh` | None |
| `/clear` for a fresh restart | `src/40-shutdown.sh` | Interrupts a busy session only |
| `Ready?` after launch | `src/55-session-launch.sh`, `src/70-start-launch.sh` | `poll_until_ready`; failure is ignored, so it sends anyway |
| `Ready?` after compact or clear | `src/75-tip-notices.sh` | Whole-pane `^❯` match |
| Home message | `src/80-templates-restore.sh` | `^❯` match in the bottom 5 lines |

The startup dialogs that `poll_until_ready` answers on purpose are out of scope.

## Verified facts

- The prompt's `❯ 1. Yes` row is indented, so `^❯` does not match it.
- The echoed user turn in the transcript does match `^❯`, so a whole-pane match reads an open dialog as idle. `poll_until_ready` and the handshake monitor both use a whole-pane match.
- The input row (`❯ ` at column 0) is in the bottom lines of the pane when idle and while busy. The open dialog replaces it.

## Design

Add one helper, `pane_accepts_input SESSION`. It captures the pane and returns 0 only if a `^❯|^> ` line is in the bottom 6 lines. Every path in the table calls it just before sending.

Busy sessions pass on purpose. A session sends itself `/clear` or `/model` during its own tool call, and typed text queues safely while busy. The `Ready?` paths and the home message keep their own busy checks.

On failure:
- `-s` prints an error and exits 1. It sends nothing.
- `/exit` on shutdown sends Escape once, rechecks, and sends `/exit` if the input row is back. Otherwise it logs a warning and takes the path used when a session does not exit in time.
- The `Ready?` paths log and skip, and the `|| true` send-anyway path goes through the helper.
- The home message returns silently, as it does today when home is not idle.

`poll_until_ready` and the handshake monitor change their prompt match to the same bottom-lines scope.

## Limits

- A gap remains between the check and Enter, so a dialog opening in that gap can still take the key. The gate narrows this race and does not close it.
- The check reads Claude Code's screen, so a UI change can break it. It fails closed: if the row is not found, nothing is sent.
- Hook-written state was considered for the check, but it is unverified. Open point: whether Claude Code's hooks report dialog open and closed reliably enough to replace the screen read.

## Decisions

- 2026-10-31: the user approved designing this gate, with a live test first (`firm`). A plain-text `--send` stays out of scope; see `cross-cli-coders.md`.
