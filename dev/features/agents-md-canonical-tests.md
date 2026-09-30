# Test plan: agents-md-canonical

Companion to `agents-md-canonical.md`. claude-mux is a bash tool; "tests" are manual
procedures on a throwaway `BASE_DIR` plus artifact/build checks. Run all migration tests
against a temp tree (`BASE_DIR` pointed at a scratch directory with `git init` repos), never
against `~/Claude`.

## 0. Pre-build verification

| # | Check | Result |
|---|---|---|
| 1 | AGENTS.md alone loads | DONE 2026-09-30 (2.1.285) |
| 2 | Ancestor CLAUDE.md + child AGENTS.md: only CLAUDE.md loads | DONE |
| 3 | Ancestor AGENTS.md + child CLAUDE.md: only CLAUDE.md loads | DONE |
| 4 | Both in one dir: CLAUDE.md wins | DONE |
| 5 | Descendant CLAUDE.md does not suppress root AGENTS.md; loads lazily | DONE |
| 6 | `.claude/AGENTS.md` beside root AGENTS.md | DONE: both load (double-load); decided ANOMALY |
| 7 | CLAUDE.md symlink to AGENTS.md counts as CLAUDE.md | DONE: yes, suppresses child AGENTS.md |
| 8 | Gemini CLI default context filenames | DEFERRED; documented as needing `context.fileName` |
| 9 | `/config` "Project instructions" storage key | DROPPED; not needed |
| 10 | User-level `~/.claude/CLAUDE.md` suppresses AGENTS.md? | DONE: no, both load |
| 11 | `CLAUDE.local.md` suppresses AGENTS.md (same dir and ancestor)? | DONE: yes, both cases |
| 12 | `@AGENTS.md` stub CLAUDE.md | DONE: content loads via import; stub still suppresses the fallback |
| 13 | CLAUDE.md above `BASE_DIR` suppresses AGENTS.md below | DONE (ancestor case, check 2) |

## 1. Version gate
- Stub `claude --version` (PATH shim) to 2.1.276: report says unsupported, `--apply` refuses, no file changed.
- 2.1.277 and 2.1.285: gate passes. `2.1.285-beta`: compares by numeric core, passes.
- `claude` missing or unparseable version: fail closed with a clear message.

## 2. Classification (one directory per class in a scratch tree)
Build one dir each for DONE, MIGRATE, LINK, IDENTICAL, CONFLICT, INVERSE, STUB, GEMINI-LINK,
LOCAL, ANOMALY (`.claude/CLAUDE.md` and `.claude/AGENTS.md`), EXT-LINK (symlink to another
target), BROKEN-LINK, NOT-A-FILE (directory named CLAUDE.md), CASE-VARIANT (`claude.md`), and
ABOVE (a CLAUDE.md in an ancestor of the scratch `BASE_DIR`). The report must label each
correctly and change nothing.
- LINK requires the symlink target to be exactly `CLAUDE.md`; a link to anything else is EXT-LINK.
- Every abort-class case makes `--apply` abort before the first change; the report names the path.
- Every CLAUDE.md in the tree, symlinks included, appears in the report.
- `-*` directories, `node_modules`, `.git`, `worktrees` are skipped; `.claude` is not.
- A hidden project (`.claudemux-ignore`) and a non-project category dir are scanned.
- Textual references to `CLAUDE.md` (`@CLAUDE.md`, prose, scripts) are listed, not edited.

## 3. Apply
- Tracked file: `git mv` used; `git status` shows a rename, uncommitted; no commit made.
- Tracked file with staged and with unstaged modifications: rename succeeds, edits preserved.
- Mixed tracked-ness matrix (CLAUDE.md tracked / untracked / gitignored, crossed with AGENTS.md
  tracked link / untracked link / absent): each combination follows the D5.3 sequence with rc 0
  and no half-staged tree. `git add -A -- CLAUDE.md AGENTS.md` is never used.
- Tracked stub/link with staged modifications that differ from both HEAD and the worktree:
  `git rm --cached -f` succeeds where plain `--cached` refuses.
- `.claude` scan: a case-variant name (`claude.md`) classifies as CASE-VARIANT, not MIGRATE, on
  case-insensitive macOS.
- Untracked file: plain `mv`.
- LINK (tracked and untracked AGENTS.md link): one atomic `mv -f`, content intact (`cmp`
  against a saved copy), index correct after `git add -A`.
- IDENTICAL (tracked and untracked): AGENTS.md replaced, CLAUDE.md gone, content intact.
- INVERSE: symlink removed, then AGENTS.md loads (`claude -p` marker check).
- STUB: removed, AGENTS.md loads. GEMINI-LINK: deleted. A real GEMINI.md is untouched.
- Nested repo, submodule, and a directory inside a parent repo: correct repo root used per file.
- Locked index (`.git/index.lock`): partial failure recorded in the manifest, run stops.
- Paths with spaces and unusual characters: manifest JSON quoting and encoding are correct.
- A symlinked directory inside the tree: `find` does not follow it.
- Post-condition: no CLAUDE.md or CLAUDE.local.md remains in any scanned walk-up path.
- Real behavior: `claude -p` in a migrated project reports the AGENTS.md marker and the
  ancestor AGENTS.md marker.
- Rerun after a partial failure is idempotent (DONE plus remaining MIGRATE).

## 4. Safety
- Manifest written atomically, before the first change (kill the process after op 2, and kill
  during the manifest write; the manifest is never half-written). Each op records class, path,
  repo root, method, original symlink target, and sha256 of any removed file.
- Simulate a failure on op N (read-only file): run stops, completed ops recorded, lock
  released; reversing them by hand restores the original tree byte for byte (`diff -r`).
- Lock: contains pid and timestamp. Honored by `autolaunch_dispatch` (home is NOT launched
  while held), `autorestore_walk`, and manual `--start` / `-n` via `create_claude_session`.
  Not consumed on sight.
- Stale lock after `kill -9`: `autolaunch_dispatch`, the tick and `--start` still work (WARN
  logged, lock not deleted); a later `--apply` reports it stale and takes it over. Live pid: a
  second `--apply` refuses. A lock dir with no pid file yet counts as live for 10 seconds.
- The lock is gitignored via `ensure_gitignore_entry()` before creation when BASE_DIR is a repo.
- Read-only default: running without `--apply` leaves the tree byte-identical.

## 5. Restart
- After `--apply`, every running managed session under `BASE_DIR` restarts via
  `restart_sessions_in`; sessions outside `BASE_DIR` are not touched; stopped sessions are not
  started.
- The calling session restarts last, in place; the summary prints before its `/exit`.
- `--apply` from a non-home managed session as the caller, and from a non-managed terminal.
- Busy sessions are named in the report/confirmation; a mid-turn session is restarted
  correctly; protected sessions are restarted and the confirmation says so.
- A session forced to fail relaunch is named; the rename is not rolled back.
- `--no-restart` leaves sessions running and prints the list needing restart.
- Each restarted session answers the `Ready?` handshake.
- Refactor guard: `--restart` (no args) behaves exactly as before the `restart_sessions_in`
  extraction, including its exit code (no new nonzero exit when a session fails to relaunch).
- `restart_sessions_in` contract: `name|dir` input, failed names and return code as output;
  DRY_RUN branch, caller-last and `.claudemux-restarting` wrapping preserved.
- Scope check uses physical paths with a trailing-slash prefix: with BASE_DIR `/x/Claude`, a
  session in `/x/Claude2` is not restarted.
- `/init` run by a live session between verify and restart: the pre-restart walk-up re-check
  catches the new CLAUDE.md.

## 6. Marker and drift
- Marker `BASE_DIR/.claudemux-agents-migrated` is written after verify, before restarts;
  contains date, count, manifest path; auto-gitignored when BASE_DIR is a repo.
- Delete the marker: rescan reports nothing to do, no error.
- Create a CLAUDE.md in a migrated project (simulating `/init`), and reintroduce one via a
  branch checkout: the home drift scan names the path; the marker's presence does not suppress it.
- The drift scan runs at most once per day, only in the home session; non-home sessions skip
  it. It never runs on the per-prompt path. Its cost is
  measured on a large tree (open item 1).

## 7. New projects, templates, injection
- Version gate passes, clean path: `apply_template` writes AGENTS.md.
- A CLAUDE.md exists in an ancestor: it writes CLAUDE.md and prints the note.
- `--save-template` from an AGENTS.md project and from a CLAUDE.md project both work.
- `claude-mux --print-system-prompt`: the "never create CLAUDE.md" line is present only in an
  AGENTS.md tree; `--migrate-agents-md` is in the feature list, triggers, and `--commands` /
  `--guide` output; both launch paths produce the same text (they share `build_system_prompt`).
- README "Session System Prompt" matches.

## 8. Multi-coder removal
- New sessions create no AGENTS.md/GEMINI.md links.
- `MULTI_CODER_FILES` set in config or `--no-multi-coder` passed (with or without `-n`): one
  warning across separate launches (stamp file under `~/.claude-mux/`), ignored, no per-session
  repetition.
- Later-minor removal: config var, flag, `config_help`, `commands_help`, `config.example`,
  README, `docs/GUIDE.md`, tips all gone.

## 9. Post-build checks
`make build` + `make check` clean; `make codemap` and `make features-index` run; README,
translations (batched at release), `docs/CLI.md`, `docs/GUIDE.md`, `docs/ISSUES.md`,
`dev/IMPLEMENTATION-SPEC.md`, `dev/CODEMAP.md` (Marker File Registry), `dev/SKELETON.md`,
`CHANGELOG.md`, `VERSION=`, `config.example`, `internal/tips.md` updated; recheck `install.sh`
and `translations/` for `MULTI_CODER_FILES`.
