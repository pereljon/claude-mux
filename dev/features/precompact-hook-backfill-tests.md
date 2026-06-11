# Test plan: PreCompact hook backfill

Companion to `precompact-hook-backfill.md`. claude-mux is a bash tool tested manually + with shell/JSON assertions; "tests" here are concrete procedures, not a framework.

## 0. Pre-build verification (do FIRST — gates the design framing)

| # | Check | How | Why it matters |
|---|---|---|---|
| T0.1 | Does Claude Code read `PreCompact` live (per `/compact`) or snapshot at session start? | Take a running session whose `settings.local.json` lacks `PreCompact`; run `--install-hooks` (writes the hook); trigger `/compact` in that session; observe whether RC reconnects WITHOUT a restart. | Determines user-facing message: instant fix for running sessions vs fixed-at-next-start. Either way ship; only wording changes. |
| T0.2 | `update_all_project_hooks()` enumerates the full set | Add a temp project under BASE_DIR + a hidden one (`.claudemux-ignore`); confirm both appear in the walk (via log lines). | Confirms backfill reaches hidden projects too. |
| T0.3 | `setup_claude_mux_permissions` pre-check truly flags a missing PreCompact | Hand-edit a settings file to remove only the PreCompact block; confirm the function detects it as needing update. | Confirms idempotent re-add works. |

## 1. Idempotency + merge safety (the critical correctness checks)

- **T1.1** Project already current (has PreCompact + on-prompt) → `--install-hooks` reports "already current," settings file byte-identical after (no churn, no reformatting that breaks user edits). Diff before/after = empty.
- **T1.2** Project missing only PreCompact → after `--install-hooks`, PreCompact block added; UserPromptSubmit + permissions + any user-added settings untouched.
- **T1.3** Project missing the whole `hooks` key → backfill creates `hooks.PreCompact` (and on-prompt if tips/update enabled) without clobbering `permissions`.
- **T1.4** Project with unrelated user hooks (e.g. a custom `PostToolUse`) → those survive; only claude-mux hooks added.
- **T1.5** Malformed/invalid JSON settings file → function fails gracefully (logs error, skips that project), does NOT crash the whole walk or write garbage. Other projects still processed.
- **T1.6** Run `--install-hooks` twice in a row → second run reports all "already current"; no duplicate PreCompact entries appended.
- **T1.7** Home project (`BASE_DIR`) → gets PreCompact AND the home-only rules (`Read/Edit/Write(~/.claude-mux/**)`, `additionalDirectories`) preserved/added correctly (is_home=true path).

## 2. `--install-hooks` command surface

- **T2.1** `claude-mux --install-hooks` → prints `Scanned N projects: M patched, K already current.`; exit 0.
- **T2.2** Counts are accurate: seed exactly 2 hook-less projects among current ones → reports `M=2`.
- **T2.3** `--dry-run --install-hooks` → reports what WOULD change, writes nothing (verify settings files unchanged on disk).
- **T2.4** Non-TTY (piped) output is clean (no TTY-only formatting); safe for the injection to display.
- **T2.5** No projects / empty BASE_DIR → graceful "Scanned 0 projects" (no error).

## 3. `do_update()` integration

- **T3.1** `--update` with a real version change → after the script is replaced, `update_all_project_hooks()` runs; a previously hook-less project now has PreCompact (without the user running `--install-hooks` separately).
- **T3.2** `--update` no-op (already latest) → does NOT walk every project (gated on version change). Verify no per-project log spam / churn.
- **T3.3** `--update` self-update failure → does NOT run the backfill against a half-updated state (order: update succeeds → then backfill).

## 4. Injection / conversational trigger

- **T4.1** Home session: "install hooks" / "backfill hooks" / "repair hooks" → Claude runs `claude-mux --install-hooks` and reports the summary verbatim.
- **T4.2** Trigger works from a non-home session too (admin action allowed anywhere).

## 5. End-to-end (the actual bug)

- **T5.1** Reproduce: create a session, hand-strip its PreCompact hook (simulating a pre-v2.0.1 settings file). Confirm `/compact` does NOT reconnect RC (baseline).
- **T5.2** Run `--install-hooks`. Per T0.1 result:
  - If live-read: trigger `/compact` in the same running session → RC reconnects, no restart.
  - If start-snapshot: restart-free next-start path — confirm the on-disk file now has the hook, then start/auto-restore the session and confirm `/compact` reconnects.
- **T5.3** Fleet check: multiple projects, some current / some stripped → one `--install-hooks` brings all to current; spot-check 3 settings files for the PreCompact block.

## 6. Post-build checks (Change Checklist)

- **T6.1** `--commands` / `commands_help()` lists `--install-hooks`.
- **T6.2** `dev/CODEMAP.md` has the `install-hooks` dispatch + wrapper; `update_all_project_hooks` second-caller noted.
- **T6.3** `dev/SKELETON.md` shows `install-hooks` dispatch + `do_update` → walker.
- **T6.4** `docs/CLI.md` + GUIDE/FAQ updated; ISSUES.md entry moved to Resolved.
- **T6.5** `CHANGELOG.md` entry; `VERSION=2.0.3`.
- **T6.6** Code review (patch scope: only changed functions — the wrapper, `do_update` delta, dispatch/arg-parse). CRITICAL/HIGH addressed.
