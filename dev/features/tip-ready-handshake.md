---
feature: tip-ready-handshake
status: IMPLEMENTED in v2.0.8 (complete version - handshake check precedes detect_claude_upgrade)
target_version: 2.0.8 (patch)
severity: Medium (daily tip almost never reaches the user)
related: start-by-name.md, restart-in-place.md
---

# Feature: the daily tip is eaten by the `Ready?` handshake

## Problem (verified 2026-06-17)

The tip-of-the-day almost never reaches the user. Root cause: the daily tip fires on
the **first `UserPromptSubmit` of the day** per session, and after any restart (or
`/compact` reconnect) that first prompt is the **synthetic `Ready?` handshake**
claude-mux sends itself. The sequence:

1. Session restarts → claude-mux sends `Ready?` (via `await_ready_handshake`, the
   looped launch wrapper, or the `on_compact` monitor).
2. `UserPromptSubmit` fires → `on_prompt` (the `--on-prompt` hook) injects
   `[claude-mux tip — share with the user…]: <tip>` into *that* turn **and stamps
   `tip_date = today`** in `~/.claude-mux/tip-state/<session_id>.json`.
3. The ready-response rule forces the model to reply with **exactly two lines**
   ("Session ready!" / "Running <model> in <mode> mode.") and *"Nothing else."* — so
   the injected tip is swallowed.
4. `tip_date` is now today → the real tip is **gated off for the rest of the day**.

Because sessions are restarted often, the tip is almost always consumed by a `Ready?`
turn and suppressed. Same applies to the update-available notice (also injected by
`on_prompt`, also swallowed by the two-line reply, also throttle-stamped).

### Evidence

- Direct hook probe: piping `{"session_id":"X","prompt":"Ready?"}` to
  `claude-mux --on-prompt` emits the tip **and** writes
  `{"tip_date":"2026-06-17",...}`. A following `{"session_id":"X","prompt":"hello"}`
  emits nothing (already gated). Reproduced 2026-06-17.
- `~/.claude-mux/tip-state/` mtimes for today cluster at 00:07-00:08, 10:01, 16:41 —
  exactly the session restart times, not organic user prompts.

This is two correct behaviors colliding (the per-session daily-tip gate vs. the
two-line ready rule), not a misconfiguration. `TIP_OF_DAY=true` is set and the
`--on-prompt` hook is correctly registered.

## Design

The `Ready?` handshake is a **synthetic prompt**, not a real user turn. `on_prompt`
should treat it as a no-op: inject nothing and **stamp no state**, so the first
genuine user prompt after a restart surfaces the tip / update / upgrade notice.

### Detection

The `UserPromptSubmit` hook's stdin JSON carries the prompt text in the `prompt`
field. The handshake string is the literal `Ready?` (sent verbatim by every handshake
site: `await_ready_handshake`, both launch wrappers, the `on_compact` monitor). Detect
it by extending the **existing** single stdin parse in `on_prompt` (today it only
extracts `session_id`) to also read `prompt` and emit an `is_handshake` flag, computed
as `prompt.strip() == "Ready?"`. One stdin read, one subprocess — no new I/O on the
hot path beyond reusing the parse that already runs.

### Change (recommended: complete — also protects the upgrade notice)

Restructure the top of `on_prompt` so the handshake check precedes everything:

```bash
on_prompt() {
    # Read stdin ONCE: session_id + whether this is the synthetic "Ready?" handshake.
    # (python emits: <sid> <is_handshake 0|1> <tip_date> <update_notify> <notify_version>)
    <extend the existing python parse to also extract prompt and print is_handshake>

    # The "Ready?" handshake is not a real user turn (claude-mux sends it after a
    # restart / compact-reconnect). The session's two-line ready reply suppresses any
    # injected text, so a tip / update / upgrade notice here is swallowed AND burns its
    # once-per-day / throttle / once-per-change budget. No-op so the first REAL prompt
    # surfaces them.
    [[ "$_is_handshake" == "1" ]] && exit 0

    # Claude Code upgrade detection (always-on; independent of tip/update config).
    _bin_notice=$(detect_claude_upgrade)

    # Cheap guard: both features off → only the upgrade notice can fire.
    if [[ "${TIP_OF_DAY:-true}" != "true" && "${UPDATE_CHECK:-true}" != "true" ]]; then
        [[ -n "$_bin_notice" ]] && printf '%s\n' "$_bin_notice"
        exit 0
    fi
    # ... rest unchanged, REUSING the already-parsed _sid / _tip_date / _update_notify /
    #     _notify_version (no second stdin read) ...
}
```

Key points:
- `detect_claude_upgrade` now runs *after* the handshake check, so the one-shot upgrade
  notice (which acks itself by overwriting `@claude-mux-claude-id`) is never consumed by
  a `Ready?` turn. (In practice a restart re-captures the id at launch, so the upgrade
  notice rarely fires on a restart-driven `Ready?`; this fully closes the
  compact-reconnect edge too.)
- **Hot-path tradeoff:** the stdin parse now runs on every prompt even when *both*
  `TIP_OF_DAY` and `UPDATE_CHECK` are off (previously the cheap guard short-circuited
  before the parse). Cost: one ~10ms python call per prompt for users who disabled both
  — a small opted-out minority. Accepted for correctness; default config (tips on)
  already runs the parse, so default users see no change.

### Alternative (minimal — preserves the both-off hot path)

Leave `detect_claude_upgrade` and the cheap guard exactly as they are; add the
`is_handshake` flag to the existing parse and, immediately after it, skip the tip +
update branches and stamp nothing when handshake:

```bash
if [[ "$_is_handshake" == "1" ]]; then
    [[ -n "$_bin_notice" ]] && printf '%s\n' "$_bin_notice"   # already computed above
    exit 0
fi
```

This fixes the reported bug (tip + update no longer eaten/stamped on `Ready?`) with a
smaller diff and no hot-path change, but leaves one niche edge: a `/compact`-reconnect
`Ready?` on a session whose `claude` binary changed mid-session would still emit (and
ack) the upgrade notice into the swallowed turn. Pre-existing, very niche, self-limited
to one lost notice. **Recommendation: take the complete version; the hot-path cost is
negligible and the semantics are cleaner ("`Ready?` is not a user turn").**

## Edge cases

| Case | Behavior |
|---|---|
| `Ready?` handshake turn | No tip / update / upgrade injected; no `tip_date` / `update_notify` stamp. Next real prompt gets them. |
| First real prompt after a restart | Tip fires normally (state was not pre-stamped by the handshake). |
| User literally types `Ready?` | Treated as handshake → they forgo a tip that day. Negligible, accepted. |
| `prompt` has trailing whitespace/newline | `strip()` handles it; `"Ready?\n"` still matches. |
| `prompt` missing / malformed JSON | `is_handshake=0` (default) → behaves as a normal prompt (current behavior preserved). |
| Tips already shown earlier today by a real prompt | Unchanged — still once per day per session. |
| Both `TIP_OF_DAY` and `UPDATE_CHECK` off | Complete version: parse runs, handshake still no-ops, upgrade notice deferred off `Ready?`. Minimal version: unchanged hot path. |

## Why low-risk

- Single function (`on_prompt`); no change to handshake senders, restart, or launch.
- The handshake string is a fixed literal (`Ready?`) emitted identically everywhere.
- Falls back to current behavior on any parse failure (`is_handshake=0`).
- No config, no injection-prompt, no display changes. Reference docs only.

## Version

Proposed **2.0.8 (patch)** — a self-contained bug fix, kept separate from 2.0.7
(start-by-name) for a clean changelog. 2.0.7 is committed but **not yet pushed or
released**, so the user *could* fold this into 2.0.7 instead (one fewer release). Decide
before the VERSION bump. Default to 2.0.8.

## Files to update (Change Checklist)

- `claude-mux`: extend the `on_prompt` stdin parse to extract `prompt` + emit
  `is_handshake`; add the handshake no-op guard (recommended: reorder so it precedes
  `detect_claude_upgrade`). `VERSION=` bump.
- `dev/CODEMAP.md`: note `on_prompt` now reads `prompt` and no-ops on the `Ready?`
  handshake.
- `dev/SKELETON.md`: `on_prompt` logic-flow — add the handshake early-exit.
- `dev/IMPLEMENTATION-SPEC.md`: tip/update delivery section — document the
  handshake-suppression behavior.
- `CHANGELOG.md`: Fixed — daily tip / update notice no longer consumed by the `Ready?`
  handshake.
- `docs/ISSUES.md`: move the (to-be-added) "tip eaten by Ready? handshake" entry to
  Resolved.
- No README / translations / config / injection / tips-array changes (behavior of the
  delivery path, not the tip content or any user-facing command).

## Out of scope

- Changing *how* tips are surfaced (still injected for the model to relay).
- The rate-limit-during-restart-all issue (separate ISSUES.md entry).
- Reworking the daily-gate model (per-session, once-per-day) — unchanged.
