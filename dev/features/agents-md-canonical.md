---
kind: feature
lifecycle: building
feature: agents-md-canonical
status: BUILDING 2026-09-30, version 2.4.0 (uncommitted in worktree agents-md-canonical). Architect-reviewed twice before build (pass 1 C1-C4, I1-I9; pass 2 N1, N2, I-a to I-e); code written and reviewed, review fixes applied (LOCKED-INDEX, DEST-EXISTS, post-lock rescan, per-op revalidation, MIXED block, drift scan). Docs pass done; manual tests (agents-md-canonical-tests.md) pending. Fallback semantics verified on Claude Code 2.1.285. Jonathan will rename his own ~/Claude tree by hand first.
target_version: 2.4.0 (minor). Behavior change plus a deprecation (MULTI_CODER_FILES), so a worktree is warranted.
severity: N/A (enhancement); a wrong migration silently drops project instructions
related: cross-cli-coders, external-prompt-routing
---

# Feature: AGENTS.md as the canonical project-instructions file

## Problem

claude-mux treats `CLAUDE.md` as the real file and links `AGENTS.md` and `GEMINI.md` to it
(`MULTI_CODER_FILES`, `src/50-restore-state.sh`). Claude Code 2.1.277 added a fallback: in a
project with no CLAUDE.md it reads AGENTS.md. So AGENTS.md can be the single real file for
Claude Code and Codex, and the symlink scheme becomes unnecessary.

The catch is that the fallback is all-or-nothing per session. A CLAUDE.md anywhere in cwd or
its ancestors makes Claude Code ignore every AGENTS.md. A half-migrated tree silently drops
instructions, in either direction. That makes migration a tree-wide, atomic operation and
makes "just rename CLAUDE.md" unsafe.

## Verified facts (Claude Code 2.1.285, `claude -p` in temp dirs, marker string per file)

| Layout | Loaded |
|---|---|
| AGENTS.md alone | AGENTS.md |
| Ancestor CLAUDE.md + child AGENTS.md | ancestor CLAUDE.md only |
| Ancestor AGENTS.md + child CLAUDE.md | child CLAUDE.md only |
| CLAUDE.md and AGENTS.md in one dir | CLAUDE.md only |
| Root AGENTS.md + CLAUDE.md in a subdirectory | both (subdirectory one loads lazily) |
| User-level `~/.claude/CLAUDE.md` + project AGENTS.md | both (user file does NOT suppress the fallback) |
| `CLAUDE.local.md` + AGENTS.md in one dir | `CLAUDE.local.md` only (**suppresses the fallback**) |
| `CLAUDE.local.md` in an ancestor + AGENTS.md in the child | ancestor `CLAUDE.local.md` only |
| CLAUDE.md containing only `@AGENTS.md` + AGENTS.md | AGENTS.md content (via the import; the stub still suppresses the fallback) |
| Root CLAUDE.md symlink to AGENTS.md + child AGENTS.md | root content only (**symlinked CLAUDE.md counts and suppresses**) |
| `.claude/AGENTS.md` + root AGENTS.md | both (double-loads) |

Rule: if a CLAUDE.md or `CLAUDE.local.md` (file, symlink or import stub) exists in cwd or any
ancestor, all AGENTS.md files are ignored. A user-level `~/.claude/CLAUDE.md` is exempt.
Descendant CLAUDE.md files do not suppress the walk-up AGENTS.md.

The tree scan re-derives the rule on every run; the facts above are tied to 2.1.285 and the
version gate is a minimum only, so later Claude Code versions may change behavior.

Minimum Claude Code version for the fallback: 2.1.277 (release notes). The `/config`
"Project instructions" setting controls it. Its storage key was not found and claude-mux does
not need it; the version gate plus the tree scan is sufficient.

## Design

### D1. Version gate
`claude --version` first token, compared numerically (x.y.z) against a constant
`MIN_AGENTS_MD_VERSION=2.1.277` (a constant, not a config var). A pre-release suffix
(`2.1.285-beta`) compares by its numeric core. Missing `claude` or an unparseable version fails
closed. Below the minimum: keep CLAUDE.md, report why, change nothing.

### D2. Command surface
- `claude-mux --migrate-agents-md` is **read-only by default**: prints the report (D3).
- `claude-mux --migrate-agents-md --apply` performs the migration and restarts running
  sessions (D6). `--no-restart` skips the restart. `--apply` and `--no-restart` are valid only
  with `--migrate-agents-md` (validation error otherwise, as `--no-multi-coder` did).
- Conversational triggers in the home session: "check agents migration", "migrate to AGENTS.md".
  The injection tells Claude to confirm once ("migrate N files and restart M running sessions")
  before running `--apply`.

### D3. Scan and report
Scan `BASE_DIR` with a `find` that prunes `.git`, `node_modules`, `-*` and `worktrees`, and does
**not** prune `.claude` or other dot-dirs (unlike `discover_projects()`, which prunes every
dot-dir and only finds directories containing `.claude`). Names match case-insensitively
(macOS is case-insensitive by default) for `CLAUDE.md`, `CLAUDE.local.md`, `AGENTS.md`,
`GEMINI.md`. Include hidden projects (`.claudemux-ignore`) and non-project category
directories such as `development/` or `personal/`: they are ancestors of every project below
them, so leaving them out breaks inheritance silently. Every CLAUDE.md found is reported. Classification uses the names returned by the directory
listing (`find -iname`, then an exact-name compare), never `-e`/`-f` on the canonical name:
on case-insensitive macOS `[[ -f CLAUDE.md ]]` is true for `claude.md`, which must classify as
CASE-VARIANT, not MIGRATE.

Also scan **upward from `BASE_DIR` to `/`** for `CLAUDE.md` and `CLAUDE.local.md` (not
`~/.claude/CLAUDE.md`, which is exempt). Files there are outside the migration's reach but
suppress every AGENTS.md below them: class ABOVE. When ABOVE aborts, the report says plainly
that this tree cannot migrate until that file is removed or merged, and that claude-mux keeps
CLAUDE.md as canonical for it (new projects get CLAUDE.md, D8). Managed-policy CLAUDE.md
paths (for example under `/Library/Application Support/ClaudeCode`) are untested; treat as
ABOVE-like until verified.

Classify each directory:

| Class | State | Action on `--apply` |
|---|---|---|
| DONE | AGENTS.md only | none |
| MIGRATE | CLAUDE.md only (real file) | rename to AGENTS.md |
| LINK | AGENTS.md is a symlink whose target is exactly `CLAUDE.md`, CLAUDE.md real | replace the link with the file (D5) |
| IDENTICAL | both real, `cmp` equal | replace AGENTS.md with CLAUDE.md (D5) |
| CONFLICT | both real, contents differ | **abort** |
| INVERSE | CLAUDE.md is a symlink to AGENTS.md (verified: counts as a CLAUDE.md and suppresses the fallback) | remove the symlink |
| STUB | CLAUDE.md whose only content is `@AGENTS.md`, real AGENTS.md alongside | remove the stub |
| GEMINI-LINK | GEMINI.md is a symlink to CLAUDE.md or AGENTS.md | delete the link. A real GEMINI.md is never touched |
| LOCAL | any `CLAUDE.local.md` (personal; suppresses the fallback; no AGENTS equivalent) | **abort** until the user merges or deletes it |
| ANOMALY | any `.claude/AGENTS.md` or `.claude/CLAUDE.md` (there should be none; `.claude/AGENTS.md` also double-loads) | **abort** |
| EXT-LINK | CLAUDE.md or AGENTS.md is a symlink to any other target | **abort** |
| BROKEN-LINK / NOT-A-FILE | dangling symlink, or a directory named CLAUDE.md / AGENTS.md | **abort** |
| CASE-VARIANT | `claude.md`, `Agents.md` and similar | **abort** |
| ABOVE | CLAUDE.md or CLAUDE.local.md in an ancestor of `BASE_DIR` | **abort** (outside the migration's reach; user resolves) |

The report also lists: Claude Code version and gate result; running managed sessions (busy or
idle); tracked files (git handling, D5); sessions outside `BASE_DIR` and Claude Code sessions
outside claude-mux, which the migration cannot restart; and every remaining textual reference
to `CLAUDE.md` in the migrated tree (`@imports`, docs, scripts), because those break silently
after the rename. References are listed, never edited.

### D4. Preflight (any failure aborts before the first change)
Version below minimum; any CONFLICT, LOCAL, ANOMALY, EXT-LINK, BROKEN-LINK, NOT-A-FILE,
CASE-VARIANT or ABOVE (a surviving CLAUDE.md leaves the path half-migrated); UNWRITABLE
(an actionable directory is not writable); LOCKED-INDEX (a git `index.lock` present in a repo
that a git-based operation touches); DEST-EXISTS (a MIGRATE destination AGENTS.md already
exists); migration lock held by a live process. A mixed tree is never produced: if the plan cannot
complete, nothing is applied.

### D5. Apply
1. **Lock:** `mkdir BASE_DIR/.claudemux-migrating/` (mutex; same convention as
   `.claudemux-restarting`, tied to the tree being migrated) containing `pid` and a timestamp.
   Write the `pid` file immediately after `mkdir`; a lock dir with no pid file yet counts as
   live for 10 seconds. **Honoring** means blocking only while the pid names a live process
   and the lock is younger than 60 minutes. A dead or missing pid, or an older lock, is "no
   lock": the launcher logs a WARN and continues, and never deletes the lock (a later `--apply`
   takes it over and reports it as stale). A killed apply therefore never stops autolaunch or
   the tick. The lock is honored at the top of `autolaunch_dispatch` (before
   `launch_home_session`), at the top of `autorestore_walk`, and by `create_claude_session`
   (manual `--start`, `-n`). It is not consumed on sight (unlike `.claudemux-restarting`).
   Call `ensure_gitignore_entry()` for it before creating it when BASE_DIR is a repo.
1b. **Post-lock rescan:** the report steps (grep, tmux) are slow, so after taking the lock the
   tree is rescanned and a plan signature (class, path, dest, link target, method, content hash
   per record) is compared with the one the report showed. Any difference aborts before the
   first change and releases the lock.
2. **Manifest:** write `~/.claude-mux/migrations/agents-md-<timestamp>.json` atomically (temp
   file then `mv`) with every planned operation **before** any change. Per operation: class,
   path, repo root, method (`git mv` or `mv`), original symlink target (LINK, GEMINI-LINK),
   sha256 of any removed AGENTS.md or stub, and git state per file (tracked, ignored, staged or
   unstaged edits present). Update each operation's status after it completes.
   It is a log for diagnosis and manual recovery; there is no `--undo` (decided 2026-09-30).
3. **Operations, top-down**, each **revalidated immediately before it runs** (MIGRATE: the
   destination is still absent, and `mv -n` is the backstop; IDENTICAL: still `cmp`-equal and
   no links; LINK: still a link to `CLAUDE.md`) and post-checked (source gone, AGENTS.md a
   regular file with the recorded sha256):
   - "Tracked" means `git -C <dir> ls-files --error-unmatch <file>` succeeds; the repo root is
     `git -C <dir> rev-parse --show-toplevel` (handles nested repos and submodules).
   - Sequence is chosen per file from `ls-files --error-unmatch` (tested in scratch repos):
     - CLAUDE.md tracked (AGENTS.md tracked link or file, untracked, or absent): `git mv -f
       CLAUDE.md AGENTS.md`. Verified: works when AGENTS.md is a tracked symlink (index type
       change, unstaged edits to CLAUDE.md preserved) and when it is an untracked link.
     - CLAUDE.md untracked or gitignored, AGENTS.md a tracked link: `mv -f CLAUDE.md
       AGENTS.md`, then `git add -- AGENTS.md` (only that path).
     - Neither tracked: plain `mv -f`, no git call.
     - **Never** `git add -A -- CLAUDE.md AGENTS.md`: it is fatal (`pathspec did not match`)
       when CLAUDE.md is ignored or untracked-and-gone, and it would stage unrelated edits.
   - INVERSE, STUB, GEMINI-LINK: if tracked, `git rm --cached -f -q -- <file>` then unlink
     (`-f` because staged edits differing from both HEAD and the worktree make plain
     `--cached` refuse); otherwise unlink.
   - **Never commit.** Repos get uncommitted changes for review. Unstaged edits survive `git mv`.
     A locked index (`.git/index.lock`) is a partial failure and is recorded.
4. **Verify:** rescan; the post-condition is no CLAUDE.md or CLAUDE.local.md in any walk-up path.
   Re-run the same walk-up check immediately before the restarts (a live session running
   `/init` after verify could recreate one); the drift scan (D7) is the backstop.
5. **Release the lock and write the marker (D7)** after verify, before any restart.
6. **On failure** (a failed operation or a failed verify): stop, release the lock, mark the
   manifest `failed`, **remove the migrated marker**, and print a "TREE IS MIXED" block: which
   paths completed, which are pending or failed, the paths still holding a CLAUDE.md after
   verify, and the manifest path. A re-run is idempotent (completed paths report DONE).
   Otherwise recovery is manual: reverse the recorded operations (`git mv` back or `git
   checkout` for tracked files, `mv` back and recreate the link from the recorded target for
   the rest). INT/TERM/HUP during apply marks the manifest `interrupted` and releases the lock.

### D6. Restart
Running sessions loaded their instructions at process start, so after a migration they are
stale. After the tree verifies, `--apply` restarts running managed sessions unless
`--no-restart`:
- The restart-all logic is inline in `src/90-dispatch.sh:220-305`, not a function. Extract
  `restart_sessions_in` and call it from both `--restart` and migration. Contract: input is a
  list of `name|dir` pairs; output is the list of failed session names plus a return code; it
  keeps `detect_github_ssh_accounts`, the `DRY_RUN` branch, the caller partition (caller last,
  in place) and the `.claudemux-restarting` wrapping; the banner text is a parameter. The
  current block ignores `create_claude_session`'s return (`:280-288`), so failure capture is
  new behavior, and `--restart`'s own exit code must stay exactly as today (no new nonzero
  exit). `get_managed_session_names` and the running-session scan stay in `--restart`.
  BASE_DIR scoping compares physical paths with a trailing-slash prefix match
  (`session_marker_dir` falls back to `pane_current_path`), so `/x/Claude2` never matches
  `/x/Claude`.
  Re-execing `--restart` would also restart sessions outside `BASE_DIR` (for example started
  with `-d`), which this feature must not do.
- Scope: running managed sessions under `BASE_DIR`. Stopped sessions pick the change up on next
  launch.
- The confirmation states that restart-all force-restarts protected sessions, lists busy
  (mid-turn) sessions, and offers `--no-restart`. Restart interrupts a mid-turn session and
  clears crash-loop history for restarted sessions; conversation history resumes (`-c`).
- The calling session restarts last, in place. **Print the full summary before sending `/exit`
  to the caller**: output after that is lost, and `--apply` runs inside that pane.
- The lock is already released (D5.5). Existing `.claudemux-restarting` locks cover the restart
  windows, and a tick relaunch after verify runs against the migrated tree, which is harmless.
- A session that fails to return does not roll back the rename. The report names it.
- `--apply` from a terminal that is not a managed session (no caller) skips the in-place step.
- Each restarted session goes through the normal `Ready?` handshake.

### D7. Marker and drift
`BASE_DIR/.claudemux-agents-migrated` (auto-gitignored by `.claudemux-*` when BASE_DIR is a
repo; via `ensure_gitignore_entry()`) records date, file count and manifest path. **It is a
record, not a gate.** Every run rescans the tree. Both new markers
(`.claudemux-agents-migrated`, `.claudemux-migrating/`) go in the CODEMAP Marker File Registry.

`/init` writes a CLAUDE.md, and a merge or checkout of an older branch or worktree can bring
one back, so a CLAUDE.md can reappear while the marker still says "migrated". The drift scan (`agents_md_drift_notice`,
implemented) runs in the home session only (never in other sessions' `--on-prompt`), at most
once a day (its own stamp `~/.claude-mux/tip-state/agents-drift`), and only when the marker
exists; cost is a marker test, a date stamp check, the tmux home check, then one pruned `find`.
It names any reappeared path. `--apply` with nothing to do on a clean tree also writes the
marker ("already migrated", for example renamed by hand).

### D8. New-project and template behavior
- `apply_template` (`src/80-templates-restore.sh:26-76`, hardcodes `CLAUDE.md` at 33 and 75-76)
  writes `AGENTS.md` when the version gate passes and no CLAUDE.md exists in the target's
  walk-up path, else `CLAUDE.md` with a one-line note. No new config var.
- `--save-template` (`src/75-tip-notices.sh:540-542`) reads AGENTS.md if present, else CLAUDE.md.
- **Injection prompt:** edit `build_system_prompt` (`src/30-helpers.sh`) **once**; both launch
  paths call it. The "never create or edit a CLAUDE.md (it makes Claude Code ignore every
  AGENTS.md)" line is conditional on the project being in an AGENTS.md tree, so other sessions
  do not pay for the tokens. Also add `--migrate-agents-md` to the compressed feature list, the
  trigger rules (confirm before `--apply`) and the `--commands`/`--guide` lookups; fix the
  CLAUDE.md-template wording at `src/30-helpers.sh` ~698 and ~760. Verify with
  `claude-mux --print-system-prompt`. Update the README "Session System Prompt" section.

### D9. Remove multi-coder files
Codex reads AGENTS.md natively. Gemini CLI reads it only if `context.fileName` in
`~/.gemini/settings.json` lists it (see Decisions), so claude-mux stops creating links for both.
- **Stop creating links** (Jonathan, 2026-09-30). Delete `setup_multi_coder_files()`
  (`src/50-restore-state.sh:745`) and its call (`src/55-session-launch.sh:125`).
- **Delete links when found:** the migration removes AGENTS.md and GEMINI.md symlinks (LINK,
  GEMINI-LINK). A real file is never touched.
- `MULTI_CODER_FILES` (`src/00-defaults.sh:97`) and `--no-multi-coder` (`src/10-flags.sh:19`,
  `:482`, `:552-553`) become accepted no-ops with a deprecation warning printed once (a stamp file under
  `~/.claude-mux/`; each launch is a separate process, so a stamp is required), and the
  `-n`-only validation at `:552-553` is dropped (the flag is a no-op everywhere), then are
  deleted in a later minor, along with `config_help` (`:203-205`), `commands_help` (`:313`),
  `config.example`, README, `docs/GUIDE.md` and the tip at `src/75-tip-notices.sh:23`.
  Deviation from the deprecation policy: the "keep it functional" period is waived for this
  var, because the links are exactly what this change removes. Consequence, accepted: Codex
  users in unmigrated trees no longer get an auto-created AGENTS.md link.

## Files affected
- `src/00-defaults.sh`, `src/10-flags.sh` (flags, `config_help`, `commands_help`)
- `src/30-helpers.sh` (`build_system_prompt`: injection, feature list, triggers, lookups)
- `src/50-restore-state.sh` (delete the symlink function)
- `src/55-session-launch.sh` (remove the call; honor the migration lock in `create_claude_session`)
- `src/75-tip-notices.sh` (`--save-template`, tip text, drift notice)
- `src/80-templates-restore.sh` (`apply_template`; lock check in `autolaunch_dispatch` and `autorestore_walk`)
- `src/90-dispatch.sh` (dispatch case; extract `restart_sessions_in`)
- New module `src/65-agents-md-migration.sh` (between `60-discovery` and `70-start-launch` in the Makefile). `src/70-start-launch.sh` changes only the `build_system_prompt` call (project dir arg): `launch_single_session` deliberately does not check the lock, because it is the wrapper's in-place relaunch entry; the lock is honored one level up in `launch_home_session` and `autolaunch_dispatch`.
- Docs: `config.example`, README + translations (batched at release), `docs/CLI.md`,
  `docs/GUIDE.md`, `docs/ISSUES.md`, `dev/IMPLEMENTATION-SPEC.md` (settings table, deprecation
  note, function docs), `dev/CODEMAP.md` (+ `make codemap`, Marker File Registry),
  `dev/SKELETON.md` (new flow; refresh the stale caller-restart text near line 890),
  `CHANGELOG.md`, `internal/tips.md`, `VERSION=`. `install.sh` appears not to reference
  `MULTI_CODER_FILES` (recheck).

## Decisions (Jonathan, 2026-09-30)
1. **Gemini:** proceed without further verification. Docs and README state that Gemini CLI
   needs `"context": {"fileName": ["AGENTS.md"]}` in `~/.gemini/settings.json` (unverified
   whether the upstream default has changed; issue #12345 suggests not). claude-mux creates
   no Gemini links. Sources: github.com/google-gemini/gemini-cli/issues/12345,
   geminicli.com/docs/cli/gemini-md/.
2. **`/config` "Project instructions" toggle:** not needed. Dropped.
3. **`.claude/AGENTS.md`:** there should be none. Any found is an ANOMALY: reported, and the
   run aborts. No double-load policy is needed.
4. **CLAUDE.md symlinks:** verified: a symlinked CLAUDE.md counts as a CLAUDE.md and suppresses
   the fallback. Every CLAUDE.md found is reported. A symlink to AGENTS.md is removed; anything
   else is reported.
5. **Multi-coder links:** stop creating them; delete when found (D9). Deprecation-policy grace period waived for `MULTI_CODER_FILES` and `--no-multi-coder`.

## Remaining open items
1. **Open-source impact.** Renaming this repo's own CLAUDE.md breaks contributors on Claude
   Code older than 2.1.277. README must state the minimum version.

## Not doing
- Auto-committing anything in any repo.
- An automated `--undo` (decided against 2026-09-30).
- Migrating projects outside `BASE_DIR`.
- Restarting Claude Code sessions not managed by claude-mux.
- A per-project marker (the constraint spans ancestors, so migration is tree-wide).
