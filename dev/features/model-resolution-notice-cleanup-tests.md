---
feature: model-resolution-notice-cleanup
---

# Test Plan: in-session model-family resolution + notice-display cleanup

Tests for `model-resolution-notice-cleanup.md`. Both parts are injected-prose / notice-string
changes, so most tests assert what the **built `claude-mux` injects** (`--print-system-prompt`)
and what the **hook emits** (`--on-prompt` stdout), not live LLM behavior. The behavioral parts
(does the in-session Claude actually resolve `sonnet` → `claude-sonnet-4-6`) are verified by a
live manual check, recorded honestly.

## Pre-build verification
- **V0.1** Confirm the bug: current rule (`src/30:742`) passes a bare family through unchanged
  (no resolution clause for a versionless family token).
- **V0.2** Confirm the leak: `--on-prompt` with a forced tip emits the meta-instruction
  `[claude-mux tip — MUST relay…]:` INSIDE the `<assistant-must-display>` tags.

## Part 1 — model resolution (injection text)
- **T1.1 Rule present + correct shape.** `--print-system-prompt <s> auto` contains a
  model-switch rule that: (a) expands a BARE family to the latest concrete ID (mentions
  `sonnet` → `claude-sonnet-4-6` or equivalent, "latest concrete ID", "dateless alias");
  (b) keeps the versioned-shorthand rewrite ("opus 4.8" → `claude-opus-4-8`); (c) passes
  full / date-suffixed IDs through; (d) says to ASK the user if it cannot resolve, rather than
  send a bare family.
- **T1.2 No bare-family pass-through claim.** The rule no longer says a bare family alias is
  "valid as-is / passes through unchanged" for `/model` (that was the v2.0.12 bug).
- **T1.3 Backtick/quote escaping.** The rule renders with literal backticks/quotes in the
  built file (no command substitution, no premature string termination); `bash -n` clean.
- **T1.4 Both-surfaces wording.** The "switch session NAME to MODEL" variant inherits the same
  resolution (one rule covers this-session and NAME).
- **T1.5 Launch path untouched.** `HOME_SESSION_MODEL` / `--home-model` / `--model`
  pass-through behavior is unchanged (grep the launch wrappers + config validator — no new
  model rewriting added there).
- **T1.6 (manual, live) Real resolution.** In a real session, "change model to sonnet" results
  in the session sending `/model claude-sonnet-4-6` (not bare `sonnet`) and the model actually
  changes (no "Kept model as…"). Record the result; if the in-session model's knowledge lags a
  brand-new family, confirm it ASKS for the exact ID instead of silently no-opping.

## Part 2 — notice-display cleanup
- **T2.1 Tip shows clean.** Forced tip emission (`--on-prompt`, fresh session_id, cache set)
  emits `<assistant-must-display>claude-mux tip: <tip></assistant-must-display>` with NO
  `MUST relay` / `in their conversation language` / bracketed-instruction text inside the tags.
- **T2.2 Update notice clean.** With `.update-check` showing a newer version, the update notice
  inside the tags is just the user-facing message (version X is out … say "update claude-mux"),
  no meta-instruction prefix.
- **T2.3 Upgrade notice clean.** With `@claude-mux-claude-id` mismatched, `detect_claude_upgrade`
  emits the upgrade message inside the tags with no meta-instruction prefix.
- **T2.4 Standing rule carries the instructions.** `--print-system-prompt` shows the standing
  notice rule (`src/30:713`) now says: surface exactly the text inside the tags verbatim, print
  nothing outside the tags, mention once per session. (The per-notice text no longer carries the
  dedup instruction.)
- **T2.5 Persist-while-relevant intact.** The update + upgrade notices still re-inject every
  prompt while their condition holds (v2.0.10 behavior unchanged); only the displayed string
  changed. Tip still daily-gated per session.
- **T2.6 (manual, live RC) Clean render.** In a real Remote-Control turn, a forced notice is
  surfaced as just the clean one-liner (no `[claude-mux … MUST relay …]:` prefix).

## Handshake / regression
- **T3.1 No notice on `Ready?`.** All notices still no-op on the synthetic handshake
  (`_is_handshake` guard) — unchanged.
- **T3.2 Both-off guard.** With `TIP_OF_DAY` and `UPDATE_CHECK` both false, only the always-on
  upgrade notice can emit, and it emits the clean string.

## Build / drift
- **T4.1** `make build` + `make check` clean (artifact drift guard, codemap, features-index);
  `bash -n` clean.
- **T4.2 features-index** includes `model-resolution-notice-cleanup` with `lifecycle` matching
  the doc (ready → building → shipped as it progresses).

## Acceptance
- Part 1 mandatory: T1.1, T1.2, T1.6 — bare family resolves to a concrete ID and the switch
  actually takes (or asks on a genuine unknown), no silent no-op.
- Part 2 mandatory: T2.1–T2.4, T2.6 — notices render clean, instructions live in the standing
  rule.
- T3.x/T4.x: handshake unaffected, build clean.

## Cleanup
Remove throwaway sessions and scratch `.update-check` / tip-state files used for tests.
