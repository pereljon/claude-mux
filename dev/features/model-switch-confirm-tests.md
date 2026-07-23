---
kind: feature
lifecycle: ready
feature: model-switch-confirm-tests
status: TEST PLAN drafted 2026-07-17; Phase 0 survey run 2026-07-21; Fable (claude-fable-5) review folded in 2026-07-21 (30s window, exit-guard ship-gate in 3.1, transcript-quote test 2.7, deps-exempt reword, dead-session early-exit). Pre-build/code-ready. Pairs with model-switch-confirm.md.
related: model-switch-confirm, model-switching-cost-research, model-resolution-notice-cleanup
---

# Test plan: auto-confirm the "Switch model?" dialog

Pairs with `model-switch-confirm.md`. Covers the pre-build empirical survey, happy path, edge
cases, self- vs cross-session switching, and post-build verification. The governing invariant:
**claude-mux keys the dialog ONLY when it positively recognizes it; in every other case it does
nothing and behaves exactly as today (manual Enter).**

## Phase 0 — Pre-build dialog survey (MUST run before finalizing the matcher)
Goal: enumerate every dialog `/model` can raise, so the matcher recognizes the real set and the
"match-known-only, else no-op" fallback is deliberate, not accidental. Use a throwaway/test session
(NOT `home`). For each case, `/model <id>` then `tmux capture-pane -t SESSION -p | tail -12` and
record the exact text (or "no dialog").

| # | Scenario | Setup | Expected observation to capture |
|---|----------|-------|---------------------------------|
| 0.1 | Cached switch to a DIFFERENT model | active/used conversation, switch sonnet→opus | the `Switch model?` dialog (baseline; the one we auto-confirm) |
| 0.2 | Uncached switch | `/clear` first, then switch | NO dialog (switch is silent) — confirms conditional hazard |
| 0.3 | Switch to the SAME model | already on opus, `/model claude-opus-4-8` | capture whatever appears (dialog? no-op? "already on"?) |
| 0.4 | Switch to an UNAVAILABLE / bad ID | `/model claude-nonexistent-9` | capture the error/dialog shape (must NOT be auto-confirmed) |
| 0.5 | Large cached conversation | big thread, switch | same `Switch model?` dialog + verify wording drift (the "slower/more tokens" line seen 2026-07-17) |

Deliverable: a short table in the design doc listing exactly which dialogs the matcher recognizes
(only 0.1/0.5's `Switch model?` for now) and which it deliberately ignores (0.3, 0.4).

## Phase 1 — Happy path (the fix working)
| # | Case | Steps | Pass criteria |
|---|------|-------|---------------|
| 1.1 | Cross-session cached switch | from home/another session: `claude-mux -s TARGET '/model claude-opus-4-8'` on a cached TARGET | within ~6s, dialog auto-confirmed; `capture-pane` tail shows dialog GONE and TARGET processing on opus; NO manual keypress needed |
| 1.2 | Self-switch (current session) | in-session "switch this session to opus 4.8" (drives `-s SELF '/model …'`) | caller's turn ends; detached confirmer presses Enter; pane resumes on opus; no stray empty prompt submitted |
| 1.3 | Conversational trigger end-to-end | say "switch robotech-game-demo to opus 4.8" from home | model resolves to `claude-opus-4-8`, sent, dialog auto-confirmed, target on opus — no hang |

## Phase 2 — Edge cases / safety (the fix NOT misfiring)
| # | Case | Steps | Pass criteria |
|---|------|-------|---------------|
| 2.1 | Uncached switch (no dialog) | `/clear` TARGET, then `-s TARGET '/model …'` | confirmer sees no dialog for full window → exits silently; NO Enter sent (verify no empty prompt submitted, no spurious turn) |
| 2.2 | Same-model switch | `-s TARGET '/model <current-id>'` | confirmer no-ops per survey finding; session unharmed |
| 2.3 | Unknown/other dialog present | simulate a non-matching dialog in the tail (e.g. a permissions prompt) | match guard fails (missing `Switch model?`/`Yes, switch to`) → confirmer does NOTHING, leaves it for the user |
| 2.4 | Non-`/model` send | `-s TARGET '/compact'`, `/clear`, etc. | confirmer NOT backgrounded at all (hook guard `== /model *` excludes them); zero behavior change |
| 2.5 | Dialog renders after the window | throttle/delay so dialog appears >30s later | confirmer already exited; falls back to today's manual-Enter; never worse |
| 2.6 | Option reorder hardening | mock a tail where `❯` is on the "No" line | confirmer does NOT press Enter (requires `❯` on the `Yes, switch to` line, in the last ~6 lines) |
| 2.7 | **Transcript-quote false-match [Fable MEDIUM-1]** | put a verbatim quote of the `Switch model?` block (incl. `❯ 1. Yes, switch to …`) in the SCROLLBACK above a normal live prompt (trivial to reproduce in the claude-mux/home sessions, which quote it in docs/replies); no live dialog | confirmer does NOT press Enter — the bottom-anchor guard (`❯…Yes` must be in the last ~6 lines AND `No, go back` present) rejects a scrolled-up quote. Worst variant: quote in scrollback + a DIFFERENT live dialog at the bottom → still must not key the other dialog's default. |

## Phase 3 — Reentrancy / process-lifetime (the architect's #1 risk)
| # | Case | Pass criteria |
|---|------|---------------|
| 3.1 | **SHIP-GATE: survives tool-call return + exit-guard [Fable HIGH-2]** | Force the adversarial condition: a genuine self-switch where `-s SELF '/model …'` is Claude's Bash tool call. The confirmer is detached via `( … & )` + `>/dev/null 2>&1` (clears job-table + fds; note pgid/session are NOT changed — no `setsid` on macOS). (a) Instrument the confirmer to log a timestamp when it sends Enter; assert Enter fires AFTER the `send` process exited AND lands on the dialog (~5-15s+ later, within the ~30s window — run with the FINAL tick count). (b) **Exit-guard probe:** run `/exit` inside the confirmer's live window and observe whether Claude Code's "Background work is running" guard lists the confirmer. If it does NOT → `( … & )` is sufficient, done. If it DOES → apply the pre-decided escalation (accept option-2 "Move to background and exit" as non-destructive, OR true-detach via `perl … setsid`). This gate decides the detach approach; do not ship on reasoning alone. |
| 3.2 | No race on self-switch | caller flushes `/model`+Enter, stops; Claude Code renders dialog; confirmer's Enter is the only key in flight → no double-submit |
| 3.3 | Concurrent switches | two sessions switched near-simultaneously → each confirmer watches its own pane by name; no cross-talk |
| 3.4 | Narrow-pane wrap | resize target pane to ~60-80 cols so wrapping inflates the dialog line count; confirm the `tail -12` window + bottom-anchored per-line `❯…Yes, switch to` match still recognizes it. Note [Fable LOW-1]: below ~45 cols the top line can fall outside `tail -12` → a safe MISS (manual fallback, never a wrong key); 80-col detached-pane default does not wrap the longest line. Do NOT grow the tail past ~15 (widens the MEDIUM-1 quote window). |

## Phase 4 — Regression / build gates
- `make build` clean; `make check` green (artifact, codemap, features-index all fresh).
- `make codemap` includes the new `confirm_model_switch` function; purpose row added by hand.
- Smoke: `bash ./claude-mux --confirm-model-switch NONEXISTENT` exits cleanly (no crash on a missing/again-idle pane) and FAST via the dead-session early-exit [Fable LOW-4] — assert it does NOT spin the full ~30s window (the `has-session` check should exit ~immediately).
- Flag arg-guard: `bash ./claude-mux --confirm-model-switch` (no session) errors like `--await-ready` does, exit 1.
- Config-skip (NOT deps-exempt) [Fable LOW-3]: `--confirm-model-switch` is added to the **config-required-skip list at `src/90-dispatch.sh:10`** (runs without a full config load, like `await-ready`). It is deliberately **NOT** in the deps-exempt list at `src/35-validate-deps.sh:93` — the confirmer needs tmux (`capture-pane`/`send-keys`), so the tmux dep check MUST stay. Do not "fix" `35-validate-deps.sh` to add it.
- Injection unchanged in shape: the model-switch rule still emits `-s '/model <id>'`; only the parenthetical about "may hang" is removed/updated.

## Verification checklist (post-build, on the repo copy)
- [ ] Phase 0 survey table recorded in the design doc; matcher recognizes only the surveyed `Switch model?` dialog.
- [ ] 1.1–1.3 all switch with NO manual keypress.
- [ ] 2.1 and 2.4 send ZERO keystrokes (grep the pane: no empty-prompt submission).
- [ ] 2.3 / 2.6 / 2.7 leave a non-matching dialog or a scrolled-up transcript quote untouched.
- [x] 3.1 SHIP-GATE run 2026-07-22 — PASS. (A) confirmer matched+confirmed+verified a real pinned dialog via the exact `( … & )` detach idiom (Enter ~1s after spawn, verify-loop saw it cleared). (B/Fable HIGH-2) a `( … & )` orphan spawned by a real Claude Bash tool survived that session's turn-end reaping (marker written 8s post-return). (b) `/exit` inside the confirmer's live 30s window → session exited cleanly, NO "Background work is running" guard → the detach is not counted as background work. **Decision by observation: `( … & )` is sufficient; no setsid/perl escalation.**
- [ ] Window is ~30s (75×0.4s), not ~6s; dead-session early-exit verified fast.
- [ ] `make check` clean; CHANGELOG + ISSUES + VERSION (2.0.14) updated.
- [x] Real end-to-end PASSED 2026-07-22 on a live warm-cached session (`ai-training`, opus-4-7→sonnet-4-6): the genuine Claude Code "Switch model?" dialog rendered (text: "Your next response will be slower and use more tokens / This conversation is cached for the current model. Switching to Sonnet 4.6 means the full history gets re-read … ❯ 1. Yes, switch to Sonnet 4.6 / 2. No, go back"), the confirmer cleared it in ~1s (rc 0, landed on Sonnet unattended), and the restore switch (sonnet→opus-4-7) via the real `-s` send-handler path auto-cleared its dialog too. **Trigger condition learned:** the dialog needs BOTH cache-eligible size (~1k+ tokens) AND a warm prompt cache (~5-min TTL) — idle sessions (cold cache) switch silently and the confirmer correctly no-ops (verified on `everything-claude-code` and a throwaway). Matcher validated against the real live text.
