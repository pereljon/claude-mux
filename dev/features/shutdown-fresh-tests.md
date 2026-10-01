---
kind: investigation
feature: shutdown-fresh-tests
status: test plan for shutdown-fresh (draft, awaiting user review)
related: shutdown-fresh.md
---

# Test Plan: shutdown-fresh

Use a throwaway project (`-n ~/Claude/development/zz-test -p`), delete it after.

## Pre-build checks

- [ ] `make build` and `make check` clean; `bash -n` on all `src/*.sh`.
- [ ] Resume-after-clear verified (done 2026-09-30): clear + shutdown + start resumes the post-clear transcript.

## Happy path

1. Idle session with some conversation: `--shutdown S --fresh`. Session ends; `.claudemux-running` removed.
2. `--start S`: transcript resumed is the post-clear one; the session has no memory of the earlier conversation; handshake reply appears.
3. Plain `--shutdown S` then `--start S` (control): earlier conversation is resumed.

## Edge cases

4. **Busy session** (mid-turn): `/clear` is not accepted; expected: interrupt then clear, or timeout and fall back to plain shutdown with a visible WARN (never a silent "fresh" that isn't).
5. **Already stopped session**: `--shutdown S --fresh` is a no-op with a clear message; no stray `/clear` sent.
6. **Handshake race**: `/exit` is not sent until the post-clear handshake reply completes; transcript has the `Ready?` turn.
7. **Protected session**: refused without `--force`; with `--force`, works.
8. **Caller (self)**: behavior per design (refuse and point to "end this session"); the script is not SIGHUPed mid-run.
9. **No-arg `--shutdown --fresh`**: all non-protected sessions cleared and stopped; the caller handled per case 8; protected skipped.
10. **Multiple names**: `--shutdown A B --fresh` handles both; one failing does not strand the other.
11. **`--on-clear` hook missing** (settings lacking SessionStart): detected or documented; confirm what resumes.

## Flag validation

12. `--fresh` still valid with `--start`, `--restart`, `-d`; now valid with `--shutdown`; still rejected elsewhere with the existing error.
13. `--commands` / `commands_help()` list the new form.

## Conversational

14. Injection: "kill SESSION" runs `--shutdown SESSION --fresh`; "stop SESSION" runs plain `--shutdown`; "end this session" unchanged. Check both launch paths (`create_claude_session`, `launch_single_session`) carry identical text, and README matches.

15. **Confirmation**: "kill X", "end this session", "restart X fresh", "restart this session fresh", "clear this session", "clear session X" each produce a one-line statement of the effect and wait for yes/no before any command runs; "no" runs nothing.
16. **No confirmation** for plain stop, restart (resume), compact, status.
17. Confirmation text is identical in both injection paths and the README.

## Post-build

- [ ] `make codemap`, `make features-index`, `make check` clean on the branch and again on `main` after merge.
- [ ] Throwaway project deleted.
