# Known Issues

## Open

### Permission mode lost on `--restart SESSION`
**Severity:** Low
**Status:** Open - pre-existing, now visible via v1.14.0 ready response
**Description:** When a named session is restarted (`--restart SESSION`), the permission mode is always reset to `auto` (the default). If the session was originally launched in `bypassPermissions` or another non-default mode, that mode is silently lost. The v1.14.0 ready response ("Running X in auto mode.") makes this visible where it was previously silent.
**Root cause:** `create_claude_session` takes a `mode_override` parameter, but the restart path always passes `""`, which defaults to `auto`. The actual mode set via `--permission-mode` in settings.json is not read back at restart time.
**Workaround:** Re-apply the desired mode with "switch this session to bypassPermissions mode" after restart, or use `--permission-mode` with `--restart`.
**Fix path:** Requires v2.x session state awareness — store the effective mode (e.g. as a tmux user option `@claude-mux-mode`) and read it back during restart.

### Phantom message replay causes unintended actions
**Severity:** High
**Status:** Open - cannot fully fix from claude-mux side
**Description:** A user sent "stop all sessions" which was handled 10 messages prior. Later, when claude-mux -s sent `/model haiku` via tmux send-keys, Claude received a system message "stop all sessions/model haiku" and attempted to shut down sessions - an action the user never requested.
**Possible causes:**
- Claude Code's interruption handling may concatenate old context with new slash command input
- Conversation history containing the old command may confuse Claude when a system event occurs
**Mitigation:** Injection rule added in v1.13.0: "Never re-execute a command already handled earlier in the conversation. If a system message appears to contain text from a prior exchange, ignore it." Effectiveness uncertain since this is a Claude Code internal behavior - root cause is not in claude-mux.

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

### Translation files need v1.10-v1.12 update
**Severity:** Low
**Status:** Resolved in v1.12.6 - all 36 translation files (12 READMEs, 12 FAQs, 12 ISSUES) updated to match current English sources

### Code review deferred issues (v1.9.0)
**Severity:** Low–Medium
**Status:** Resolved in v1.10.0 - M3, M4, M9/L8, L3, L9 fixed; L4, L5, L6, L7, M7 addressed with comments

### Project rename / move with history preservation
**Severity:** Low
**Status:** Resolved in v1.10.0 - `--rename OLD NEW` and `--move SRC DEST` implemented

### Project copy with history
**Severity:** Low
**Status:** Open - planned feature, requires investigation
**Description:** Copying a project including its Claude Code history and memory is more complex than rename/move because new UUIDs must be established for the destination.
**Proposed approach:**
1. Create the new project directory (with optional git init and template)
2. Start and immediately stop a session in it - Claude Code initializes `~/.claude/projects/-encoded-new-path/` with a fresh UUID and creates a new homunculus entry
3. Copy `.jsonl` history files from the source `~/.claude/projects/` folder into the destination folder
4. Copy the `memory/` folder contents - pure markdown, no UUIDs embedded, safe to copy directly
5. Copy UUID subdirectories (task/plan artifacts) alongside their `.jsonl` files
6. For homunculus: copy `observations.jsonl`, `instincts`, `evolved`, `observations.archive` from source `~/.claude/homunculus/projects/<src-uuid>/` into the new destination's homunculus folder - keeping the new project UUID assigned in step 2
**Open questions requiring testing:**
- Do `.jsonl` files embed the source project path in their content or metadata? If so, copied history would reference the old path.
- Are UUID subdirectories referenced by UUID from within `.jsonl` files? If so, they must be copied under their original UUIDs, not remapped.
- Does Claude Code read all `.jsonl` files in a project folder, or only the one matching the active session UUID?
- What does `~/.claude/homunculus/projects/<uuid>/evolved` and `instincts` contain - are they derived/computed or user-meaningful? Worth preserving in a copy?
- Are there any other internal references that would break a naive file copy?
**Prerequisite:** Test the above before implementing to avoid shipping a copy command that produces subtly broken history.

### Tip of the day
**Severity:** Low
**Status:** Resolved in v1.10.0 - `--tip`, `TIP_OF_DAY`, `TIP_MODE`, daily gate, session-start delivery implemented

### Reply timestamp
**Severity:** Low
**Status:** Open - discuss before implementing
**Description:** Optional config var (`REPLY_TIMESTAMP=false` default) that injects an instruction into the system prompt telling Claude to begin each response with the current date and time via `date '+%Y-%m-%d %H:%M'`.
**Tradeoff:** Requires a bash tool call at the start of every reply (small overhead). Alternative: inject session start time into prompt (free, but drifts in long sessions).
**Note:** Per-project CLAUDE.md instruction (as in the analytical template) is the lighter version - only on projects that want it. The config var makes it global.

### Demo video
**Severity:** Low
**Status:** Open - planned asset
**Description:** A screen recording showing claude-mux from curl install through common and interesting commands, with terminal and Remote Control visible simultaneously.
**Format:** Split screen, single take. Terminal (full claude-mux session) on the left, RC on iPhone mirrored via QuickTime on the right. Both live at the same time - the viewer sees actions in RC immediately reflected in the terminal and vice versa.
**See:** `internal/demo-script.md` for the full shot-by-shot outline.
**Notes:**
- The key shot is typing in RC on the phone and watching the terminal respond in real time
- No editing required beyond trim - single continuous recording
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
**Status:** Resolved in v1.10.0 - curl install implemented, release-assets workflow added, README updated

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
**Description:** Claude Code's `!` shell passthrough is a Claude Code CLI input-handler feature - it intercepts `!command` before the shell sees it. tmux send-keys cannot replicate this: keystrokes sent while Claude Code is active go nowhere (tested: `!touch test` via send-keys did not execute). There is no path for claude-mux to implement `!command` bypass for RC users.
**Resolution:** Injection rule added in v1.13.0: Claude will not suggest `! <command>` syntax to users, since RC users have no shell and terminal users can type shell commands directly.

---

## Planned Patches

Small UX work pulled out of the v2.0 milestone to ship under the lifted feature freeze. Each patch is bumped as a minor (x.Y.0) since they add new behavior, not bug fixes.

### v1.14.0 - Launch and restart transparency

**Status: Implemented. Pending code review, commit, push, release.**

Two coherent small wins, both about telling the user what's happening at session boundaries.

**1. Show model on session start.** Extend the injection so Claude's `Session ready!` response also reports the model and permission mode:

```
Session ready!
Running Opus 4.7 in default mode
```

claude-mux already passes `--model` on the launch line (claude-mux:2629, :2958). Pass that value into the injection at launch so Claude knows what to report. No interaction with RC: the `--remote-control` flag is what makes a session discoverable to RC, not pane text — earlier claims about "RC detects the `Session ready!` string" were wrong.

**2. Warn before restart in `--update` and `--restart`.** Before tearing down sessions, print a short message explaining why and noting RC needs to reconnect:

```
Restarting 5 session(s) to apply updated injection. RC will need to reconnect in ~10s.
```

One summary line at the start of the restart sweep, not per-session.

**Out of scope:** mid-tick warnings, status pages, model badges in `-l` — deferred to v2.0/v2.1.

**Implementation order:**

1. Implement "Warn before restart" first (smaller, pure string output in two existing functions).
2. Implement "Show model on session start" second (needs the model value plumbed into the injection at launch).
3. Test: restart cycles, single session vs `--restart` all, `--update` flow, RC reconnect notice, injection update.
4. CHANGELOG, VERSION bump to `1.14.0`, doc-updater for user-facing changes.
5. Code review (minor bump → review all functions added/modified per CLAUDE.md).
6. Commit / push / release.

---

## v2.0 Milestone

Architectural changes significant enough to warrant a major version bump. Sequenced into three minors (v2.0, v2.1, v2.2). Not scheduled.

### Data directory separation
Move static data (tips, default templates, possibly command/guide output) out of the script and into a platform-appropriate data directory. The script would resolve `DATA_DIR` at startup relative to the binary location, with embedded fallbacks for single-file installs.

- Homebrew (Apple Silicon): `/opt/homebrew/share/claude-mux/`
- Homebrew (Intel): `/usr/local/share/claude-mux/`
- Linux: `/usr/local/share/claude-mux/` or `$XDG_DATA_DIRS`
- Manual install: fallback to embedded defaults (single-file installs keep working)

Trigger: when the embedded data (tips, default templates) grows large enough to make the script hard to read, or when default templates need to ship via brew independently of script releases.

### Agent teams compatibility (investigation)

Investigation task, not an implementation feature. Goal: test the friction points below, document findings, decide whether any claude-mux change is warranted.

Claude Code v2.1.32+ includes experimental agent teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`). Since claude-mux sessions run inside tmux, `teammateMode` auto-detects tmux and defaults to split-pane mode - no extra config needed. That part works for free.

Known friction points to investigate and document:

- **Unmanaged teammate sessions**: teammates are spawned by Claude Code directly, not by claude-mux. They don't get the claude-mux injection (`--append-system-prompt`), don't appear in `claude-mux -l`, and aren't accessible via RC through the normal session list.
- **Orphaned sessions on restart**: if `--restart` is called on a lead session with active teammates, it's unclear whether Claude Code cleans up teammates first or leaves orphaned tmux sessions. Needs testing.
- **RC visibility**: teammates may not be launched with `--remote-control`, so they may not appear in the mobile app. Needs verification.

Design posture: don't interfere with agent team lifecycle - that's Claude Code's domain. Document the known behavior so users know what to expect. The "infrastructure, not a framework" principle applies here.

### Auto-restore running sessions after reboot

Persist running-session state to a per-project marker file so the LaunchAgent can restore the user's working set after a reboot or crash.

**Marker:** `.claudemux-running` in each project folder.

**Lifecycle:**
- On session start (`-d`, `-n`, `--restart`): write `.claudemux-running` first, then start tmux/Claude.
- On `--shutdown`: remove `.claudemux-running` first, then kill tmux. Order matters - prevents a race where a concurrent `--restore-autostart` could relaunch a session that's mid-shutdown.
- Survives crash, reboot, SIGKILL - that persistence is the whole point.
- `home` folder gets no marker; LaunchAgent always starts home.
- The marker matches what `claude-mux -l` reports as "running" - single concept, single name.

**Restore flow:**
- Extend `--autolaunch` (the flag the LaunchAgent already calls). After ensuring `home` is up, walk `PROJECT_DIRS` for `.claudemux-running` markers and launch any whose tmux session isn't already alive.
- Pure bash loop in the script - no involvement from home's Claude turn, no injection delays, no token cost.
- Because the LaunchAgent re-fires `--autolaunch` on `KeepAlive` (every `ThrottleInterval`, currently 60s), the same loop self-heals mid-day crashes: any tracked session that dies comes back on the next tick. Boot recovery and runtime watchdog from a single code path.

**Shared infrastructure note:** the `--autolaunch` tick is also the natural home for **Claude Code binary upgrade detection** and **zombie-session detection** below. Implement this one first; the others bolt on as additional passes inside the same loop.

**Behavior change to call out in release notes:** `tmux kill-session` on a claude-mux project will now be auto-resurrected within ~60s as long as the marker is present. To truly stop a session, use `claude-mux --shutdown` (removes marker first, then kills tmux).

**Default-on, no opt-out (initial):** auto-restore is standard behavior. If user feedback warrants it later, add an `AUTORESTORE=true/false` config var as a small follow-up - not in the v2.0 scope.

**Implementation notes:**
- **Hidden and protected markers are orthogonal to the restore loop.** It walks for `.claudemux-running` and starts what it finds. `.claudemux-ignore` and `.claudemux-protected` persist in the project folder alongside the running marker - hidden sessions come back hidden, protected sessions come back protected. Visibility and protection are about how the session is listed and shut down, not whether it should be alive.
- **First-time install backfill**: on upgrade to the version that adds this feature, scan tmux for already-running claude-mux sessions and write markers so the very first reboot doesn't lose them.
- **Auto-gitignore**: add `.claudemux-running` via `ensure_gitignore_entry()` like other marker files.

**Invariant:** marker present ⇒ session should be alive. The only correct way to clear that bit is `claude-mux --shutdown`.

### Model/mode columns in session listings

Show model and permission mode alongside each session in `claude-mux -l` and `-L`. `status` already reports model/mode for the current session (self-reported), but the listing commands show nothing per-session. Users managing multiple sessions want this at a glance.

**Possible format:** one-letter codes like `O/P` (Opus/Plan), `H/D` (Haiku/Default), `S/B` (Sonnet/Bypass). Letter collisions need resolution (D=default, A=acceptEdits, P=plan, B=bypass — maybe Y for yolo/bypass).

**Open questions:**
- **Data source.** Claude Code doesn't expose model/mode externally. Options: (1) query each running session via send-keys (slow, fragile), (2) cache what claude-mux sets via `-s` commands (can drift if user changes manually), (3) read Claude Code internal state files if they exist.
- Stopped sessions: show last-known model/mode or blank?
- Performance: querying N sessions adds latency. Caching avoids this but introduces staleness.

**How to apply:** Evaluate during v2.0 planning. May need Claude Code to expose session metadata before this is practical.

### Claude Code binary upgrade detection

claude-mux has no awareness of `claude` binary upgrades. `--update` handles claude-mux itself (script + injection) and triggers `--restart` to refresh injection. The `claude` binary is upgraded out-of-band (`brew upgrade claude`, npm, curl installer). Running sessions hold a `claude` process spawned from whichever binary was on PATH at launch time, so they keep running the old binary until restarted. New sessions pick up the new binary because PATH resolves at exec time.

**Same shape as the claude-mux injection-staleness problem, but for the dependency.**

**Shared infrastructure:** rides on the `--autolaunch` tick added by **Auto-restore running sessions after reboot** above. Implement after that, as an additional pass in the same loop.

**Possible mechanisms:**

- **Detect on `--autolaunch` tick.** Compare each session's `claude` PID's executable path/mtime against `command -v claude`. If a session is running an older binary, surface in `-l` as a "stale" badge.
- **Conversational notice.** On detection, inject a one-shot note: *"Claude Code was upgraded since this session started; say 'restart this session' to load the new binary."*
- **Extend `--update`.** Detect `brew outdated claude` (or equivalent for npm/curl installs) and offer to upgrade both together with a single restart sweep.

**Adjacent but distinct** from "Warn before restart in `--update` and RC" — that item is about explaining *our* restarts; this is about detecting an external dependency upgrade.

**Open questions:**
- Detection across install methods: brew is easy (`brew outdated`), npm-global and curl installs need a different probe (mtime on the resolved binary?).
- Should detection be opt-in or always-on? Cheap if it's just an mtime compare on each `--autolaunch` tick.
- Behavior when the user upgrades while a session is mid-task: notify but don't auto-restart.

### Inter-agent messaging

Formalize session-to-session communication. claude-mux sessions are already persistent, project-bound agents and `-s` is a de facto message bus — but `-s` currently hard-rejects non-slash input, so true inter-agent messaging is blocked. A dedicated command + an authorization marker turns the existing infrastructure into a lightweight agent network.

Contrast with Claude Code agent teams: those are ephemeral and task-scoped. claude-mux sessions are long-lived and independent, coordinating ad-hoc — a different shape, not a competitor.

**New command: `--message`**

```
claude-mux --message TARGET_SESSION 'natural language text'
```

- **Sender attribution** baked in: receiver sees `[from: home] ...` so it can route a reply via its own `--message home '...'`.
- **Escaping** handled properly rather than relying on `send-keys -l` by accident.
- **Delivery gate**: wait for the target's `Session ready!` handshake before injecting. No mid-tool-call interruptions.
- **Auto-start always.** If TARGET is not running, claude-mux starts it, waits for ready, then delivers. No `--start` flag. Safety net is the existing managed-session check: unknown session name → error.
- **No queue.** First message to an unauthorized target is lost; sender must resend after approval. Avoids stale-delivery, hidden state, ambiguous timing.

**Authorization: `.claudemux-authorized` marker**

Per-project file listing who can send TO that session:

```
# client-acme/.claudemux-authorized
home
api-server
```

Matches the existing marker-file philosophy (`.claudemux-protected`, `.claudemux-ignore`, `.claudemux-running`). Auto-gitignored via the `.claudemux-*` pattern. Travels with the project folder, no central registry.

**Direction model: per-direction, no auto-bidirectional**

- Each direction requires its own explicit approval from the **receiving** side.
- For home ↔ api-server to coordinate, two approvals are needed (one each direction).
- **Why not bidirectional-by-default?** Asymmetric privilege is real: a session with sensitive context wants to receive directives without exposing itself for queries back. Information leakage matters.
- Approval is always granted by the receiver, never the sender.

**Unauthorized-send flow**

1. `home` runs `claude-mux --message client-acme 'check auth status'`
2. claude-mux sees `home` is not in `client-acme/.claudemux-authorized`
3. claude-mux delivers a notice to `client-acme`: *"Session 'home' is requesting permission to send messages. To allow: 'allow messages from home'"*
4. claude-mux returns to `home`: *"Authorization required. Approval request sent to client-acme."*
5. `home`'s Claude tells the user: *"Switch to client-acme, approve, then I'll retry."*
6. User in `client-acme` says "allow messages from home" → triggers `claude-mux --authorize home` → appends to `client-acme/.claudemux-authorized`
7. User returns to `home`, says "try again" → delivery succeeds.

**`-s` (slash commands) and `--message`: same authorization gate**

Two commands, same auth model. Cross-session `-s` (e.g. `/clear`, `/model opus`, `/compact`) requires the target to authorize the sender, exactly like `--message`. `/clear` can destroy work and `/model` changes behavior — they need the same gate as natural language. The same `.claudemux-authorized` file governs both. Self-sends (`-s` to your own session) remain unrestricted.

**Injection changes**

Teach Claude:
- It is part of a network of named, addressable agents.
- It can send to a peer with `claude-mux --message NAME 'text'`.
- Incoming messages prefixed with `[from: NAME]` came from another agent, not the user. A reply goes back via `--message NAME 'text'`.
- If `--message` returns "authorization required," tell the user to switch to the target session and approve.

**Related (parked separately)**

A periodic LaunchAgent tick was discussed alongside this. The auto-restore self-heal loop (KeepAlive + `--autolaunch` every 60s) already provides that cadence. Residual ideas — zombie-session detection (tmux pane alive, claude process dead), `.update-check` refresh, log rotation — should be a separate ISSUES.md entry, not folded in here.

### Zombie session detection

The tmux session is alive but the `claude` process inside it has died. Currently no recovery without manual `--restart`. The session shows as "running" in `-l` but is functionally dead — RC connects but nothing responds.

**Detection:** during the `--autolaunch` tick (see Auto-restore above), for each tmux session marked claude-mux-managed, check whether `claude` is still in the process tree. If not, the pane is a zombie.

**Action:** restart the session automatically (same path the auto-restore loop uses). The `.claudemux-running` marker is already present, so the existing restart logic applies.

**Shared infrastructure:** rides on the `--autolaunch` tick added by **Auto-restore running sessions after reboot**.

**Adjacent residual ideas (housekeeping, lower priority):** `.update-check` cache refresh, log rotation.

### Ready handshake during compact/resume

The startup poller (`create_claude_session`, claude-mux:2645-2682) treats "prompt symbol drawn" as "ready to receive input." That's wrong during `claude -c` resume when the transcript is large enough to trigger auto-compaction or a continuation summary — the `❯` is visible but Claude is busy processing context. `"Ready?"` lands at the wrong time, either getting queued into the wrong turn or interrupting the compact mid-process.

The injection rule added in v1.13.2 ("After a resume/compaction continuation, stay silent") mitigates the symptom; the timing bug remains.

**Fix:**

1. After detecting the prompt symbol, check for busy indicators in the pane: `Compacting`, `Summarizing`, spinner glyphs (`⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏`), or a non-empty status line above the input box.
2. If busy → keep polling. Extend the timeout (current 10s is far too short for compaction; allow ~120s).
3. Send `"Ready?"` only when the pane is at the prompt **and** not busy.
4. Never auto-confirm or auto-press anything during the busy window — just wait it out.

**Shared infrastructure:** the busy check is the same `tmux capture-pane` pass already in use, so this bolts onto the existing poller without new dependencies. Also overlaps with the `--autolaunch` tick used by auto-restore, binary detection, and zombie detection.

**Open questions:**
- What's the exhaustive list of busy indicators across Claude Code versions? Need to capture-pane samples during compact, summarize, and long tool runs to confirm.
- Should we surface "session compacting at startup" in `-l` so the user knows why a session isn't immediately responsive?

### Session handoff / brief workflow

**Status:** Initial sketch. Full functionality still needs to be worked through — sub-features below are starting points, not final design.

claude-mux defaults to `claude -c` on every session start and restart. That's the exact pattern argued against in ["Stop Resuming Long Sessions: Brief Injection"](https://claudecodefornoncoders.substack.com/p/stop-resuming-long-sessions-brief): resuming a long transcript floods the model with stale tool output (directory listings, file contents, command results that no longer match disk) and dilutes attention across past back-and-forth. The article recommends ending the session, writing a 5-7 line brief (branch state, key decisions, active constraints, files modified, next steps), and starting fresh with the brief as the only context.

We added `--restart --fresh` in v1.13.0 as the escape hatch, but it requires the user to know about it and ask. The brief workflow makes the article's pattern the easy path.

**Sub-features (cluster, implement together):**

1. **Brief-on-shutdown.** On graceful shutdown (not crash), `-s` Claude with a prompt to write a 5-7 line handoff to `.claudemux-brief` in the project folder. Marker-file convention; auto-gitignored.
2. **Brief-injection on resume.** On next session start, if `.claudemux-brief` exists, inject it as an addendum to the system prompt. User can still say "resume the full conversation" to fall back to standard `-c`.
3. **Transcript size warning.** During `--autolaunch` tick (shared infra with auto-restore/zombie/binary-detection), check `~/.claude/projects/<encoded>/*.jsonl` size. Over a threshold (10MB? 25MB? TBD), surface in `-l` as a badge and inject a conversational note suggesting `restart this session fresh` or the brief workflow.
4. **`--restart --brief` shortcut.** One command: prompt for brief, shutdown, restart fresh with brief injected. The user-facing verb that makes the right handoff pattern trivial.

**Open questions to resolve before implementing:**
- Default behavior: opt-in (config flag) or always-on for shutdowns? Article suggests always-on is the right call but users may want the old `-c` behavior for short same-day sessions.
- Brief format: prose? structured (YAML/JSON)? Claude-authored or template-driven?
- What about crash recovery — no chance to write a brief. Fall back to `-c` and warn?
- Multiple briefs over time: keep history, or each brief overwrites the last? If history, where does old briefs go (`.claudemux-briefs/`)?
- Interaction with the auto-restore loop: when LaunchAgent restarts a session that died unexpectedly, should it use the last brief or `-c`?
- Interaction with `--restart --fresh`: same thing, or different (fresh = no brief either)?
- Does the brief replace conversation history or supplement it?

**Why this matters:** the "Ready handshake during compact/resume" item above is downstream of this. Long transcripts → auto-compact at startup → ready handshake misfires. Solving the root cause (don't resume the giant transcript) eliminates the symptom. Article's framing: "The transcript is a tool, not a context."

### Memory management from sessions

Conversational triggers and/or CLI flags for managing Claude Code's per-project memory (`~/.claude/projects/*/memory/`) from within claude-mux sessions. Memory files accumulate and go stale; there's no easy way to see what Claude "remembers" about a project, clean up outdated entries, or review memories across projects without browsing the filesystem.

**Potential scope:**
- List memories for the current project (or all projects)
- View a specific memory file
- Delete or update stale memories
- Search across memories
- Triggers: "show my memories", "what do you remember about this project"
- CLI: `claude-mux --memories`, `claude-mux --memories PROJECT`

**Automated memory review:**
- Run review/optimization on some event (session start, restart, compact, periodic schedule)
- Claude reviews its own memories for staleness, duplicates, contradictions, outdated project state
- Purge memories no longer relevant (shipped features, resolved decisions)
- Consolidate overlapping memories
- Implementation: PostToolUse on compact, Stop hook, or conversational trigger ("review memories")

**Obsidian / auto-tagging (further out):**
- Auto-tag CLAUDE.md, memory files, or other project MD with metadata that Obsidian (or similar indexers) can consume. Mechanism and value TBD.

**How to apply:** Not yet scoped for a specific release. Consider alongside other v2.0 features.

---

## Open Questions

Not features. Long-running design questions to revisit periodically.

### Language / runtime reconsideration
The monolithic bash script is the right call at current scope. If claude-mux grows significantly - project rename/move/copy operations, a relay layer, cross-platform packaging, a data directory - bash starts fighting back. At that point, rewriting the session management core in Go or another typed language (with bash as a thin CLI wrapper) is worth evaluating.

Trigger to re-evaluate: when any single bash function exceeds ~150 lines of branching logic, when cross-platform packaging needs more than `uname -s` dispatch, or when the script as a whole crosses ~5000 lines.

---

## Resolved

### Fresh-start restart (MCP / config reload)
**Resolved in:** v1.13.0 - `--restart --fresh` implemented with conversational triggers "restart this session fresh", "restart SESSION fresh", "kill this session"


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

Documented here because several planned features (rename, move, copy, cleanup) must interact with this structure correctly. Not exhaustive - covers the parts relevant to claude-mux.

### Project history and memory: `~/.claude/projects/`

One subdirectory per working directory Claude Code has been used in. Named by encoding the absolute path: `/` → `-`, spaces and special characters → `-`. Lossy but readable.

Contents of each project folder:
- `<uuid>.jsonl` - full conversation transcript for that session. One file per conversation.
- `<uuid>/` - subdirectory of artifacts associated with a conversation (tasks, plans). UUID matches the `.jsonl` file.
- `memory/` - persistent cross-session memory files (markdown with frontmatter). Present only if memory has been written for the project.

The link between a working directory and its history is purely the encoded folder name. Renaming or moving the project directory without renaming this folder causes Claude Code to start fresh with no history.

**Encoding rule:** absolute path with every `/`, space, and special character replaced by `-`. Leading `/` becomes a leading `-`. Encoding is lossy - consecutive special characters and spaces adjacent to slashes both become `-`, so the original cannot always be perfectly reconstructed.

### Parallel observability registry: `~/.claude/homunculus/`

A separate system that tracks tool-level events per project. Not part of core Claude Code history - appears to be a monitoring/learning layer.

- `projects.json` - registry of all known projects, keyed by short hex UUID (`d6b3aef60967`, etc.). Each entry has: `id`, `name`, `root` (absolute path), `remote`, `created_at`, `last_seen`.
- `projects/<uuid>/project.json` - per-project metadata (same fields as the registry entry).
- `projects/<uuid>/observations.jsonl` - timestamped `tool_start`/`tool_complete` events: tool name, session UUID, project name/id, input/output snippets.
- `projects/<uuid>/instincts` - derived patterns (contents unknown, likely computed).
- `projects/<uuid>/evolved` - evolved/learned state (contents unknown).
- `projects/<uuid>/observations.archive` - archived older observations.

**Key difference from `~/.claude/projects/`:** Uses short hex UUIDs as keys, not encoded paths. The `root` field holds the absolute path. Any operation that changes a project's path (rename, move) must update `root` in both `projects.json` and `projects/<uuid>/project.json`.

### Global config: `~/.claude/settings.json`

Main Claude Code settings file. Rolling backups written to `~/.claude/backups/` as `~/.claude.json.backup.<timestamp>` - several per hour during active use. claude-mux should not touch this file.

### Global agents, skills, commands

- `~/.claude/agents/` - subagent definitions (`.md` files, ~38). Global, not per-project.
- `~/.claude/skills/` - skill directories (~125). Global, not per-project.
- `~/.claude/commands/` - slash command definitions (`.md` files, ~72). Global, not per-project.
- `~/.claude/hooks/hooks.json` - hook definitions. Global. claude-mux should not touch these.

### Potential future features

| Feature | What to touch |
|---------|--------------|
| `--copy` | Create dir; start+stop session to init both registries; copy `.jsonl` + `memory/` + UUID subdirs; copy homunculus observation files into new UUID folder |
| `--delete` cleanup | Already trashes the project folder. Optionally: remove orphaned `~/.claude/projects/` encoded folder and `~/.claude/homunculus/` entry |
| History size warning | Alert when a project's `.jsonl` files exceed a threshold (the main claude-mux transcript hit 107MB in a single long session) |
