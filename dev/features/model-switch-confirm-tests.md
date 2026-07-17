---
kind: feature
lifecycle: ready
feature: model-switch-confirm-tests
status: TEST PLAN drafted 2026-07-17 alongside the build plan; pre-build. Pairs with model-switch-confirm.md.
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
| 2.5 | Dialog renders after the window | throttle/delay so dialog appears >6s later | confirmer already exited; falls back to today's manual-Enter; never worse |
| 2.6 | Option reorder hardening | mock a tail where `❯` is on the "No" line | confirmer does NOT press Enter (requires `❯` on the `Yes, switch to` line) |

## Phase 3 — Reentrancy / process-lifetime (the architect's #1 risk)
| # | Case | Pass criteria |
|---|------|---------------|
| 3.1 | **Survives tool-call return (the real risk)** | Force the adversarial condition: a genuine self-switch where `-s SELF '/model …'` is Claude's Bash tool call. The confirmer is detached via `( … & )` (NOT bare `&`, which stays in the caller's process group and can catch SIGHUP when the tool call is reaped). Instrument the confirmer to log a timestamp when it sends Enter; assert that Enter fires AFTER the `send` process has exited. Enter must still land on the dialog. |
| 3.2 | No race on self-switch | caller flushes `/model`+Enter, stops; Claude Code renders dialog; confirmer's Enter is the only key in flight → no double-submit |
| 3.3 | Concurrent switches | two sessions switched near-simultaneously → each confirmer watches its own pane by name; no cross-talk |
| 3.4 | Narrow-pane wrap | resize target pane to ~60 cols so wrapping inflates the dialog line count; confirm the `tail -12` window + per-line `❯…Yes, switch to` match still recognizes it (guards against the clipped-window bug that motivated tail -12) |

## Phase 4 — Regression / build gates
- `make build` clean; `make check` green (artifact, codemap, features-index all fresh).
- `make codemap` includes the new `confirm_model_switch` function; purpose row added by hand.
- Smoke: `bash ./claude-mux --confirm-model-switch NONEXISTENT` exits cleanly (no crash on a missing/again-idle pane) AND within the ~6s bounded window (assert it does not hang).
- Flag arg-guard: `bash ./claude-mux --confirm-model-switch` (no session) errors like `--await-ready` does, exit 1.
- Deps-exempt: `--confirm-model-switch` runs without a full config load (like `--await-ready`).
- Injection unchanged in shape: the model-switch rule still emits `-s '/model <id>'`; only the parenthetical about "may hang" is removed/updated.

## Verification checklist (post-build, on the repo copy)
- [ ] Phase 0 survey table recorded in the design doc; matcher recognizes only the surveyed `Switch model?` dialog.
- [ ] 1.1–1.3 all switch with NO manual keypress.
- [ ] 2.1 and 2.4 send ZERO keystrokes (grep the pane: no empty-prompt submission).
- [ ] 2.3 / 2.6 leave a non-matching dialog untouched.
- [ ] `make check` clean; CHANGELOG + ISSUES + VERSION (2.0.14) updated.
- [ ] Real end-to-end: switch a genuinely cached session across models from home and confirm it lands on the new model unattended.
