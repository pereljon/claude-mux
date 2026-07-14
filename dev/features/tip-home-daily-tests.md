---
feature: tip-home-daily
---

# Test Plan: daily tip is home-only, once per day globally

Tests for `tip-home-daily.md`. Decisive metric: the tip fires **at most once per day**,
**only in the home session**, regardless of how many times the conversation rotates
(compact/clear/restart). The actionable notices (update-available, Claude-upgrade) keep
firing in every session.

The tip path now depends on the tmux session name (`#S`), which the hook reads from the
inherited `$TMUX`. So unlike `tip-ready-handshake-tests.md` (pure stdin probe), the home
gate must be exercised **from inside a tmux session** (or with `$TMUX` set). Two layers:
fast stdin probes for the parts that don't need `#S`, and an in-session check for the
home gate.

Global stamp under test: `~/.claude-mux/tip-state/tip.json`. Back it up and restore
around tests so a real day's tip is not disturbed:

```bash
TIP=~/.claude-mux/tip-state/tip.json
cp "$TIP" /tmp/tip.json.bak 2>/dev/null || true
restore(){ cp /tmp/tip.json.bak "$TIP" 2>/dev/null || rm -f "$TIP"; }
hook(){ echo "{\"prompt\":\"$1\"}" | bash ./claude-mux --on-prompt; }   # no session_id needed now
```

## Pre-build verification (confirm before coding) — done 2026-06-22

- **V0.1 Root cause:** `~/.claude-mux/tip-state/` held 7 `<uuid>.json` files stamped
  2026-06-22, 4 within an 18-min window — proves the gate key (session_id) rotates and
  re-triggers the tip. CONFIRMED (see feature doc evidence block).
- **V0.2 Home name is literal `home`:** `src/35-validate-deps.sh:41`
  (`LAUNCH_SESSION_NAME="home"`) and the `== "home"` special-cases throughout. So the
  gate is `#S == "home"`.
- **V0.3 Update notice has no session_id dependency:** the `UPDATE_CHECK` block gates on
  the cached `_latest` vs `VERSION`, not on per-session state — so dropping `session_id`
  from the tip path does not affect it.

## Static / generation checks (post-build)

- **T0.1** `make build` clean; `make check` clean (artifact matches `src/`).
- **T0.2** `bash -n claude-mux` passes.
- **T0.3** `claude-mux --on-prompt < /dev/null` (empty stdin) exits 0, no crash
  (`is_handshake=0`, `_sess` empty → not home → no tip).
- **T0.4** `grep -c '<sid>\|session_id' src/75-tip-notices.sh` in the tip path — confirm
  `session_id` is gone from the tip gate (it may still appear in comments; verify no
  per-session `<sid>.json` read/write remains).

## Home gate (must run inside the `home` tmux session, or with `$TMUX` pointing at it)

Run these from the home session pane (so `#S == home`). Reset `tip.json` first.

- **T1.1 Home shows the tip once.** `restore`-then-`rm -f "$TIP"`; `hook "hello"` →
  emits `claude-mux tip:` line; `cat "$TIP"` → `{"tip_date":"<today>"}`.
- **T1.2 Home does NOT re-show same day.** Immediately `hook "again"` → **no** tip line
  (global stamp already today). **Primary fix.**
- **T1.3 Conversation rotation does not re-trigger.** With `tip.json` stamped today,
  simulate a rotated conversation by passing a different/absent `session_id`:
  `echo '{"session_id":"brand-new-uuid","prompt":"hi"}' | bash ./claude-mux --on-prompt`
  → no tip. (Pre-fix this would have emitted, because the key changed.)
- **T1.4 New day re-emits.** Set `tip.json` to yesterday
  (`echo '{"tip_date":"2000-01-01"}' > "$TIP"`); `hook "hi"` → emits the tip, restamps
  today. Confirms the date comparison, not a one-time latch.

## Non-home suppression

Run from a NON-home session (any project session pane), or set `$TMUX`/`#S` to a
non-home name.

- **T2.1 Project session never shows the tip.** With `tip.json` absent (eligible):
  `hook "hello"` in a project session → **no** tip line; `tip.json` is **not** created.
  Confirms the home gate.
- **T2.2 Project session still gets notices.** Seed `~/.claude-mux/.update-check` with a
  higher version than `VERSION` (back it up first); `hook "hi"` in a project session →
  emits the `update available` line. Confirms only the *tip* is home-gated, not the
  notices. Restore the cache after.

## Handshake / config interaction

- **T3.1 Handshake no-ops (home).** From home: `hook "Ready?"` → no tip, `tip.json`
  unchanged (handshake check precedes the home gate). Then `hook "real"` → tip fires.
- **T3.2 `TIP_OF_DAY=false`.** `TIP_OF_DAY=false hook "hi"` from home → no tip;
  `tip.json` untouched. With `UPDATE_CHECK=true` + a seeded higher version, the update
  line still appears.

## Orphan sweep (only if the sweep option is built)

- **T4.1** Create a decoy `~/.claude-mux/tip-state/00000000-0000-0000-0000-000000000000.json`;
  trigger a home tip (T1.1 conditions) → after the run, the decoy is gone and `tip.json`
  remains. Confirms the one-time sweep removes UUID-shaped siblings, not `tip.json`.
- **T4.2** If sweep is NOT built: just confirm old `<uuid>.json` files are simply never
  read again (no behavior depends on them).

## Live end-to-end

- **T5.1** Deploy (`cp claude-mux ~/bin/`), restart the home session. The restart's
  `Ready?` turn shows only the two-line ready reply (no tip). The **first real** home
  prompt that day surfaces the tip; subsequent home prompts that day do not. Compact home
  once, then prompt again → still no tip (global stamp held across the rotation). This is
  the scenario that reproduced the bug.
- **T5.2** In a project session the same day, send a normal prompt → no tip (home-only).

## Cleanup

`restore` (`tip.json`) and restore any seeded `.update-check` after live probes.

## Acceptance

- T1.1–T1.4: home shows the tip once/day globally, survives conversation rotation,
  re-emits across a date boundary. (Primary fix.)
- T2.1–T2.2: project sessions never show the tip but still get notices.
- T3.1–T3.2: handshake + `TIP_OF_DAY=false` unregressed.
- T0.*: build/check clean, robust to empty stdin, `session_id` removed from the tip gate.
- T5.*: live restart + compact on home no longer re-shows the tip.
