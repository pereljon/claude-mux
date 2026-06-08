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
| `implentation-spec.md` | Product spec: architecture, config reference, design decisions, translation standards, deprecation policy |
| `README.md` | Landing page: install, capabilities, conversational examples, links to docs |
| `CHANGELOG.md` | What changed per release |
| `docs/CLI.md` | Full CLI command reference for scripting and automation |
| `docs/guide.md` | Configuration, session details, internals, troubleshooting |
| `docs/INSTALL.md` | Full installation guide (curl, Homebrew, manual, uninstall) |
| `docs/FAQ.md` | Common questions about claude-mux |
| `docs/ISSUES.md` | Open bugs, planned features, resolved issues |
| `docs/CODEMAP.md` | Function index, config vars, dispatch table, marker file registry — for locating things in the script |
| `docs/SKELETON.md` | Pseudo-code showing script structure, logic flow, and key invariants — for understanding how the script works |
| `docs/features/<feature>.md` | Per-feature design doc: the implementable spec for a feature, extracted from `docs/ISSUES.md` once it's ready to build |
| `docs/features/<feature>-tests.md` | Per-feature test plan: happy path, edge cases, verification steps, pre-build and post-build checks |

**Feature design + test docs convention (decided 2026-06-07):** when a planned feature in `docs/ISSUES.md` matures to "ready to build," lift it into a dedicated design doc at `docs/features/<feature>.md` and a matching test plan at `docs/features/<feature>-tests.md`. `docs/ISSUES.md` stays the planned-features tracker; the `docs/features/` pair is the implementable spec + test plan that the build works from. Verify assumptions the design rests on *before* finalizing the design doc, so the docs reflect verified reality, not assumptions.

## Non-Obvious Behaviors

These affect how code changes should be made. Full architecture is in `implentation-spec.md`. Line numbers cited here are approximate — `docs/CODEMAP.md` has the authoritative function index with current line ranges.

- **Tmux-aware sessions**: each session gets `--append-system-prompt` with its tmux session name for self-referencing slash commands via `send-keys`
- **Multi-coder symlinks**: `AGENTS.md`/`GEMINI.md` created as symlinks to `CLAUDE.md`. Configurable via `MULTI_CODER_FILES`.
- **Ready trigger**: `poll_until_ready` waits until the session is genuinely idle (busy = `esc to interrupt` in the bottom status lines; ready = not busy + prompt drawn + quiescent, ~120s timeout) before sending `Ready?`, so it does not misfire during a resume-time compaction. Claude responds with "Session ready!" plus a second line "Running [model] in [mode] mode." — the injection passes the permission mode string at launch so Claude can report it accurately
- **Output display tags**: listing commands wrap output in `<assistant-must-display>` XML tags when stdout is not a TTY
- **Caller-last restart ordering**: `--restart` (all) from inside a session restarts the calling session last
- **Home session**: session named `home` in `$BASE_DIR`, protected by default (via `$BASE_DIR/.claudemux-protected` marker, created by `--install`), requires `--force` to shut down
- **LaunchAgent scope**: the LaunchAgent only manages the `home` session - it checks if `home` is running and starts it if not. It does not start, restart, or monitor any other sessions.
- **Script, not binary**: claude-mux is a shell script, not a compiled binary. Every invocation reads the script fresh from disk - there is no "stale binary in memory". After `brew upgrade claude-mux`, any new `claude-mux` command immediately uses the updated script. However, running sessions have the injection prompt baked in at creation time (via `--append-system-prompt`). Sessions won't pick up injection changes until restarted. After an upgrade, say "restart all sessions" or run `--update` (which calls `--restart` automatically).
- **Remote Control reconnect**: RC connections are tied to the tmux session. When a session is restarted (via `--restart`, `--update`, or crash recovery), the RC connection drops and must be manually reconnected after ~5-10 seconds. This is expected behavior, not a bug. `/compact` also drops RC - when sent via `claude-mux -s SESSION /compact` or the conversational trigger, a background monitor sends `Ready?` after compact completes to reconnect RC without restarting the session; when typed directly in the pane, run `--restart SESSION` manually to recover.
- **Version injection**: `get_version_prompt_lines()` reads `~/.claude-mux/.update-check`; if a newer version is cached, it appends an update note telling Claude to notify the user and suggest "update claude-mux"
- **Claude Code upgrade detection** (distinct from the above, which is about the claude-mux script): each session stores the `claude` binary identity (`realpath:mtime`) in the `@claude-mux-claude-id` tmux option at launch. `detect_claude_upgrade()` in the on-prompt hook compares it on each prompt and injects a one-shot "Claude Code was upgraded; restart this session" notice when it changes (acking by overwriting the option). Notify-only; a `--restart` re-captures the id so it self-clears.
- **Launch wrapper**: the generated launch script passes the system prompt via `--append-system-prompt-file <temp-path>` (not inline, so it's not in `ps`); the prompt temp file is deleted right after the ready handshake (Claude reads it once at startup), with the script's `trap` as backstop. A clean in-pane `/exit` (rc 0) removes the marker + temp files and `kill-session`s the tmux session (no lingering shell pane); a crash leaves the pane for the restore tick. `create_claude_session` is `send-keys`-into-shell (pane would otherwise linger); `launch_single_session` is the pane command.
- **Session status**: `>` prefix marks the calling session (via `$TMUX_PANE`); `protected` status for protected+running sessions; `stopped` for protected+not-running

## Project Folder Indicators - Marker-File Philosophy

Per-project state lives in the project folder, not in central config. State files use the prefix `.claudemux-` and are auto-added to `.gitignore` when claude-mux creates them in a git-tracked project.

| Marker | Meaning |
|---|---|
| `.claudemux-ignore` | Hide project from `claude-mux -L` and `discover_projects()` |
| `.claudemux-protected` | Set `@claude-mux-protected = 1` on the tmux session at launch |
| `.claudemux-running` | Auto-restore intent: session should be alive. The `--autolaunch` tick restores it if Claude died. Removed on clean `/exit` (rc 0) or `--shutdown`. Written at launch (not for home). |

**Why marker files, not config:**
- State follows the folder across renames, moves, and machine syncs.
- Discoverable from `ls -la` inside the project.
- One gitignore pattern (`.claudemux-*`) covers all current and future markers.
- No central registry to corrupt or drift.

**Conventions when adding new per-project state:**
- Boolean flags: empty file at `.claudemux-<name>`, presence = on.
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

- **Consult docs before coding**: before writing any code or starting a debug session, read `docs/SKELETON.md` to understand the logic flow and `docs/CODEMAP.md` to locate the relevant functions. Don't grep blind.
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

Edit the repo copy (`claude-mux`), not the installed copy (`~/bin/claude-mux`). Deploy after commit: `cp claude-mux ~/bin/`

Before coding any change, apply the **Consult docs before coding** rule (Working Rules) to scope what's affected before editing.

### Code Review Before Release

Required scope depends on version bump:

- **Patch (x.y.Z)**: review only the changed functions
- **Minor (x.Y.0)**: review all functions added or modified in the release
- **Major (X.0.0)**: full code review of the entire script

Use `docs/SKELETON.md` to understand the impact on logic flows and `docs/CODEMAP.md` to identify which functions changed and what calls them. Use the `superpowers:code-reviewer` agent. Address CRITICAL and HIGH issues before committing.

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

- `README.md` + `translations/README.*.md` (translation standards in `implentation-spec.md`)
- `config.example` + `~/.claude-mux/config` (new settings)
- `install.sh` (new flags, config generation)
- `implentation-spec.md` (architecture, settings table, function docs)
- `CLAUDE.md` (if key behaviors changed)
- **Injection prompt** in both `create_claude_session` and `launch_single_session`
- **Session System Prompt** section in README (must match injection)
- `docs/CODEMAP.md` (new/renamed/removed functions, new dispatch cases, new config vars, significant line range shifts)
- `docs/SKELETON.md` (logic flow changes: new conditions, changed call sequences, new control paths)
- `ISSUES.md` (new bugs, resolved entries)
- `CHANGELOG.md` (new features, fixes, removals per release)
- `VERSION=` bump if needed (semver: patch/minor/major)
- Deprecation: warn for 1-2 minor versions before removing (details in `implentation-spec.md`)
- **When adding a config var**: update `config_help()` in the script and add an entry to `config.example`
- **When adding a CLI flag**: update `commands_help()` in the script and the compressed feature list in `build_system_prompt()`
- **When adding a new lookup flag** (`--*-help`, `--*-commands`): add it to the Reference lookups meta-block in `build_system_prompt()`
- **When adding a user-facing feature**: add a tip to `internal/tips.md` and embed it in the `tip_of_day()` array in the script. Tips teach users how to use conversational commands (the injection triggers), not CLI flags or internal implementation details.

When proposing or making multiple changes, consider logical ordering -- some changes should be performed before others (e.g. move code to a new location before updating references to it, validate inputs before using them).
