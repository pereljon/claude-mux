# Test plan: Cross-CLI coders

Companion to `cross-cli-coders.md`. Covers pre-build verification (injection mechanisms - partly DONE), behavior/unit checks, integration, end-to-end, and per-CLI matrix. claude-mux is a bash tool tested manually + with shell assertions; "tests" here are concrete procedures, not a framework. Installed versions at spec time: Gemini 0.45.2, Codex 0.138.0 - re-pin and re-verify if the build happens against newer CLIs.

## 0. Pre-build verification

### 0a. Injection mechanisms (DONE — 2026-06-10)

| # | Check | Result |
|---|---|---|
| 1 | Does Gemini have a per-launch append-system-prompt flag? | NO. `gemini --help` (0.45.2): no append flag. Additive path = `GEMINI.md` context files; override path = `GEMINI_SYSTEM_MD` env → file (full replace). |
| 2 | Does Codex have a per-launch append-system-prompt flag? | NO. `codex --help` (0.138.0): no append flag. Additive path = `AGENTS.md` + `AGENTS.override.md`; override path = `model_instructions_file` (config.toml, ex-`experimental_instructions_file`, full replace). |
| 3 | Is the additive path what `MULTI_CODER_FILES` already symlinks? | YES. `GEMINI.md`/`AGENTS.md` → `CLAUDE.md` is the additive static layer. Static injection already cross-CLI. |
| 4 | Override path safe to use? | NO. Both overrides replace the entire built-in system prompt → discard CLI defaults. Rejected. Use additive only. |
| 5 | Non-Claude control-surface analogues exist? | YES. Gemini: `-r/--resume`, `--session-id`, `--approval-mode {default,auto_edit,yolo,plan}`, `-m`, `mcp/hooks/skills`. Codex: `resume/fork`, sandbox/approval flags, `-c model=`, `mcp/plugin`, `remote-control` subcmd. |

### 0b. Still to verify BEFORE finalizing build (the open questions)

| # | Check | How | Why it matters |
|---|---|---|---|
| 6 | Gemini loads an *extra* hierarchical `GEMINI.md` (dynamic block) alongside the symlinked root | Place a second `GEMINI.md` in a subdir/parent with a unique marker string; start gemini; confirm the marker appears in its context | Picks the per-session dynamic-inject mechanism for Gemini |
| 7 | Codex `AGENTS.override.md` is additive-on-top, NOT full-replace | Put a marker in `AGENTS.override.md`, distinct content in `AGENTS.md`; confirm BOTH reach the model | Confirms the clean Codex dynamic hook |
| 8 | Codex `AGENTS.override.md` gitignore behavior | Inspect in a git project | Decide explicit ignore entry vs `.claudemux-*` rename |
| 9 | Exact Codex approval/sandbox flag names + non-interactive "auto" equivalent | `codex --help` deep dive + docs | Build the `approval_map` |
| 10 | Does Gemini/Codex accept a controllable session *name/id*? | Gemini `--session-id <uuid>`; Codex naming TBD | Whether `-l`/restart can map name→session like Claude `--name` |
| 11 | RC reality: Codex `remote-control` / Gemini `--acp` mobile-reachable? | Launch + try from mobile app | Whether RC can be promised for non-Claude (default: NO) |

## 1. Adapter selection (behavior)

- **T1.1** `CODER` unset → defaults to `claude`; existing behavior byte-identical (regression guard - no existing user sees a change).
- **T1.2** `CODER=gemini` global → new `-d`/`-n` sessions launch the `gemini` binary.
- **T1.3** `.claudemux-coder` file containing `codex` in a project → that project launches codex even when global `CODER=claude`. Marker overrides global.
- **T1.4** Unknown `CODER`/marker value (e.g. `foobar`) → clear error, no launch, non-zero exit.
- **T1.5** Marker is read from the project folder (marker-file philosophy), travels with rename/move.

## 2. Launch invocation (per-CLI templates)

- **T2.1** claude profile: launch line unchanged from current (`claude -c --remote-control ... --append-system-prompt-file`). Diff against pre-feature behavior = none.
- **T2.2** gemini profile: launches `gemini` with resume + approval + model, and **no** `--name`/append flag (would error). Session comes up interactive in the pane.
- **T2.3** codex profile: launches `codex` with resume + sandbox/approval + `-c model=`, no append flag. Session comes up.
- **T2.4** Missing target binary (e.g. `CODER=gemini` but `gemini` not installed) → the existing `CLAUDE_BIN`-style guard fires for the selected binary with a helpful "install or set ..." message, no half-started tmux session.
- **T2.5** `--dry-run` prints the exact per-CLI launch line without executing.

## 3. Static injection (already works — regression guard)

- **T3.1** gemini session in a folder with `GEMINI.md` → `CLAUDE.md` symlink: ask it "what session-management commands do you know" → it reflects the injected trigger rules (proves static layer reached it).
- **T3.2** codex session with `AGENTS.md` → `CLAUDE.md`: same check.
- **T3.3** `--no-multi-coder` on `-n` → no symlinks created; a subsequent gemini/codex launch in that folder gets NO injection (documents the dependency).

## 4. Dynamic per-session injection

- **T4.1** codex: the per-session dynamic block (tmux session name, etc.) is written to `AGENTS.override.md`; codex session can self-report its claude-mux session name → proves dynamic inject reached it.
- **T4.2** gemini: dynamic block via the chosen mechanism (extra hierarchical `GEMINI.md`, per T0b#6) → gemini self-reports its session name.
- **T4.3** Two sessions, two folders, both codex: each gets its OWN dynamic block (different session names), no cross-contamination (folder-scoped = per-session in claude-mux's model).
- **T4.4** Dynamic file is cleaned/rewritten on `--restart` (no stale session name from a prior launch).
- **T4.5** Override path is NOT used: confirm `GEMINI_SYSTEM_MD` / `model_instructions_file` are never set by claude-mux (grep the launch path + env).

## 5. Liveness + auto-restore (parameterized regex)

- **T5.1** `claude_running_in_session` with `liveness_regex=/gemini/` returns true for a live gemini session, false after killing it.
- **T5.2** Auto-restore: a marked-but-dead gemini session is resurrected by the `--autolaunch` tick (resume flag = `-r latest`, not `-c`).
- **T5.3** A claude session is NOT matched by a gemini profile's regex and vice-versa (no cross-profile false-positive liveness).
- **T5.4** Stray-process adoption (`pgrep -f "$BIN"`) uses the selected binary, not hardcoded `claude`.
- **T5.5** `-l`/`-L` shows mixed-CLI sessions with correct running/idle/stopped status across profiles.

## 6. Capability degradation (Tier-2 features no-op, not misfire)

- **T6.1** "compact this session" / `/compact` to a gemini session → returns "not supported for gemini" (or silently skips), does NOT send-keys `/compact` garbage into the pane.
- **T6.2** "switch model" to a profile without slash routing → either uses the per-CLI mechanism if mapped, or reports unsupported. Never injects a Claude slash command blindly.
- **T6.3** Ready-handshake: non-claude profiles skip the `esc to interrupt` scraper and use the settle delay; `Ready?`/RC reconnect logic does not hang waiting for a Claude-only signal.
- **T6.4** Permission-mode request maps through `approval_map` (e.g. "yolo" → gemini `-y`) or reports unsupported; never sends Claude's Shift+Tab cycle to a non-Claude TUI.

## 7. End-to-end

- **T7.1** `CODER=gemini`, `claude-mux -d <project> --no-attach` → gemini session persists in tmux, survives terminal close, shows in `-l`, reachable. Static + dynamic injection present.
- **T7.2** Same for codex.
- **T7.3** Mixed fleet: claude + gemini + codex sessions running concurrently; `-L` lists all three correctly; auto-restore handles each with its own resume mechanism after a simulated crash.
- **T7.4** Reboot recovery (real reboot or simulated): marked gemini/codex sessions come back via their resume flags.

## 8. v2.2 network tie-in (forward-compat check, if inbox exists)

- **T8.1** A codex/gemini session taught (via its static context file) to poll `~/.claude-mux/inbox/<name>/` reads and acts on a delivered message by PULL - no Claude-specific delivery needed.
- **T8.2** Inbox message format is CLI-agnostic (plain file the injection of any coder can parse); no Claude-only assumptions in the on-read instructions.

## 9. Post-build checks (Change Checklist verification)

- **T9.1** `config_help()` lists `CODER`; `config.example` has it (default `claude`).
- **T9.2** Marker registry in `CLAUDE.md` + `dev/CODEMAP.md` includes `.claudemux-coder`.
- **T9.3** `dev/CODEMAP.md` / `dev/SKELETON.md` reflect parameterized launch + new functions.
- **T9.4** Injection prompt is capability-aware (a gemini session's prompt does not advertise `/compact`).
- **T9.5** `README.md` advertises multi-CLI launch (not just shared-instruction symlinks).
- **T9.6** `CHANGELOG.md` entry + `VERSION` minor bump.
- **T9.7** Code review (minor-bump scope: all added/modified functions), CRITICAL/HIGH addressed.
