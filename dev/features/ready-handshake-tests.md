# Test plan: Ready-handshake during compact/resume

Companion to `ready-handshake.md`. Manual + shell-assertion procedures.

## 0. Pre-build verification (DONE)

| # | Check | Result |
|---|---|---|
| 1 | `esc to interrupt` distinguishes busy vs idle | RE-VERIFIED 2026-06-08 (v2.1.149): busy pane shows `· esc to interrupt`; idle shows `· ← for agents`; multi-session scan flagged only the mid-turn session |
| 2 | `❯` is drawn during compaction (prompt-only check is wrong) | DONE 2026-06-06: `❯` present for the full ~50s compaction |
| 3 | No `Compacting…`/`Summarizing…` body text; glyphs `✳✻✽·◐` | DONE 2026-06-06 |
| 4 | Idle pane is static (quiescence holds) | DONE: idle status line has no animating element |

## 1. `poll_until_ready()` (unit, stubbed capture-pane)

- **T1.1** Bottom-4 contains `esc to interrupt` → treated busy, keeps polling (never returns ready).
- **T1.2** `esc to interrupt` only in transcript body (lines above bottom-4) → NOT treated busy (scan is scoped).
- **T1.3** Prompt present, not busy, two identical captures ≥1.1s apart → returns 0 (ready).
- **T1.4** Prompt present, not busy, but captures differ (animation/edit) → keeps polling, not ready.
- **T1.5** Becomes busy again in the confirming second capture → keeps polling (no false ready).
- **T1.6** Never reaches ready → returns 1 at ~timeout; caller still sends `Ready?` (fallback preserved).
- **T1.7** Trust prompt (`Yes, I trust this folder`) → Enter, continues (not counted as ready).
- **T1.8** bypassPermissions warning (`yes.*accept`) → Down, Enter, continues; ready only confirmed afterward.
- **T1.9** capture-pane failure on an iteration → continue, no crash.

## 2. Launch integration

- **T2.1** Fresh `-n` session: comes up, `poll_until_ready` returns ready in 1-3s, `Ready?` sent once, "Session ready!" reply.
- **T2.2** `--restart` of a small session: ready fast, no misfire.
- **T2.3** `--restart` of a **large** session that auto-compacts on resume: `Ready?` is NOT sent until compaction finishes (~50s), then sent once. (The core fix — reproduce the old misfire on the pre-change binary, confirm fixed on the new one.)
- **T2.4** `launch_single_session` (home / `-d`): backgrounded poller uses the detector; attach is not blocked by the longer timeout.
- **T2.5** bypassPermissions launch: trust + accept auto-handled before ready; `Ready?` only after.
- **T2.6** Timeout path: a session that never quiesces within ~120s still gets a `Ready?` (no permanent hang).

## 3. Interaction / regression

- **E3.1** Restart-all: normal sessions still restart at roughly prior speed (ready detected quickly); only compacting ones wait longer (correct).
- **E3.2** autorestore_walk relaunch (uses `create_claude_session`): a restored session that compacts on resume waits for ready; tick still one-shot; staggering unaffected.
- **E3.3** No `Ready?` is sent twice; the protect-marker / `@claude-mux-*` option steps still run after.
- **E3.4** `bash -n claude-mux` clean; deploy to `~/bin`; smoke `-d`, `--restart`, home autolaunch.

## 4. Robustness

- **R4.1** If `esc to interrupt` ever changes wording (future Claude Code), quiescence still prevents a mid-work false-ready (animation defeats the match) — verify by stubbing the string absent but the pane animating.
- **R4.2** Scope check: a transcript that literally contains "esc to interrupt" in body text does not wedge the poller (T1.2).

## Notes

- The ~120s timeout and 1.2s quiescence gap are first values; record real compaction durations seen in T2.3 and tune if needed.
- T2.3 (large-session resume compaction) is the one test that proves the feature; run it manually at least once before declaring done.
