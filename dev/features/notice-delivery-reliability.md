---
kind: feature
lifecycle: shipped
feature: notice-delivery-reliability
status: IMPLEMENTED 2026-06-19 (v2.0.10; persist-while-relevant for update+upgrade notices, <assistant-must-display> wrapping + standing surface rule, in-place-restart id re-capture in await_ready_handshake). Upstream RC-delivery ask still open (Part D).
target_version: 2.0.10 (patch; the actionable-notice fix is a real bug fix) + an upstream Claude Code feature request
severity: HIGH for the actionable notices (claude-mux update available, Claude binary upgraded) — they can be silently lost for 7 days / until next upgrade. LOW for the daily tip.
related: tip-ready-handshake (v2.0.8 handshake fix), inter-agent-messaging (same relay-dependence)
---

# Feature: reliable delivery of claude-mux notices (tip / update / upgrade)

## Problem (with live evidence, 2026-06-19)

The three notices claude-mux injects via the `UserPromptSubmit` hook (`on_prompt`,
`src/75-tip-notices.sh`) are **unreliably delivered to the user** — and worse, they
**consume their gate on injection, not on the user actually seeing them**, so a single
miss loses the notice for its whole window.

**Evidence.** The user worked in several sessions on the morning of 2026-06-19 and saw
no tip; one came through later in a different session. The `~/.claude-mux/tip-state/`
files show **three** session-state files stamped `tip_date: 2026-06-19` (08:11, 10:11,
10:12) — the gate fired (and, per the code, a tip was *emitted* into the context) in all
three, including the two morning sessions where the user saw nothing. So the trigger
worked; the **delivery** failed: the receiving session's Claude didn't relay the injected
one-liner, and the gate stamped the day anyway → no retry.

## Root cause — two stacked flaws

1. **The channel is relay-dependent.** The `UserPromptSubmit` hook can only inject
   **context into the conversation**; it cannot render anything to the user's screen. The
   user sees a notice only if *that session's Claude chooses to relay it*. There is no
   guaranteed hook→user path. (`src/75:98` already documents the hook as "the only
   delivery path proven to surface in Remote Control.")
2. **The gate is spent on injection, not on confirmed delivery.** Each notice stamps its
   gate the moment the hook emits (coupled in code: the stamp is set only inside the
   emit branch, then persisted). A single non-relay permanently burns the notice:
   - **Tip** — `tip_date` per `session_id`: missed → lost for the day.
   - **claude-mux update available** — `update_notify` (7-day) + `notify_version`:
     missed → **lost for 7 days**.
   - **Claude binary upgraded** (`detect_claude_upgrade`) — acks by overwriting
     `@claude-mux-claude-id`: missed → **lost until the next upgrade** (you keep running a
     stale-injection session, unaware).

## The Remote-Control constraint (decisive)

The user works **mostly in Remote Control.** RC is **Claude Code's own `--remote-control`
feature**, not a claude-mux bridge (claude-mux just launches `claude --remote-control`).
Consequences (verified `src/30:705`, `src/75:98`):
- **RC renders the conversation only.** tmux UI — status line, `display-popup`, bell — is
  terminal chrome **RC never shows.** So any tmux-native notice channel is invisible to
  the primary user. (`src/30:705`: RC users "cannot see tool output.")
- **The on-prompt hook injection is the *only* channel that reaches an RC user**, and
  it's relay-dependent. There is no fallback.

So the fix must live entirely in the conversation channel.

## Current injection strings (the weak point)

```
tip      (src/75:173): [claude-mux tip — share with the user, in their conversation language]: <tip>
update   (src/75:193): [claude-mux update available — tell the user, in their conversation language]: version X is out (current: Y). Suggest they say "update claude-mux".
upgrade  (src/75:91):  [claude-mux — tell the user, in their conversation language]: Claude Code was upgraded since this session started; say "restart this session" to load the new binary.
```

These are **soft inline pleas** ("share with the user" / "tell the user") with **no
standing rule** in the session system prompt backing them. They're a bracketed aside
competing with the user's actual request, so Claude often doesn't surface them.

**The repo already has a stronger, RC-proven mechanism it isn't using here.**
`build_system_prompt` (`src/30-helpers.sh:1480`) injects a hard standing rule for listing
output: *"When command output contains `<assistant-must-display>` tags, output every
single line between the tags verbatim … This is critical for mobile/Remote Control users
who cannot see tool output."* The notices should ride that same mechanism.

## Fix

### Part A — Strengthen relay (all three notices)

1. **Add a standing notice-surfacing rule to `build_system_prompt`** (the injection):
   *"claude-mux may inject `[claude-mux …]` notices into your turn context. Always surface
   them to the user verbatim at the start of your reply, before answering."* Makes relaying
   a baked-in behavior instead of a per-notice plea. (Mirror this in the README "Session
   System Prompt" section.)
2. **Wrap the notices in `<assistant-must-display>`** and **broaden that standing rule**
   from "command output" to also cover hook-injected context (it's currently framed for
   tool output; the hook isn't tool output). **Honest scoping (architect HIGH):** the
   `<assistant-must-display>` rule's force is *proven* for tool/command output, NOT for
   `UserPromptSubmit`-injected context (a different surface — system context on the user's
   turn). So this **reuses the tag convention; relay for injected context is not
   independently proven and remains best-effort** — do NOT claim parity with the
   listing-output guarantee. Part D (upstream) is the only path to a real guarantee. The
   test plan adds a live RC check that a wrapped injected notice is actually surfaced.
3. **Firmer inline wording** — "MUST relay verbatim at the start of your reply," not
   "share with the user."

Honest limit: strengthening **raises the odds** (materially, via #2) but is **not a hard
guarantee** — Claude can deviate. So pair it with Part B for the actionable notices.

### Part B — persist-while-relevant (the two ACTIONABLE notices)

Replace "emit once + stamp the gate" with **re-inject every prompt while the underlying
condition holds**, and let Claude de-dup within its own conversation:
- **Update available:** re-inject while `version_gt "$latest" "$VERSION"`. The condition
  self-clears when the user updates (VERSION rises). Drop the `update_notify`/7-day stamp.
- **Binary upgraded:** re-inject while the live binary id differs from `@claude-mux-claude-id`.
  Self-clears on restart (which re-captures the id). Drop the ack-on-emit.
  - **CRITICAL pre-req (architect, 2026-06-19) — in-place restart must re-capture the id.**
    Dropping the ack-on-emit makes self-clear depend *entirely* on a restart re-capturing
    `@claude-mux-claude-id`. But that option is captured only on the **kill+recreate** path
    (`src/55:74,93`, `src/70:96,243`); the **in-place caller restart** (the documented
    default for "restart this session" and restart-all-from-home — the wrapper loop's
    relaunch branch, `src/55:191-202` + `src/70`'s equivalent) regenerates the prompt and
    `continue`s but **never re-runs `claude_binary_id` / re-sets the option**. Today this is
    masked because `detect_claude_upgrade` acks-on-emit; once Part B drops that ack, an
    in-place restart-to-load-the-new-binary leaves the stale stored id → the upgrade notice
    **re-injects every turn, forever** (the exact fail-to-clear failure mode, on the most
    common restart path). **Fix is part of this build:** add
    `set-option @claude-mux-claude-id "$(claude_binary_id)"` inside both in-place relaunch
    branches (`src/55` ~L200 and `src/70`'s equivalent, alongside the `--await-ready &` /
    `continue`), so the in-place path re-captures the baseline like kill+recreate does.
- **De-dup instruction (avoids spam):** *"mention this once; do not repeat if you've
  already told the user this session; it clears when they act."* Claude's own conversation
  memory provides the de-dup.
- **Compaction caveat (architect HIGH — disposition chosen, accepted as a known minor):**
  the de-dup relies on Claude's conversation memory, which `/compact` wipes. So:
  - **Restart** → new session, the notice re-announces once = **correct** (a fresh session
    legitimately re-surfaces a still-pending update).
  - **`/compact` within the same session** → the user already saw it, but the de-dup memory
    is gone, so it re-announces once. This is a **bounded, low-frequency, self-clearing
    re-announce** (one extra mention per compaction of a still-pending actionable notice),
    **not** an unbounded nag — accepted as a known minor for a single-user/low-stakes tool.
    (Rejected alternative: a persisted `announced_version=X` de-dup hint that survives
    compaction and re-arms only on restart or a changed condition value — reintroduces a
    stamp, not worth it here; revisit only if the compact re-announce proves annoying.)
  - **Upgrade-notice corollary (architect MEDIUM, 2026-06-19):** the upgrade notice clears
    on the action (restart), and restart is what wipes conversation memory — so a
    restart-to-fix legitimately re-announces once on the new session (correct). The only
    extra-mention path is a user who `/compact`s repeatedly while ignoring the upgrade
    notice instead of restarting: each compact re-announces once. Still bounded per-compact
    and self-clearing on the action; disposition stands.

Result: a missed relay just retries next turn → the actionable alert can't be silently
lost; it persists until the user acts; no burn-on-inject gate at all. Mild repetition
until action is *correct* for an actionable alert.

**Ordering + budget (architect MEDIUM):**
- **The live-condition check MUST run *after* the `Ready?` handshake guard** (`on_prompt`
  exits at `_is_handshake == 1` before any notice work; `detect_claude_upgrade` likewise).
  Persist-while-relevant must never fire on the synthetic handshake turn.
- **Per-turn injection footprint is bounded** — at most two one-liners, and only while a
  notice is pending. Before, the actionable notice rode the context ≤ once per 7 days; now
  it rides every pending turn. Negligible for two short lines, but stated so a future
  reviewer doesn't treat per-turn injection as free (the CLAUDE.md note that handshake-turn
  injection is "consumed without being seen + burns budget" is why the handshake guard
  ordering above matters).

### Part C — the daily tip (best-effort)

The tip has **no resolution condition** (it's FYI) and **no relay signal**, so there's no
clean "persist until done." It keeps the once-per-day gate but benefits from Part A's
strengthening. Optionally re-inject for the first few turns of the day to raise the odds
(accepting possible duplication if Claude relays more than once). Low stakes — deprioritize
vs the actionable notices.

### Part D — the real fix is upstream (file it)

Guaranteed delivery to an RC user is **impossible from claude-mux alone**: it can only
inject context that depends on Claude relaying it, and it does not own RC's transport
(Claude Code does). True determinism needs an **upstream Claude Code feature**: a hook (or
RC) channel that renders text **directly to the remote user**, bypassing the model. File
this as a feature request; it is the only path to deterministic notice delivery.

## Files to update (Change Checklist)

- **Source (`src/`, then `make build` + `make check`):**
  - `src/30-helpers.sh` `build_system_prompt` — add the standing notice-surfacing rule;
    broaden the `<assistant-must-display>` rule to cover hook-injected notices.
  - `src/75-tip-notices.sh` `on_prompt` + `detect_claude_upgrade` — wrap notices in
    `<assistant-must-display>` + firmer wording; convert update + upgrade to
    persist-while-relevant: drop `update_notify`/`notify_version` stamping; for the upgrade
    notice **drop ONLY the ack-on-emit overwrite of `@claude-mux-claude-id`** — **KEEP the
    launch-time and restart-time capture** of that option (it is the detection *baseline*;
    without it `detect_claude_upgrade` has nothing to compare against). Gate both on the
    live condition instead; add the de-dup instruction to the notice text.
  - **`src/55-session-launch.sh` + `src/70-start-launch.sh` — in-place relaunch branches
    (CRITICAL, architect):** add `set-option @claude-mux-claude-id "$(claude_binary_id)"`
    inside each wrapper loop's in-place relaunch branch (`src/55:191-202`, `src/70`'s
    equivalent), so an in-place restart re-captures the baseline like kill+recreate already
    does (`src/55:74,93`, `src/70:96,243`). Without this the upgrade notice never
    self-clears on the default restart path once the ack-on-emit is dropped (see Part B).
  - **`src/75-tip-notices.sh` — prune dead state (LOW, architect):** after dropping the
    update stamp, `notify_version`/`update_notify` lose their only writers. Prune the
    persist block + the python state read down to just `tip_date` (or leave intact
    deliberately and note why), so the fields don't linger as dead state.
- **Session System Prompt section in README** must match the new injection rule.
- `dev/CODEMAP.md` / `dev/SKELETON.md` — note the on_prompt notice flow change (persist
  vs stamp); `dev/IMPLEMENTATION-SPEC.md` — the notice-delivery model + RC limitation.
- `CLAUDE.md` non-obvious-behaviors — update the handshake/notice notes to reflect
  persist-while-relevant for actionable notices.
- `CHANGELOG.md` `### Fixed` — actionable notices no longer silently lost.
- `docs/ISSUES.md` — record the bug + the upstream RC ask.
- `config.example` — only if a new toggle is added (none planned).

## Test plan → `notice-delivery-reliability-tests.md`

## Out of scope
- Solving deterministic RC delivery in claude-mux (impossible without upstream support —
  Part D).
- Reworking the tip into an actionable/persisted notice (it has no resolution condition).
