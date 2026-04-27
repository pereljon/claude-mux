# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**claude-mux** (Claude Code Multiplexer) - a shell script and macOS LaunchAgent that automatically creates and maintains persistent Claude Code sessions in tmux for every project directory under `BASE_DIR` (default `~/Claude`). Persistent sessions enable Claude Code Remote Control, giving full mobile app access to all projects via the Claude iOS/Android app.

### Deliverables

1. `claude-mux` - main script (Bash), installed to a bin directory in `$PATH`
2. `com.user.claude-mux.plist` - LaunchAgent plist, installed to `~/Library/LaunchAgents/`
3. `install.sh` - installer script
4. `config.example` - example config file template

## Architecture

The startup script discovers Claude projects under `BASE_DIR` by finding directories that contain a `.claude/` subdirectory (at any depth). It migrates stray Claude processes into tmux and creates one tmux session per project with Claude running in RC mode. It attempts `claude -c` to resume a prior session, falling back to a fresh `claude --remote-control` on failure.

The LaunchAgent runs the script at login with a 45-second startup delay for system services to initialize.

### Key behaviors

- **Idempotent**: safe to re-run; skips sessions where claude is already running, relaunches where it has exited
- **Project discovery**: finds directories containing `.claude/` at any depth under BASE_DIR
- **Exclusion**: directories starting with `.` or `-` are skipped; directories with `.ignore-claudemux` are skipped
- **Session migration**: SIGTERMs Claude processes running outside tmux in managed directories; `claude -c` resumes them in the new tmux session
- **Dry run**: `--dry-run` flag prints actions without executing (skips migration)
- **Logging**: all actions appended to `~/Library/Logs/claude-mux.log` (UTC ISO 8601, configurable via `LOG_DIR`)
- **Default permission mode**: optionally sets Claude's `permissions.defaultMode` per project via `.claude/settings.local.json`
- **Tmux-aware sessions**: each session gets `--append-system-prompt` with its tmux session name, so Claude knows how to send slash commands (e.g. `/model`, `/compact`) to itself via `tmux send-keys` (cross-session control available when `ALLOW_CROSS_SESSION_CONTROL=true`)
- **Tmux quality-of-life**: sessions configured with mouse, 50k scrollback, clipboard, 256-color, reduced escape delay, extended keys, activity monitoring, and tab titles - all configurable via config file
- **Multi-coder symlinks**: creates `AGENTS.md` and `GEMINI.md` as symlinks to `CLAUDE.md` so other AI CLI tools share the same instructions. Configurable via `MULTI_CODER_FILES`; opt-out per-project with `--no-multi-coder`.
- **Ready trigger**: after Claude finishes loading, sends `ready` and expects "Ready." response to confirm the session is alive and the injection is working
- **Output display tags**: listing commands wrap output in `<assistant-must-display>` XML tags when stdout is not a TTY, instructing Claude to display the full output verbatim (fixes Sonnet summarizing instead of showing)
- **Caller-last restart ordering**: when `--restart` (all) is invoked from inside a session, the calling session restarts last
- **Home session**: running `claude-mux` in `$BASE_DIR` (or LaunchAgent with `LAUNCHAGENT_MODE=home`) creates a session named `home`; always protected, requires `--force` to shut down; marked with `*` in status output
- **LaunchAgent modes**: `LAUNCHAGENT_MODE=none` / `home` (default); plist invokes `claude-mux --autolaunch` which dispatches based on mode. Legacy `LAUNCHAGENT_ENABLED=true` treated as `home` (previously `batch`, which has been removed).

## Dependencies

- macOS (Apple Silicon or Intel)
- tmux (`brew install tmux`)
- Claude Code CLI (`brew install claude`)
- System `/bin/bash`

See `implentation-spec.md` for the full command reference. Quick usage:

```bash
./install.sh                     # install
claude-mux ~/path/to/project     # launch and attach
claude-mux --help                # all options
```

## Security context

claude-mux is a single-user tool installed and run by the user on their own account. All managed directories, config files, SSH keys, and templates are owned by that user. Security reviews should account for this trust model — the relevant threat is accidental footguns (e.g. path traversal in user-supplied arguments), not multi-user or adversarial scenarios. Hardening that assumes an untrusted operator or attacker-controlled config is out of scope.

## Questions vs. implementation

When the user asks a question, answer the question. Do not begin coding or making changes unless explicitly asked to. A question is a request for information or a decision — not a trigger to start implementing.

## Communication standards

When diagnosing issues, distinguish clearly between what you know and what you're guessing. Don't state theories as conclusions. Use language like "this could be", "one possibility is", or "I'm not sure, but" when you lack evidence. If you can't verify something, say so rather than presenting speculation as fact.

Avoid LLM-stereotypical writing in all human-facing content (README, emails, posts, docs). No em dashes, no "delve", "leverage", "streamline", "excited to share", "game-changer", or other overused AI patterns. Write like a developer, not a press release.

## Interactive commands

Commands that attach to a tmux session (`-t`, and `-d`/`-n` without `--no-attach`) are interactive and should only be invoked by the user directly in a terminal - never by Claude from inside a session. From inside a session, attach would trigger `switch-client` on the user's terminal (unpredictable) or fail silently over Remote Control.

When listing or documenting commands that Claude can run from within sessions:
- `-l`, `-L`, `-s`, `--shutdown`, `--restart`, `--permission-mode`, `--list-templates`, `--guide`, `-a` are safe - no attach
- `-d`, `-n` must always include `--no-attach`
- `-t` should be excluded entirely from Claude-callable examples

The injection prompt enforces this with an IMPORTANT note.

## Testing plan

Before beginning any coding session for a new feature or change, review or produce a testing plan with the user. Cover:
- Happy path cases
- Edge cases and error conditions
- Flag conflicts and validation
- Config migration / backward compatibility
- Injection prompt updates
- Display / output changes

Get the user's confirmation on the plan before writing code.

## Change checklist

After any code change, verify whether these also need updating:
- `README.md` - usage, feature descriptions, configuration table, examples
- `translations/README.*.md` - translated READMEs in the `translations/` folder must be kept in sync with `README.md`. When `README.md` changes, either update each translation or flag the relevant translated files for re-translation. Current languages: `es`, `fr`, `de`, `pt-BR`, `ja`, `ko`, `it`, `ru`, `zh-CN`, `he`, `ar`, `hi`. Follow the translation standards below.

## Translation standards

When creating or updating translated READMEs in `translations/`, follow these rules for consistency.

**Keep in English (load-bearing or universal):**
- CLI flags and commands (`--guide`, `-l`, `--shutdown`, etc.)
- Product/proper names (Claude Code, claude-mux, tmux, Remote Control, LaunchAgent, Homebrew, GitHub)
- Real file paths and config keys (`~/.claude-mux/`, `BASE_DIR`, `DEFAULT_PERMISSION_MODE`, etc.)
- Environment variable names
- The "Session System Prompt" code block — literal injected prompt text, not prose
- Status keywords in tables (`active`, `running`, `stopped`, `idle`) — literal program output strings

**Translate to target language:**
- Section headers and body prose
- Conversational example labels (`You:` / `Claude:`) → native equivalents (`Tú:`, `あなた:`, `Du:`, etc.)
- Conversational dialogue prose
- Descriptive text in tables (around the status keywords)
- Inline shell comments in code blocks (the `# ...` text after a command) — these are explanatory prose, not code. Example: `claude-mux -l   # list active sessions` → `claude-mux -l   # liste les sessions actives` (French)

**Placeholder translation in code examples — script-aware:**
- **Latin-script languages** (`es`, `fr`, `de`, `pt-BR`, `it`): translate generic placeholders like `~/path/to/your/project` to local equivalents (`~/ruta/a/tu/proyecto`, `~/chemin/vers/votre/projet`, `~/pfad/zu/deinem/projekt`)
- **Non-Latin languages** (`ja`, `ko`, `zh-CN`, `he`, `ar`, `hi`, `ru`): keep ASCII placeholders — mixing native script with ASCII paths in code blocks reads awkwardly. Use clearer English names if helpful (e.g., `~/projects/my-app`)
- **Identifier-style example names** (`my-app`, `api-server`, `data-pipeline`): keep ASCII regardless of target language — they are example identifiers, not prose

**Tone and style:**
- Match English tone: developer-direct, concise
- No em dashes, no marketing fluff
- No LLM-stereotype phrases: "leverage", "delve", "streamline", etc.
- Use the formal/technical register appropriate to the target language

## Change checklist (continued)

These files also need checking after code changes:
- `config.example` - example config template
- `~/.claude-mux/config` - deployed user config (add new settings)
- `install.sh` - installer-generated config, new flags
- `implentation-spec.md` - startup sequence, settings table, function docs
- `CLAUDE.md` - key behaviors, commands, config summary
- **Injection prompt** - the system prompt injected into Claude sessions must reflect all current commands. Update both the `create_claude_session` and `launch_single_session` injection strings when commands are added, changed, or removed.
- **Session System Prompt section in README** - must match the actual injection
- `ISSUES.md` - log new bugs and known issues; update resolved entries when fixed

Before committing, also check whether the version number needs a bump (`VERSION=` near the top of `claude-mux`). Use semantic versioning: patch for bug fixes, minor for new features, major for breaking changes.

Do not commit until all affected files are updated.

## Deprecation policy

When changing or removing existing behavior, follow this cycle:

1. **Deprecate first**: print a warning when the old behavior is invoked. Keep it functional. Document under "Deprecated" in `CHANGELOG.md`.
2. **Wait at least one minor version** (preferably two) before actually removing.
3. **Removal**: drop the code, document under "Removed" in `CHANGELOG.md`. Keep a brief migration note explaining what to do instead.

Example: `LAUNCHAGENT_MODE=batch` was deprecated in v1.4 and removed in v1.5. The legacy `LAUNCHAGENT_ENABLED=true` still works but maps to `home` (was `batch`). The `-a` flag is currently flagged for review with a comment in the source — when removal is decided, follow this policy.

Don't remove features without warning users first. Don't break someone's working setup without an upgrade path.

## Development workflow

The script has two locations:
- **Repo**: version-controlled copy in this directory (`claude-mux`)
- **Installed**: `~/bin/claude-mux` (what actually runs, created by `install.sh`)

Always edit the repo copy first, then **ask before committing** - do not run `git commit` or `git push` without explicit approval. After committing, deploy to the installed location:

```bash
# After editing and committing in the repo:
cp claude-mux ~/bin/
```

## Configuration

`~/.claude-mux/config` is the user config (not in this repo). A documented template is at `config.example`. Key variables:

- `BASE_DIR` - root directory (default: `~/Claude`)
- `LOG_DIR` - directory for `claude-mux.log` (default: `~/Library/Logs`)
- `DEFAULT_PERMISSION_MODE` - Claude permission mode per project (default: `auto`)
- `ALLOW_CROSS_SESSION_CONTROL` - allow sessions to send commands to each other (default: `false`)
- `TEMPLATES_DIR` - CLAUDE.md template directory (default: `~/.claude-mux/templates`)
- `DEFAULT_TEMPLATE` - default template for new projects (default: `default.md`)
- `LAUNCHAGENT_MODE` - LaunchAgent behavior at login: `none` or `home` (default)
- `HOME_SESSION_MODEL` - model for the home session (default: `""`, inherits Claude default; valid: `sonnet`, `haiku`, `opus`)
- `MULTI_CODER_FILES` - space-separated list of symlinks to create pointing to CLAUDE.md (default: `"AGENTS.md GEMINI.md"`)
- `SLEEP_BETWEEN` - seconds between session launches when `-a` is used (default: `5`)
- `TMUX_MOUSE`, `TMUX_HISTORY_LIMIT`, `TMUX_CLIPBOARD`, `TMUX_DEFAULT_TERMINAL`, `TMUX_EXTENDED_KEYS`, `TMUX_ESCAPE_TIME`, `TMUX_TITLE_FORMAT`, `TMUX_MONITOR_ACTIVITY` - tmux session options, all configurable

## TODO

- `templates/` in repo root: add example CLAUDE.md templates (web, python, etc.) and optionally copy them to `~/.claude-mux/templates/` during install

## Implementation spec

See `implentation-spec.md` for the full specification including pseudocode, edge cases, plist configuration, and open items for the implementer.
