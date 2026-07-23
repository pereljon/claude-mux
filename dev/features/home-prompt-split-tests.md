---
kind: feature
lifecycle: designing
feature: home-prompt-split-tests
status: TEST PLAN drafted 2026-07-22; reconciled 2026-07-23 with the resolved open questions + architect review (personal-notes branch dropped, role-neutral config line, Q4 keep-list). Pre-build. Pairs with home-prompt-split.md.
related: home-prompt-split, model-switch-confirm
---

# Test plan: split home orchestrator prompt out of the ancestor CLAUDE.md

Pairs with `home-prompt-split.md`. Governing invariant: **home identity/orchestration reaches ONLY
the home session; every session gets the shared comms style (via ancestor CLAUDE.md) plus ONE
role-neutral config-authority line (via injection), and no project session is EVER told it is the
home orchestrator.** The cheapest oracle is `--print-system-prompt`, which is the exact text
`build_system_prompt` produces — assert on it directly, no live session needed.

## Phase 0 — Baseline capture (before any edit)
Record today's behavior so the diff is provable:
- `bash ./claude-mux --print-system-prompt home auto > /tmp/prompt-home.before`
- `bash ./claude-mux --print-system-prompt <some-project> auto > /tmp/prompt-proj.before`
- Confirm the home identity currently comes from the ancestor CLAUDE.md (not the injection) by noting
  what `home_line`/`home_management` already contain vs what's only in `~/Claude/CLAUDE.md`.

## Phase 1 — Home injection carries the orchestrator role
| # | Case | Assert (on `--print-system-prompt home auto`) |
|---|------|-----------------------------------------------|
| 1.1 | Home identity present | output contains the consolidated home-orchestrator role (identity + session-management authority + the "operational / auto mode" posture line moved out of CLAUDE.md) |
| 1.2 | Config authority reaches home | contains the role-neutral config line; read as home, it grants direct edit ("if this session is named `home` … edit directly") |
| 1.3 | No duplication | the home role appears ONCE — not duplicated between injection and (stripped) CLAUDE.md, and not duplicated against the shared protected-session Rule |
| 1.4 | No false permission claim | the old "only home has filesystem permissions for ~/.claude-mux/" wording is GONE (Q3: convention, not enforcement) |

## Phase 2 — Non-home injection is clean of home identity, carries the neutral config rule
| # | Case | Assert (on `--print-system-prompt <project> auto`) |
|---|------|-----------------------------------------------------|
| 2.1 | NO home identity | output does NOT contain "This is the home session" / "you are the orchestrator" framing |
| 2.2 | NO home management block | does NOT contain the home-gated config/template operational triggers (show config, set CONFIG_VAR, add template, …) |
| 2.3 | Role-neutral config line present | contains the shared line; assert the route-to-home clause ("otherwise route the change to the home session"), NOT a "do not edit" string — the line is role-neutral, not a prohibition |
| 2.4 | No "this session" ambiguity | no line a project session could read as granting *itself* config authority; the line anchors identity to the session name (`home`), which the header states explicitly |
| 2.5 | Same line, both roles | the config line is IDENTICAL in home and project prompts (one shared line, self-disambiguating) — diff confirms no per-role variants |

## Phase 3 — Shared comms style reaches everyone; ancestor no longer leaks identity
| # | Case | Pass criteria |
|---|------|---------------|
| 3.1 | CLAUDE.md stripped per Q4 | `~/Claude/CLAUDE.md` contains the Communication Style block (minus the "auto mode" line) + the analytical-project template pointer, and NOTHING else: no identity, no session-mgmt, no config authority, no directory map, no migration procedure |
| 3.2 | Comms reaches a project session | a live project session under `~/Claude/` still has the comms rules (no em-dashes, no filler) via ancestor loading |
| 3.3 | Comms reaches home | the home session still has comms rules (home cwd = BASE_DIR loads the same file) |
| 3.4 | Migration procedure relocated | the 5-step migration procedure lives in its on-demand doc with at most a one-line pointer in CLAUDE.md; home can still find and follow it when asked to migrate a project |

## Phase 4 — Transition-window ordering (architect-required)
Hard sequence, not preference: **ship code → restart home → strip CLAUDE.md → restart home.**
| # | Case | Pass criteria |
|---|------|---------------|
| 4.1 | Never strip first | verify home is restarted on the new code (its baked prompt contains the orchestrator identity) BEFORE `~/Claude/CLAUDE.md` is stripped — home must never be identity-bare |
| 4.2 | Window is harmless for children | a project session launched after code-ship but before the strip gets today's (known) leak plus the neutral config line — no new regression |
| 4.3 | Final state clean | after the second home restart, home identity comes ONLY from the injection; CLAUDE.md supplies only comms + template pointer |

## Phase 5 — Regression / build gates
- `make build` clean; `make check` green. No new fragment expected (Q1: extend in place) — if that
  changes, the fragment MUST be in the Makefile `MODULES` list and its function greppable in the
  built artifact (stray-fragment landmine).
- **README "Session System Prompt" section matches the new injection** (Change Checklist requirement).
- `--print-system-prompt home` vs `--print-system-prompt <project>` differ ONLY by the home
  block — diff them and eyeball nothing unexpected leaked; the config line appears in both.
- Restart-in-place regen: a home restart regenerates via `--print-system-prompt home` and still gets
  the orchestrator role (the wrapper path uses the same function, so this should follow for free —
  confirm once).
- Name-gate assumption (recorded in the design): the home gate keys on `session_name == "home"`
  only. Sanity-check the recorded boundary: tmux dedup + the always-on protected home block a second
  live `home`, so no test needed beyond confirming the design documents the assumption.

## Verification checklist (post-build)
- [ ] `--print-system-prompt home` has the orchestrator role; `--print-system-prompt <project>` does not.
- [ ] Both prompts carry the identical role-neutral config line; neither carries the false "filesystem permissions" claim.
- [ ] Ordering followed: code shipped → home restarted → CLAUDE.md stripped → home restarted.
- [ ] `~/Claude/CLAUDE.md` is comms + template pointer only; a live project session no longer reports being the home orchestrator.
- [ ] Migration procedure reachable from home via its on-demand doc.
- [ ] `make check` clean; README injection section + IMPLEMENTATION-SPEC + CHANGELOG + VERSION updated.
- [ ] Real end-to-end: restart a project session and confirm it does NOT identify as the home orchestrator; restart home and confirm it still does.
