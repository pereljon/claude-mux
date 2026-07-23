---
kind: investigation
feature: session-activity-timestamps
status: test plan for session-activity-timestamps.md
---

# Test plan: session-activity-timestamps

Companion to `session-activity-timestamps.md`. Verifies timestamp writing, event mapping,
listing sort/display, and safe fallbacks.

## Pre-build verification (do FIRST, before finalizing the design)

1. **SessionStart `source` tokens.** Register a throwaway SessionStart hook that logs the
   stdin JSON. Confirm the `source` value for: fresh launch, resume, `/clear`, `/compact`.
   Expected `startup` / `resume` / `clear` / `compact`. If `/clear` is not `clear`, adjust
   the `conversation_started` reset condition.
2. **`/clear` really does not hit `UserPromptSubmit`.** Confirm `on_prompt` does NOT fire on
   `/clear` (justifies needing SessionStart). Log a marker in `on_prompt` and run `/clear`.
3. **`on_prompt` fires on `-s`-sent commands too** (so `last_activity` covers programmatic
   sends), and fires with the `Ready?` handshake (so the post-handshake placement matters).

## Happy path

1. **Create → file exists.** New session: `.claudemux-activity.json` has `created` and
   `conversation_started` ≈ now; no `last_*`.
2. **Real prompt → `last_activity`.** Send a user prompt; `last_activity` updates. Sibling
   fields (`created`, `conversation_started`) unchanged.
3. **`-s` command → `last_activity`.** `claude-mux -s SESSION '/model sonnet'` bumps
   `last_activity`.
4. **Compact → `last_compact`.** `/compact`; `last_compact` updates, `conversation_started`
   unchanged.
5. **`/clear` → `conversation_started` resets.** `conversation_started` jumps to now;
   `created` unchanged; `last_activity` unchanged by the clear itself.
6. **Restart (resume) → `last_restart`, conversation preserved.** `last_restart` updates;
   `conversation_started` unchanged (same conversation resumed).
7. **Clean shutdown → `stopped_at`.** `--shutdown SESSION` sets `stopped_at`. Next launch
   updates/clears it.

## The handshake guard (critical)

8. **Restart does not bump `last_activity`.** Record `last_activity`, restart the session
   (fires the `Ready?` handshake), confirm `last_activity` is **unchanged** by the handshake.
   Only a subsequent real prompt bumps it.
9. **`last_activity` written even when tips/updates are off.** Set `TIP_OF_DAY=false` and
   `UPDATE_CHECK=false`; a real prompt still updates `last_activity` (write precedes the
   both-off early-exit).

## Listing: sort + display

10. **Sort by recency.** Three sessions used at different times; `-l` orders most-recent
    first (per `LIST_SORT` default). Idle projects sort in by `last_activity`/`created`.
11. **Relative-age display.** Rows show `used 2h ago` / `idle 4d` / `just now`. Verify
    `fmt_relative_age` boundaries: <60s → "just now"; minutes; hours; days.
12. **All rows still verbatim.** With the `<assistant-must-display>` non-TTY path, every row
    is emitted (sort must not drop/collapse rows). Row-count footer matches.
13. **Staleness marker.** A session with old `conversation_started` and old/absent
    `last_compact` shows the `⚠ stale` marker; a fresh one does not. Thresholds respected.

## Fallbacks / edge cases (must never error)

14. **Missing file.** Delete `.claudemux-activity.json`; `-l`/`-L` still work, row sorts to
    bottom, no age shown, no crash.
15. **Corrupt JSON.** Write garbage into the file; reads treat it as all-unknown, listing
    works, next write repairs (or overwrites) it.
16. **Pre-feature project.** A project that never had the file: appears in listings, sorts
    last, gains the file on first write. No backfill required for correctness.
17. **Concurrent writers.** Trigger `on_prompt` and `on_compact` near-simultaneously;
    confirm neither clobbers the other's field (read-modify-write per field).
18. **gitignore.** In a git project, `.claudemux-activity.json` is auto-added to
    `.gitignore` (covered by `.claudemux-*`); it is not tracked.

## Hook registration

19. **Fresh install registers SessionStart.** New project via `-n` has the SessionStart hook
    in `.claude/settings.json`.
20. **`--install-hooks` backfills SessionStart.** A project missing it gains the SessionStart
    hook after `--install-hooks`; existing UserPromptSubmit/PreCompact hooks untouched.
21. **Settings-restore idempotent.** Running the ensure-hooks path twice does not duplicate
    the SessionStart entry.

## Post-build checks

- `make build && make check` clean (artifact rebuilt, codemap + features-index fresh).
- `bash ./claude-mux -l` / `-L` render sort + age without error on the repo copy.
- Smoke: create a throwaway session, exercise prompt/compact/clear/restart/shutdown, inspect
  the JSON after each.
- Confirm `home` and protected sessions behave normally (no auto-action — auto-unload is out
  of scope this release).
