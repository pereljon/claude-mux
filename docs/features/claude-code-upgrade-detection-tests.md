# Test plan: Claude Code upgrade detection

Companion to `claude-code-upgrade-detection.md`. Manual + shell-assertion procedures (claude-mux has no test framework).

## 0. Pre-build verification (DONE — 2026-06-08)

| # | Check | Result |
|---|---|---|
| 1 | `realpath` + `stat -f %m` on `claude` compose a stable id | DONE: `…/Caskroom/claude-code/2.1.149/claude:1779474221` |
| 2 | Cask upgrade changes realpath; npm/curl changes mtime | DONE (reasoned from versioned cask path; one signal covers both) |
| 3 | on-prompt hook inherits `$TMUX` (sibling child of `claude` has it) | DONE (inheritance inference; SIP blocks `ps eww` confirmation) |

## 1. `claude_binary_id()` (unit)

- **T1.1** Returns `realpath:mtime` for the current `claude`; non-empty; contains exactly one `:` separating an absolute path and a numeric mtime.
- **T1.2** Fallbacks: if `realpath` absent, `readlink -f` is used; if both absent, the raw `$CLAUDE_BIN`. If `stat -f %m` fails, `stat -c %Y`; if both fail, `0`. (Simulate by stubbing.)
- **T1.3** Stable across repeated calls when the binary is untouched (same string twice).

## 2. Launch capture (behavior)

- **T2.1** `create_claude_session` (via `-n`, `--restart`, setmode) sets `@claude-mux-claude-id` to `claude_binary_id()` (verify `tmux show-options -v @claude-mux-claude-id`).
- **T2.2** `launch_single_session` (`-d`, home, autolaunch) sets it too.
- **T2.3** Both backfill branches (already-running session) set it, so pre-feature sessions get it on the next claude-mux touch.
- **T2.4** A `--restart` re-captures it to the current binary (option value updates).

## 3. `detect_claude_upgrade()` (unit, with a stubbed `claude_binary_id`/tmux)

- **T3.1** No `$TMUX` / session name empty -> echoes nothing, no error.
- **T3.2** Option unset (pre-feature session) -> echoes nothing.
- **T3.3** `id_now == id0` -> echoes nothing; option unchanged.
- **T3.4** `id_now != id0` -> echoes the notice line AND sets the option to `id_now` (acknowledge).
- **T3.5** After T3.4, a repeat call with the same `id_now` -> echoes nothing (one-shot held by the ack).
- **T3.6** After T3.4, a further change of `id_now` (second upgrade) -> echoes again, re-acks.

## 4. `on_prompt` integration

- **T4.1** Both `TIP_OF_DAY` and `UPDATE_CHECK` off, binary changed -> the upgrade notice is still emitted (always-on; runs before the cheap-guard exit).
- **T4.2** Both off, binary unchanged -> nothing emitted, hook exits 0 (cheap-guard preserved).
- **T4.3** Tip/update on + binary changed -> the upgrade notice is prepended to the tip/update output (single combined emission).
- **T4.4** The detection adds no dependency on `session_id`/stdin; a malformed stdin still lets the binary check run.
- **T4.5** Hot-path cost: detection is a `display-message` + `show-options` + `realpath` + `stat` (no python); confirm no perceptible per-prompt latency.

## 5. End-to-end (manual)

- **T5.1 Cask upgrade:** in a running session, `brew upgrade claude-code` (or simulate by repointing the `/opt/homebrew/bin/claude` symlink to a different version dir); next prompt shows the one-shot notice; a following prompt does not repeat it.
- **T5.2 In-place upgrade:** `touch -t` the resolved binary to bump mtime; next prompt notices; restart the session; the notice does not reappear (launch re-captured the id).
- **T5.3 Restart clears:** after a notice, `restart this session`; subsequent prompts are quiet (option re-set to current).
- **T5.4 No false positive on a fresh session:** start a session, prompt several times without upgrading -> never notices.

## 6. Regression / change-checklist

- `@claude-mux-claude-id` in CODEMAP tmux-options table; `on_prompt` purpose updated.
- SKELETON: `on_prompt` gains the pre-guard detection step; launch sections set the option.
- CHANGELOG `[Unreleased]`, implentation-spec, ISSUES status note.
- `bash -n claude-mux` clean; deploy to `~/bin`; smoke-test a prompt in a session (no spurious notice when binary unchanged).

## Notes

- The acknowledge-write means a user who ignores the notice is reminded again only on the *next* upgrade, not every prompt. Acceptable: the `-l` "stale" badge (deferred) would be the persistent surface if wanted.
