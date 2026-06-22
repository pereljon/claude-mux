---
kind: investigation
feature: model-switching-cost-research
status: RESEARCH 2026-06-21 (verified against platform.claude.com docs + live Claude Code dialog). Reference for the model-switch-confirm + context-cost-awareness features.
related: model-switch-confirm, context-cost-awareness, model-resolution-notice-cleanup
---

# Investigation: the cost of switching models mid-conversation (and the right order of operations)

Analysis-only. Captures why mid-conversation model switching is expensive and the correct
order of operations, so the two dependent features (`model-switch-confirm`,
`context-cost-awareness`) rest on verified mechanics, not guesses.

## Sources
- Prompt caching: platform.claude.com/docs/en/build-with-claude/prompt-caching (fetched 2026-06-21).
- Model IDs / tokenizer / windows: platform.claude.com/docs/en/about-claude/models/overview + .../model-ids-and-versions (fetched 2026-06-21).
- The live Claude Code "Switch model?" dialog (captured from the `home` pane 2026-06-21).

## Why each turn already costs more as a conversation grows
The model is stateless: every turn re-sends the ENTIRE transcript as input. So per-turn input
cost scales with conversation length. Prompt caching softens this (the unchanged prefix reads
at 0.1×, see below) but does not stop the growth — a 500k history costs ~5× the per-turn
history cost of a 100k history, at the discounted rate. Output cost per turn is independent of
history length. Levers to reset the growth: `/compact` (shrink), `/clear` (reset), fresh session.

## Prompt-cache cost multipliers (relative to base input)
"Base input" (1.0×) = the model's headline input $/MTok: Haiku $1, Sonnet $3, Opus 4.8 $5.

| Operation | Multiplier | Meaning |
|---|---|---|
| Base input | 1.0× | processed fresh, uncached |
| Cache write (5-min TTL) | 1.25× | first time content is stored |
| Cache write (1-hour TTL) | 2.0× | stored for 1h |
| Cache read (hit) | 0.1× | reusing cached content (90% off) |

- Default TTL 5 min, refreshed each time the cache is used; an idle session past the TTL goes
  cold and re-warms at 1.25× on the next message.
- Output tokens are NOT affected by caching (always full output price; Opus 4.8 output = $25/MTok).
- Minimum cacheable prefix: Fable 512, Opus/Sonnet 1,024, Haiku 4,096 tokens (below → not cached).

## The switch penalty
The prompt cache is effectively per-model. Switching makes the entire history a cache MISS on
the new model: re-read + re-written, so the history that rode at 0.1× now costs ~1.25× that one
turn — a **~12× jump** on the whole prefix, plus full latency. The live dialog states it:
"this conversation is cached for the current model … switching means the full history gets
re-read on your next message."

Worked example (Opus 4.8, 100k history = 0.1 MTok):
- steady-state turn (cache read 0.1×): 0.1 × $0.50 = **$0.05** for the history.
- turn right after a switch (re-read+write ~1.25×): 0.1 × $6.25 = **$0.625**. Scales with length.

Extra switch costs stacked on top:
- **Re-tokenization across the Opus-4.7 boundary:** Opus 4.7+ and Fable/Mythos use a NEW
  tokenizer (~30% more tokens for the same text); Sonnet 4.6 and Haiku 4.5 use the old one. So
  Sonnet/Haiku → Opus 4.8 re-counts the whole history ~30% larger (and fewer going back).
- **Price tier:** the re-read is billed at the new model's rate (Haiku $1 → Sonnet $3 → Opus $5).
- **Capability/context shifts:** context windows differ (Opus 4.8 / Sonnet 4.6 = 1M; Haiku 4.5 =
  200k → switching to Haiku mid-long-thread can overflow). Switching to Haiku (or older models)
  DROPS all prior thinking blocks; Opus 4.5+/Sonnet 4.6+ keep them. Opus 4.8 defaults effort=high.

## The cost of compaction
`/compact` is itself a model call: reads the full current history (input) + generates a summary
(output), then replaces the transcript with the summary.
- Cost ≈ (full history input, mostly 0.1× if cache warm) + (summary output at full output price —
  the expensive side). Worked: Opus 4.8, 200k history warm, ~4k summary → ~$0.10 input + ~$0.10
  output ≈ **$0.20 one-time** (~$1.10 cold).
- Payoff: history drops 200k → ~4k, so per-turn history cost falls ~$0.10 → ~$0.002. Recovers the
  $0.20 in ~2 turns. Strongly net-positive on a session you'll keep using.
- Wasteful only if you (a) compact a thread you then abandon, or (b) compact too often (overhead
  without enough turns to amortize). Sweet spot: compact at task breakpoints.
- Note: Claude Code AUTO-compacts near the context-window limit — that's for capacity, not cost;
  it lets the thread grow large and expensive first. That gap is the opening for a cost feature.

## The right ORDER of operations (the governing principle)
**Shrink BEFORE you switch, never after.** The switch penalty is ~1.25× × (history size on the
new model), so make the history as small as possible at the moment of the switch.

| Intent | Order |
|---|---|
| New model, fresh start (task changed) | **clear → switch** (cheapest; likely NO dialog — see below) |
| New model, keep context, long thread | **compact → switch** (new model re-reads the summary, not the raw history) |
| New model, short context | just **switch** (penalty is small) |
| New model for a bounded subtask | **hand off** (sub-agent on its own model / new session); don't switch the main thread |

**Bonus of clear-first:** the "Switch model?" dialog fires because "this conversation is cached
for the current model." A cleared conversation has nothing cached, so switching after a clear
should raise NO dialog (also sidesteps the model-switch-confirm hang). Inferred from the dialog's
wording; worth an empirical confirm but the logic is sound.

**Anti-patterns:** switch → then clear/compact (pay the full re-read, then discard it); switching
a long cached conversation in place when unnecessary (max penalty + triggers the blocking dialog);
frequent back-and-forth flips (each re-warms the cache, may re-tokenize, and Opus↔Haiku churns
thinking blocks).

## Implications for the features
- `model-switch-confirm`: handle the `/model` "Switch model?" dialog (it blocks input until a
  keypress). See that doc.
- `context-cost-awareness`: surface conversation size/cost (transcript-file proxy) and, when a
  thread is large and the user asks to switch, nudge "clear or compact first to avoid the re-read."
  See that doc. The two features together = "switch models intelligently."
