---
name: claude-mux-change-pipeline
description: Use when carrying a claude-mux change from feature definition through design docs, code, review, context-file updates, commit, merge, deploy, push, release and post-release clear. Gives the canonical 15-step order and the approval gates.
---

# claude-mux change pipeline

The canonical order of a change, start to finish. This list is the *sequence*; the rules live in the repo `AGENTS.md` and the shared `../AGENTS.md` (Branches and git approvals, Releases, Change Checklist, Session hygiene) — do not duplicate them here.

1. **Define the feature** — when a `docs/ISSUES.md` entry is ready to build, lift it to `dev/features/<feature>.md`.
2. **Research & verify assumptions** — confirm what the design rests on against reality (read the actual code, GitHub/vendor docs, run probes) *before* finalizing the plan.
3. **Write the design + test plans** — `dev/features/<feature>.md` + `<feature>-tests.md`. Review the test plan with the user (shared items plus config migration, injection/display changes). Confirm before coding.
4. **Checkpoint before coding** — if context is heavy, write state to the feature docs and tell the user it is a good point to compact. Never self-compact.
5. **Branch** — for behavior changes; report it. Worktree only for the shared policy's three reasons.
6. **Code** — read `dev/SKELETON.md` + `dev/CODEMAP.md` first. Edit `src/*.sh` (never `claude-mux` directly), `make build`, then smoke-test the built file (`bash ./claude-mux ...`) as you go.
7. **Code review** — on the branch; scope by version bump; fix CRITICAL/HIGH. Decide the bump early (it sets review scope) even though `VERSION=` is written in step 8.
8. **Update context files** — the *Change Checklist* GATE. After review, so docs reflect the final code.
9. **Test** — verify real behavior (happy path + edge cases) on the repo copy.
10. **Commit** — on the branch, no approval (report branch + hash); on `main`, [approval gate].
11. **Merge** — [approval gate]; merge locally, then re-run `make check` on `main`.
12. **Deploy** — `make build` then `cp claude-mux ~/bin/` so local sessions use the new code.
13. **Push** — [approval gate].
14. **Release** — [approval gate]; only if a deliverable changed; `make check` clean immediately before `git tag`; `git tag` → `git push origin TAG` → `gh release create`, ascending version order.
15. **Post-release clear** — `claude-mux -s SESSION '/clear'`. The handoff lives in the feature docs and `docs/ISSUES.md`, not the transcript.

Plan docs (steps 1-3) come before code; reference/changelog docs (step 8) come after code and review so they describe the final result. Merge, push, and release are independent approval gates — one does not imply the next.
