---
feature: ready-handshake
kind: feature
lifecycle: shipped
---

# Feature: Ready-handshake during compact/resume (v2.0 self-healing)

Implementable design spec. Lifted from `docs/ISSUES.md` (v2.0 Milestone, "Ready handshake during compact/resume"); assumptions verified before finalizing (see "Verified assumptions"). Test plan: `ready-handshake-tests.md`.

## Goal

Stop the launch/restart poller from sending `Ready?` while a session is still busy. The current poller treats "the `❯` prompt is drawn" as "ready," but on a `claude -c` resume large enough to trigger auto-compaction or a continuation summary, the `❯` is drawn for the *entire* compaction (~50s measured) while Claude is still working. `Ready?` then lands mid-compaction: queued into the wrong turn or interrupting the process. The 10s poller timeout also expires mid-compaction and "sends ready anyway."

## Scope

**In:** a shared `poll_until_ready()` detector (busy signal + prompt + quiescence, ~120s timeout) replacing the prompt-only ready check in both launch pollers (`create_claude_session` synchronous poller; `launch_single_session` backgrounded poller). Keep the existing trust-prompt / bypassPermissions auto-accept, gated to before ready.

**Out (follow-ups):** refactoring the `/compact` RC-reconnect monitor (in the `send` dispatch) to reuse the detector (same bug class, separate path); v2.1 graceful-restart warn-and-flush (will reuse this detector); the parked `starting` `-l` badge; **parallel restart** — `create_claude_session` is synchronous, so `--restart` (all) and `autorestore_walk` block up to the timeout per session sequentially; if many sessions simultaneously resume-compact, restart-all could block for minutes. Acceptable for v2.0 (common case returns in ~2s; only heavy resume-compaction is slow), but firing session creations in background subshells would remove the worst case. Tracked, not built.

## Detector

```
busy(session)  ⇔  the bottom ~4 lines of capture-pane contain "esc to interrupt"
ready(session) ⇔  NOT busy
              AND a prompt is at line start (^❯ or "^> ")
              AND quiescent: two captures ≥1.1s apart are identical after trailing-whitespace normalize
otherwise → keep polling
timeout: ~120s (measured compaction ~50s; leave headroom)
```

- **`esc to interrupt`** is the single reliable busy discriminator: present for the whole of a normal turn AND a real compaction, gone the instant the session is idle (idle shows `· ← for agents` / shortcut hints in the same slot). Scope the scan to the bottom ~4 lines so the words can't false-match transcript body.
- **Quiescence** is the version-proof backstop: while working, the status line animates (glyph `✳✻✽·◐` + `Ns` timer + token counter), so a moving screen reads as not-ready even if the string check is ever defeated. The ≥1.1s gap avoids sampling the same elapsed-second twice. Implemented as a confirming second capture (`sleep 1.2`) once the pane looks idle+at-prompt; re-check busy didn't reappear in the second snapshot.
- **No body-text grep.** `Compacting…`/`Summarizing…` do not exist in Claude Code v2.1.149; do not key on verb strings or a glyph denylist. They are optional fast-path only.

## `poll_until_ready(session, [timeout=120])`

```
start = now
loop:
    now = epoch; if now - start >= timeout: return 1        # timeout
    sleep 0.5
    pane = capture-pane(session)  (continue on failure)
    if pane has "Yes, I trust this folder":  send Enter; sleep 2; continue   # pre-ready auto-accept
    if pane has /yes.*accept/i:               send Down; sleep 1; send Enter; sleep 2; continue
    if bottom-4(pane) has "esc to interrupt": continue       # busy
    if pane lacks ^❯ / "^> ":                 continue       # no prompt yet
    snap1 = trailing-ws-normalize(pane)
    sleep 1.2
    snap2 = trailing-ws-normalize(capture-pane(session))
    if bottom-4(snap2) has "esc to interrupt": continue      # became busy again
    if snap1 == snap2: return 0                              # ready (quiescent)
    # else not yet quiescent → keep polling
```

Caller then sends `Ready?` regardless of return (ready, or timeout = send-anyway fallback, preserving today's behavior that a slow session still eventually gets the handshake) — but after a *real* readiness wait, not a 10s guess.

## Wiring

- `create_claude_session` (synchronous poller, ~claude-mux:2669-2706): replace the `_poll<20` loop with `poll_until_ready "$session_name"`, then the existing `send Ready?`. Trust/bypass auto-accept moves into `poll_until_ready`.
- `launch_single_session` (backgrounded poller in the `( … ) &`): same replacement. Already async, so the longer timeout never blocks attach.
- Keep `Ready?` send + the protect-marker step unchanged.

## Verified assumptions (pre-build)

1. **`esc to interrupt` busy signal** — RE-VERIFIED live 2026-06-08 (Claude Code v2.1.149): a mid-turn session shows `⏵⏵ auto mode on (shift+tab to cycle) · esc to interrupt` with `❯` drawn above; an idle session shows `· ← for agents` and no "esc to interrupt". A multi-session scan flagged only the busy one. (Original capture-pane experiment 2026-06-06: signal present for the full ~50s of a real compaction; `❯` drawn throughout; no `Compacting…` text; glyphs `✳✻✽·◐`, not Braille; 10s timeout is the live misfire.)
2. **Quiescence is safe when idle** — an idle pane has no animating element (status line shows static hints), so two captures ≥1.1s apart match; during work the timer/glyph animate, so they differ.

## Change-checklist impact (when built)

- New helper `poll_until_ready()` (shared by both launch pollers).
- Modified: `create_claude_session`, `launch_single_session` (poller bodies) → CODEMAP/SKELETON.
- Behavior change: launch/restart `Ready?` can now take up to ~120s on a heavy resume-compaction (instead of misfiring at 10s); the common case is unchanged (ready in 1-3s). Note in CHANGELOG.
- No new config (timeout is an internal constant; could be promoted later), no marker, injection unchanged.
- Follow-up noted: `/compact` monitor reuse; v2.1 warn-and-flush reuse.
