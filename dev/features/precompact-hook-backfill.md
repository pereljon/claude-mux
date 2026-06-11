---
feature: precompact-hook-backfill
status: shipped
version: 2.0.3
---

# Feature: PreCompact hook backfill (`--install-hooks`)

Implementable design spec. Test plan: `precompact-hook-backfill-tests.md`.

## Problem

The universal `/compact` RC-reconnect `PreCompact` hook shipped in v2.0.1, but it only lands in a project's `.claude/settings.local.json` when `setup_claude_mux_permissions()` runs - which happens at session create/launch. Projects whose settings file was last written before v2.0.1 are missing the hook and get no RC reconnect after `/compact`. `--update` restarts sessions but doesn't re-run permission setup on every project's on-disk file. Confirmed: sylvia-estate had `UserPromptSubmit` but no `PreCompact`. Current workaround is to manually restart each affected session - tedious and easy to miss.

## Key finding: the backfill logic already exists

`update_all_project_hooks()` (claude-mux:3646) already does exactly what's needed:

```
update_all_project_hooks():
    discover_projects
    dirs = [BASE_DIR] + PROJECT_DIRS + HIDDEN_PROJECT_DIRS
    for dir in dirs:
        skip if no dir/.claude
        is_home = (dir == BASE_DIR)
        setup_claude_mux_permissions(dir, is_home)   # idempotent, merge-based
```

`setup_claude_mux_permissions()` (claude-mux:2554) is idempotent: its pre-check (first python block) already verifies PreCompact presence and returns "needs update" when missing; the merge block (second python block) adds the `--on-compact` PreCompact hook unconditionally if absent, **preserving all other settings**. So a walk over every project already backfills the missing hook. The function is currently only reachable via `enable_tips`/`disable_tips`.

**Therefore the fix is to expose the existing walker, not to write new merge logic.**

## Scope

**In:**
1. New `--install-hooks` command that calls `update_all_project_hooks()` and prints a summary (how many projects scanned / patched / already-correct).
2. Call `update_all_project_hooks()` from `do_update()` so `--update` backfills automatically going forward.
3. Injection trigger + (optionally) a conversational phrase ("install hooks" / "backfill hooks").

**Out:**
- No new hook types. Only re-applies the existing `--on-compact` + `--on-prompt` registration.
- No forced session restart. The command only edits on-disk settings files.
- No change to `setup_claude_mux_permissions()` merge logic (already correct).

## Key assumption to VERIFY before finalizing (pre-build)

**Does Claude Code read the `PreCompact` hook live (per `/compact` event) or snapshot it at session start?** This determines the value framing:

- **If live-read:** backfilling the on-disk file fixes *currently-running* sessions immediately - the next `/compact` reconnects RC with no restart. Matches the bug's "without requiring a session restart" hope.
- **If start-snapshot:** a running session keeps its old (hook-less) snapshot until it next starts. Backfill still fixes the on-disk state for *all* projects at once, so the hook is present at the next natural launch (reboot, auto-restore, manual start) with no forced restart-all. Still strictly better than the per-session manual-restart workaround, just not instant for already-running sessions.

Verify empirically (test T0.1) and frame the user-facing message accordingly. Either way the feature is worth shipping; only the messaging changes.

## Design

### `--install-hooks` command

```
claude-mux --install-hooks
```

- Dispatch case `install-hooks` → a thin wrapper around `update_all_project_hooks()` that counts outcomes.
- Output (TTY + non-TTY): `Scanned N projects: M patched, K already current.` Patched list logged to `$LOG_FILE` via the existing `log "Adding claude-mux permissions to $dir ..."` line in `setup_claude_mux_permissions`.
- Honors `--dry-run`: `setup_claude_mux_permissions` already early-returns on `DRY_RUN` after logging "Would ..."; the wrapper reports what *would* change.
- Safe to run repeatedly (idempotent). No-op on already-correct projects.

To get per-outcome counts without changing `setup_claude_mux_permissions`'s return contract: either (a) have the wrapper re-run the same pre-check the function uses, or (b) add a lightweight return signal. Prefer (a) — call a small "needs_hooks(dir)" predicate (extract the existing pre-check python into a helper, or inline) before/after to tally. Keep `setup_claude_mux_permissions` behavior unchanged.

### `do_update()` integration

After a successful self-update (script replaced), call `update_all_project_hooks()` so every `--update` brings all projects' settings current. This closes the gap for the common upgrade path without the user needing to know about `--install-hooks`. Gate it so it only runs on actual version change (don't walk every project on a no-op update).

### Injection / conversational trigger

Add a trigger rule so the home session can run it on request:
```
- When user says: install hooks / backfill hooks / repair hooks — run claude-mux --install-hooks and report the summary
```
Low-frequency admin action; no tip needed. (Optional: add a tip if it proves commonly needed.)

## Verified facts (current code)

- `update_all_project_hooks()` exists (claude-mux:3646), walks BASE_DIR + visible + hidden, skips dirs without `.claude`, sets `is_home` correctly.
- `setup_claude_mux_permissions()` (2554) is idempotent + merge-preserving; PreCompact pre-check at ~2601-2607, merge at ~2690-2700, `timeout: 10`.
- Hook command form: `<CLAUDE_MUX_BIN> --on-compact` under `hooks.PreCompact[].hooks[]`.
- `discover_projects` populates `PROJECT_DIRS` / `HIDDEN_PROJECT_DIRS`.

## Change checklist (per CLAUDE.md)

- [ ] `claude-mux`: `--install-hooks` arg parse + `install-hooks` dispatch + wrapper-with-counts; call `update_all_project_hooks()` from `do_update()` (version-change-gated); injection trigger rule in `build_system_prompt`.
- [ ] `commands_help()` + `--commands`: document `--install-hooks`.
- [ ] `dev/CODEMAP.md`: new dispatch case + wrapper function; note `update_all_project_hooks` now has a second caller.
- [ ] `dev/SKELETON.md`: `install-hooks` dispatch line; `do_update` now calls the walker.
- [ ] `docs/CLI.md`: add `--install-hooks`.
- [ ] `docs/GUIDE.md` / `docs/FAQ.md`: "my old sessions don't reconnect RC after /compact" → run `--install-hooks` (or update).
- [ ] `docs/ISSUES.md`: move the "PreCompact hook not registered in pre-v2.0.1 sessions" entry to Resolved.
- [ ] `CHANGELOG.md` + `VERSION` patch bump (2.0.3).
- [ ] Release gate: script changed → release required (per CLAUDE.md).
