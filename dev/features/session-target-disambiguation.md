---
kind: feature
lifecycle: shipped
feature: session-target-disambiguation
status: implemented (v2.0.5)
target_version: 2.0.5
severity: MEDIUM (correctness / footgun)
---

# Feature: Don't silently default an unresolved session NAME to the current session

Implementable design spec. Test plan: `session-target-disambiguation-tests.md`.

## Problem

A session-targeting conversational command whose NAME doesn't resolve gets silently applied to the **current** session instead of asking. Observed 2026-06-16: from the `home` session the user said "Restart claudemux session" (intending to restart the `claude-mux` project session). Home ran `claude-mux --restart home` — it restarted **itself**. The `claude-mux` session was never touched. Log evidence:

```
[05:35:13Z] === claude-mux restart: home ===
[05:35:14Z] Sending /exit to session 'home'
[05:35:21Z] === claude-mux restart complete ===
```

The user saw home's own post-restart "Ready?" handshake and concluded (correctly) that the intended restart "didn't happen" and that "Ready? was injected into the home session."

## Root cause

This is an injection/NLU-layer issue, not a bug in the restart code. The restart of `home` itself worked. The misrouting comes from the trigger rule wording in `build_system_prompt()` (claude-mux:1526):

> When user says: restart this session / restart session NAME — run claude-mux --restart with session name (**or current session if none given**)

The parenthetical fallback collapses two distinct intents ("restart *this* session" vs "restart the session named X") into one rule with a silent default. When Claude can't cleanly extract/resolve a NAME (here "claudemux" read as the tool name, not a session, plus the hyphen drift "claudemux" vs `claude-mux`), it falls back to the current session and acts. The wrong session is restarted and the intended one is silently skipped.

The CLI already backstops *typos passed to it*: `claude-mux --restart <unknown>` errors `'<unknown>' is not a claude-mux managed session` (claude-mux:4450-4455, exact-match `is_managed_session`). The gap is entirely that Claude resolves to "current" **before** calling the CLI, so the CLI never sees an unknown name.

## Scope of the footgun (not restart-only)

The same silent-default pattern is in many session-targeting trigger rules:

| Line | Rule | Current fallback |
|---|---|---|
| 1524 | stop this session / stop session NAME | "or current session if none given" |
| 1526 | restart this session / restart session NAME | "or current session if none given" |
| 1527 | restart fresh / kill this session | "use current session name if none given" |
| 1531 | switch MODE | "named or current" |
| 1532 | switch MODEL | "named or current" |
| 1533 | compact | "named or current" |
| 1534 | clear | "named or current" |
| 1536-1539 | hide / show / protect / unprotect | "no arg = current session, or pass session name" |

Blast radius varies: restart/restart-fresh/stop/clear are the dangerous ones (wrong session torn down or conversation lost). switch/compact/hide/protect are lower-stakes but still wrong-target.

## Design

A single governing rule plus a light touch to the per-command wording. Generic - no per-session-name special-casing (the `claude-mux` tool/session collision resolves as a side effect; it is not hard-coded).

### 1. Add a governing "resolve a session NAME" instruction

Insert once, immediately above the session-targeting rules block (around claude-mux:1523), so every rule below inherits it:

```
- Resolving a session NAME in the rules below: "this session" / "the current session" (explicit) always means the session you are running in. For any OTHER phrasing that names a target ("the X session", "session X", "restart X"), resolve X against the live list (claude-mux -l): act only on an exact single match; if X matches zero sessions or is ambiguous, ASK the user which session (offer the closest matches from the list) — never fall back to the current session. Number references (e.g. "restart 5") already resolve via the list and are safe.
```

### 2. Remove the silent fallback from each per-command rule

Replace "(or current session if none given)" / "(no arg = current session, or pass session name)" / "named or current" with explicit two-intent wording. Restart example (1526):

```
- When user says: restart this session — run claude-mux --restart <CURRENT_SESSION>.
  When user says: restart session NAME / restart the NAME session — resolve NAME per the rule above, then run claude-mux --restart NAME. If NAME doesn't resolve to exactly one session, ask which session; do not default to the current session.
```

Apply the same split to stop (1524), restart-fresh (1527), switch mode/model (1531-1532), compact (1533), clear (1534), and hide/show/protect/unprotect (1536-1539).

### 3. Always-confirm before a named action (decision: yes)

For a NAMED target, Claude should run `claude-mux -l` first to confirm the name exists before acting. One cheap list call removes any guesswork about what "looks uncertain" means and makes the ask deterministic. "this session" / "current session" needs no lookup (Claude knows its own name from the injected tmux session name).

## Why not other approaches

- **Fuzzy-match NAME in the CLI** ("claudemux" -> "claude-mux"): risky - could silently match the wrong session. Better to error/ask than guess. The CLI's exact-match error is the correct backstop; the fix belongs at the NLU layer.
- **Bake a `claude-mux` tool-vs-session note into the injection**: doesn't generalize (only this dev machine has a session named `claude-mux`); pollutes every user's prompt. Rejected in favor of the generic resolve-or-ask rule.
- **Fix restart only**: leaves stop/clear/compact/etc. with the same footgun. The governing rule fixes the class at once for the same cost.

## Decided

- **Scope: fix the whole class** via the governing rule + per-rule rewording (not restart-only). One rule covers all session-targeting commands.
- **Always-confirm** named targets against the list before acting.
- Keep "restart all sessions" (1528) unchanged - no NAME to resolve.

### Code-review refinements (v2.0.5 review, applied)

- **List by command type, not always `-l`.** `-l` only lists running sessions, so resolving every named target against `-l` would make idle/stopped/hidden project commands always ask. The governing rule now selects: `-l` for commands needing a running session (stop, restart, restart-fresh, switch mode/model, compact, clear, get-mode); `-L` / `-L --hidden` for project-level commands that can target idle/hidden projects (hide, show/unhide, protect, unprotect, delete).
- **`get-mode` and `delete` were added to the reworked set** - both still carried the old ambiguous pattern. `delete` is the most destructive command, so its named form now resolves per the rule and (as before) confirms in chat before acting.
- **Not changed (deliberate):** `kill SESSION` never existed ("kill this session" is current-only, no regression); `rename`/`move` are current-project commands (the governing rule still covers any named variant).

## Related (separate, not in this change)

- **Self-restart by name has no caller-handoff protection**: "restart this session" → `claude-mux --restart <self>` goes through the single-named path, which `/exit`s its own pane (same caller-kills-itself class fixed for restart-all in v2.0.4). It worked in the incident, but it's latent risk. Track separately.
- **Home comes up fresh after restart** (RC re-registration race; diagnostics added in v2.0.4 commit 4c02956). Separate investigation.

## Verified facts (current code)

- Injection trigger rules live once in `build_system_prompt()` (claude-mux:1459); both launch wrappers call it (`create_claude_session` 2931, `launch_single_session` 3274). One edit site for the injection itself.
- Restart trigger rule with the silent fallback: claude-mux:1526. Sibling rules with the same pattern: 1524, 1527, 1531-1534, 1536-1539.
- CLI backstop: named `--restart` validates `is_managed_session` and errors on no match (claude-mux:4450-4455). `is_managed_session` is exact-match.
- The incident command `claude-mux --restart home` is the named-restart path; confirmed in log (`=== claude-mux restart: home ===`).
- Injection changes take effect only after a session restart (prompt baked at launch via `--append-system-prompt-file`).

## Change checklist (per CLAUDE.md)

- [ ] `claude-mux` `build_system_prompt()`: add governing resolve-a-NAME rule above 1523; reword 1524, 1526, 1527, 1531-1534, 1536-1539 to drop the silent current-session fallback.
- [ ] `README.md` "Session System Prompt" section: mirror the reworded trigger rules (must match injection).
- [ ] `translations/README.*.md`: defer to the batch translation pass at release (per project convention).
- [ ] `dev/CODEMAP.md`: no function signature change; note only if the trigger-block structure is referenced (it isn't by line). Likely no change.
- [ ] `dev/SKELETON.md`: `build_system_prompt()` flow unchanged (same function, longer text). Likely no change; verify.
- [ ] `CHANGELOG.md`: v2.0.5 entry - behavior change: a named session command that doesn't resolve now asks instead of defaulting to the current session.
- [ ] `VERSION=` bump to 2.0.5.
- [ ] `docs/ISSUES.md`: add a resolved entry referencing this incident.
- [ ] No new CLI flag, no `commands_help()` change, no `config.example` change.
- [ ] Effective only after sessions restart; note in CHANGELOG / when reporting to user.
- [ ] Release gate: `claude-mux` changed (injection is functional) → release required.

## Open questions (resolve before coding)

1. **Bump as patch or minor?** It's an injection behavior change (not a new flag). Prior injection-only changes shipped as minors (e.g. status-filter). Lean v2.0.5 minor. Confirm.
2. **Reword all listed rules now, or restart/stop/clear (destructive) first and the rest as a fast-follow?** Design assumes all-at-once via the governing rule. Confirm scope.
3. **Bundle with the pending v2.0.4 push** (restart fix + diagnostics, currently 2 commits ahead, unpushed) or ship after? They're independent.
