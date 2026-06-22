---
kind: feature
lifecycle: ready
feature: model-switch-confirm
status: DESIGNED 2026-06-21 (architect-reviewed). Pre-build. Hit live TWICE on the home session (2026-06-21). Logged in docs/ISSUES.md.
target_version: 2.1.x or 2.0.x patch (a real bug: in-session model switch stalls on a blocking dialog)
severity: MEDIUM — a cached-conversation `/model` switch silently stalls the session on a confirmation dialog until the user manually presses a key; it also blocks any later input (a queued "clear" sat behind it).
related: model-switching-cost-research, model-resolution-notice-cleanup, context-cost-awareness
---

# Feature: auto-confirm Claude Code's "Switch model?" dialog after an in-session `/model`

## Problem (observed live 2026-06-21, twice, on `home`)
Model switching goes through `claude-mux -s SESSION '/model <id>'`, which types the command into
the pane and returns — **fire-and-forget**. On a **cached conversation**, `/model <id>` pops a
Claude Code confirmation dialog that BLOCKS all input until a keypress:
```
Switch model?
This conversation is cached for the current model. Switching to Sonnet 4.6
means the full history gets re-read on your next message.
❯ 1. Yes, switch to Sonnet 4.6
  2. No, go back
```
Nothing confirms it, so the session sits stuck until a human presses Enter (option 1 "Yes" is
pre-highlighted). Worse, it blocks everything queued behind it — on 2026-06-21 a "clear this
session" sent afterward sat unprocessed behind the dialog and looked like the clear had hung.

The dialog is CONDITIONAL: it only appears when the conversation is cached for the current model
(a fresh/cleared conversation switches with no dialog — see `model-switching-cost-research.md`).

## Why this is solvable (unlike the rejected `/model` picker fallback)
The picker fallback failed because the *result* and the *list to choose from* were only
observable next-turn. This is categorically different: the action is a single deterministic
`Enter` on a known two-option dialog, and claude-mux ALREADY drives a confirmation dialog with a
detached external poller (the `bypassPermissions` startup poller: detect the prompt, send keys),
so the in-turn-observability problem is sidestepped entirely.

## Design (architect-recommended)
**Where it lives:** special-case a `/model` payload inside the existing `send` dispatch
(`src/90-dispatch.sh`, the `send` command) — NOT a new user-facing flag. After `send` types the
payload, if it starts with `/model `, background a confirmer. The injection rule at
`src/30-helpers.sh` ~L742 keeps emitting `-s '/model <id>'` unchanged; the confirmer auto-attaches.

**The confirmer** — a new INTERNAL subcommand (e.g. `--confirm-model-switch SESSION`), dispatched
like `--await-ready` (`src/90-dispatch.sh` dispatch + the config-exempt list; flag-parse pattern
copied from `--await-ready` in `src/10-flags.sh`), and backgrounded (`&`, detached so it survives
the sending Claude's turn ending — exactly how the launch wrapper backgrounds `--await-ready`):
```
[[ "$SEND_COMMAND" == /model\ * ]] && "$CLAUDE_MUX_BIN" --confirm-model-switch "$SEND_SESSION" >/dev/null 2>&1 &
```

**Confirmer flow** (reuse the `poll_until_ready` capture idiom, `src/50-restore-state.sh`):
- Bounded poll, ~6s window, ~0.4s interval.
- Each tick: `capture-pane -p` of the target pane TAIL (~8 lines, so transcript history can't
  match).
- If the dialog is present → confirm it → verify it cleared → exit.
- If the window expires with NO dialog ever seen → exit silently, send NOTHING.

## The CRITICAL safety rules (from the "are there other dialogs?" review)
1. **Recognize-then-confirm — never see-a-dialog-press-default.** Match the SPECIFIC dialog by its
   distinctive text: require BOTH `Switch model?` AND `Yes, switch to` present in the tail. Only
   then act. Any dialog that doesn't match → do nothing (leave it for the user = today's behavior).
   Blindly pressing the default key on an unrecognized dialog is the footgun to avoid (some other
   dialog's default could be "No/Cancel" or worse).
2. **Confirm the explicit affirmative, not a position.** Press `Enter` only because option 1 is
   "Yes, switch to …" and is pre-highlighted (`❯`). HARDENING worth adding: verify the `❯` is on
   the "Yes" line before pressing, so a future reorder can't make Enter select the wrong option.
   (For this Yes/No dialog even a wrong default is non-destructive — worst case no switch — but the
   rule generalizes safely.)
3. **Never send a blind `Enter`.** The conditional-dialog hazard: if no dialog appears (uncached
   switch), a stray Enter would submit an empty prompt. Only key when both match-strings are present.

## Pre-build task: empirical dialog survey
We have only observed ONE dialog ("Switch model?" cache warning). The full set `/model` can raise
is undocumented. Before finalizing the matcher, survey in a throwaway/test session: switch to the
SAME model, to an UNAVAILABLE model, on an UNCACHED (just-cleared) conversation, etc., and capture
each dialog (or absence) with `capture-pane`. List exactly which dialogs we recognize. The
"match-known-only, else do nothing" rule keeps us safe even if the survey misses one.

## Self-switch reentrancy (verified reasoning)
When switching the CURRENT session, the sending Claude ends its turn with the `/model` Enter
already flushed; Claude Code consumes it and renders the dialog; the pane then idles awaiting the
dialog keypress. The detached confirmer (separate process, not a child of the Claude turn) survives
and its `Enter` lands on the dialog — no race, because the Claude has stopped emitting. Cross-session
("switch session NAME") is simpler (the confirmer watches a pane that isn't the caller's).

## Failure modes / graceful degradation
- Same-model / uncached switch → no dialog → confirmer no-ops. Correct.
- Future wording change → strings don't match → times out silently → falls back to today's
  manual-Enter behavior. Never worse.
- Dialog renders after the 6s window → user presses Enter manually = today's behavior.

## Files to update (Change Checklist)
- `src/90-dispatch.sh` (the `send` handler: detect `/model ` payload, background the confirmer;
  add the `confirm-model-switch` dispatch case + config-exempt entry).
- `src/10-flags.sh` (`--confirm-model-switch` flag parse, copying the `--await-ready` pattern).
- `src/55-session-launch.sh` or a new small fragment (the confirmer body; reuse `poll_until_ready`
  capture idiom from `src/50-restore-state.sh`; keypress precedent = the bypass poller).
- `src/30-helpers.sh` ~L742 — update only the parenthetical to note claude-mux now auto-confirms
  the cached-conversation "Switch model?" dialog (so the session needn't warn the user it may hang).
- `dev/CODEMAP.md` (new function purpose row + `make codemap`), `dev/SKELETON.md` (the send→confirm
  flow), CHANGELOG, `docs/ISSUES.md` (mark resolved), VERSION.
- Optional tie-in to `context-cost-awareness`: when the thread is large, nudge "clear/compact first
  to avoid the re-read" (see `model-switching-cost-research.md` order-of-operations).

## Out of scope
- Generic "confirm any dialog" handling (explicitly rejected — recognize specific dialogs only).
- The `/model` picker / model-ID resolution (already shipped in `model-resolution-notice-cleanup`).
