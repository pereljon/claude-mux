---
kind: feature
lifecycle: idea
feature: context-cost-awareness
status: IDEA 2026-06-21 (concept + feasibility sketched; not yet designed/architect-reviewed). Brainstorm scope before specing.
target_version: unscheduled
severity: N/A (enhancement) — addresses the observation that claude-mux's persistence biases toward long-lived conversations, whose per-turn input cost escalates (see model-switching-cost-research).
related: model-switching-cost-research, model-switch-confirm
---

# Feature (idea): context-cost awareness — make long-conversation cost visible / managed

## Motivation
claude-mux keeps sessions alive and RESUMES the conversation on restart (`claude -c`), which biases
users toward one long-running thread instead of fresh ones. Per `model-switching-cost-research.md`,
per-turn input cost scales with conversation length (the whole transcript is re-read every turn;
caching softens it to 0.1× but it still grows), and idle-then-resumed long sessions pay a cache
re-warm. So persistence quietly escalates cost. claude-mux could turn that into "persistence WITH
cost awareness." (Note: persistence itself adds no token cost — only the growing transcript does;
the two are separable.)

## The feasibility unlock
claude-mux can't read Claude Code's internal token count (same blind spot as model/mode). BUT every
session's conversation is stored as a `.jsonl` transcript under `~/.claude/projects/<encoded-path>/`
which claude-mux CAN stat. File size (or a chars/4 token estimate) is an external, readable proxy
for conversation length/cost. claude-mux already handles that path encoding (`encode_claude_path`,
used by rename/move), so locating a session's transcript is solved. VERIFY before specing: exact
transcript location/naming for a session, that size tracks length usefully, and a sane token
estimate (jsonl includes metadata overhead, so chars/4 on the raw file overcounts — may need to
sum message text fields, or just use a calibrated fudge factor).

## Three tiers (pick ambition during brainstorming)
1. **Visibility (lightest, safest).** Add conversation size to `status` and/or the `-l`/`-L`
   listing — a token estimate or % of a reference window, from the transcript file. Pure read, no
   behavior change. Turns "cost escalates silently" into "you can see it."
2. **Nudge (medium).** When a session's transcript crosses a threshold, inject a notice ("this
   conversation is ~Xk tokens; 'compact this session' to cut cost") via the existing
   persist-while-relevant notice machinery (`on_prompt`). Self-clears when a compact shrinks the
   file. Opt-in, non-destructive. (Depends on the notice-display issues being clean — see
   model-resolution-notice-cleanup + the `<assistant-must-display>` tag follow-up in ISSUES.)
3. **Auto-compact on cost (heaviest, riskiest).** claude-mux triggers `/compact` past a threshold.
   Powerful but: compaction has real cost + is lossy (see the cost research), so this needs
   guardrails — cadence limits, per-session opt-in config, and it must respect the
   order-of-operations (don't auto-compact mid-task surprisingly). Likely behind an explicit
   config flag only, if at all.

## Recommendation (pre-brainstorm instinct)
Tier 1 + Tier 2 is the sweet spot: make cost visible and nudge, leave the compact DECISION to the
user (compaction cost + lossiness make auto-compaction on a timer a footgun). Tier 3 only behind an
explicit opt-in.

## Tie-in: the order-of-operations nudge
Strong synergy with `model-switch-confirm`: when the user asks to "change model to X" AND the
transcript is large, claude-mux could nudge "this thread is ~Xk tokens — 'clear' or 'compact' first
to avoid the re-read" (the shrink-before-switch principle from the cost research). The cost feature
and the model-switch fix are two halves of "switch models intelligently."

## Prior art (reference, not to build)
**graphify** (`safishamsi/graphify`, reviewed 2026-07-01) is a "memory layer" that attacks the same
underlying problem from the other side: instead of re-reading whole files each turn, it builds a
queryable knowledge graph of the project and installs assistant hooks that redirect grep/Read toward
graph *queries* — cutting the tokens a long conversation pulls in. It ships as a cross-CLI **skill**
(Claude Code, Codex, Gemini, OpenClaw, etc.), not session infrastructure. Relevant as a reference
approach for the context-discipline thread and the memory-management idea, and as prior art for the
cross-CLI skill-distribution pattern (`cross-cli-coders.md`). **Not something to build into
claude-mux** — it's an external tool that can be used alongside claude-mux (query-first context
reduction is skill/tooling territory, not session-infra territory). See memory `reference_graphify`.

## Open questions for brainstorming / architect
- Transcript location/format: confirm the exact path + how to estimate tokens reliably from jsonl.
- Where size surfaces: `status` only, or also `-l`/`-L` (adds a column; affects the
  `<assistant-must-display>` table the trigger rules render verbatim)?
- Thresholds: what token counts warrant a nudge? Per-model (Haiku's 200k window vs 1M)?
- Cost vs capacity: Claude Code already auto-compacts near the WINDOW limit; this feature is about
  COST (earlier, cheaper). Make sure the two don't fight.
- Config surface: a `CONTEXT_NUDGE`/threshold config var? Default on/off?

## Reuse
`encode_claude_path` (transcript path), `on_prompt` notice machinery (tier 2),
`status_claude_sessions` / `status` reporting, the `-l`/`-L` listing.

## Out of scope (for now)
- Real token accounting (we only have a file-size proxy; don't promise exactness).
- Anything that reads Claude Code internal state (not available).
