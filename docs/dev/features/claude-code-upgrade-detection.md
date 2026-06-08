# Feature: Claude Code upgrade detection (v2.0 self-healing)

Implementable design spec. Lifted from `docs/ISSUES.md` (v2.0 Milestone, "Claude Code upgrade detection"); assumptions verified before finalizing (see "Verified assumptions"). Test plan: `claude-code-upgrade-detection-tests.md`.

> Naming: this is about the **`claude` executable** (Claude Code itself), not the claude-mux script. claude-mux is a script and updates instantly on disk; `claude` is a separately-installed binary.

## Goal

Detect when the `claude` executable has been upgraded out-of-band (`brew upgrade`, npm, curl installer) since a session started, and tell the user to restart that session to pick up the new binary. A running session keeps the `claude` process spawned from whatever binary was on PATH at launch, so it runs the old binary until restarted.

## Scope

**In:** capture the binary identity at launch (tmux option), compare on each prompt via the existing `UserPromptSubmit` hook, inject a one-shot conversational notice on change.

**Out:** auto-restart (mid-task danger), auto-`brew upgrade` (per-install-method logic, risky), the `-l` "stale" badge (optional follow-up, not required for v2.0), any config gate (always-on; the check is negligible).

## Why no tick

A session with a stale binary is, by definition, **running** (claude alive, just old). The v1.15.0 `UserPromptSubmit` hook (`--on-prompt`) already fires in it on the next prompt, so detection lands exactly where it is relevant. **Decoupled from auto-restore / the `--autolaunch` tick; ships independently.**

## Binary identity

```
claude_binary_id() = realpath(CLAUDE_BIN) + ":" + mtime(realpath)
```

One signal covers both install styles (verified macOS 2026-06-08):
- **Cask**: `command -v claude` -> `/opt/homebrew/bin/claude` -> realpath `…/Caskroom/claude-code/<version>/claude`. Upgrade repoints the symlink, so the **realpath changes**.
- **npm/curl**: replace the file in place (same path, new **mtime**).

`realpath` falls back to `readlink -f` then the raw path; `stat -f %m` (macOS) falls back to `stat -c %Y` (Linux) then `0`. No macOS process introspection (`ps -o etimes` and `/proc` are unavailable; `lsof` is fiddly).

Minor accepted false-positive: a same-version reinstall bumps mtime -> one harmless "stale" notice -> a harmless restart. A precise `claude --version` compare would avoid it but costs a process spawn at launch; not worth it.

## State home: a tmux option, re-set at launch

`@claude-mux-claude-id` is set on the session at launch (in `create_claude_session` and `launch_single_session`, alongside `@claude-mux-dir`/`@claude-mux-managed`), to `claude_binary_id()`.

Why a tmux option, not the per-session JSON state:
- The on-prompt hook's per-session state (`tip-state/<session_id>.json`) is keyed by Claude's **conversation UUID**, which **persists across `--restart`/resume**. Storing the launch binary there would keep reporting "stale" after the user already restarted into the new binary.
- A tmux option is **session-runtime** state: a `--restart` recreates the tmux session and re-runs the launch path, which re-captures `@claude-mux-claude-id` to the now-current binary. So a real restart self-clears the staleness with no extra logic.

## Detection (in `on_prompt`, before the tip/update cheap-guard)

Always-on, so it must run even when `TIP_OF_DAY` and `UPDATE_CHECK` are both off. It needs no stdin/`session_id` (it uses the tmux session name), so it runs before the existing python stdin parse.

```
detect_claude_upgrade() -> echoes a notice line (or nothing):
    sess = tmux display-message -p '#S'          # needs $TMUX (inherited by the hook)
    [[ -z sess ]] && return                       # not in tmux -> silent no-op
    id0  = tmux show-options -v @claude-mux-claude-id
    [[ -z id0 ]] && return                         # pre-feature session / unset -> skip
    id_now = claude_binary_id()
    if id_now != id0:
        echo "[claude-mux — tell the user]: Claude Code was upgraded since this
              session started; say 'restart this session' to load the new binary."
        tmux set-option @claude-mux-claude-id id_now    # acknowledge -> one-shot per upgrade
```

**One-shot gating** is the acknowledge write: after notifying, the option holds `id_now`, so subsequent prompts compare equal and stay quiet until *another* upgrade changes `id_now` again. No new JSON field, no change to the python hot path.

`on_prompt` flow becomes:
```
bin_notice = detect_claude_upgrade()
if TIP_OF_DAY != true AND UPDATE_CHECK != true:
    print bin_notice (if any); exit 0          # preserve the cheap-guard, but flush the notice
... existing tip + update logic accumulating _out ...
_out = bin_notice + _out                        # prepend
print _out (if any); exit 0
```

## Decisions (from ISSUES.md)

- **Always-on** (no config var; the compare is a `realpath`+`stat`).
- **Notify-only.** Never auto-restart, never auto-`brew upgrade`.
- Distinct from "warn before our own restarts" (that explains *our* restarts; this detects an *external* dependency upgrade).

## Verified assumptions (pre-build, 2026-06-08, macOS)

1. **`realpath` + `stat -f %m` on `claude`** works; cask path is versioned (`…/2.1.149/claude`), confirming realpath-changes-on-cask-upgrade. Composed id e.g. `…/2.1.149/claude:1779474221`.
2. **The on-prompt hook inherits `$TMUX`.** The hook runs as a child of the `claude` process; a sibling child (the agent's own shell) has `TMUX`/`TMUX_PANE` set and `tmux display-message -p '#S'` resolves the session name. `ps eww` can't confirm directly (macOS SIP hides env), but the inheritance inference is sound. Residual risk is mitigated by the silent-skip fallbacks (no false notice, no error if `$TMUX` is somehow absent).

## Change-checklist impact (when built)

- New helpers: `claude_binary_id()`, `detect_claude_upgrade()`.
- New tmux option `@claude-mux-claude-id` set in `create_claude_session` + `launch_single_session` (both new and backfill branches) -> CODEMAP tmux-options table.
- Modified: `on_prompt` (call detection before the cheap-guard; prepend notice) -> CODEMAP/SKELETON.
- No new config var, no new marker, no version-string dependency.
- Docs: CODEMAP, SKELETON, CHANGELOG `[Unreleased]`, implementation-spec, ISSUES status note.
- Injection: unchanged (the notice is delivered by the hook, not the system prompt).
