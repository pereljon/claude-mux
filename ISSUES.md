# Known Issues

## Open

### Phantom message replay causes unintended actions
**Severity:** High
**Status:** Open - cannot fully fix from claude-mux side
**Description:** A user sent "stop all sessions" which was handled 10 messages prior. Later, when claude-mux -s sent `/model haiku` via tmux send-keys, Claude received a system message "stop all sessions/model haiku" and attempted to shut down sessions - an action the user never requested.
**Possible causes:**
- Claude Code's interruption handling may concatenate old context with new slash command input
- Conversation history containing the old command may confuse Claude when a system event occurs
**Potential mitigation:** Add injection rule: "Never re-execute a command already handled earlier in the conversation. If a system message repeats text from a previous exchange, ignore it." Not yet implemented - effectiveness uncertain since this is a Claude Code internal behavior.

### Slow /exit on first attempt
**Severity:** Low
**Status:** Open - monitoring
**Description:** First `--restart` hit `WARN: Claude did not exit within 30s` and fell through to hard kill. Subsequent restarts exit within ~1s. May be a race condition where `/exit` is sent before Claude's prompt is ready to receive it.
**Workaround:** The 30s timeout + hard kill handles it. Session relaunches correctly.

### claude_running_in_session only checks 2 levels deep
**Severity:** Low
**Status:** Open - acceptable for current use
**Description:** Process tree walk checks pane_pid → children → grandchildren. If Claude is deeper in the tree (e.g. extra shell wrapper), detection fails. Current launch path is exactly 2 levels (bash → claude) so this works in practice.
**Workaround:** None needed currently. Would require recursive walk or `pgrep -a` to fix.

### Installer upgrade UX could be smarter
**Severity:** Low
**Status:** Open - future improvement
**Description:** On reinstall, the installer detects existing config and skips prompts. But it doesn't offer to show current settings, merge new config options added in newer versions, or let the user selectively update values. Users must manually edit `~/.claude-mux/config` to pick up new settings introduced in later versions.
**Potential improvements:**
- Show current config values during upgrade
- Offer to add new settings (with defaults) that didn't exist in the old config
- Option B: pre-fill prompts with existing config values and let user change them

### Example CLAUDE.md templates not shipped
**Severity:** Low
**Status:** Open - future improvement
**Description:** `templates/` in the repo root should contain example CLAUDE.md templates (web, python, etc.) that `install.sh` optionally copies to `~/.claude-mux/templates/` during install. Currently users must create templates from scratch.

### Code review deferred issues (v1.9.0)
**Severity:** Low–Medium
**Status:** Open — deferred from v1.9 code review
**Description:** Items identified during v1.9 pre-release review, intentionally deferred:
- **M3** `delete_command` mixes local `force` param with global `FORCE` mutation for `shutdown_single_session`. Works correctly today but fragile if a non-dispatch call path is added.
- **M4** TOCTOU race in `move_to_trash`: two deletions at the same second produce a collision; `mv` fails with a clear error message. Use `$$` or a counter instead of a second-granularity timestamp.
- **M7** Shift+Tab count in setmode doesn't document that `dontAsk` and "unknown" both fall into the 3-press default branch. Add a comment.
- **M9** Startup polling loop breaks out after accepting a trust prompt without re-polling for a subsequent bypassPermissions warning. Affects first-run sessions in a new project directory with bypassPermissions mode — existing restart fallback covers it.
- **L3** `ensure_gitignore_entry` uses `grep -xF` (literal), so `.claudemux-*` may be appended alongside individually-listed marker entries. Idempotency edge case, not a correctness bug.
- **L4** `resolve_project_dir` returns unresolved relative path on `cd` failure, contradicting its contract. Callers catch it via `[[ ! -d ]]`.
- **L5** `hide_command` dry-run exits before `ensure_gitignore_entry`, so the gitignore update step isn't shown in dry-run output.
- **L6** `protect_command` sets the tmux option even when `already_protected=true`, but outputs "Already protected". Intentional for upgrade idempotency; needs a comment.
- **L7** Redundant `${#HIDDEN_PROJECT_DIRS[@]+1}` guard alongside explicit `> 0` check — simplify.
- **L8** Same as M9: sequential trust + bypass prompts not handled by the polling loop.
- **L9** "Yes, I accept" bypassPermissions detection is fragile to Claude UI text changes. Use `grep -qi "yes.*accept"` for resilience.

### Project rename / move with history preservation
**Severity:** Low
**Status:** Open - planned feature
**Description:** When a project directory is renamed or moved, its Claude Code history and memory are stored under the old encoded path in `~/.claude/projects/`. The new path gets no history — Claude Code starts fresh. There is currently no claude-mux command to handle this.
**Proposed behavior:** `claude-mux --rename OLD NEW` / `claude-mux --move DIR DEST` — renames/moves the project directory and renames the corresponding `~/.claude/projects/` folder to the new encoded path. History and memory follow automatically since they live inside that folder. Marker files (`.claudemux-*`) travel with the project directory via the `mv` itself.
**Notes:** Rename and move are the same operation under the hood (`mv`). The encoded path in `~/.claude/projects/` uses `-` for `/`, spaces, and most special characters — the rename must re-encode the new path correctly.
**Additional registries to update (see ~/.claude structure notes below):**
- `~/.claude/homunculus/projects.json` — contains a parallel project registry keyed by short hex UUID with a `root` path field. Must update the `root` value for the matching entry, or homunculus loses track of the project entirely.
- `~/.claude/homunculus/projects/<uuid>/project.json` — also contains the `root` path. Must be updated in sync.
- The `~/.claude/projects/` encoded folder rename handles history and memory automatically.

### Project copy with history
**Severity:** Low
**Status:** Open - planned feature, requires investigation
**Description:** Copying a project including its Claude Code history and memory is more complex than rename/move because new UUIDs must be established for the destination.
**Proposed approach:**
1. Create the new project directory (with optional git init and template)
2. Start and immediately stop a session in it — Claude Code initializes `~/.claude/projects/-encoded-new-path/` with a fresh UUID and creates a new homunculus entry
3. Copy `.jsonl` history files from the source `~/.claude/projects/` folder into the destination folder
4. Copy the `memory/` folder contents — pure markdown, no UUIDs embedded, safe to copy directly
5. Copy UUID subdirectories (task/plan artifacts) alongside their `.jsonl` files
6. For homunculus: copy `observations.jsonl`, `instincts`, `evolved`, `observations.archive` from source `~/.claude/homunculus/projects/<src-uuid>/` into the new destination's homunculus folder — keeping the new project UUID assigned in step 2
**Open questions requiring testing:**
- Do `.jsonl` files embed the source project path in their content or metadata? If so, copied history would reference the old path.
- Are UUID subdirectories referenced by UUID from within `.jsonl` files? If so, they must be copied under their original UUIDs, not remapped.
- Does Claude Code read all `.jsonl` files in a project folder, or only the one matching the active session UUID?
- What does `~/.claude/homunculus/projects/<uuid>/evolved` and `instincts` contain — are they derived/computed or user-meaningful? Worth preserving in a copy?
- Are there any other internal references that would break a naive file copy?
**Prerequisite:** Test the above before implementing to avoid shipping a copy command that produces subtly broken history.

### Tip of the day
**Severity:** Low
**Status:** Open - planned feature
**Description:** A rotating tip shown at session start and available on demand, surfacing features users may not know about.
**Proposed behavior:**
- `claude-mux --tip` prints a single tip (usable standalone or from inside a session)
- Conversational trigger: "tip" or "tip of the day" — Claude calls `--tip` and displays it
- On session start: if `TIP_OF_DAY=true` (default), show a tip once per day. Daily gate checked via `~/.claude-mux/.tip-date` (stores last date shown, per-user not per-session — all sessions on the same day see the same tip, only the first session of the day shows it automatically)
- Selection: date-based hash by default (`day_of_year % num_tips`) so the same tip shows all day; `TIP_MODE=random` for pure random
- Config options: `TIP_OF_DAY=true/false` (disable entirely), `TIP_MODE=daily|random`
**Implementation notes:**
- Tips stored as a numbered bash array embedded in the script. Source of truth is `internal/tips.md` in the repo.
- No external file dependency at runtime — tips travel with the binary.
- `--tip` output should be short: one tip, 1-3 lines, no header/footer noise. Just the tip text.
- See `internal/tips.md` for the full tips list.

### Demo video
**Severity:** Low
**Status:** Open - planned asset
**Description:** A screen recording showing claude-mux from curl install through common and interesting commands, with terminal and Remote Control visible simultaneously.
**Format:** Split screen, single take. Terminal (full claude-mux session) on the left, RC on iPhone mirrored via QuickTime on the right. Both live at the same time — the viewer sees actions in RC immediately reflected in the terminal and vice versa.
**See:** `internal/demo-script.md` for the full shot-by-shot outline.
**Notes:**
- The key shot is typing in RC on the phone and watching the terminal respond in real time
- No editing required beyond trim — single continuous recording
- Host on YouTube + embed in README; also useful for Product Hunt launch

### Submit to homebrew-core for brew.sh listing
**Severity:** Low
**Status:** Future - waiting on adoption
**Description:** claude-mux is currently distributed via a personal tap (`pereljon/tap`). To appear on brew.sh, it needs to be accepted into homebrew-core. Homebrew's notability gate typically requires a few hundred GitHub stars before a shell script utility submission is accepted; low-star submissions are closed quickly.
**When ready:**
- Ensure formula passes `brew audit --strict --new`
- Submit PR to `Homebrew/homebrew-core` with the formula
- Note: macOS-only tools face higher reviewer scrutiny; Linux support (see below) would help

### curl install support (macOS + Linux)
**Severity:** Low
**Status:** Open - planned for v1.10
**Description:** A curl-based install path that works on both macOS and Linux without requiring Homebrew or a package manager. The mechanism is already essentially in place (`install.sh` + `--update` self-replace), but it needs to be documented, tested, and promoted as a first-class install method.
**Proposed:**
```bash
curl -fsSL https://github.com/pereljon/claude-mux/releases/latest/download/install.sh | bash
```
- Downloads and runs `install.sh`, which pulls the binary and runs `claude-mux --install`
- `--update` already handles self-replace from GitHub releases for non-brew installs
- Works on macOS (alternative to Homebrew), Linux (primary method until distro packages exist), and WSL2
**Notes:** WSL2 on Windows gets this for free — Claude Code runs in WSL2, tmux runs in WSL2, curl install works unchanged. No separate Windows support needed.
**README change (v1.10):** Promote curl to primary install method in Quick Start. Move Homebrew to "macOS alternative" below it. curl works for any user on any platform with no prerequisites; Homebrew requires Homebrew to be installed first.

### macOS only - no Linux/systemd support
**Severity:** Medium
**Status:** Open - partially addressed (path detection done, LaunchAgent/installer remain macOS-only)
**Description:** Uses macOS LaunchAgent (launchd) and macOS-specific tools. Path detection was refactored to use `command -v` (no longer hardcodes `/opt/homebrew/bin`), so the core script now works on any platform where tmux and claude are in PATH. LaunchAgent and installer remain macOS-specific.
**Remaining:** systemd user unit, XDG Autostart fallback, `uname -s` dispatch in installer.
**Package strategy (v1.10+):**
- curl install: universal fallback, works everywhere (see above)
- AUR: low effort, high reach for the target audience on Arch/Manjaro
- apt PPA: when there's demand from Debian/Ubuntu users
- Homebrew on Linux: covers users who already have it
- Snap/Flatpak: not worth it for a bash script

### ! commands not available in Remote Control
**Severity:** Low
**Status:** Closed - not feasible
**Description:** Claude Code's `!` shell passthrough is a Claude Code CLI input-handler feature — it intercepts `!command` before the shell sees it. tmux send-keys cannot replicate this: keystrokes sent while Claude Code is active go nowhere (tested: `!touch test` via send-keys did not execute). There is no path for claude-mux to implement `!command` bypass for RC users.
**Resolution:** Add injection rule to tell Claude never to suggest `! <command>` to users, since RC users have no shell and terminal users can just type it themselves.

---

## v2.0 Milestone

Architectural changes significant enough to warrant a major version bump. Not scheduled — collected here so they don't get lost.

### Data directory separation
Move static data (tips, default templates, possibly command/guide output) out of the script and into a platform-appropriate data directory. The script would resolve `DATA_DIR` at startup relative to the binary location, with embedded fallbacks for single-file installs.

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` or `$XDG_DATA_DIRS`
- Manual install: fallback to embedded defaults (single-file installs keep working)

Trigger: when the embedded data (tips, default templates) grows large enough to make the script hard to read, or when default templates need to ship via brew independently of script releases.

### Language / runtime reconsideration
The monolithic bash script is the right call at current scope. If claude-mux grows significantly — project rename/move/copy operations, a relay layer, cross-platform packaging, a data directory — bash starts fighting back. At that point, rewriting the session management core in Go or another typed language (with bash as a thin CLI wrapper) is worth evaluating.

---

## Resolved

### Claude ignores injection and claims it cannot run slash commands
**Resolved in:** v1.2.0 (injection updated)
**Fix:** Added explicit rule to injection: "You CAN send slash commands (`/model`, `/compact`, `/clear`, etc.) to this session via the `-s` command. Never tell the user you cannot change models or run slash commands." Claude's base training inclines it to believe it cannot control its own model/settings; the explicit rule overrides this in practice.



### Multiple commands return exit code 1 despite success
**Resolved in:** v1.2.0 (restart), v1.3.0 (all commands)
**Fix:** Added explicit `exit 0` after every dispatch path in the case statement. The last command in a function can leak a non-zero exit code from internal tests or grep calls.

### --dry-run gives misleading output for --restart
**Resolved in:** v1.2.0 (commit a10c0c2)
**Fix:** Dry-run now shows "Would restart session" instead of simulating kill then checking real state.

### Session detection fails with pgrep on macOS
**Resolved in:** commit e1b11b5
**Fix:** Replaced `pgrep -P` with `ps -eo` + `awk` for reliable child process detection.

### $TMUX variable shadowed tmux's environment variable
**Resolved in:** commit 02a2e82
**Fix:** Renamed to `$TMUX_BIN`.

### Bash 3.2 incompatibility (declare -A)
**Resolved in:** commit 575eac1
**Fix:** Replaced associative arrays with string-based collision detection.

---

## Reference: ~/.claude Folder Structure

Documented here because several planned features (rename, move, copy, cleanup) must interact with this structure correctly. Not exhaustive — covers the parts relevant to claude-mux.

### Project history and memory: `~/.claude/projects/`

One subdirectory per working directory Claude Code has been used in. Named by encoding the absolute path: `/` → `-`, spaces and special characters → `-`. Lossy but readable.

Contents of each project folder:
- `<uuid>.jsonl` — full conversation transcript for that session. One file per conversation.
- `<uuid>/` — subdirectory of artifacts associated with a conversation (tasks, plans). UUID matches the `.jsonl` file.
- `memory/` — persistent cross-session memory files (markdown with frontmatter). Present only if memory has been written for the project.

The link between a working directory and its history is purely the encoded folder name. Renaming or moving the project directory without renaming this folder causes Claude Code to start fresh with no history.

**Encoding rule:** absolute path with every `/`, space, and special character replaced by `-`. Leading `/` becomes a leading `-`. Encoding is lossy — consecutive special characters and spaces adjacent to slashes both become `-`, so the original cannot always be perfectly reconstructed.

### Parallel observability registry: `~/.claude/homunculus/`

A separate system that tracks tool-level events per project. Not part of core Claude Code history — appears to be a monitoring/learning layer.

- `projects.json` — registry of all known projects, keyed by short hex UUID (`d6b3aef60967`, etc.). Each entry has: `id`, `name`, `root` (absolute path), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json` — per-project metadata (same fields as the registry entry).
- `projects/<uuid>/observations.jsonl` — timestamped `tool_start`/`tool_complete` events: tool name, session UUID, project name/id, input/output snippets.
- `projects/<uuid>/instincts` — derived patterns (contents unknown, likely computed).
- `projects/<uuid>/evolved` — evolved/learned state (contents unknown).
- `projects/<uuid>/observations.archive` — archived older observations.

**Key difference from `~/.claude/projects/`:** Uses short hex UUIDs as keys, not encoded paths. The `root` field holds the absolute path. Any operation that changes a project's path (rename, move) must update `root` in both `projects.json` and `projects/<uuid>/project.json`.

### Global config: `~/.claude/settings.json`

Main Claude Code settings file. Rolling backups written to `~/.claude/backups/` as `~/.claude.json.backup.<timestamp>` — several per hour during active use. claude-mux should not touch this file.

### Global agents, skills, commands

- `~/.claude/agents/` — subagent definitions (`.md` files, ~38). Global, not per-project.
- `~/.claude/skills/` — skill directories (~125). Global, not per-project.
- `~/.claude/commands/` — slash command definitions (`.md` files, ~72). Global, not per-project.
- `~/.claude/hooks/hooks.json` — hook definitions. Global. claude-mux should not touch these.

### Potential future features

| Feature | What to touch |
|---------|--------------|
| `--rename` / `--move` | `mv` project dir; rename `~/.claude/projects/` encoded folder; update `root` in `~/.claude/homunculus/projects.json` and `projects/<uuid>/project.json` |
| `--copy` | Create dir; start+stop session to init both registries; copy `.jsonl` + `memory/` + UUID subdirs; copy homunculus observation files into new UUID folder |
| `--delete` cleanup | Already trashes the project folder. Optionally: remove orphaned `~/.claude/projects/` encoded folder and `~/.claude/homunculus/` entry |
| History size warning | Alert when a project's `.jsonl` files exceed a threshold (the main claude-mux transcript hit 107MB in a single long session) |
