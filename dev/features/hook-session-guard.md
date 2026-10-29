---
kind: feature
lifecycle: building
feature: hook-session-guard
status: BUILT 2026-10-28 on branch hook-session-guard; tests pass (see -tests.md); awaiting code review
target_version: 2.5.0 (minor), alongside --shutdown --fresh
severity: Medium (a compaction or clear outside claude-mux types "Ready?" into an unrelated live session)
related: clear-ready-handshake.md, claude-code-upgrade-detection.md, tip-home-daily.md, cross-cli-coders.md
---

# Feature: hooks act only inside the claude-mux pane that owns them

This doc fixes the claude-mux hook handlers so they act only when they run inside a claude-mux-managed tmux session. Today they act on whatever session tmux reports as current, even outside tmux.

## Problem

The hook handlers find their session with `tmux display-message -p '#S'`. Outside tmux, that command exits 0 and prints the session tmux treats as current. On 2026-10-28, `env -u TMUX -u TMUX_PANE tmux display-message -p '#S'` printed `financial-planner`. The handlers' `|| return 0` and empty-string guards never trigger.

These Claude Code sessions run the hooks but not in their project's claude-mux pane:
- `claude` started in a plain terminal in a project folder.
- An agent view background session (`claude --bg`).
- A session in `<project>/.claude/worktrees/<name>`, since Claude Code uses the main checkout's `.claude/settings.local.json` there (per the development session's reading of the settings docs; not checked here).
- A `claude` in a tmux session that claude-mux does not manage.
- A Codex session that imported these hooks (`docs/ISSUES.md`, 2026-09-04 entry).

Effects, by handler (`src/75-tip-notices.sh`):
- `on_compact` and `on_clear` call `spawn_ready_handshake_monitor`, which types "Ready?" and Enter into the wrong session.
- `detect_claude_upgrade`, called by `on_prompt`, compares the binary with another session's stored id, so the upgrade notice can be wrong. Its comment claims a no-op outside tmux; that claim is false.
- `on_prompt` emits the update notice in any session, wrapped in `<assistant-must-display>` tags. Only claude-mux's injected prompt teaches a session to relay those tags.
- `on_prompt` shows the daily tip if the resolved session happens to be `home`.

## Design

Add one helper, `hook_session`, and use it in all four places.

```bash
hook_session() {
    [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]] || return 1
    local s
    s=$("$TMUX_BIN" display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null) || return 1
    [[ -n "$s" ]] && is_claude_mux_session "$s" || return 1
    printf '%s\n' "$s"
}
```

- `-t "$TMUX_PANE"` resolves the pane the hook runs in, not tmux's current client.
- `is_claude_mux_session` (`src/40-shutdown.sh`) checks the `@claude-mux-managed` session option. Every launch path sets that option. The check is one tmux call, so `on_prompt` stays fast.
- `on_compact`, `on_clear`, and `detect_claude_upgrade` return 0 when `hook_session` fails.
- `on_prompt` exits 0 with no output when `hook_session` fails. This drops the update notice for sessions outside claude-mux. Those sessions never learned to relay the tags, so the notice there only leaks raw tags.

## Verified: background sessions

A `claude --bg` started from inside a managed pane does not pass `TMUX` or `TMUX_PANE` to its hooks (test case 6, Claude Code 2.1.312). The guard therefore covers it, and no process-ancestry check is needed.

## Decisions

- 2026-10-28: resolve through `$TMUX_PANE` and check `@claude-mux-managed`. Rejected: `is_managed_session`, because it scans every project folder on each prompt. Rejected: a process-ancestry check, because test case 6 showed background sessions carry no tmux variables.

## Change checklist

- `src/75-tip-notices.sh` (helper and four call sites); `make build`, `make codemap`, `make check`.
- `dev/CODEMAP.md` purpose row for `hook_session`; `dev/SKELETON.md` hook section.
- `CHANGELOG.md` under Unreleased; `docs/ISSUES.md` entry marked resolved.
- No injection, flag, or config change. Translations deferred until the release.
