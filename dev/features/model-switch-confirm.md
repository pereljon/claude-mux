---
kind: feature
lifecycle: ready
feature: model-switch-confirm
status: TOP-PRIORITY / ACTIVE BUILD TARGET (promoted 2026-07-17). DESIGNED 2026-06-21 (architect-reviewed); build plan + test plan added 2026-07-17 (this pass), re-run through architect. Pre-build. Hit live THREE times now — TWICE on `home` (2026-06-21) and again on `robotech-game-demo` (2026-07-17, manually cleared with a single Enter, confirming option 1 "Yes" pre-highlighted). Logged in docs/ISSUES.md.
target_version: 2.0.14 (patch) — a real bug: in-session model switch stalls on a blocking dialog
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

**Third live confirmation (2026-07-17, `robotech-game-demo`):** "switch to claude opus" ran
`/model claude-opus-4-8`; Claude even printed "Switched this session to claude-opus-4-8", then the
`Switch model?` dialog rendered and the session sat idle. A single `Enter` (option 1 already `❯`
pre-highlighted) confirmed it and the session resumed on Opus. This re-confirms every assumption in
this design: the dialog is exactly two options, "Yes" is option 1 and pre-highlighted, and a lone
`Enter` clears it. Captured tail:
```
⏺ Switched this session to claude-opus-4-8.
   Switch model?
   Your next response will be slower and use more tokens
   This conversation is cached for the current model. Switching to Opus 4.8
   means the full history gets re-read on your next message.
   ❯ 1. Yes, switch to Opus 4.8
     2. No, go back
```
Note the extra line "Your next response will be slower and use more tokens" not seen on
2026-06-21 — wording drifts, which is exactly why the matcher keys on the STABLE strings
`Switch model?` + `Yes, switch to` (see safety rules), not the full block.

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

## Build steps (coding plan, ordered — grounded in current src @ VERSION 2.0.13)
Verified anchor points (read 2026-07-17):
- `send` handler ends at `src/90-dispatch.sh:90` — `"$TMUX_BIN" send-keys -t "$SEND_SESSION" -l "$SEND_COMMAND" && ... Enter` then `exit 0` at :91. **Hook point:** between the send-keys line (:90) and `exit 0` (:91).
- Dispatch cases live in the `case "$COMMAND" in` block at `src/90-dispatch.sh:42+`; `await-ready)` is at :54 — the new `confirm-model-switch)` case slots in right beside it.
- `--await-ready` flag parse in `src/10-flags.sh` sets `COMMAND=await-ready` + `AWAIT_SESSION` — copy that exact shape.
- Confirmer body reuses the `capture-pane -p` + bounded-loop idiom from `poll_until_ready` (`src/50-restore-state.sh`) and the keypress precedent from the `bypassPermissions` startup poller.

> **Architect review 2026-07-17: APPROVE-WITH-CHANGES.** Design + safety model sound; four required
> corrections (2 CRITICAL) to the build steps, all folded in below. Verified-accurate anchors:
> send-keys `90-dispatch.sh:90` / `exit 0` `:91`; dispatch block `:42+`, `await-ready)` `:54`;
> `--await-ready` parse `10-flags.sh:494-497`; `poll_until_ready` `50-restore-state.sh:808`, its
> keypress precedent `:821-836`; `setmode` keypress example dispatch `:335-362`; `CLAUDE_MUX_BIN`
> defined `20-config.sh:135-137`; subshell-detach precedent `75-tip-notices.sh:210`; Makefile
> explicit `MODULES` list `:15-19`.

**Order of edits (do 1→2 before 3 so the dispatch target exists before the caller references it):**
1. **Flag parse** (`src/10-flags.sh`, mirror `--await-ready` at `:494-497`): add `--confirm-model-switch)` → set `COMMAND="confirm-model-switch"` and `CONFIRM_MODEL_SESSION="$2"` (shift 2). **Copy the arg-guard line** (`:495`: `[[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR…" >&2; exit 1; }`).
   - **[Change A — CRITICAL]** Exempt lists: add `confirm-model-switch` to the **config-required-skip list at `src/90-dispatch.sh:10`** (where `await-ready` already is — it runs detached, no config load). Do **NOT** add it to the deps-exempt list at `src/35-validate-deps.sh:93` — `await-ready` is NOT there and the confirmer needs tmux (`capture-pane`/`send-keys`), so it must keep the tmux dep check. (The earlier draft's "add to deps-exempt alongside await-ready" was wrong on both counts.)
2. **Confirmer function** — **[Change D — CRITICAL]** append `confirm_model_switch <session>` to **`src/55-session-launch.sh`** (adjacent to the wrapper/`--await-ready` machinery it mirrors, `:195-211`). Do NOT create a new `src/56-*.sh` fragment: `src/` is NOT globbed; a stray fragment compiles to NOTHING (Makefile `MODULES` is explicit, `:15-19`) and `make check` stays green while the function is silently absent → dispatch-to-undefined at runtime. (If a new fragment is ever truly wanted, adding it to Makefile `MODULES` becomes a mandatory ordered step 0.)
   - Bounded loop: ~15 ticks × ~0.4s ≈ 6s window.
   - Each tick: `TAIL=$("$TMUX_BIN" capture-pane -t "$session" -p | tail -12)` (**tail -12**, not -8 — the dialog spans ~7 lines and narrow-pane wrapping inflates it; aligns with the test plan's Phase 0).
   - Match guard (BOTH required): `[[ "$TAIL" == *"Switch model?"* && "$TAIL" == *"Yes, switch to"* ]]`.
   - Hardening (**per-line, not two whole-tail tests**): require a SINGLE line containing BOTH `❯` and `Yes, switch to`, e.g. `printf '%s\n' "$TAIL" | grep -q '❯.*Yes, switch to'` — so `❯` on the "No" line with `Yes, switch to` elsewhere does NOT pass.
   - On match: `"$TMUX_BIN" send-keys -t "$session" Enter`; then poll up to ~2s to verify `Switch model?` is GONE from the tail (confirms it took); exit 0.
   - On window-expiry with no match ever seen: exit 0 silently, send NOTHING (never a blind Enter).
3. **Dispatch case** (`src/90-dispatch.sh` ~:54, beside `await-ready)`): `confirm-model-switch) confirm_model_switch "$CONFIRM_MODEL_SESSION"; exit 0 ;;`.
4. **Hook the send handler** (`src/90-dispatch.sh` between :90 and :91): after send-keys succeeds, background the confirmer only for `/model ` payloads. **[Change B — HIGH]** use the `( … & )` subshell-detach idiom (precedent `75-tip-notices.sh:210` for `--update-check-bg`), NOT a bare `&` — a bare `&` stays in the caller's process group and can catch SIGHUP when Claude's Bash tool call is reaped at turn-end (the real self-switch reentrancy risk; `--await-ready` avoids it only because its parent is the long-lived launch wrapper, not a tool call). **[Change C — HIGH]** invoke via `"$CLAUDE_MUX_BIN"` (defined `20-config.sh:135-137`), NOT `$0` (unreliable under relative paths):
   ```
   if [[ "$SEND_COMMAND" == /model\ * ]]; then
       ( "$CLAUDE_MUX_BIN" --confirm-model-switch "$SEND_SESSION" >/dev/null 2>&1 & )
   fi
   ```
5. **Docs/version** (see Change Checklist below): `make build` + `make check`, `make codemap` (new `confirm_model_switch` purpose row), SKELETON send→confirm flow, CHANGELOG, ISSUES resolved, VERSION → 2.0.14. Injection parenthetical at the model-switch rule so it no longer warns the user the switch may hang.

**Test plan lives in** `dev/features/model-switch-confirm-tests.md` (pre-build dialog survey + happy path + edge cases + self-switch/cross-switch + verification steps).

## Files to update (Change Checklist)
- `src/90-dispatch.sh` (the `send` handler: detect `/model ` payload, background the confirmer via
  `( "$CLAUDE_MUX_BIN" … & )`; add the `confirm-model-switch` dispatch case; add `confirm-model-switch`
  to the config-required-skip list at `:10`).
- `src/10-flags.sh` (`--confirm-model-switch` flag parse + arg-guard, copying `--await-ready` at `:494-497`).
- `src/55-session-launch.sh` (the confirmer body `confirm_model_switch` — append here, NOT a new fragment,
  or the Makefile `MODULES` list must be edited too; reuse `poll_until_ready` capture idiom from
  `src/50-restore-state.sh:808`; keypress precedent = bypass poller `:821-836` / `setmode` `:335-362`).
- `src/35-validate-deps.sh` — do NOT add `confirm-model-switch` here; it needs tmux, keep the dep check.
- `src/30-helpers.sh` ~L742 — update only the parenthetical to note claude-mux now auto-confirms
  the cached-conversation "Switch model?" dialog (so the session needn't warn the user it may hang).
- `dev/CODEMAP.md` (new function purpose row + `make codemap`), `dev/SKELETON.md` (the send→confirm
  flow), CHANGELOG, `docs/ISSUES.md` (mark resolved), VERSION.
- Optional tie-in to `context-cost-awareness`: when the thread is large, nudge "clear/compact first
  to avoid the re-read" (see `model-switching-cost-research.md` order-of-operations).

## Out of scope
- Generic "confirm any dialog" handling (explicitly rejected — recognize specific dialogs only).
- The `/model` picker / model-ID resolution (already shipped in `model-resolution-notice-cleanup`).

## Future tie-in (NOT this build)
This confirmer's recognize-then-confirm machinery (detached poller + tail-match + keystroke) is
reusable for a *separate* logged bug: Claude Code's **"Background work is running" exit-guard** that
stalls the caller-last in-place restart (`docs/ISSUES.md`, observed 2026-07-21 on `home`). That's a
distinct dialog (`Background work is running` + the `claude-mux --restart` line → "Move to background
and exit"), out of scope for 2.0.14, but a natural follow-on once this pattern is proven. Also note:
this build's Phase 3.1 self-switch test (`-s SELF '/model …'` as Claude's own Bash tool call) will
now *trigger* that exit-guard, which is exactly why Change B's `( … & )` subshell-detach must be
verified — a bare `&` confirmer would itself be counted as blocking background work at `/exit` time.
