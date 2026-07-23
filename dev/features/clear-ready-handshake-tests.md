---
kind: investigation
feature: clear-ready-handshake-tests
status: test plan for clear-ready-handshake
related: clear-ready-handshake.md
---

# Test Plan: clear-ready-handshake

## Pre-build checks

- [ ] `on_compact` refactor leaves compact behavior identical: after `spawn_ready_handshake_monitor`
      extraction, `bash -n claude-mux` clean and `on_compact` still spawns the monitor.
- [ ] `make build` clean; `make check` passes (artifact matches `src/`, codemap + features-index fresh).

## Unit / static

1. **Flag parse**: `bash ./claude-mux --on-clear` with no tmux → handler runs, no crash, exits 0.
   (Outside tmux, `display-message` fails → `on_clear` returns 0 early, same as `on_compact`.)
2. **Dispatch skip-config**: `--on-clear` is in the config-skip case list — running it with no
   config file present does not prompt or error.
3. **`--commands`** output includes the `--on-clear` line.
4. **shellcheck / `bash -n`** clean on all `src/*.sh` and built `claude-mux`.

## Hook install / merge (setup_claude_mux_permissions)

5. **Fresh settings**: point install at a temp `settings.json` (empty). After merge, it contains a
   `SessionStart` entry with `matcher: "clear"` and command `<b> --on-clear`, alongside the existing
   `PreCompact --on-compact` and `UserPromptSubmit --on-prompt` entries.
6. **Idempotent**: run merge twice → second run is a no-op (desired-state check returns
   "already current"; no duplicate SessionStart entry).
7. **Backfill**: a settings.json that has PreCompact but no SessionStart → `--install-hooks`
   (or `update_all_project_hooks`) adds the SessionStart entry and reports the project as patched.
8. **Desired-state detects missing**: settings.json missing the SessionStart hook → desired-state
   python exits non-zero (triggers re-patch).
9. **Uninstall**: `do_uninstall` removal python strips the `SessionStart --on-clear` entry; if
   SessionStart becomes empty it is dropped; a non-claude-mux SessionStart entry is preserved.

## Gating (critical)

10. **source=clear fires**: feed `on_clear` stdin `{"source":"clear", ...}` → monitor spawned,
    `Ready?` sent (verify with a stub tmux or by checking the code path / log line).
11. **source=startup no-ops**: stdin `{"source":"startup"}` → `on_clear` returns without spawning a
    monitor / sending Ready? (guards against double-send racing the launch handshake).
12. **source=resume no-ops**; **source=compact no-ops**; **missing/empty source no-ops** (fail
    closed — only `clear` triggers).
13. **matcher gate**: the installed config uses `matcher: "clear"`, so Claude Code itself only
    invokes the hook on clear even before the stdin check.

## Behavioral / live (on the repo copy, real tmux session)

14. **Triggered clear**: in a live claude-mux session, `clear this session` → after the clear,
    the session replies exactly "Session ready!" + "Running [model] in [mode] mode." and nothing else.
15. **In-pane clear**: type `/clear` directly in the pane → same handshake reply (parity with
    in-pane `/compact`).
16. **Model readout correct**: switch model, then clear → the ready line reports the new model.
17. **No double handshake on startup/restart**: restart the session → exactly one `Ready?`
    handshake (from the launch path), the SessionStart(clear) hook does NOT also fire.
18. **Compact unchanged**: `compact this session` still produces the handshake (shared helper
    regression check).
19. **No tip/notice eaten**: the `Ready?` after clear does not consume the daily tip (on_prompt
    no-ops on `Ready?`).

## Post-build checklist

- [ ] CODEMAP purpose rows: `on_clear`, `spawn_ready_handshake_monitor`, updated `on_compact`,
      `setup_claude_mux_permissions`; dispatch table `--on-clear` row; `make codemap` index fresh.
- [ ] SKELETON: hook flow includes SessionStart(clear) → on_clear.
- [ ] IMPLEMENTATION-SPEC: hook table / settings section lists the SessionStart hook.
- [ ] README + Session System Prompt section unchanged (no injection change) OR note added if the
      clear trigger rule gets the confirmation note.
- [ ] CHANGELOG 2.2.0 entry; VERSION bump; ISSUES updated; features-index regenerated.
- [ ] `--install-hooks` help + CLAUDE.md hook description mention SessionStart if listing hooks.
