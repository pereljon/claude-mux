---
kind: feature
lifecycle: shipped
feature: model-switch-confirm
status: SHIPPED in v2.0.14 (committed 618128f 2026-07-22, deployed to ~/bin). Code-reviewed (0 CRITICAL/HIGH; the one MEDIUM double-key race closed with a per-session mkdir lock, LOW default var added). **Phase 3.1 ship-gate PASSED 2026-07-22:** (A) confirmer matches+confirms+verifies a real dialog through the exact `( … & )` detach idiom; (B/Fable HIGH-2) the `( … & )` orphan survives a real Claude turn-end reaping on macOS; (b) `/exit` inside the confirmer's live window exits cleanly with NO "Background work is running" guard → detach is NOT counted as background work. `( … & )` confirmed sufficient; no setsid/perl escalation. **LIVE end-to-end verified 2026-07-22** on a real warm-cached session (`ai-training`, opus-4-7→sonnet): the genuine dialog rendered and the confirmer cleared it in ~1s unattended (incl. the restore switch via the real `-s` path). Trigger needs BOTH cache-eligible size AND a warm ~5-min cache; idle/cold sessions switch silently (confirmer no-ops correctly). Phase 0 survey COMPLETE 2026-07-21 (Claude Code v2.1.205): only ONE dialog exists, matcher validated live. Hit live THREE times pre-fix (TWICE on `home` 2026-06-21, once on `robotech-game-demo` 2026-07-17). Remaining: release gate (push + tag + gh release). Logged in docs/ISSUES.md.
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
- Bounded poll, **~30s window** (~75 ticks × ~0.4s), ~0.4s interval. **[Fable HIGH-1]** NOT ~6s — on
  a self-switch the `/model` slash command does not execute until the caller's turn *ends* (tool
  result returns + Claude writes its closing text), 5-15s+ later, so a 6s window measured from
  send-time routinely expires before the dialog renders (the 2026-07-17 capture shows `⏺ Switched…`
  closing text THEN the dialog). 30s covers self-switch + slow-rendering large cached threads. Happy
  path still exits on match, so the wider window costs nothing when a dialog appears.
- **Early-exit on a dead session** **[Fable LOW-4]**: bail if `has-session` fails, or after N
  consecutive capture failures — so a missing/again-idle pane doesn't spin the full 30s.
- Each tick: `capture-pane -p` of the target pane TAIL (bottom-anchored, see matcher rules — the
  dialog is bottom-anchored; transcript quotes scroll up and out of the last ~6 lines).
- If the dialog is present → confirm it → verify it cleared → exit.
- If the window expires with NO dialog ever seen → exit silently, send NOTHING.

## The CRITICAL safety rules (from the "are there other dialogs?" review)
1. **Recognize-then-confirm — never see-a-dialog-press-default.** Match the SPECIFIC dialog by its
   distinctive text: require BOTH `Switch model?` AND `Yes, switch to` present in the tail. Only
   then act. Any dialog that doesn't match → do nothing (leave it for the user = today's behavior).
   Blindly pressing the default key on an unrecognized dialog is the footgun to avoid (some other
   dialog's default could be "No/Cancel" or worse).
   - **[Fable MEDIUM-1] Bottom-anchor the match — transcript text can satisfy both guards.** The
     dialog is a live TUI element pinned to the bottom of the pane; quoted dialog TEXT (e.g. Claude's
     own reply, or this repo's own docs — ISSUES.md and this design doc quote the block verbatim, `❯`
     included) scrolls UP as history. A whole-tail match on a quote would key `Enter` at a normal
     prompt (harmless no-op — empty input isn't submitted), OR, worse, press the default of some
     *other* live dialog sitting below the quote. **Fix:** require the `❯ … Yes, switch to` line
     within the LAST ~6 lines of the tail (bottom-anchored), and additionally require the `No, go
     back` line — the live dialog always has all three at the bottom; a scrolled-up quote does not.
     The claude-mux/home sessions are the worst case since they literally work on this feature.
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

### Phase 0 survey RESULTS (completed 2026-07-21 — Claude Code v2.1.205, throwaway session)
Ran all five scenarios in a disposable session (Opus 4.8 default). Findings:

| # | Scenario | Observed result | Matcher fires? |
|---|----------|-----------------|----------------|
| 0.1 | Cached cross-model (Opus→Sonnet) | `Switch model?` dialog, 7 lines; incl. `Your next response will be slower and use more tokens`; `❯ 1. Yes, switch to Sonnet 4.6` / `  2. No, go back` | **YES (intended)** |
| 0.2 | Uncached (`/clear` then switch) | **NO dialog** — one-line `⎿ Set model to Sonnet 4.6 and saved as your default for new sessions` | NO (correct — conditional-dialog hazard confirmed) |
| 0.3 | Same-model (Opus→Opus) | **NO dialog** — `⎿ Set model to Opus 4.8 and saved as your default for new sessions` | NO (correct) |
| 0.4 | Bad/unavailable ID (`claude-nonexistent-9`) | **NO dialog** — `⎿ Model 'claude-nonexistent-9' not found` | NO (correct) |
| 0.5 | Reverse cached (Sonnet→Opus) | Identical `Switch model?` dialog; live per-line matcher passed (see below) | **YES (intended)** |

**The `/model` command raises exactly ONE dialog: the cached "Switch model?" confirmation.** It
appears ONLY on a cached *cross-model* switch (0.1, 0.5). Every other outcome (same-model, bad-id,
uncached) resolves silently with a one-line `⎿` result and NO dialog — so the "recognize-known-only,
else no-op" rule leaves all of them untouched, and a blind `Enter` on the silent cases (0.2/0.3/0.4)
would have wrongly submitted an empty prompt. Conditional-dialog hazard empirically confirmed.

**Matcher validated LIVE against real output** (not inference): on 0.5 the exact design guard ran
against the captured tail —
`tail -12 | grep -q 'Switch model?'` AND `tail -12 | grep -qE '❯.*Yes, switch to'` → **both passed**.
The dialog is 7 lines; `tail -12` captures it with margin. Confirmed details: exactly 2 options,
option 1 `Yes, switch to <Model>` pre-highlighted (`❯`), `Escape` cancels cleanly (`Kept model as
<current>`). The `slower and use more tokens` line IS present in v2.1.205 (matches the 2026-07-17
live capture, absent 2026-06-21) — which is exactly why the matcher keys on the STABLE substrings
`Switch model?` + `Yes, switch to`, not the full block.

**Conclusion: no design change needed.** The matcher (`tail -12`, both-strings guard, per-line
`❯.*Yes, switch to` hardening) is validated as specified. Build can proceed.

## Self-switch reentrancy + timing (corrected by Fable review 2026-07-21)
When switching the CURRENT session, `-s SELF '/model …'` types the command into the pane **while the
caller's turn is still running** (it IS Claude's Bash tool call). Claude Code queues the typed input;
the `/model` slash command executes only **after the turn ends** — tool result returns, then Claude
generates its closing text ("Model switch sent…"), THEN the dialog renders. That is 5-15s+ after the
send (more if Claude makes another tool call first). The 2026-07-17 capture proves the ordering
(`⏺ Switched this session to claude-opus-4-8.` closing text, THEN `Switch model?`). Implications:
- The confirmer must poll for **~30s from send-time**, not ~6s, or it expires before the dialog
  exists (Fable HIGH-1; the fix is the widened window above).
- No double-submit race: the caller has stopped emitting by the time the dialog renders, so the
  confirmer's `Enter` is the only key in flight.
- **Process survival** is a separate axis from timing — see the detach analysis in Build step 4
  (Change B): `( … & )` clears the job table + fds (what survives turn-end reaping) but does NOT
  change process-group or session; whether it dodges Claude Code's "Background work is running"
  exit-guard is unknowable from design and is gated by Phase 3.1.
Cross-session ("switch session NAME") is simpler (the confirmer watches a pane that isn't the
caller's), but a BUSY target's turn is unbounded, so even 30s can't guarantee coverage there —
accepted degradation (falls back to manual Enter).

## Failure modes / graceful degradation
- Same-model / uncached switch → no dialog → confirmer no-ops. Correct.
- Future wording change → strings don't match → times out silently → falls back to today's
  manual-Enter behavior. Never worse.
- Dialog renders after the ~30s window (very slow render, or a busy cross-session target) → user
  presses Enter manually = today's behavior.

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
>
> **Fable (claude-fable-5) review 2026-07-21 (post Phase 0): APPROVE-WITH-CHANGES.** All folded in:
> HIGH-1 window ~6s→~30s (self-switch dialog renders only after the caller's turn ends); HIGH-2
> reframe the `( … & )` detach claim (clears job-table+fds, does NOT change pgid/session — no
> `setsid` on macOS — so Phase 3.1 is the ship-gate with a pre-decided escalation); MEDIUM-1
> bottom-anchor the matcher + require `No, go back` (transcript quotes of the dialog can otherwise
> satisfy both guards, worst-case in this very repo); MEDIUM-2 never re-key on verify-timeout;
> LOW-4 dead-session early-exit; LOW-3 test-plan deps-exempt reword. Verified-correct (no change):
> `capture-pane -p` emits plain text (no ANSI between `❯` and `Yes`), `❯` is cell-based (precedent
> `50-restore-state.sh:840`), module/dispatch/flag-mirror/`CLAUDE_MUX_BIN` mechanics, exempt-list split.

**Order of edits (do 1→2 before 3 so the dispatch target exists before the caller references it):**
1. **Flag parse** (`src/10-flags.sh`, mirror `--await-ready` at `:494-497`): add `--confirm-model-switch)` → set `COMMAND="confirm-model-switch"` and `CONFIRM_MODEL_SESSION="$2"` (shift 2). **Copy the arg-guard line** (`:495`: `[[ $# -lt 2 || "$2" == -* ]] && { echo "ERROR…" >&2; exit 1; }`).
   - **[Change A — CRITICAL]** Exempt lists: add `confirm-model-switch` to the **config-required-skip list at `src/90-dispatch.sh:10`** (where `await-ready` already is — it runs detached, no config load). Do **NOT** add it to the deps-exempt list at `src/35-validate-deps.sh:93` — `await-ready` is NOT there and the confirmer needs tmux (`capture-pane`/`send-keys`), so it must keep the tmux dep check. (The earlier draft's "add to deps-exempt alongside await-ready" was wrong on both counts.)
2. **Confirmer function** — **[Change D — CRITICAL]** append `confirm_model_switch <session>` to **`src/55-session-launch.sh`** (adjacent to the wrapper/`--await-ready` machinery it mirrors, `:195-211`). Do NOT create a new `src/56-*.sh` fragment: `src/` is NOT globbed; a stray fragment compiles to NOTHING (Makefile `MODULES` is explicit, `:15-19`) and `make check` stays green while the function is silently absent → dispatch-to-undefined at runtime. (If a new fragment is ever truly wanted, adding it to Makefile `MODULES` becomes a mandatory ordered step 0.)
   - Bounded loop: **~75 ticks × ~0.4s ≈ 30s window** (**[Fable HIGH-1]** — NOT ~15/6s; on self-switch the dialog renders only after the caller's turn ends, 5-15s+ post-send; see the self-switch timing section).
   - **Dead-session early-exit** (**[Fable LOW-4]**): at loop top, `"$TMUX_BIN" has-session -t "$session" 2>/dev/null || exit 0` (or bail after N consecutive `capture-pane` failures) so a missing pane doesn't spin the full 30s.
   - Each tick: `TAIL=$("$TMUX_BIN" capture-pane -t "$session" -p | tail -12)` (**tail -12** — the dialog spans ~7 lines; validated live in Phase 0; do NOT grow past ~15, that widens the transcript-quote window MEDIUM-1 guards against).
   - Match guard (BOTH required): `[[ "$TAIL" == *"Switch model?"* && "$TAIL" == *"Yes, switch to"* ]]`.
   - Hardening (**per-line + bottom-anchored**, **[Fable MEDIUM-1]**): require a SINGLE line containing BOTH `❯` and `Yes, switch to` **within the last ~6 lines** (dialog is bottom-anchored; a scrolled-up transcript quote is not), AND additionally require the `No, go back` line present. e.g. `printf '%s\n' "$TAIL" | tail -6 | grep -q '❯.*Yes, switch to' && printf '%s\n' "$TAIL" | grep -q 'No, go back'`. This defeats both `❯`-on-the-No-line and a verbatim quote of the dialog in the transcript above a live prompt (the claude-mux/home sessions are the worst case — they quote the dialog in docs + replies).
   - On match: `"$TMUX_BIN" send-keys -t "$session" Enter`; then poll up to ~2s to verify `Switch model?` is GONE from the tail (confirms it took); exit 0.
   - **Never re-key** (**[Fable MEDIUM-2]**): send `Enter` exactly ONCE. If the ≤2s verify times out with the string still visible (slow redraw, or a transcript quote that never disappears), **exit 0 anyway — do NOT send a second Enter**. Nothing loops back to the matcher after keying.
   - On window-expiry with no match ever seen: exit 0 silently, send NOTHING (never a blind Enter).
3. **Dispatch case** (`src/90-dispatch.sh` ~:54, beside `await-ready)`): `confirm-model-switch) confirm_model_switch "$CONFIRM_MODEL_SESSION"; exit 0 ;;`.
4. **Hook the send handler** (`src/90-dispatch.sh` between :90 and :91): after send-keys succeeds, background the confirmer only for `/model ` payloads. **[Change B — HIGH]** use the `( … & )` subshell-detach idiom (precedent `75-tip-notices.sh:210` for `--update-check-bg`) with `>/dev/null 2>&1`, NOT a bare `&`. **[Change C — HIGH]** invoke via `"$CLAUDE_MUX_BIN"` (defined `20-config.sh:135-137`), NOT `$0` (unreliable under relative paths):
   ```
   if [[ "$SEND_COMMAND" == /model\ * ]]; then
       ( "$CLAUDE_MUX_BIN" --confirm-model-switch "$SEND_SESSION" >/dev/null 2>&1 & )
   fi
   ```
   - **[Fable HIGH-2] What `( … & )` actually does — corrected from "prevents SIGHUP" to a precise, checkable claim.** In a non-interactive shell it: (a) clears the tool shell's **job table** (the job lives in the exiting subshell), and (b) with `>/dev/null 2>&1` holds **no open fds** back to the tool call. Those two are what let it **survive normal turn-end reaping** — a completed Bash tool call isn't signaled, and bash scripts don't HUP their children on exit (`huponexit` is interactive-login only). What it does **NOT** do: it does **not** change **process group** (no `setpgid` in a subshell under job-control-off) and does **not** start a new **session** (macOS ships no `setsid(1)` binary). So the SIGHUP/exit-guard exposure is only real if Claude Code kills the tool's *process group* or scans by *process tree* rather than job table — **unknowable from design**, and the ISSUES "Background work is running" entry proves the guard already fires on something claude-mux spawns.
   - **Ship-gate: Phase 3.1 decides this, not reasoning.** Run `/exit` inside the confirmer's live (~30s) window after a self-switch and observe whether the exit-guard lists the confirmer. **Pre-decided escalation if it does:** (i) accept it — option 2 "Move to background and exit" is non-destructive and the confirmer finishes in the background; or (ii) true-detach via `perl -e 'use POSIX; setsid(); exec @ARGV' -- "$CLAUDE_MUX_BIN" --confirm-model-switch "$SESSION"` (macOS has no `setsid(1)`). Note the widened 30s window (HIGH-1) *lengthens* this exposure window, so run 3.1 with the FINAL tick count.
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
