---
feature: tip-ready-handshake
---

# Test Plan: tip eaten by the `Ready?` handshake

Tests for `tip-ready-handshake.md`. Decisive metric: a `Ready?` handshake turn must
inject nothing and stamp no state, so the **first real prompt** after a restart gets
the daily tip.

All tests drive the hook directly by piping `UserPromptSubmit` JSON to
`claude-mux --on-prompt` (the probe shape already used to confirm the bug). Use a
throwaway `session_id` per run and clean up its state file:
`~/.claude-mux/tip-state/<sid>.json`.

Helper:
```bash
SID="t-tip-$(date +%s)-$$"; STATE=~/.claude-mux/tip-state/$SID.json
hook(){ echo "{\"session_id\":\"$SID\",\"prompt\":\"$1\"}" | bash ./claude-mux --on-prompt; }
cleanup(){ rm -f "$STATE"; }
```

## Pre-build verification (confirm before coding) — already done 2026-06-17

- **V0.1 Bug reproduces:** `hook "Ready?"` emits a tip AND writes `tip_date=<today>`;
  a following `hook "hello"` emits nothing. CONFIRMED.
- **V0.2 Handshake string:** every sender uses the literal `Ready?` — `grep -n
  '"Ready?"' claude-mux` shows `await_ready_handshake`, both launch wrappers, and the
  `on_compact` monitor. Re-confirm if a sender changed.
- **V0.3 stdin carries `prompt`:** `UserPromptSubmit` JSON includes `prompt` (the probe
  passed it and the hook ran). The fix adds extraction of this field.

## Static / generation checks (post-build)

- **T0.1** `bash -n claude-mux` passes.
- **T0.2** `claude-mux --on-prompt < /dev/null` (no stdin JSON) exits 0 and does not
  crash (malformed/empty stdin → `is_handshake=0`, behaves as today: no tip without a
  valid session_id).

## Core behavior (live, via hook probe)

Run each with a FRESH `$SID` (so `tip_date` is unset → a tip is eligible).

- **T1.1 Handshake injects nothing, stamps nothing.**
  `hook "Ready?"` → **no** `[claude-mux tip …]` line in output; `cat $STATE` →
  file absent OR `tip_date` NOT today (no stamp). This is the fix vs. the current
  `tip_date=<today>` write.

- **T1.2 First real prompt after a handshake gets the tip.**
  `hook "Ready?"` then `hook "what's the status"` (same `$SID`) → the **second** call
  emits the `[claude-mux tip …]` line and stamps `tip_date=<today>`. (Pre-fix, the
  second call emitted nothing because the handshake had already stamped it.)

- **T1.3 Real prompt still gated to once/day.**
  `hook "first"` (emits tip, stamps today) then `hook "second"` → second emits no tip.
  Unchanged daily-gate behavior.

- **T1.4 Whitespace handshake.**
  `printf '{"session_id":"%s","prompt":"Ready?\\n"}' "$SID" | bash ./claude-mux
  --on-prompt` → treated as handshake (no tip, no stamp). Confirms `strip()`.

- **T1.5 Non-handshake that merely contains the word.**
  `hook "Are you ready? let's go"` → NOT a handshake (≠ exact `Ready?`); behaves as a
  real prompt (tip eligible). Confirms exact-match, not substring.

## Upgrade-notice interaction (complete version only)

- **T2.1 Upgrade notice not consumed on a handshake.** With the reorder, a handshake
  turn must not run `detect_claude_upgrade`'s ack. PASSED live 2026-06-17 on the
  `claude-mux` session: backed up `@claude-mux-claude-id` + the `.update-check` cache,
  set a bogus id and seeded a higher cached version, then drove `--on-prompt` directly:
  - `Ready?` turn → empty output, id stayed bogus (detect_claude_upgrade skipped, not
    acked), no tip-state stamp.
  - real prompt → emitted ALL THREE notices (Claude Code upgrade + tip + claude-mux
    update-available) and re-acked the id to the real binary.
  State restored exactly (id + cache) via an `EXIT` trap. Confirms both the
  Claude-Code-binary-upgrade and the claude-mux-GitHub-update notices reach the first
  real prompt and neither is burned by the `Ready?` handshake.

## Regression

- **T3.1 Update-available notice still fires on a real prompt.** Seed the cache with a
  higher version (or use a fresh `$SID`), `hook "hi"` → emits the
  `[claude-mux update available …]` line. Confirms the update path is intact off the
  handshake.
- **T3.2 Both features off.** Set `TIP_OF_DAY=false UPDATE_CHECK=false` in the
  environment/config for the run: `hook "Ready?"` and `hook "hi"` both emit no tip/update
  (only a possible upgrade notice). Complete version: confirm the handshake still
  no-ops; minimal version: confirm hot path unchanged.
- **T3.3 Live end-to-end.** After deploy + "restart all sessions": the `Ready?` turn
  shows only the two-line ready reply (no tip), and the **next** real message in a
  session surfaces the tip. Spot-check one session (e.g. send a normal prompt and look
  for the injected tip relay). Confirm `tip-state/<sid>.json` was NOT stamped by the
  restart's `Ready?` (mtime predates the restart, or tip_date != today until the real
  prompt).

## Cleanup

`cleanup` (remove `$STATE`) after each live probe so stray throwaway state files don't
accumulate in `~/.claude-mux/tip-state/`.

## Acceptance

- T1.1-T1.2: handshake no-ops; first real prompt gets the tip. (Primary fix.)
- T1.3-T1.5: daily gate intact; exact-match detection; whitespace tolerated.
- T3.1-T3.3: update notice unregressed; both-off path correct; live restart no longer
  burns the day's tip.
- T0.1-T0.2 + (complete) T2.1: syntax clean, robust to empty stdin, upgrade notice not
  consumed on the handshake.
