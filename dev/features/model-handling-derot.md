---
kind: feature
lifecycle: ready
feature: model-handling-derot
status: PLANNED — pre-build
target_version: 2.0.x (patch; one real bug + drift removal)
severity: MEDIUM — claude-mux's closed model allowlist now REJECTS valid models (e.g. `fable`); plus two drift liabilities (stale injection example, hand-maintained allowlist)
related: make-codemap (same "stop hardcoding source-of-truth that drifts" theme), notice-delivery-reliability
---

# Feature: de-rot model handling (version-agnostic example + pass-through model validation)

## Problem

claude-mux hardcodes model knowledge that **rots on every model release**, and one piece
is now **actively wrong** — it rejects valid models. Surfaced 2026-06-19: this session
runs `claude-opus-4-8`, but a home session reported "the latest Opus is `claude-opus-4-7`",
and the docs now list **Opus 4.7 as legacy** behind **Opus 4.8**, plus entirely new
families **Claude Fable 5 (`claude-fable-5`)** and **Claude Mythos 5 (`claude-mythos-5`)**.

Three rot points — **two are claude-mux's to fix:**

1. **Closed model allowlist `{sonnet, haiku, opus}` — now a real bug.** claude-mux validates
   model names against a fixed set and **errors on anything else**:
   - `src/20-config.sh:74-80` — `HOME_SESSION_MODEL` config: `""|sonnet|haiku|opus) ;; *) ERROR + exit`.
   - `src/30-helpers.sh:338-341` — `--home-model` flag: same allowlist, errors + exits.
   - `src/30-helpers.sh:445-453` — interactive install prompt: accepts only `sonnet|haiku|opus`,
     silently falls back to default otherwise ("Invalid model, using default").
   - `src/10-flags.sh:181-182, 306` — help text presents it as a closed `sonnet | haiku | opus` set.
   Today `HOME_SESSION_MODEL=fable` (a valid model) is **rejected** with "must be sonnet,
   haiku, opus, or empty." The allowlist must be hand-updated on every release and is
   already stale.
2. **Stale `"Opus 4.7"` example in the injection.** `src/30-helpers.sh:713` (the "ready"
   handshake instruction in `build_system_prompt`): *"using your actual model name as
   Claude Code shows it (e.g. `"Opus 4.7"`, `"Sonnet 4.6"`, `"Haiku 4.5"`)."* The
   instruction is correct (report your *real* model), but the **example is outdated** and
   rots every release.
3. **(Upstream, NOT claude-mux's)** Claude Code's own injected model note ("Model IDs —
   Opus 4.7: `claude-opus-4-7`") lags new releases. claude-mux cannot change Claude Code's
   system prompt; noted for completeness only.

## Principle

Same as `make-codemap`: **stop maintaining a source of truth that drifts.** The set of
valid Claude models is **Claude Code's** to know, not claude-mux's — maintaining a model
registry in a session wrapper violates "don't duplicate what Claude Code already handles"
and guarantees drift. claude-mux should **pass the model through and let `claude` be the
authority.**

## Fix

### A — pass-through model validation (membership → format)

Replace the **closed-allowlist (membership) checks** with a **format (safe-token) check**:
the model just needs to be a shell-safe token; *which* tokens are valid is Claude Code's
call (it errors at launch on a genuinely bad name).

- `src/20-config.sh:74-80` and `src/30-helpers.sh:338-341`: replace
  `""|sonnet|haiku|opus) ;; *) ERROR` with: empty is allowed (Claude Code default); else
  require the value match a safe token **`^[A-Za-z0-9._][A-Za-z0-9._-]*$`** and **pass it
  through** — no membership check, no exit.
  - **Regex forbids a LEADING DASH (architect, security):** the value is interpolated as a
    bare, *unquoted* token into `claude --model ${model}` in the generated launch scripts,
    so a value like `-rm` or `--dangerously-…` that began with `-` would be misparsed by
    `claude` as a *separate flag* (arg-injection). `^[A-Za-z0-9._][A-Za-z0-9._-]*$` (first
    char not a dash) closes that. The charset still covers every real model ID/alias
    (`claude-haiku-4-5-20251001`, `claude-opus-4-8`, `claude-fable-5`, `sonnet`).
  - **Security note:** the safe-token format check is now the *sole* thing keeping the
    unquoted interpolation safe (membership is gone). Single-user threat model = typos, not
    attackers, but the format check is the load-bearing safety invariant of this change.
  - **Chokepoint invariant (architect):** `src/20-config.sh` runs on **every** config load,
    so it is the guaranteed format-check chokepoint the launch wrappers rely on — even a
    hand-edited `~/.claude-mux/config` is caught there. Every path that can set
    `HOME_SESSION_MODEL` (config, `--home-model`, install prompt) MUST format-check; the
    config validator is the always-runs backstop.
- `src/30-helpers.sh:445-453` (install prompt): accept **any** safe-token input (not just
  `sonnet|haiku|opus`); only blank → default. Reword the prompt to present examples, not a
  closed set: `Home session model? (e.g. sonnet, haiku, opus, opus-4-8, fable; blank = default) [sonnet]:`.
- `src/10-flags.sh:181-182, 306` (help): reword from the closed `sonnet | haiku | opus` to
  "any model alias or ID `claude --model` accepts (e.g. sonnet, haiku, opus, opus-4-8,
  fable)".
- **Default stays `sonnet`** (`src/00-defaults.sh:70`) — a sensible, broadly-available
  default; empty also remains valid (Claude Code's own default).

### B — version-agnostic injection example

`src/30-helpers.sh:713`: change the example from `e.g. "Opus 4.7", "Sonnet 4.6", "Haiku 4.5"`
to **version-agnostic family names** `e.g. "Opus", "Sonnet", "Haiku"` (drop the version
numbers — versioning the example just re-rots next release). The instruction already tells
the session to report its *actual* model, so the example only needs to convey format.

### Out of scope (upstream)
Claude Code's stale "latest model" note (#3) — file/track as an upstream observation; not
fixable here.

## Why not just add `fable`/`mythos` to the allowlist?
Because that's the drift treadmill we're trying to leave: the next model breaks it again,
in 5 places. Pass-through removes the class. (And Mythos is limited-availability — a
closed list would also have to track availability tiers it has no business knowing.)

## Edge cases / risks

| Case | Handling |
|---|---|
| Typo'd model (e.g. `sonet`) | Passes claude-mux's format check, then **`claude` errors at launch**. See the crash-loop row below for what that means in the tmux/auto-restore machinery. |
| **Leading-dash value (e.g. `-rm`, `--foo`)** | **Rejected** by the leading-dash-forbidding regex `^[A-Za-z0-9._][A-Za-z0-9._-]*$` — prevents arg-injection into the unquoted `claude --model ${model}` interpolation. |
| Shell-metachar value (`opus; rm -rf x`, backticks, `$()`) | Rejected by the format check before it reaches the launch command (footgun guard preserved). |
| **Bad-but-format-valid model in persistent config (architect HIGH)** | The launch runs in a backgrounded tmux pane via the looped wrapper; a bad `--model` makes `claude` exit non-zero → the wrapper loop breaks, leaving the pane for the `--autolaunch` restore tick. **Disposition:** (a) **non-home** sessions are bounded by the existing **crash-loop guard** (`MIN_HEALTHY` 5min, trip at 3 → `failed` status) — no infinite churn; (b) the launch wrappers already capture `claude` stderr (`2>"$_resume_err"`), so the model error is **discoverable in the captured launch error / log**, not wholly silent; (c) **home is the sharp case** — home is LaunchAgent-managed (not marker/crash-loop-guarded), so a bad `HOME_SESSION_MODEL` can make the LaunchAgent retry home each tick. Mitigation: `HOME_SESSION_MODEL` is user-set via install/flag (foreground, the user sees it), correctable in config; we do **not** add a pre-launch model probe (heavy, requires launching `claude`). Documented as a known limit; the cause lands in the log. (Revisit a foreground "this model is unrecognized; claude will validate it at launch" warning if it bites.) |
| Empty model | Allowed → Claude Code default (unchanged). |
| New family (fable/mythos/future) | Just works — no claude-mux change needed (the point). |
| Existing configs with `sonnet/opus/haiku` | Unchanged — still valid (format check passes). No migration needed. |

## Files to update (Change Checklist)

- **Source (`src/`, then `make build` + `make check`):** `src/20-config.sh` (validation —
  the chokepoint), `src/30-helpers.sh` (`--home-model` validation L338-341, install prompt
  L445-453, config-writer L248-249, **injection example L713**), `src/10-flags.sh` (help
  text), `src/00-defaults.sh` (default comment — value stays `sonnet`).
- **Launch wrappers — stale security comments MUST be rewritten (architect HIGH):**
  `src/70-start-launch.sh:137` and `src/55-session-launch.sh:117` carry inline comments
  justifying the unquoted `--model` interpolation as safe *"because model_flag is
  whitelisted."* After this change the value is **format-validated, not whitelisted** — the
  comments go false. Rewrite the **model clause only** to: *"model is validated to
  `^[A-Za-z0-9._][A-Za-z0-9._-]*$` (shell-safe, no leading dash) at every set-boundary."*
  **Preserve the permission-mode clause** — perm modes REMAIN a closed allowlist (a fixed,
  Claude-Code-defined set, not a drift-prone model list), so `src/55:117`'s
  "perm_flag_value comes from a validated whitelist" stays accurate, as does the
  `mode_override` whitelist note at `src/55:101`. Only the *model* half goes false. This is
  the load-bearing safety invariant for the model path.
- **Injection change → README "Session System Prompt" section must match** the version-agnostic
  example.
- `config.example` + `config_help()` — `HOME_SESSION_MODEL` description: "any model
  `claude --model` accepts; blank = Claude Code default" (not a closed list).
- `docs/CLI.md` / `docs/GUIDE.md` / `docs/FAQ.md` — `--home-model` / `HOME_SESSION_MODEL`
  wording (grep FAQ for any closed-list "which models" phrasing).
- `src/30-helpers.sh:248-249` (config writer) — confirm a non-default new family (e.g.
  `fable`) is written as an **uncommented** `HOME_SESSION_MODEL="fable"` line (it comments
  the line out only for the `sonnet` default).
- `dev/CODEMAP.md` / `dev/IMPLEMENTATION-SPEC.md` — note pass-through model handling.
- `CLAUDE.md` — if the model set is referenced.
- `CHANGELOG.md` `### Fixed` (rejects valid models) + `### Changed` (model validation now
  pass-through).
- `docs/ISSUES.md` — record + the upstream note (#3).
- `internal/tips.md` + `tip_of_day` array — the existing tips reference "Haiku"/"opus"
  generically (no version), so no rot there; no change needed.

## Out of scope
- A `--list-models` / Models-API integration (heavier; pass-through already solves the bug).
- Per-session model config beyond `HOME_SESSION_MODEL` (the worker-model design in the
  parked inter-agent feature should also be pass-through when/if revived).
- Validating model *availability tiers* (limited-availability models like Mythos) — not
  claude-mux's job.
