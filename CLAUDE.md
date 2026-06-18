# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**claude-mux** -- persistent Claude Code sessions in tmux. Shell script + macOS LaunchAgent. Deliverables: `claude-mux`, `install.sh`, `config.example`, `com.user.claude-mux.plist`.

This is an open-source project with external users. Treat it accordingly: safety, portability, stability matter.

## Feature Freeze

**Status: LIFTED** as of 2026-05-30. v2.0 planning and implementation work has begun. Patches in the v1.14.x range and v2.x minors are in scope.

Sequencing is tracked in `docs/ISSUES.md`:
- **Planned Patches** section: small UX work shipping as v1.14.x minors before v2.0.
- **v2.0 Milestone** section: architectural changes split across v2.0 ("Self-healing + situational awareness"), v2.1 ("Context discipline"), v2.2 ("Agent network").

**Prior exception (v1.13.0):** `--restart --fresh` / "restart this session fresh" / "kill this session" was shipped under the previous freeze due to high severity (MCP installs unusable without it).

## Design Principles

Infrastructure, not a framework. Keep sessions alive, get out of the way.

- **Lean over featureful.** Don't duplicate what Claude Code or tmux already handle.
- **Support, don't impose.** Make Claude Code persistent and accessible, not reshaped.
- **Conversational first.** Natural language in-session is the primary interface.
- **Eliminate complexity, don't relocate it.** Every abstraction must remove more burden than it introduces.
- **Session management is invisible.** Claude should be able to manage sessions without permission prompts interrupting the conversation. Achieved two ways: (1) claude-mux is added to each project's allow list by `setup_claude_mux_permissions()` so Claude can run it freely; (2) the injection instructs Claude to use claude-mux rather than raw shell commands that would trigger prompts. Destructive operations (e.g. `--delete`) may still require confirmation - that's intentional, not a gap.
- **Session names, not paths.** CLI commands operate on session names, not directory paths. The script resolves session names to directories internally via tmux (running sessions) or `PROJECT_DIRS` scanning (idle projects). Exceptions that accept paths (e.g. `--move` destination, `-d`/`-n` launch directory) require explicit approval before adding.

## Documentation Roles

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Conventions, checklists, guardrails for working in this repo |
| `dev/IMPLEMENTATION-SPEC.md` | Product spec: architecture, config reference, design decisions, translation standards, deprecation policy |
| `README.md` | Landing page: install, capabilities, conversational examples, links to docs |
| `CHANGELOG.md` | What changed per release |
| `docs/CLI.md` | Full CLI command reference for scripting and automation |
| `docs/GUIDE.md` | Configuration, session details, internals, troubleshooting |
| `docs/INSTALL.md` | Full installation guide (curl, Homebrew, manual, uninstall) |
| `docs/FAQ.md` | Common questions about claude-mux |
| `docs/ISSUES.md` | Open bugs, planned features, resolved issues |
| `dev/CODEMAP.md` | Function index, config vars, dispatch table, marker file registry — for locating things in the script |
| `dev/SKELETON.md` | Pseudo-code showing script structure, logic flow, and key invariants — for understanding how the script works |
| `dev/features/<feature>.md` | Per-feature design doc: the implementable spec for a feature, extracted from `docs/ISSUES.md` once it's ready to build |
| `dev/features/<feature>-tests.md` | Per-feature test plan: happy path, edge cases, verification steps, pre-build and post-build checks |

**Feature design + test docs convention (decided 2026-06-07):** when a planned feature in `docs/ISSUES.md` matures to "ready to build," lift it into a dedicated design doc at `dev/features/<feature>.md` and a matching test plan at `dev/features/<feature>-tests.md`. `docs/ISSUES.md` stays the planned-features tracker; the `dev/features/` pair is the implementable spec + test plan that the build works from. Verify assumptions the design rests on *before* finalizing the design doc, so the docs reflect verified reality, not assumptions.

## Non-Obvious Behaviors

These affect how code changes should be made. Full architecture is in `dev/IMPLEMENTATION-SPEC.md`. Line numbers cited here are approximate — `dev/CODEMAP.md` has the authoritative function index with current line ranges.

- **Tmux-aware sessions**: each session gets `--append-system-prompt` with its tmux session name for self-referencing slash commands via `send-keys`
- **Multi-coder symlinks**: `AGENTS.md`/`GEMINI.md` created as symlinks to `CLAUDE.md`. Configurable via `MULTI_CODER_FILES`.
- **Ready trigger**: `poll_until_ready` waits until the session is genuinely idle (busy = `esc to interrupt` in the bottom status lines; ready = not busy + prompt drawn + quiescent, ~120s timeout) before sending `Ready?`, so it does not misfire during a resume-time compaction. Claude responds with "Session ready!" plus a second line "Running [model] in [mode] mode." — the injection passes the permission mode string at launch so Claude can report it accurately
- **The `Ready?` handshake turn swallows any other injected content (general caveat)**: the post-restart / post-compact `Ready?` prompt forces Claude to reply with exactly the two ready lines and "Nothing else." Anything a `UserPromptSubmit` hook injects into *that* turn is therefore never surfaced to the user — and worse, any per-turn side effect the hook commits (state stamp, throttle, one-shot ack) still fires, so the message is *consumed* without being seen. This bit the daily tip, the claude-mux update notice, and the Claude Code upgrade notice (all injected by `on_prompt`), which is why `on_prompt` now detects the literal `Ready?` (`prompt.strip() == "Ready?"`) and **no-ops on it** before any injection or stamp (fixed v2.0.8; see `dev/features/tip-ready-handshake.md`). **Rule for future work:** any new `UserPromptSubmit` injection MUST short-circuit on the handshake the same way, or it will be silently eaten and burn its budget on the first prompt after every restart. The handshake string is a fixed literal emitted by `await_ready_handshake`, both launch wrappers, and the `on_compact` monitor.
- **Output display tags**: listing commands wrap output in `<assistant-must-display>` XML tags when stdout is not a TTY
- **Caller-last restart ordering**: `--restart` (all) from inside a session restarts the calling session last, **in place** (`restart_caller_in_place`: set `@claude-mux-restart` + `/exit`, the looped wrapper relaunches in-pane) rather than killing its pane. Non-caller sessions keep the kill+recreate path.
- **Home session**: session named `home` in `$BASE_DIR`, protected by default (via `$BASE_DIR/.claudemux-protected` marker, created by `--install`), requires `--force` to shut down
- **LaunchAgent scope**: the LaunchAgent only manages the `home` session - it checks if `home` is running and starts it if not. It does not start, restart, or monitor any other sessions.
- **Script, not binary**: claude-mux is a shell script, not a compiled binary. Every invocation reads the script fresh from disk - there is no "stale binary in memory". After `brew upgrade claude-mux`, any new `claude-mux` command immediately uses the updated script. However, running sessions have the injection prompt baked in at creation time (via `--append-system-prompt`). Sessions won't pick up injection changes until restarted. After an upgrade, say "restart all sessions" or run `--update` (which calls `--restart` automatically).
- **Remote Control reconnect**: RC connections are tied to the tmux session. When a session is restarted (via `--restart`, `--update`, or crash recovery), the RC connection drops and must be manually reconnected after ~5-10 seconds. This is expected behavior, not a bug. `/compact` also drops RC - when sent via `claude-mux -s SESSION /compact` or the conversational trigger, a background monitor sends `Ready?` after compact completes to reconnect RC without restarting the session; when typed directly in the pane, run `--restart SESSION` manually to recover.
- **Version injection**: `get_version_prompt_lines()` reads `~/.claude-mux/.update-check`; if a newer version is cached, it appends an update note telling Claude to notify the user and suggest "update claude-mux"
- **Claude Code upgrade detection** (distinct from the above, which is about the claude-mux script): each session stores the `claude` binary identity (`realpath:mtime`) in the `@claude-mux-claude-id` tmux option at launch. `detect_claude_upgrade()` in the on-prompt hook compares it on each prompt and injects a one-shot "Claude Code was upgraded; restart this session" notice when it changes (acking by overwriting the option). Notify-only; a `--restart` re-captures the id so it self-clears.
- **Launch wrapper (looped, restart-in-place)**: the generated launch script passes the system prompt via `--append-system-prompt-file <path>` (not inline, so it's not in `ps`). The prompt lives at `<project>/.claudemux-prompt` (mode 600, in the project folder — stable, not `$TMPDIR`-reaped — so it survives and is regenerated across relaunches), NOT deleted after the ready handshake; the wrapper owns its lifetime. The `claude` invocation runs inside a `while` loop. On a clean exit (rc 0) the wrapper checks the `@claude-mux-restart` tmux option: if set, it relaunches `claude` in the **same pane** (resume, or fresh when the option is `fresh`) — consuming the option, regenerating the prompt via `--print-system-prompt`, and backgrounding `--await-ready` to handshake from outside the busy pane — instead of tearing down. With no restart pending it removes the marker + prompt + launch script and `kill-session`s the tmux session (no lingering shell pane). A crash (non-zero) breaks the loop, leaving the pane for the restore tick. This loop is what fixes restart-all-from-home (the caller resumes in-pane instead of being killed + forked). `create_claude_session` is `send-keys`-into-shell; `launch_single_session` is the pane command. Both wrappers are identical in shape.
  - **This wrapper is malleable, not a fixed invariant.** Its behaviors are design *choices*, not constraints to engineer around. When a problem traces back to what the wrapper does (e.g. the caller-restart context-loss investigation, where the old clean-exit teardown is what killed an in-pane relaunch — now fixed by the loop), the right move is often to **change the wrapper itself** rather than build external machinery to work around it. Question this wrapper before adding handoffs/helpers/launchd tricks around it.
- **Session status**: `>` prefix marks the calling session (via `$TMUX_PANE`); `protected` status for protected+running sessions; `stopped` for protected+not-running

## Project Folder Indicators - Marker-File Philosophy

Per-project state lives in the project folder, not in central config. State files use the prefix `.claudemux-` and are auto-added to `.gitignore` when claude-mux creates them in a git-tracked project.

| Marker | Meaning |
|---|---|
| `.claudemux-ignore` | Hide project from `claude-mux -L` and `discover_projects()` |
| `.claudemux-protected` | Set `@claude-mux-protected = 1` on the tmux session at launch |
| `.claudemux-running` | Auto-restore intent: session should be alive. The `--autolaunch` tick restores it if Claude died. Removed on clean `/exit` (rc 0, no restart pending) or `--shutdown`. Written at launch (not for home). Preserved through a `--restart` (via `shutdown_single_session`'s `preserve_marker` arg) so a crashed restart is recoverable. |
| `.claudemux-restarting/` | Transient restart lock (directory; atomic `mkdir`/`rmdir`). Presence = an intentional restart is in flight. Created around each non-caller session's shutdown+create in `--restart`, removed after create. The `--autolaunch` tick consumes it on sight (`rmdir` + defer one tick) so auto-restore doesn't race the restart window. NOT used for in-place caller restarts (the pane never goes down). |
| `.claudemux-prompt` | Per-session system-prompt file (`--append-system-prompt-file`). In the project folder (stable, not `$TMPDIR`-reaped) so it survives + is regenerated (`--print-system-prompt`) across in-place relaunches. Mode 600; removed on final teardown. |

**Why marker files, not config:**
- State follows the folder across renames, moves, and machine syncs.
- Discoverable from `ls -la` inside the project.
- One gitignore pattern (`.claudemux-*`) covers all current and future markers.
- No central registry to corrupt or drift.

**Conventions when adding new per-project state:**
- Boolean flags: empty file at `.claudemux-<name>` (`touch`), presence = on. Long-lived.
- Transient locks: directory at `.claudemux-<name>/` (`mkdir`/`rmdir`). `mkdir` is atomic (claim-this-name fails if it exists), so it doubles as a mutex; `.claudemux-restarting` uses this. Rule of thumb: `mkdir` for locks, `touch` for flags.
- Richer state: JSON file at `.claudemux-<name>.json` (no current cases).
- Always auto-gitignore via `ensure_gitignore_entry()`.
- Folder-name conventions (`-prefix` and `.prefix`) are legacy and still respected by `discover_projects()`, but new features use markers.

**When NOT to use marker files:**
- Truly user-global preferences → `~/.claude-mux/config`.
- Truly session-runtime state → tmux user options (e.g. `@claude-mux-protected`).
- Markers are for state that should travel with the project folder.

## Security Context

Single-user tool on the user's own account. Threat model: accidental footguns (path traversal, injection via user-supplied args), not multi-user or adversarial scenarios.

## Known Issues / Hypotheses

- **`bypassPermissions` confirmation prompt**: Claude shows a warning with "No, exit" / "Yes, I accept" when launched with `bypassPermissions`. The startup poller detects "Yes, I accept", sends Down (to move from option 1 to option 2), waits 1s for the UI to register the selection, then sends Enter. The 1s pause is critical - without it the keystrokes race and confirm "No, exit" instead.
- **`bypassPermissions` requires restart to enter**: cannot switch a running session to `bypassPermissions` mid-session - must restart with the flag. Once in the Shift+Tab cycle, re-entry from other modes is silent (no prompt). Confirmation prompt only fires on initial launch.

## Working Rules

- **Consult docs before coding**: before writing any code or starting a debug session, read `dev/SKELETON.md` to understand the logic flow and `dev/CODEMAP.md` to locate the relevant functions. Don't grep blind.
- **Questions vs. implementation**: answer questions as questions. Don't start coding until explicitly asked.
- **No speculation as fact**: distinguish what you know from what you're guessing. Say "I'm not sure" when you can't verify.
- **No LLM-stereotype writing** in human-facing content: no "delve", "leverage", "streamline", "excited to share". Write like a developer.
- **No em dashes**. Use regular dashes (-) instead, everywhere: code, docs, comments, commit messages.

## Interactive Commands

Commands that attach (`-t`, `-d`/`-n` without `--no-attach`) are user-only -- never run from inside a session. From inside sessions:
- Safe: `-l`, `-L`, `-s`, `--shutdown`, `--restart`, `--permission-mode`, `--list-templates`, `--guide`
- Must add `--no-attach`: `-d`, `-n`
- Never use: `-t`

## Development Workflow

`claude-mux` is a **generated, committed artifact**, built from `src/*.sh` by `make build`. Source of truth is `src/`.

- **Edit `src/*.sh`, never `claude-mux` directly.** A direct edit to `claude-mux` is silently reverted by the next `make build`.
- After editing fragments: `make build`, then `cp claude-mux ~/bin/` to deploy locally (after commit). Smoke-test with `bash ./claude-mux ...`.
- `make check` (`make build && git diff --exit-code claude-mux`) must pass before any commit; the mandatory pre-commit hook enforces this. Install the hook once per clone: `make install-hooks` (sets `core.hooksPath .githooks`).
- Merge conflicts in `claude-mux` are resolved by rebuilding from `src/` (`make build`), never by hand-merging the artifact (`.gitattributes` marks it generated).
- See `dev/IMPLEMENTATION-SPEC.md` "Build / source layout" for the module map.

Before coding any change, apply the **Consult docs before coding** rule (Working Rules) to scope what's affected before editing.

### Workflow Pipeline

The canonical order of a change, start to finish. This list is the *sequence*; the detailed rules live in the sections it links to — do not duplicate them here.

1. **Define the feature** — when a `docs/ISSUES.md` entry is ready to build, lift it to `dev/features/<feature>.md` (see the feature design+test convention under Documentation Roles).
2. **Research & verify assumptions** — confirm what the design rests on against reality (read the actual code, GitHub/vendor docs, run probes) *before* finalizing the plan. Docs must reflect verified reality, not guesses.
3. **Write the design + test plans** — `dev/features/<feature>.md` + `<feature>-tests.md`. Review happy path, edge cases, flag conflicts, config migration, injection/display changes with the user (see Testing Plan). Confirm before coding.
4. **Pre-code compact** — if context is getting heavy, compact before the code phase (coding is the context-hungry part; see the performance rules).
5. **Code** — apply *Consult docs before coding* (read `dev/SKELETON.md` + `dev/CODEMAP.md` first). Edit `src/*.sh` (never `claude-mux` directly), `make build`, then smoke-test the built file (`bash ./claude-mux ...`) as you go.
6. **Code review** — *Code Review Before Release*: scope by version bump; `superpowers:code-reviewer` agent; fix CRITICAL/HIGH. Decide the bump early (it sets review scope) even though `VERSION=` is physically written in step 7.
7. **Update context files** — the *Change Checklist* GATE. After review, so docs reflect the final code: CODEMAP, SKELETON, IMPLEMENTATION-SPEC, README, CHANGELOG, VERSION, ISSUES, injection prompt, etc.
8. **Test** — verify real behavior (happy path + edge cases) on the repo copy. Tests verify correctness; running the actual command verifies the feature works.
9. **Commit** — [approval gate] (see Git Approvals).
10. **Deploy** — `make build` then `cp claude-mux ~/bin/` so local sessions use the new code (after commit).
11. **Push** — [approval gate].
12. **Release** — [approval gate]; only if `claude-mux`/`install.sh` changed; **`make check` must pass clean immediately before `git tag`** (never tag a stale artifact); `git tag` → `git push origin TAG` → `gh release create`, ascending version order (see Git Approvals → Release).
13. **Post-release compact** — `claude-mux -s SESSION '/compact'`.

Plan docs (steps 1-3) come before code; reference/changelog docs (step 7) come after code+review so they describe the final result. Commit, push, and release are independent approval gates — one does not imply the next.

### Code Review Before Release

Required scope depends on version bump:

- **Patch (x.y.Z)**: review only the changed functions
- **Minor (x.Y.0)**: review all functions added or modified in the release
- **Major (X.0.0)**: full code review of the entire script

Use `dev/SKELETON.md` to understand the impact on logic flows and `dev/CODEMAP.md` to identify which functions changed and what calls them. Use the `superpowers:code-reviewer` agent. Address CRITICAL and HIGH issues before committing.

## Git Approvals

Each step requires explicit user approval. Approval for one step does not imply approval for the next.

1. **Commit**: propose the commit message and changed files, wait for approval before running `git commit`
2. **Push**: wait for explicit approval before running `git push`
3. **Release**: only the user can authorize a release. A release requires all three: `git tag vX.Y.Z`, `git push origin vX.Y.Z`, and `gh release create vX.Y.Z`. "Commit" or "push" do not imply release. Pushing a tag alone does NOT create a GitHub Release.
   - **Release gate**: only create a release if `claude-mux` or `install.sh` have changed since the last release. These are the only release assets users download. Injection changes count as functional changes (they alter session behavior). Docs-only changes (translations, FAQ, ISSUES, CHANGELOG, README) are available via the repo and do not need a release.
   - **Release order matters**: the Homebrew bump CI triggers on every `gh release create` and blindly sets the formula to that version. Always create releases in ascending version order. If backfilling an older release after a newer one is already live, manually update the tap formula afterward.

After completing work, proactively ask which steps the user wants: "Want to commit, push, or release?"

After a release completes, compact the session: `claude-mux -s SESSION_NAME '/compact'` where SESSION_NAME is the current tmux session name.

## Testing Plan

Before coding a new feature or change, review with the user: happy path, edge cases, flag conflicts, config migration, injection prompt updates, display changes. Get confirmation before writing code.

## Change Checklist

**GATE: Do NOT suggest commit, push, or release until every item below has been checked and all affected files are updated.** This is not optional - it is a prerequisite before proposing any git operation.

After any code change, check whether these need updating:

- **`make build` + `make check`** — code edits go in `src/*.sh`; rebuild the `claude-mux` artifact and confirm `make check` is clean. The pre-commit hook blocks otherwise. (Never edit `claude-mux` directly.)
- `README.md` + `translations/README.*.md` (translation standards in `dev/IMPLEMENTATION-SPEC.md`)
- `config.example` + `~/.claude-mux/config` (new settings)
- `install.sh` (new flags, config generation)
- `dev/IMPLEMENTATION-SPEC.md` (architecture, settings table, function docs)
- `CLAUDE.md` (if key behaviors changed)
- **Injection prompt** in both `create_claude_session` (`src/55-session-launch.sh`) and `launch_single_session` (`src/70-start-launch.sh`)
- **Session System Prompt** section in README (must match injection)
- `dev/CODEMAP.md` (new/renamed/removed functions, new dispatch cases, new config vars, significant line range shifts)
- `dev/SKELETON.md` (logic flow changes: new conditions, changed call sequences, new control paths)
- `ISSUES.md` (new bugs, resolved entries)
- `CHANGELOG.md` (new features, fixes, removals per release)
- `VERSION=` bump if needed (semver: patch/minor/major)
- Deprecation: warn for 1-2 minor versions before removing (details in `dev/IMPLEMENTATION-SPEC.md`)
- **When adding a config var**: update `config_help()` in the script and add an entry to `config.example`
- **When adding a CLI flag**: update `commands_help()` in the script and the compressed feature list in `build_system_prompt()`
- **When adding a new lookup flag** (`--*-help`, `--*-commands`): add it to the Reference lookups meta-block in `build_system_prompt()`
- **When adding a user-facing feature**: add a tip to `internal/tips.md` and embed it in the `tip_of_day()` array in the script. Tips teach users how to use conversational commands (the injection triggers), not CLI flags or internal implementation details.

When proposing or making multiple changes, consider logical ordering -- some changes should be performed before others (e.g. move code to a new location before updating references to it, validate inputs before using them).
