---
kind: feature
lifecycle: designing
feature: home-prompt-split-tests
status: TEST PLAN drafted 2026-07-22 alongside the design. Pre-build. Pairs with home-prompt-split.md.
related: home-prompt-split, model-switch-confirm
---

# Test plan: split home orchestrator prompt out of the ancestor CLAUDE.md

Pairs with `home-prompt-split.md`. Governing invariant: **home identity/orchestration reaches ONLY
the home session; project sessions get the shared comms style + a config prohibition, and are NEVER
told they are the home orchestrator.** The cheapest oracle is `--print-system-prompt`, which is the
exact text `build_system_prompt` produces — assert on it directly, no live session needed.

## Phase 0 — Baseline capture (before any edit)
Record today's behavior so the diff is provable:
- `bash ./claude-mux --print-system-prompt home auto > /tmp/prompt-home.before`
- `bash ./claude-mux --print-system-prompt <some-project> auto > /tmp/prompt-proj.before`
- Confirm the home identity currently comes from the ancestor CLAUDE.md (not the injection) by noting
  what `home_line`/`home_management` already contain vs what's only in `~/Claude/CLAUDE.md`.

## Phase 1 — Home injection carries the orchestrator role
| # | Case | Assert (on `--print-system-prompt home auto`) |
|---|------|-----------------------------------------------|
| 1.1 | Home identity present | output contains the consolidated home-orchestrator role (identity + session-management authority) |
| 1.2 | Config GRANT present | contains the home config/template grant (existing `:684` line, consolidated) |
| 1.3 | Personal-notes pointer (if option a) | contains the "load home-orchestrator notes from `<path>` if present" line |
| 1.4 | No duplication | the home role appears ONCE — not duplicated between injection and (stripped) CLAUDE.md |

## Phase 2 — Non-home injection is clean of home identity, carries the prohibition
| # | Case | Assert (on `--print-system-prompt <project> auto`) |
|---|------|-----------------------------------------------------|
| 2.1 | NO home identity | output does NOT contain "This is the home session" / "you are the orchestrator" framing |
| 2.2 | NO config grant | does NOT contain the home config/template management block |
| 2.3 | **Config PROHIBITION present** | contains the new "do not edit `~/.claude-mux/`; that is the home session's job" line |
| 2.4 | No "this session" ambiguity | there is no line a project session could read as granting *itself* config authority |
| 2.5 | Prohibition harmless for home | on `--print-system-prompt home`, the prohibition either is absent (gated) or is phrased so it does not contradict the home grant |

## Phase 3 — Shared comms style reaches everyone; ancestor no longer leaks identity
| # | Case | Pass criteria |
|---|------|---------------|
| 3.1 | CLAUDE.md stripped | `~/Claude/CLAUDE.md` contains ONLY the Communication Style block (no identity, no session-mgmt, no config authority, no directory map) |
| 3.2 | Comms reaches a project session | a live project session under `~/Claude/` still has the comms rules (no em-dashes, no filler) via ancestor loading |
| 3.3 | Comms reaches home | the home session still has comms rules (home cwd = BASE_DIR loads the same file) |
| 3.4 | "auto mode" line moved | the "operational session in auto mode" line is in HOME-INJ, not in the shared CLAUDE.md |

## Phase 4 — Personal home-only content (option a) is home-only by construction
| # | Case | Pass criteria |
|---|------|---------------|
| 4.1 | Home loads personal notes | with the personal notes file present, the home session has the analytical-project conventions / migration procedure available |
| 4.2 | **Children do NOT load it** | a project session does NOT get the personal notes (filename is non-CLAUDE.md, so ancestor loading skips it) — verify by capturing a project session's loaded context |
| 4.3 | Absent file is harmless | with the personal notes file absent, home injection does not error and just omits the pointer's target |

## Phase 5 — Regression / build gates
- `make build` clean; `make check` green (+ codemap/features-index if a fragment/function was added).
- If a `src/XX-orchestrator-prompt.sh` fragment was added, it IS in the Makefile `MODULES` list AND
  its function appears in the built `claude-mux` (guard against the stray-fragment landmine: grep the
  built artifact for the function).
- **README "Session System Prompt" section matches the new injection** (Change Checklist requirement).
- `--print-system-prompt home` vs `--print-system-prompt <project>` differ ONLY by the home
  block + the prohibition — diff them and eyeball nothing unexpected leaked.
- Restart-in-place regen: a home restart regenerates via `--print-system-prompt home` and still gets
  the orchestrator role (the wrapper path uses the same function, so this should follow for free —
  confirm once).

## Verification checklist (post-build)
- [ ] `--print-system-prompt home` has the orchestrator role + config grant; `--print-system-prompt <project>` has neither.
- [ ] Project prompt has the config PROHIBITION; home prompt is not contradicted by it.
- [ ] `~/Claude/CLAUDE.md` is comms-only; a live project session no longer reports being the home orchestrator.
- [ ] Personal home-only notes load for home, NOT for a project session.
- [ ] `make check` clean; README injection section + CHANGELOG + VERSION updated.
- [ ] Real end-to-end: restart a project session and confirm it does NOT identify as the home orchestrator; restart home and confirm it still does.
