---
feature: session-target-disambiguation
---

# Test Plan: Don't silently default an unresolved session NAME to the current session

Test plan for `session-target-disambiguation.md`. These are mostly **behavioral** tests of the injected trigger rules - they exercise how Claude routes a phrase, not a code path with a deterministic exit code. Run them by issuing the phrase to a live session (ideally over RC, since RC is where the incident occurred) and observing the command Claude runs (via `claude-mux.log`) plus whether it asks vs acts.

A session must be **restarted** to pick up the reworded injection before any of these tests are meaningful (prompt is baked at launch).

## Pre-build verification

### V0.1 Confirm the silent-fallback wording exists (current state)
```bash
sed -n '1524,1539p' claude-mux   # expect "(or current session if none given)" etc.
```

### V0.2 Confirm single injection source
```bash
grep -n 'build_system_prompt' claude-mux   # expect def ~1459, callers ~2931 and ~3274 only
```

### V0.3 Confirm the CLI backstop
```bash
# Unknown name must error, not act:
claude-mux --restart definitely-not-a-session 2>&1   # expect "not a claude-mux managed session"
```

### V0.4 Reproduce the incident on current injection (optional)
From `home` (over RC), say "restart claudemux session". Expect (the bug): `=== claude-mux restart: home ===` in the log (home restarts itself), no `restart: claude-mux`. Confirmed 2026-06-16.

## Behavioral tests (post-fix, after restarting the test session)

Setup for the group: at least 3 managed sessions with distinct names, e.g. `home` (caller), `claude-mux`, `datetime-hook`. Issue each phrase from `home`.

### T1.1 Exact named match acts directly
- Say: "restart session claude-mux" (or "restart the claude-mux session").
- Expect: Claude runs `claude-mux -l` (confirm), finds exact match, runs `claude-mux --restart claude-mux`. Log shows `=== claude-mux restart: claude-mux ===`. Home is NOT restarted.

### T1.2 The incident phrasing now asks instead of self-restarting
- Say: "restart claudemux session" (no hyphen, the original failure phrase).
- Expect: Claude does NOT run `--restart home`. It lists, sees no exact `claudemux`, and ASKS which session (surfacing `claude-mux` as the close match). No restart happens until the user confirms. Log shows NO `restart: home`.

### T1.3 Explicit "this session" still self-targets without a lookup
- Say: "restart this session".
- Expect: Claude restarts the current session (`--restart <current>`), no clarifying question. (Self-restart-by-name caveat is tracked separately; behavior here is unchanged from today.)

### T1.4 Unknown name asks, never defaults
- Say: "restart the backend session" (no `backend` session exists).
- Expect: Claude asks which session / reports no match. Never restarts the current session.

### T1.5 Ambiguous / partial name asks with candidates
- Setup: sessions `api-staging` and `api-prod`.
- Say: "restart the api session".
- Expect: Claude lists both candidates and asks which; does not pick one silently, does not default to current.

### T1.6 Number reference still works (regression)
- Say: "restart 2" (where row 2 is `claude-mux` in the latest `-l`).
- Expect: resolves via the list to `claude-mux`, restarts it. (Number refs were already list-resolved; confirm no regression.)

## Sibling-command coverage (same governing rule)

### T2.1 stop session NAME — unknown name asks
- Say: "stop the foo session" (no `foo`).
- Expect: asks; does NOT stop the current session. (This is the highest-stakes regression to prevent: silently stopping the caller.)

### T2.2 clear session NAME — unknown name asks
- Say: "clear the foo session".
- Expect: asks; does not clear the current session.

### T2.3 compact session NAME — exact match acts
- Say: "compact session datetime-hook".
- Expect: `claude-mux -s datetime-hook /compact`. Current session not compacted.

### T2.4 switch model for a named session — unknown asks
- Say: "switch the foo session to sonnet model".
- Expect: asks; does not switch the current session's model.

### T2.5 protect/hide a named project — exact vs unknown
- "protect session claude-mux" → acts on claude-mux. "protect the foo session" → asks. Current session never silently targeted.

## Side effects / regressions

### T3.1 "restart all sessions" unchanged
- Say: "restart all sessions". Expect the restart-all path (`=== claude-mux restart starting ===`), unaffected by the NAME-resolution rule (no NAME to resolve).

### T3.2 Non-English phrasing still routes
- Say the restart-named intent in another language (rules are language-agnostic, claude-mux:1551). Expect the same resolve-or-ask behavior.

### T3.3 RC vs pane parity
- Run T1.1 and T1.2 both over RC and by typing in a pane. Behavior should be identical (the fix is in the injected text, not the transport).

### T3.4 CLI still backstops a slipped-through name
- If, despite the rule, Claude passes an unknown name, `claude-mux --restart <unknown>` must still error (V0.3). Confirms defense-in-depth intact.

## Verification commands

```bash
# Watch which command Claude actually runs after a phrase:
grep -E 'restart: |restart starting|restart complete|shutdown starting|-s .* /(compact|clear)' ~/Library/Logs/claude-mux.log | tail -20

# Confirm home was NOT self-restarted by an ambiguous phrase (the incident signature):
grep -E '=== claude-mux restart: home ===' ~/Library/Logs/claude-mux.log | tail -5   # expect none after the fix for ambiguous phrasing
```

## Acceptance

- Ambiguous/unknown named targets ALWAYS ask; never act on the current session (T1.2, T1.4, T1.5, T2.1, T2.2, T2.4).
- Exact named matches act directly (T1.1, T2.3, T2.5).
- "this session" still self-targets (T1.3); "all sessions" unchanged (T3.1).
- No regression to number refs (T1.6) or the CLI backstop (T3.4).
