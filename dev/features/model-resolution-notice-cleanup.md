---
kind: feature
lifecycle: shipped
feature: model-resolution-notice-cleanup
status: IMPLEMENTED 2026-06-21 (v2.0.13; expand-from-knowledge model resolution + notice-display cleanup). Live manual checks (real /model resolution, clean RC render) pending real-world use.
target_version: 2.0.13 (patch; one real bug fix + one display regression fix)
severity: MEDIUM — "change model to <family>" silently no-ops (in-session model switch broken for bare family names); plus a notice-display regression (the relay instruction leaks into the visible tip/notice).
related: model-handling-derot (the pass-through principle this upholds), notice-delivery-reliability (introduced the <assistant-must-display> wrapping this corrects)
---

# Feature: in-session model-family resolution + notice-display cleanup

Two unrelated fixes that both live in the injected system prompt / notice strings, bundled
into one patch (v2.0.13).

---

## Part 1 — Resolve loose model tokens to a concrete ID for the in-session `/model`

### Problem
"change model to sonnet" makes the in-session Claude send `/model sonnet` (a bare family
name). Claude Code's `/model` picker **silently ignores a bare family** — it reports
"Kept model as <current>" and the model does NOT change. Confirmed live 2026-06-20: a
session on `claude-opus-4-8` stayed there after `/model sonnet`.

The current rule (v2.0.12, `src/30-helpers.sh` ~L742) only rewrites a *versioned*
shorthand ("opus 4.8" → `claude-opus-4-8`) and **passes a bare family through unchanged** —
which is exactly the no-op. The bare-family case was never handled.

### Surfaces are different (key fact)
- **Launch time** (`--model <token>`, the `model-handling-derot` pass-through) and
  **in-session** (`/model <token>` via the picker) are DIFFERENT surfaces. derot's
  pass-through is correct for launch; it does not cover the in-session picker. This feature
  touches only the in-session `/model` trigger rule. Leave the launch-time `--model`
  pass-through (`HOME_SESSION_MODEL`, etc.) untouched.

### Model ID facts (from platform.claude.com docs, verified 2026-06-21)
- 4.6-generation and later use **dateless pinned IDs**: `claude-<family>-<major>-<minor>`
  (e.g. `claude-opus-4-8`, `claude-sonnet-4-6`). Each is a fixed snapshot, not an evergreen
  pointer.
- Pre-4.6 models use a **date-suffixed** ID (`claude-haiku-4-5-20251001`) **plus** a dateless
  alias (`claude-haiku-4-5`) that resolves to the latest snapshot. So the dateless alias is
  the right "latest" form to send.
- Current latest per family: Opus `claude-opus-4-8`, Sonnet `claude-sonnet-4-6`, Haiku
  `claude-haiku-4-5` (alias) / `claude-haiku-4-5-20251001` (concrete), plus `claude-fable-5`,
  `claude-mythos-5` (limited).
- Evidence the picker accepts these: this session runs `claude-opus-4-8`, set via
  `/model claude-opus-4-8`.

### Chosen design: expand-from-knowledge (injection prose only)
The in-session Claude resolves MODEL to a concrete ID **before** sending `/model`, using its
own model knowledge **plus the model-ID list Claude Code injects into every session's
context**. No new files, no CLI subcommand, no daily job. Resolution order:

1. **Bare family** (`opus`/`sonnet`/`haiku`/any family) → expand to the latest concrete ID
   the Claude knows for that family, preferring the dateless alias form (`sonnet` →
   `claude-sonnet-4-6`).
2. **Family + version shorthand** (`opus 4.8`, `opus-4-8`, `opus 4 8`) → the dash-joined
   `claude-`-prefixed ID `claude-opus-4-8` (unchanged from v2.0.12).
3. **Already-full or date-suffixed ID** (`claude-opus-4-8`, `claude-haiku-4-5-20251001`) →
   pass through unchanged.
4. **Cannot confidently resolve** (e.g. a model newer than its knowledge) → **ask the user**
   for the exact ID rather than send a bare family (which silently no-ops).

Then send `/model <resolved-id>`. Same resolution for "switch session NAME to MODEL".

### Rejected alternatives (architect-reviewed; recorded so they are not re-litigated)
- **Picker-scraping fallback** (send `/model`, read the picker, pick latest, re-send): the
  trigger is **unobservable** — `/model` via `claude-mux -s self` is fire-and-forget; the
  "Kept model as…" result only surfaces on the NEXT turn, not in-turn. Same-turn
  `capture-pane` polling of a TUI overlay is timing-fragile, reentrant, and violates the
  "no raw tmux" injection rule. Rejected.
- **`~/.claude-mux/models.txt` fetched daily + deterministic resolver:** a public no-auth
  source DOES exist (the models/overview docs page), so the original "no source" objection
  was wrong — but it still fails on two grounds: (a) the docs are the **API** surface, while
  the subscription `/model` **picker is a different surface claude-mux can't observe**, so a
  docs-resolved ID that the picker doesn't offer fails as the SAME silent no-op (the scraper
  doesn't close the hole, it just moves where the wrong ID comes from); (b) it adds a parser,
  cache, daily job, and a new failure class (a partial/garbled fetch writes a models.txt
  missing a family → the resolver then BLOCKS a model the user can actually select), all for
  a sub-case (a model newer than both the Claude's knowledge AND Claude Code's injected list)
  that is rare and self-heals on the next Claude Code upgrade. It re-introduces the
  drifting-registry treadmill `model-handling-derot` deliberately removed. Rejected.
- **`GET /v1/models` JSON API:** clean JSON, but needs `X-Api-Key: $ANTHROPIC_API_KEY`; a
  Claude **subscription** user (OAuth `/login`) has no usable standalone key, and the API
  enumerates API IDs that need not match the subscription picker. Rejected.

### Why expand-from-knowledge wins
For every CURRENT family the in-session Claude reliably knows the latest ID (training + the
Claude-Code-injected list), and those IDs are proven to work in the picker. So the scraper
adds zero value for everything that exists today, while adding real infrastructure and a new
failure mode. Expand-from-knowledge fixes the reported bug with zero infra and degrades
gracefully (ask the user) for the rare unknown-new-model case. Honors derot (Claude Code
stays the model authority).

**Honest limitation:** on the day a brand-new model ships that the in-session Claude's
knowledge AND Claude Code's injected list both miss, resolution falls back to asking the user
for the exact ID. Accepted — there is no observable authoritative list of picker-accepted IDs
to consult.

---

## Part 2 — Notice-display cleanup (the relay instruction leaks into the visible notice)

### Problem
The tip/update/upgrade notices wrap the **meta-instruction inside** the
`<assistant-must-display>` tags, e.g. (`src/75-tip-notices.sh:174`):

```
<assistant-must-display>[claude-mux tip — MUST relay to the user verbatim at the start of your reply, in their conversation language]: <tip></assistant-must-display>
```

`<assistant-must-display>` means "print everything between the tags verbatim", so the
instruction prefix (`[claude-mux tip — MUST relay…]:`) is printed to the user along with the
tip. Same defect in the update notice (`src/75:194`) and the upgrade notice
(`detect_claude_upgrade`, `src/75:95`). Introduced by `notice-delivery-reliability` (v2.0.10)
when the notices were first wrapped.

### Fix
Put **only the clean user-facing text inside the tags**; the relay/dedup instruction lives in
the standing rule in `build_system_prompt` (`src/30-helpers.sh:713`), which already exists and
just needs tightening. New notice strings:

- Tip (`src/75:174`): `<assistant-must-display>claude-mux tip: <tip></assistant-must-display>`
- Update (`src/75:194`): `<assistant-must-display>claude-mux: update available — version X is out (current: Y). Say "update claude-mux" to update.</assistant-must-display>`
- Upgrade (`src/75:95`): `<assistant-must-display>claude-mux: Claude Code was upgraded since this session started. Say "restart this session" to load the new binary.</assistant-must-display>`

Standing rule (`src/30:713`) reworded to: *the user-facing text is wrapped in
`<assistant-must-display>` tags; surface exactly that text verbatim at the START of your reply;
do not print anything outside the tags; mention each notice at most once per session* (the
once-per-session dedup moves here, out of the per-notice text).

### Tradeoff (accepted)
`<assistant-must-display>` is inherently **verbatim**, which conflicts with "in their
conversation language" (translate the tip). That conflict already existed; resolve it in favor
of clean, reliable verbatim display. Tips display in English. The actionable
notices (update/upgrade) are short and action-oriented, so verbatim English is fine.

---

## Files to update (Change Checklist)
- **Source (`src/`, then `make build` + `make check`):**
  - `src/30-helpers.sh` — model-switch rule (~L742, Part 1) + standing notice rule (~L713,
    Part 2). This is the single injection source (`build_system_prompt`); both
    `create_claude_session` and `launch_single_session` use it.
  - `src/75-tip-notices.sh` — three notice strings (tip L174, update L194, upgrade L95) +
    update the comments that say the dedup lives "in the notice text" (it now lives in the
    standing rule).
- **README** — model examples (e.g. "Sends /model haiku") now resolve to a concrete ID
  (`claude-haiku-4-5`); the "Session System Prompt"/notice references if any.
- `docs/GUIDE.md` — the model-switch trigger bullet (update the parenthetical to describe
  bare-family expansion).
- `CLAUDE.md` non-obvious-behaviors — the notice notes (dedup now in the standing rule, not
  the notice text).
- `dev/CODEMAP.md` / `dev/SKELETON.md` — `on_prompt` / `detect_claude_upgrade` notice wording;
  no structural/function change.
- `CHANGELOG.md` — `### Fixed` (bare-family no-op; tip-prefix leak).
- `docs/ISSUES.md` — record both (resolved in v2.0.13).
- `VERSION` → 2.0.13.
- `make features-index` after this doc lands.

## Out of scope
- Any models.txt / `--resolve-model` / `/v1/models` integration (rejected above).
- The launch-time `--model` / `HOME_SESSION_MODEL` path (different surface; pass-through stays).
- Translating notices (incompatible with verbatim `<assistant-must-display>`).
