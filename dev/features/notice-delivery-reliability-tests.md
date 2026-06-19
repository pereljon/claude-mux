---
feature: notice-delivery-reliability
---

# Test Plan: reliable notice delivery (tip / update / upgrade)

Tests for `notice-delivery-reliability.md`. The decisive properties: **actionable
notices can no longer be silently lost** (they persist while their condition holds and
retry on every prompt), and the **strengthened relay rule** rides the `<assistant-must-display>`
mechanism. Delivery itself stays relay-dependent (only an upstream Claude Code feature
makes it deterministic), so tests assert *injection/gating behavior*, not "the human saw
it" (which the hook can't observe).

## Pre-build verification

- **V0.1** Confirm the current coupling: in `on_prompt`, the tip/update stamps are set
  *only* inside the emit branch and persisted — i.e. stamp ⟺ emit. (This is the bug.)
- **V0.2** Confirm `detect_claude_upgrade` acks (`set-option @claude-mux-claude-id`) on
  emit, regardless of relay.
- **V0.3** Confirm `build_system_prompt` (`src/30-helpers.sh:1480`) currently has the
  `<assistant-must-display>` rule for *command output* only (not hook context).

## Strengthening (Part A)

- **T1.1 Standing rule present.** `--print-system-prompt <session>` output contains the
  new "always surface `[claude-mux …]` notices verbatim at the start of your reply" rule.
- **T1.2 Notices wrapped.** A forced tip/update/upgrade emission wraps the notice in
  `<assistant-must-display>` tags (assert the tags are in the hook stdout).
- **T1.3 Rule covers hook context.** The broadened standing rule text references
  hook-injected notices, not only "command output."
- **T1.4 Live RC surfacing (manual, architect).** In a real `--remote-control` session,
  force a pending notice and confirm a wrapped `<assistant-must-display>` injected notice is
  actually surfaced **verbatim to the RC user** on a real turn. This validates the
  *unproven* claim that the tag mechanism transfers from tool-output to injected context —
  T1.2 only proves the tags are emitted; this proves they're honored. Record the result
  honestly: if relay is still flaky, the doc's "best-effort, Part D is the only guarantee"
  framing stands.

## persist-while-relevant — update notice (Part B)

- **T2.1 Re-injects every prompt while newer version cached.** With `.update-check`
  showing `latest > VERSION`, the update notice is emitted on prompt #1, #2, #3 … (not
  stamped-and-silenced after the first).
- **T2.2 No 7-day stamp burn.** A second prompt still emits the notice (the old behavior
  would have suppressed it for 7 days). Assert no `update_notify`/`notify_version`
  gate suppresses it.
- **T2.3 Self-clears on update.** When `VERSION` is bumped to ≥ `latest`, the notice stops
  (condition `version_gt latest VERSION` is false).
- **T2.4 De-dup instruction present.** The emitted notice text instructs Claude to mention
  it once per session and not repeat — so persistence in *context* doesn't mean spam in
  *output* (behavioral; verified by reading the injected text).

## persist-while-relevant — upgrade notice (Part B)

- **T2.5 Re-injects while binary id mismatched.** With `@claude-mux-claude-id` ≠ live
  `claude_binary_id`, `detect_claude_upgrade` emits on every prompt (not acked-once).
- **T2.6 Self-clears on restart.** After `--restart` re-captures the id, the notice stops.
- **T2.7 No ack-on-emit.** `detect_claude_upgrade` no longer overwrites the option on
  emit (only a restart updates it).

## Tip (Part C)

- **T3.1 Still once/day baseline.** Tip gated by `tip_date` per session_id as before (or
  the chosen first-few-turns variant); strengthened wording/tags applied.
- **T3.2 Strengthening applies to the tip too** (wrapped + standing rule).

## Handshake interaction (regression)

- **T4.1 No notice on `Ready?`.** All notices still no-op on the synthetic handshake
  (`_is_handshake == 1` exits first); persist-while-relevant must not fire on a handshake
  turn and must not consume anything.

## Regression / build

- **T5.1 Build clean.** `make build` + `make check` pass; `bash -n` clean.
- **T5.2 Existing pointers coexist.** Tip + update + upgrade still flow through `on_prompt`
  together; the both-off `TIP_OF_DAY`/`UPDATE_CHECK` guards still flush the always-on
  upgrade notice.
- **T5.3 RC reality documented.** No tmux-native channel is introduced (it would be
  invisible in RC); the doc/CHANGELOG state the relay-dependence + the upstream ask.

## Acceptance

- T2.x mandatory: the two actionable notices persist-while-relevant and can't be burned by
  a single missed relay — the core bug fix.
- T1.x: strengthening rides `<assistant-must-display>` + a standing rule.
- T3.x/T4.x/T5.x: tip best-effort, handshake unaffected, build clean, no tmux channel.

## Cleanup
Remove throwaway sessions and any scratch `.update-check` / tip-state files used for tests.
