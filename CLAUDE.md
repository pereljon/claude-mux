# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project

**claude-mux** -- persistent Claude Code sessions in tmux. Shell script + macOS LaunchAgent. Deliverables: `claude-mux`, `install.sh`, `config.example`, `com.user.claude-mux.plist`.

## Design Principles

Infrastructure, not a framework. Keep sessions alive, get out of the way.

- **Lean over featureful.** Don't duplicate what Claude Code or tmux already handle.
- **Support, don't impose.** Make Claude Code persistent and accessible, not reshaped.
- **Conversational first.** Natural language in-session is the primary interface.
- **Eliminate complexity, don't relocate it.** Every abstraction must remove more burden than it introduces.

## Documentation Roles

| File | Purpose |
|------|---------|
| `CLAUDE.md` | Conventions, checklists, guardrails for working in this repo |
| `implentation-spec.md` | Product spec: architecture, config reference, design decisions, translation standards, deprecation policy |
| `README.md` | End-user installation, usage, configuration |
| `CHANGELOG.md` | What changed per release |

## Non-Obvious Behaviors

These affect how code changes should be made. Full architecture is in `implentation-spec.md`.

- **Tmux-aware sessions**: each session gets `--append-system-prompt` with its tmux session name for self-referencing slash commands via `send-keys`
- **Multi-coder symlinks**: `AGENTS.md`/`GEMINI.md` created as symlinks to `CLAUDE.md`. Configurable via `MULTI_CODER_FILES`.
- **Ready trigger**: sends `ready` after Claude loads; expects "Ready." response to confirm session is alive
- **Output display tags**: listing commands wrap output in `<assistant-must-display>` XML tags when stdout is not a TTY
- **Caller-last restart ordering**: `--restart` (all) from inside a session restarts the calling session last
- **Home session**: session named `home` in `$BASE_DIR`, always protected, requires `--force` to shut down

## Security Context

Single-user tool on the user's own account. Threat model: accidental footguns (path traversal, injection via user-supplied args), not multi-user or adversarial scenarios.

## Working Rules

- **Questions vs. implementation**: answer questions as questions. Don't start coding until explicitly asked.
- **No speculation as fact**: distinguish what you know from what you're guessing. Say "I'm not sure" when you can't verify.
- **No LLM-stereotype writing** in human-facing content: no em dashes, no "delve", "leverage", "streamline", "excited to share". Write like a developer.

## Interactive Commands

Commands that attach (`-t`, `-d`/`-n` without `--no-attach`) are user-only -- never run from inside a session. From inside sessions:
- Safe: `-l`, `-L`, `-s`, `--shutdown`, `--restart`, `--permission-mode`, `--list-templates`, `--guide`
- Must add `--no-attach`: `-d`, `-n`
- Never use: `-t`

## Development Workflow

Edit the repo copy (`claude-mux`), not the installed copy (`~/bin/claude-mux`). Deploy after commit: `cp claude-mux ~/bin/`

## Git Approvals

Each step requires explicit user approval. Approval for one step does not imply approval for the next.

1. **Commit**: propose the commit message and changed files, wait for approval before running `git commit`
2. **Push**: wait for explicit approval before running `git push`
3. **Release**: only the user can authorize a release (tag + push tag). "Commit" or "push" do not imply release.

After completing work, proactively ask which steps the user wants: "Want to commit, push, or release?"

## Testing Plan

Before coding a new feature or change, review with the user: happy path, edge cases, flag conflicts, config migration, injection prompt updates, display changes. Get confirmation before writing code.

## Change Checklist

After any code change, check whether these need updating:

- `README.md` + `translations/README.*.md` (translation standards in `implentation-spec.md`)
- `config.example` + `~/.claude-mux/config` (new settings)
- `install.sh` (new flags, config generation)
- `implentation-spec.md` (architecture, settings table, function docs)
- `CLAUDE.md` (if key behaviors changed)
- **Injection prompt** in both `create_claude_session` and `launch_single_session`
- **Session System Prompt** section in README (must match injection)
- `ISSUES.md` (new bugs, resolved entries)
- `CHANGELOG.md` (new features, fixes, removals per release)
- `VERSION=` bump if needed (semver: patch/minor/major)
- Deprecation: warn for 1-2 minor versions before removing (details in `implentation-spec.md`)

When proposing or making multiple changes, consider logical ordering -- some changes should be performed before others (e.g. move code to a new location before updating references to it, validate inputs before using them).
