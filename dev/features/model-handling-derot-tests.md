---
feature: model-handling-derot
---

# Test Plan: de-rot model handling

Tests for `model-handling-derot.md`. Decisive properties: **claude-mux no longer rejects
a valid model it doesn't recognize** (pass-through), it **still rejects shell-unsafe
tokens** (footgun guard preserved), and the **injection example no longer carries a
version number** (drift-proof).

## Pre-build verification

- **V0.1** Confirm the current closed-allowlist sites reject non-`{sonnet,haiku,opus}`:
  `HOME_SESSION_MODEL=fable bash ./claude-mux <config-requiring cmd>` errors today;
  `--home-model fable` errors today. (Baseline for the fix.)
- **V0.2** Confirm the model value flows into `claude --model <x>` in both launch wrappers
  (`src/55`, `src/70`) and is quoted — so the format check is the right safety layer.

## Pass-through validation (A)

- **T1.1 New family accepted — config.** `HOME_SESSION_MODEL=fable` no longer errors; the
  value passes through to the launch command (`--dry-run` shows `--model fable`, or the
  launch wrapper carries it).
- **T1.2 New family accepted — flag.** `--home-model fable` (and `--home-model opus-4-8`)
  no longer errors; sets the home model.
- **T1.3 New family accepted — install prompt.** Entering `fable` (or `opus-4-8`) at the
  interactive prompt is accepted, not silently replaced by the default.
- **T1.4 Existing values still work.** `sonnet` / `haiku` / `opus` / empty all still
  accepted (no regression; no migration needed).
- **T1.5 Empty = Claude Code default.** Empty `HOME_SESSION_MODEL` is allowed and passes no
  `--model` (or the documented default) — unchanged behavior.

## Format / footgun guard (security preserved)

- **T2.1 Shell-unsafe token rejected.** A model containing shell metacharacters (e.g.
  `opus; rm -rf x`, backticks, `$()`) is **rejected** by the
  `^[A-Za-z0-9._][A-Za-z0-9._-]*$` format check before reaching the launch command.
- **T2.2 Leading-dash value rejected (arg-injection guard).** `HOME_SESSION_MODEL=-rm` and
  `--home-model --foo` are **rejected** by the leading-dash-forbidding regex — they must
  NOT reach the unquoted `claude --model ${model}` interpolation (where they'd be misparsed
  as a separate `claude` flag).
- **T2.3 Real IDs with internal dashes accepted.** `claude-opus-4-8`,
  `claude-haiku-4-5-20251001`, `claude-fable-5` all pass (internal dashes fine; only a
  *leading* dash is forbidden).
- **T2.4 Typo passes claude-mux, fails at `claude`.** A safe-but-invalid model (`sonet`)
  passes the format check; `claude` errors at launch. Confirm the error lands in the
  captured launch stderr / log (discoverable), and (non-home) the crash-loop guard bounds
  retries — see T4.5.

## Version-agnostic injection (B)

- **T3.1 Example has no version number.** `--print-system-prompt <session>` output's
  "ready" instruction reads `e.g. "Opus", "Sonnet", "Haiku"` — no `4.7`/`4.6`/`4.5`.
- **T3.2 Instruction intent intact.** It still says report the *actual* model name as
  Claude Code shows it (only the example changed).
- **T3.3 README matches.** The README "Session System Prompt" section's example matches
  the new version-agnostic injection (Change-Checklist sync).

## Regression / build

- **T4.1 Build clean.** `make build` + `make check` pass; `bash -n` clean.
- **T4.2 Help/config wording.** `--help` / `config_help` / `config.example` present the
  model field as "examples / any model `claude --model` accepts," not a closed set.
- **T4.3 Default unchanged.** Default home model is still `sonnet`.
- **T4.4 No new allowlist introduced.** Grep confirms no remaining
  `sonnet|haiku|opus)` *membership* `case` in validation paths (only examples in
  help/prompts).
- **T4.5 Bad-model launch failure is bounded + discoverable.** With a format-valid but
  invalid `HOME_SESSION_MODEL` on a non-home session: the wrapper exits non-zero, the
  crash-loop guard trips after 3 attempts (`failed` status — no infinite churn), and the
  `claude` model error is present in the captured launch stderr / log. (Home/LaunchAgent
  retry behavior documented as a known limit, not a test target.)
- **T4.6 Config writer keeps non-default uncommented.** `--home-model fable` (or any
  non-`sonnet`) writes an **active** `HOME_SESSION_MODEL="fable"` line in the generated
  config (not commented out); `sonnet` default may stay commented as today.
- **T4.7 Launch-wrapper comments updated.** The `src/55`/`src/70` inline security comments
  no longer say "whitelisted"; they describe the format-validation invariant.
- **T4.8 FAQ wording.** `docs/FAQ.md` has no closed-list "which models" phrasing post-change.

## Acceptance

- T1.x: pass-through — valid models (incl. new families) accepted everywhere a model is set.
- T2.x: footgun guard preserved (format, not membership).
- T3.x: injection example de-versioned + README synced.
- T4.x: build clean, wording updated, default intact, no lingering membership check.

## Cleanup
Restore any scratch config used for T1/T2.
