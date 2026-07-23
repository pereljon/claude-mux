---
kind: feature
lifecycle: shipped
feature: clear-ready-handshake
status: SHIPPED in v2.2.0 (committed 3542d98, RELEASED 2026-07-23, deployed to ~/bin). Code review APPROVE (0 findings). Live end-to-end verified: real in-pane /clear → SessionStart(clear) hook → --on-clear → handshake reply with model, on a throwaway session. Mechanism verified via claude-code-guide agent (SessionStart source=clear confirmed against Claude Code docs).
target_version: 2.2.0 (minor) — new always-on hook + new capability (clear now produces the ready handshake, at parity with compact)
severity: N/A (enhancement) — UX parity with compact; clear currently gives no confirmation and no model readout
related: tip-ready-handshake.md, notice-delivery-reliability.md, ready-handshake.md
---

# Feature: `/clear` produces the ready handshake, like `/compact` does

## Problem

`compact this session` (and an in-pane `/compact`) causes the session to reply
"Session ready! Running [model] in [mode] mode." — a useful confirmation that the
session is back and a readout of the current model/mode. `clear this session` (and an
in-pane `/clear`) produces **no** such confirmation. The user wants clear to behave like
compact: after the context is wiped, the session should confirm ready and report its
current model.

Note this is a **confirmation/parity** feature, not an RC-reconnect fix. Verified
(claude-code-guide agent, 2026-07-23): `/clear` does **not** restart the `claude`
process, so the Remote Control connection is not expected to drop on clear (unlike
compact, whose original motivation was RC reconnect). The value here is the handshake
reply + model readout, which happens to reconnect RC as a side effect if it ever were
needed.

## Mechanism (verified)

Claude Code's `SessionStart` hook fires with `source: "clear"` when `/clear` runs,
matchable via `"matcher": "clear"`. It fires for **both** an in-pane `/clear` and a
programmatic (`-s`) one — exact parallel to how `PreCompact` catches `/compact`. This is
the trigger.

New hook, mirroring the existing PreCompact `--on-compact` hook:

```json
"SessionStart": [
  { "matcher": "clear",
    "hooks": [ { "type": "command", "command": "<claude-mux> --on-clear", "timeout": 10 } ] }
]
```

`--on-clear` runs a new `on_clear()` handler that (like `on_compact`) spawns a disowned
monitor: wait for the shell prompt to return, then `send-keys` `Ready?` + Enter. The
session's injection already instructs it to reply with exactly the two ready lines.

### Strict gating (critical)

`SessionStart` also fires on `startup` and `resume`, where the launch wrapper **already**
sends `Ready?` (`create_claude_session` / `launch_single_session` / `await_ready_handshake`).
If our hook fired there too it would race the launch handshake at the most fragile moment
(a duplicate `Ready?` into a session mid-launch). We gate **twice**:

1. `"matcher": "clear"` in the hook config — Claude Code only invokes the hook on the
   clear source.
2. In-handler defense: `on_clear` reads the hook stdin JSON and **no-ops unless
   `source == "clear"`**. Belt-and-suspenders against any matcher-semantics surprise or a
   hand-edited settings file that drops the matcher.

### Reuse, not duplicate

`on_compact` already implements "wait for prompt, then send Ready?". Factor that inner
monitor into a shared helper `spawn_ready_handshake_monitor <session>` (disowned
background poller: 5s lead-in, poll `^❯|^> ` up to 120s, `has-session` guard, send
`Ready?`+Enter). `on_compact` and `on_clear` both call it. This keeps the diff small and
avoids drift between the two paths. `on_clear` adds only the stdin `source` check in front.

## Touch points

Same three hook-management sites the PreCompact hook uses, plus flag/dispatch/handler:

| Site | File | Change |
|---|---|---|
| Handler | `src/75-tip-notices.sh` | New `on_clear()`; extract `spawn_ready_handshake_monitor()` from `on_compact()` and have both call it |
| Flag parse | `src/10-flags.sh` | `--on-clear) set_command "--on-clear" "on-clear"` + `--commands` help line |
| Dispatch | `src/90-dispatch.sh` | `on-clear) on_clear; exit 0` + add `on-clear` to the config-skip case list |
| Hook install/merge | `src/50-restore-state.sh` (~657-704) | Add always-on `SessionStart` matcher=`clear` entry running `<b> --on-clear`; include `SessionStart` in the "drop emptied hook lists" loop |
| Desired-state check | `src/50-restore-state.sh` (~596-602) | Require the `SessionStart` `--on-clear` hook present (so `update_all_project_hooks` re-patches stale projects) |
| Uninstall removal | `src/75-tip-notices.sh` (~398-413) | Add `('SessionStart', '--on-clear')` to the removal tuple list |

Backfill is automatic: `install_hooks_command` → `update_all_project_hooks` →
`setup_claude_mux_permissions`, which is where the merge lives. Existing sessions won't
fire the hook until restarted or `--install-hooks` run (same rollout as PreCompact).

### Hook-entry shape difference

Existing claude-mux hook entries have no matcher: `{'hooks': [ ... ]}`. The SessionStart
entry needs `{'matcher': 'clear', 'hooks': [ ... ]}`. The install/desired-state/removal
python must match on command suffix (`--on-clear`) as today, and the install must write
the `matcher` key.

## Interaction notes

- **on_prompt no-op on `Ready?`** already exists (tip-ready-handshake fix): the injected
  `Ready?` won't consume a daily tip or notice. No change needed there.
- **SessionStart(clear) can inject context** (e.g. the superpowers skill intro). That
  injection rides on the `Ready?` turn and is swallowed by the handshake reply — identical
  to startup, where `Ready?` is also the first prompt. Not a regression; the content stays
  in context as a system-reminder, only its surfacing is suppressed for that one turn.
- **Home session**: home gets the hook too; the ready handshake rule applies to home.
- **Conversational `clear this session` trigger** (`src/30-helpers.sh`): no change to the
  send path required — the hook fires on the resulting `/clear`. Optionally add a one-line
  note to the trigger rule that the session will confirm ready (kept minimal / optional).

## Non-goals

- No `SessionEnd` hook (SessionStart(clear) is sufficient and fires when the fresh cleared
  session is ready).
- No new config gate — always-on, like PreCompact.
- No change to compact behavior beyond the shared-helper extraction (must stay byte-behavior
  identical).

## Version / review

2.2.0 minor. Code review scope (minor): all functions added or modified —
`on_clear` (new), `spawn_ready_handshake_monitor` (new, extracted), `on_compact`
(refactored to call it), `setup_claude_mux_permissions` (hook install + desired-state),
the uninstall removal python, dispatch + flag additions.
