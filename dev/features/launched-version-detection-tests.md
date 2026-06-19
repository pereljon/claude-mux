---
feature: launched-version-detection
---

# Test Plan: launched-version detection (stale claude-mux nudge)

Tests for `launched-version-detection.md`. The feature is a notify-only injection
that mirrors `detect_claude_upgrade`. Decisive checks: the nudge fires exactly when
the on-disk `$VERSION` is newer than the session's launch-time
`@claude-mux-launched-version`, fires **once** per upgrade, never fires on the
`Ready?` handshake, and is silent for pre-feature sessions.

## Pre-build verification (confirm before coding)

- **V0.1** `version_gt` semantics: `version_gt "$VERSION" "$launched"` is true iff
  the first arg is strictly greater. Confirm with the existing helper
  (`src/30-helpers.sh:22`) - e.g. `version_gt 2.1.0 2.0.7` true, `version_gt 2.0.7
  2.0.7` false, `version_gt 2.0.6 2.0.7` false.
- **V0.2** All four launch sites that set `@claude-mux-dir`/`@claude-mux-claude-id`
  are covered by the stamp edit (fresh + backfill, in `src/55` and `src/70`). Grep
  to confirm none is missed: every `set-option ... @claude-mux-claude-id` gains a
  sibling `@claude-mux-launched-version`.
- **V0.3** The handshake no-op (`on_prompt` exits when `_is_handshake == 1`,
  `src/75:136`) precedes the new detector call. Confirm ordering after the edit.

## Detection logic (unit-ish, with a stubbed tmux/session)

Drive `detect_claudemux_upgrade` against a real throwaway tmux session (set the
option, run the hook entrypoint, inspect stdout + the option after).

- **T1.1 Fires when on-disk is newer.** Set `@claude-mux-launched-version` to a
  version below `$VERSION` → the detector prints the "restart this session" notice
  naming both versions.
- **T1.2 One-shot ack.** After T1.1, the detector overwrote the option to `$VERSION`.
  Run it again → **no** output (already acked). Mirrors the Claude Code detector.
- **T1.3 Equal version → silent.** Option == `$VERSION` → no output, option unchanged.
- **T1.4 Downgrade → silent.** Option set to a version *above* `$VERSION` → no output
  (`version_gt` false).
- **T1.5 Pre-feature session → silent.** Option unset/empty → `return 0`, no output,
  nothing written.
- **T1.6 Not in tmux → silent.** Run the hook with no `$TMUX` / failing
  `display-message` → no output, no error.

## Handshake interaction (the sharp one)

- **T2.1 No fire on `Ready?`.** Feed `on_prompt` a stdin JSON with
  `"prompt":"Ready?"` while the session's option is stale. `on_prompt` exits at the
  handshake check **before** the detector runs → no notice, and the option is **not**
  acked (so the nudge still fires on the first real prompt). Verify the option is
  unchanged after the handshake turn.
- **T2.2 Fires on the first real prompt after a restart.** Same stale option, then a
  real prompt (non-`Ready?`) → the notice appears exactly once; the option is acked.

## on_prompt integration (all flush paths carry the notice)

The notice is always-on, so it must survive every early exit, like `_bin_notice`:

- **T3.1 Tips + updates both OFF.** `TIP_OF_DAY=false UPDATE_CHECK=false` with a stale
  option and a real prompt → the nudge still prints (the both-off guard flushes it).
- **T3.2 No/!invalid session_id.** stdin with no `session_id` → tip/update work is
  skipped, but the always-on nudge still flushes.
- **T3.3 Co-existence with the Claude Code nudge.** Both `@claude-mux-claude-id` and
  `@claude-mux-launched-version` stale → both notices appear (order stable, no
  clobbering of one another's ack).
- **T3.4 Co-existence with a daily tip.** Stale option + tip due → both the tip and
  the nudge surface in one turn.

## Launch-time stamp

- **T4.1 Fresh launch sets the option.** Start a throwaway session; `tmux show-options
  -t <s> -v @claude-mux-launched-version` == current `$VERSION`.
- **T4.2 Backfill path sets it.** A path that hits the live-session backfill branch
  (`src/55:73-74` / `src/70:95-96`) also sets the option (so sessions adopted by an
  upgraded script get stamped, not left blank forever).
- **T4.3 `--update` re-stamps.** After `--update` (which `exec ... --restart`s),
  the option equals the new `$VERSION` → the in-tool path never shows the nudge.

## Behavior smoke / regression

- **T5.1 `.claudemux-running` unchanged.** The marker is still a bare, empty
  `touch`-ed file; no version suffix, no content. `should_be_alive` /
  `autorestore_status` / wrapper `rm -f` are untouched (grep diff shows no marker
  reader changed).
- **T5.2 Build still byte-clean.** `make build && make check` pass; `bash -n` clean.
- **T5.3 Read-only commands** (`-l`, `-L`, `--guide`, `--commands`, `--config-help`)
  unaffected.
- **T5.4 End-to-end stale nudge.** Start a session; manually set its
  `@claude-mux-launched-version` to an older value (simulating an out-of-band
  upgrade); send a real prompt; confirm the restart nudge appears once; say "restart
  this session"; confirm the relaunched session is stamped with the current `$VERSION`
  and the nudge no longer fires.

## Acceptance

- T1.x: detector fires exactly on newer-on-disk, once, and is silent otherwise.
- T2.x: never fires on the handshake; fires on the first real prompt.
- T3.x: surfaces through every `on_prompt` flush path, alongside existing notices.
- T4.x: stamped at every launch site; `--update` self-clears the window.
- T5.x: marker untouched, build clean, no regressions.

## Cleanup

Remove throwaway test sessions. No persistent state is introduced beyond the tmux
option (gone when the session ends) - nothing to clean on disk.
