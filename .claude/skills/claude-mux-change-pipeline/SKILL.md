---
name: claude-mux-change-pipeline
description: Use when carrying a claude-mux change from feature definition through design docs, code, review, context-file updates, commit, merge, deploy, push, release and post-release clear. Gives the canonical 15-step order and the approval gates.
---

# claude-mux change pipeline

The canonical order of a change, start to finish. This list is the *sequence*; the detailed rules live in the sections of the repo `CLAUDE.md` it links to (Worktree Policy, Code Review Before Release, Git Approvals, Testing Plan, Change Checklist) — do not duplicate them here.

1. **Define the feature** — when a `docs/ISSUES.md` entry is ready to build, lift it to `dev/features/<feature>.md` (see the feature design+test convention under Documentation Roles).
2. **Research & verify assumptions** — confirm what the design rests on against reality (read the actual code, GitHub/vendor docs, run probes) *before* finalizing the plan. Docs must reflect verified reality, not guesses.
3. **Write the design + test plans** — `dev/features/<feature>.md` + `<feature>-tests.md`. Review happy path, edge cases, flag conflicts, config migration, injection/display changes with the user (see Testing Plan). Confirm before coding.
4. **Pre-code compact** — if context is getting heavy, compact before the code phase (coding is the context-hungry part; see the performance rules).
5. **Set up a worktree** (if warranted, see Worktree Policy) — report when creating one, no need to ask first.
6. **Code** — apply *Consult docs before coding* (read `dev/SKELETON.md` + `dev/CODEMAP.md` first). Edit `src/*.sh` (never `claude-mux` directly), `make build`, then smoke-test the built file (`bash ./claude-mux ...`) as you go.
7. **Code review** — *Code Review Before Release*: scope by version bump; `superpowers:code-reviewer` agent; fix CRITICAL/HIGH. Decide the bump early (it sets review scope) even though `VERSION=` is physically written in step 8.
8. **Update context files** — the *Change Checklist* GATE. After review, so docs reflect the final code: CODEMAP, SKELETON, IMPLEMENTATION-SPEC, README, CHANGELOG, VERSION, ISSUES, injection prompt, etc.
9. **Test** — verify real behavior (happy path + edge cases) on the repo copy. Tests verify correctness; running the actual command verifies the feature works.
10. **Commit** — [approval gate] (see Git Approvals).
11. **Merge** — if built in a worktree, merge to `main` locally by default (Worktree Policy), then re-run `make check` on `main` before deploying/pushing.
12. **Deploy** — `make build` then `cp claude-mux ~/bin/` so local sessions use the new code (after commit/merge).
13. **Push** — [approval gate].
14. **Release** — [approval gate]; only if `claude-mux`/`install.sh` changed; **`make check` must pass clean immediately before `git tag`** (never tag a stale artifact); `git tag` → `git push origin TAG` → `gh release create`, ascending version order (see Git Approvals → Release).
15. **Post-release clear** — `claude-mux -s SESSION '/clear'`. The next cycle starts a fresh feature; no context from this cycle needs to carry over (the handoff lives in the feature docs + memory, not the transcript).

Plan docs (steps 1-3) come before code; reference/changelog docs (step 8) come after code+review so they describe the final result. Commit, push, and release are independent approval gates — one does not imply the next.
