# Changelog

All notable changes to claude-mux are documented here. Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.1.0] - 2026-07-23

### Changed
- **Home-orchestrator identity now ships in the injection, home-only; config authority is one role-neutral rule in every session.** Keeping the home session's identity in an ancestor `CLAUDE.md` (base directory) leaked it into every project session underneath via Claude Code's walk-up loading — each project session was told it *is* the home orchestrator, and the "config edits must be made from this session" line ambiguously read as granting the project session config authority. The home injection block now carries the orchestrator identity itself (session management and project orchestration, not project work; operational posture), so no ancestor file has to. The old home-only grant line — which falsely claimed "only home has filesystem permissions for `~/.claude-mux/`" (it's convention, not OS enforcement; all sessions run as the same user) — is replaced by one self-disambiguating rule injected into **all** sessions: config/template edits are the home session's responsibility; a session named `home` edits directly, any other session routes the change to home. Injection-only change (takes effect per session after restart). If your base-directory `CLAUDE.md` carries home-identity text, you can now trim it to genuinely shared content. Design + test plan: `dev/features/home-prompt-split.md`.

## [2.0.15] - 2026-07-22

### Fixed
- **The daily tip no longer re-shows on every `/clear`, restart, or compact.** The once-per-day gate was keyed on Claude Code's per-conversation `session_id`, which mints a fresh UUID on every `/clear` and restart/resume — so each rotation found no stamp and re-emitted the tip (observed: seven `tip-state` files stamped in one day, four inside an 18-minute window). The tip is now gated **once per day globally**, in the **`home` session only**, via a single stamp `~/.claude-mux/tip-state/tip.json`; `session_id` drops out of the tip path entirely. Project sessions no longer show the tip at all (tips are orchestration-themed and home is the always-on session). Orphaned legacy per-session `<uuid>.json` stamps are swept once on the first home tip fire. The two actionable notices (update-available, Claude-Code-upgraded) are unchanged and still fire in every session.
  - **Behavior change:** if you run no `home` session (LaunchAgent not installed), tips no longer appear. Use `--tip` on demand, or the always-on `home` session, to see them. Design + test plan: `dev/features/tip-home-daily.md`.

## [2.0.14] - 2026-07-22

### Fixed
- **A conversational model switch no longer stalls the session on Claude Code's "Switch model?" dialog.** When you switch a session's model and that model is already cached, Claude Code pops a blocking confirmation dialog ("Switch model? … ❯ Yes, switch to … / No, go back") that nothing answered, so the session sat stuck until someone hit Enter in the pane (observed live three times). The `-s SESSION '/model <id>'` send now backgrounds a detached confirmer that watches the pane (~30s), positively recognizes that specific dialog (bottom-anchored so a scrolled-up transcript quote of the dialog text can't false-fire), and confirms the pre-highlighted "Yes" with a single Enter. When there is no dialog (uncached or same-model switch) it matches nothing and exits silently, never sending a stray Enter. A per-session `mkdir` lock ensures two overlapping `/model` sends can't both key the dialog (which would submit an empty prompt). Recognize-then-confirm, same pattern as the `bypassPermissions` startup poller. Design + test plan: `dev/features/model-switch-confirm.md`.

## [2.0.13] - 2026-06-21

### Fixed
- **"Change model to sonnet" now actually switches the model.** The in-session `/model` picker silently ignores a bare family name (it reports "Kept model as …" and leaves the model unchanged), and the v2.0.12 rule passed bare family names through untouched — so "switch this session to sonnet" was a no-op. Sessions now resolve a bare family to the latest concrete ID they know (`sonnet` → `claude-sonnet-4-6`, preferring the dateless alias form), using the model-ID list Claude Code injects into each session plus their own knowledge; versioned shorthand (`opus 4.8`) still becomes `claude-opus-4-8`, and full/date-suffixed IDs pass through. If a token can't be confidently resolved (e.g. a model newer than the session knows), the session asks for the exact ID rather than sending a bare family. No model registry, scraper, or daily fetch — resolution stays the session's job, Claude Code stays the authority (per `model-handling-derot`). Design + rejected alternatives (picker scraping, models.txt, `/v1/models`): `dev/features/model-resolution-notice-cleanup.md`.
- **Notices no longer leak their relay instruction into the visible text.** The daily tip and the update/upgrade notices wrapped the meta-instruction *inside* the `<assistant-must-display>` tags, so the user saw `[claude-mux tip — MUST relay … in their conversation language]:` printed in front of the actual tip. The notices now contain only the clean user-facing line inside the tags (`claude-mux tip: …`); the relay + once-per-session instruction moved to the standing notice rule in the injected system prompt. (Tradeoff: `<assistant-must-display>` is verbatim, so notices display in English rather than being translated — the prior wording conflicted with itself on this.)

## [2.0.12] - 2026-06-19

### Changed
- **"Switch to opus 4.8" now resolves to the full `claude-opus-4-8` model ID.** The model-switch injection rule used to forward whatever the user said straight to `/model`, so a family-plus-version shorthand like "opus 4.8" (or "opus-4-8") was rejected by Claude Code as an unknown model. Sessions now rewrite a versioned shorthand to the canonical `claude-<family>-<major>-<minor>` form (e.g. "opus 4.8" → `claude-opus-4-8`) before sending `/model`, while bare family aliases (`opus`/`sonnet`/`haiku`), already-full IDs, and date-suffixed IDs (`claude-haiku-4-5-20251001`) pass through untouched. Injection-only change (takes effect after sessions restart).
- **`HOME_SESSION_MODEL` examples corrected.** The install prompt, `--home-model` help, `config.example`, and the docs suggested values like `opus-4-8` and `fable` as if valid, but those are rejected by `claude --model` (they need a bare alias like `opus` or a full ID like `claude-opus-4-8`). Examples now show valid forms only. Note: config values are **not** auto-normalized the way the conversational `/model` trigger is — normalizing in shell would require a hardcoded model-family list, reintroducing the drift the pass-through design removed — so set `HOME_SESSION_MODEL` to a bare alias or a full `claude-…` ID.

## [2.0.11] - 2026-06-19

### Fixed
- **Commands that don't need tmux or claude no longer require them.** The startup dependency check ran for every command and `exit 1`ed if `tmux` or `claude` was missing — even for `--list-templates`, `--tip`, `--enable-tips`/`--disable-tips`, and `--install-hooks`, none of which touch tmux or claude (they only read/print or edit on-disk config). Those commands are now exempt; the check still gates every session-managing command (including `--save-template`, whose default form resolves the current session via tmux). This also unblocked the `build-and-check` CI job, whose read-only smoke runs `--list-templates` on a Linux runner with no tmux/claude. (`--guide`/`--commands`/`--config-help` were already unaffected — they exit during arg-parse, before the check.)

### Internal
- CI (`.github/workflows/ci.yml`) now installs `tmux` and a no-op `claude` stub before the read-only smoke, so the smoke exercises real command paths representatively rather than tripping the dependency check.

## [2.0.10] - 2026-06-19

### Fixed
- **The two actionable notices (claude-mux update available, Claude Code binary upgraded) can no longer be silently lost.** They previously "spent their gate" the moment the `UserPromptSubmit` hook injected them — not when the user actually saw them — but delivery depends on the session's Claude *relaying* the injected context (especially in Remote Control, which renders only the conversation). So a single non-relay permanently burned the notice: the update notice was suppressed for 7 days, the upgrade notice until the next binary upgrade. Now both are **persist-while-relevant**: re-injected every prompt while their condition holds (update: while a newer version is cached and `latest > VERSION`; upgrade: while the live `claude` binary id differs from the launch-captured `@claude-mux-claude-id`), so a missed relay simply retries next turn. Each self-clears when the user acts (update → VERSION rises; upgrade → restart re-captures the id). Claude de-dups within the conversation via a "mention once per session" instruction baked into the notice text. Design: `dev/features/notice-delivery-reliability.md`.

### Changed
- **Notices now ride the Remote-Control-proven `<assistant-must-display>` mechanism.** All three notices (tip, update, upgrade) are wrapped in `<assistant-must-display>` tags with firmer "MUST relay verbatim at the start of your reply" wording, and `build_system_prompt` gained a standing rule telling Claude to surface bracketed `[claude-mux ...]` notices verbatim, once per session. Honest scoping: the tag's force is *proven* for tool/command output, not for `UserPromptSubmit`-injected context, so this raises the odds materially but remains best-effort — deterministic delivery to a Remote-Control user needs an upstream Claude Code feature (a hook/RC channel that renders text directly to the remote user, bypassing the model); filed as an upstream ask.

### Internal
- The upgrade notice's `detect_claude_upgrade` no longer acks-on-emit (it used to overwrite `@claude-mux-claude-id` after echoing once). Self-clear now depends entirely on a restart re-capturing the id, so the in-place caller-restart path (the default for "restart this session" / restart-all-from-home, which bypasses the kill+recreate capture sites) now re-captures the id in `await_ready_handshake`. Without this the upgrade notice would re-inject forever after an in-place restart. Per-session state pruned to `{tip_date}` (the dead `update_notify`/`notify_version` fields removed).
- **`log()` is now self-healing and never affects control flow**, fixing the `build-and-check` CI job (red since the `src/*.sh` split). It `mkdir -p`s the log dir, makes the `touch`/`chmod`/append best-effort, and `return 0`s unconditionally — the trailing `[[ -t 1 ]] && echo` used to return 1 whenever stdout wasn't a TTY (CI, pipes), aborting callers under `bash -e`, and the macOS-only `~/Library/Logs` is absent on the Linux runner. Also hardens real macOS use if the Logs dir is wiped or relocated.

## [2.0.9] - 2026-06-19

### Fixed
- **claude-mux no longer rejects valid models it doesn't recognize.** The home-session model was checked against a closed allowlist `{sonnet, haiku, opus}` at three sites (config validation, `--home-model` flag, interactive install prompt), so a valid newer model like `fable` or `opus-4-8` errored with "must be sonnet, haiku, opus, or empty." The allowlist had to be hand-updated every release and was already stale.

### Changed
- **Model handling is now pass-through.** Which models exist is Claude Code's to know, not claude-mux's, so the membership checks are replaced with a format check: the value need only be a shell-safe token (`^[A-Za-z0-9._][A-Za-z0-9._-]*$`, leading dash forbidden to prevent arg-injection into the unquoted `claude --model ${model}` interpolation) and is passed straight through to `claude`, which validates it at launch. Empty still inherits Claude Code's default; default stays `sonnet`. The `src/20-config.sh` validation runs on every config load, so even a hand-edited `~/.claude-mux/config` is caught. Also de-versioned the injection's "ready" example from `"Opus 4.7"/"Sonnet 4.6"/"Haiku 4.5"` to `"Opus"/"Sonnet"/"Haiku"` (the instruction already says report your *actual* model; the versioned example just re-rotted each release). Design: `dev/features/model-handling-derot.md`.

### Internal
- **Two drift-prone doc indexes are now generated from source and guarded like `claude-mux`** (dev-tooling; the shipped `claude-mux` is byte-identical, no release). `make codemap` → `dev/CODEMAP.index.md` (every `^funcname()` in `src/*.sh` → `module:within-module-line`, iterating the explicit `$(MODULES)` so a stray file can't reorder it); `make features-index` → `dev/features/INDEX.md` (the build queue, projected from each feature doc's new `kind:`/`lifecycle:` frontmatter, FAIL on missing/unknown lifecycle for a `kind: feature` doc). Both fold into `make check` (`check-codemap` + `check-features-index`), and the pre-commit hook now runs the index checks **unconditionally**, so a hand-edit of a generated index or a frontmatter-only change can't slip past. This closes the structural-doc-drift class behind a real incident (`build_system_prompt` hand-mislabeled to module `70` instead of `30`, propagated across 5 docs): you cannot mistype a `grep` result. `dev/CODEMAP.md` keeps the prose (purposes, dispatch table, config vars); its function→location index moved to the generated file. Every `dev/features/*.md` migrated to carry `kind`/`lifecycle`. Design: `dev/features/make-codemap.md`.
- **`claude-mux` is now built from `src/*.sh` via `make build`.** The single ~4900-line script is split into 13 ordered fragments (`src/00-defaults.sh` ... `src/90-dispatch.sh`) that concatenate back into a **byte-identical** `claude-mux` (verified by `cmp`). Distribution is unchanged: curl and Homebrew still fetch the one committed `claude-mux`, which stays a committed (generated) artifact. No behavior, flag, config, or injection change. Developer workflow inverts: edit `src/`, run `make build`, never edit `claude-mux` directly. Drift is guarded by `make check`, a mandatory pre-commit hook (`git config core.hooksPath .githooks`), `.gitattributes` (marks the artifact generated), and a CI job (`make check` + `bash -n` + shellcheck-on-built-file + read-only smoke). No release (the shipped file is unchanged byte-for-byte).

## [2.0.8] - 2026-06-17

### Fixed
- **The daily tip and the update-available notice are no longer eaten by the post-restart `Ready?` handshake.** Both are injected by the `UserPromptSubmit` hook (`--on-prompt`), which fires on the *first* prompt of the day per session. After any restart or `/compact` reconnect, that first prompt is the synthetic `Ready?` handshake claude-mux sends itself - whose forced two-line reply ("Session ready!" / "Running ...") swallows the injected text, while the hook still stamped the once-per-day tip gate and the 7-day update throttle. So the tip almost never reached the user and the update notice was suppressed for a week. `on_prompt` now parses the hook's stdin once, detects the `Ready?` handshake (`prompt.strip() == "Ready?"`), and no-ops on it - injecting nothing and stamping no state - so the **first real prompt** after a restart surfaces the tip / update / upgrade notice. The Claude Code upgrade notice (also `on_prompt`) is covered too: the handshake check now runs before it.

## [2.0.7] - 2026-06-17

### Added
- **`--start SESSION...`**: start one or more sessions *by name*. Starts a session if it is stopped (resuming its prior conversation, or `--fresh` for a new one), and is a no-op if it is already running (prints "Session 'NAME' is already running." and never cycles a live session). Distinct from `-d` (which launches by directory *path*) and `-a` (which starts *all* projects). Conversational trigger "start session NAME" now maps to `--start NAME` (resolves by name, no path) instead of the misleading `-d NAME --no-attach`.

### Changed
- **`--restart NAME` now works on a stopped session.** Previously it resolved the working directory only from the live tmux session, so a stopped session errored "not found or cannot determine working directory". It now falls back to a by-name project lookup (`resolve_session_dir`) and, when nothing is running, skips the shutdown and just starts the session. Running-session restart (including the caller in-place path) is unchanged.

### Internal
- New `launch_home_session()` helper centralizes the home-launch setup (`LAUNCH_DIR`/`HOME_LAUNCH`/`LAUNCH_SESSION_NAME` + `launch_single_session`) so the stopped-home cases of `--start`/`--restart` bring home up via the proper path, preserving `HOME_SESSION_MODEL`. The LaunchAgent autolaunch path now uses it too.

## [2.0.6] - 2026-06-17

### Fixed
- **Restarting all sessions *from* the home session no longer loses home's history.** A restart-all (or a named restart targeting the caller) used to `kill-session` the caller's tmux pane - but the restart script runs *in* that pane, so the SIGHUP killed the script before it could recreate the session. External recovery then brought the caller back as a fresh conversation (history lost) or left Remote Control stuck. The launch wrapper is now a loop ("restart-in-place"): on a clean exit it checks a new `@claude-mux-restart` tmux option and, if set, relaunches `claude` in the *same* pane (resuming, or fresh for `--restart --fresh`) instead of tearing down - the pane and its Remote Control connection never go down, and no LaunchAgent/auto-restore recovery is needed. The caller of any restart now sets that option and sends `/exit` (`restart_caller_in_place`) rather than being killed; non-caller sessions keep the existing kill-and-recreate path. Closes the bug tracked since 2.0.4.

### Changed
- **The per-session system prompt now lives at `<project>/.claudemux-prompt`** (was a `$TMPDIR` temp file). It is regenerated with the current injection on every in-place relaunch (so a restart always picks up the latest prompt) and removed on final teardown. Mode `600`; covered by the `.claudemux-*` gitignore pattern.

### Internal
- New internal subcommands `--await-ready SESSION` (poll-until-ready, then send the "Ready?" handshake from outside the pane) and `--print-system-prompt SESSION MODE` (emit the injection for the wrapper to regenerate). Not user-facing.

## [2.0.5] - 2026-06-16

### Changed
- **A named session command that doesn't resolve now asks instead of silently acting on the current session.** The conversational trigger rules previously defaulted an unresolved session NAME to the current session ("restart session NAME ... or current session if none given"). That made "restart the claude-mux session" (said from `home`) restart `home` itself. The injection now resolves any named target against the live session list and, on no exact match or ambiguity, asks which session - it never falls back to the current session. Explicit "this session" / "current session" still self-targets. Applies to the whole class: stop, restart, restart-fresh, switch mode/model, compact, clear, hide/show, protect/unprotect. Injection change - takes effect after sessions are restarted.

## [2.0.4] - 2026-06-16

### Fixed
- **`--restart` (all) no longer strands sessions**: restarting all sessions from inside a managed session (e.g. `home`) used to `/exit` every session in alphabetical order via a blanket shutdown, including the caller - whose exit SIGHUPed the restart script mid-loop, leaving most sessions either `/exit`ed-but-not-relaunched (idle) or never reached (still running). The restart-all path now shuts down and recreates each non-caller session individually, honoring the caller partition (the caller is restarted last via the existing background handoff). The bug was ordering-dependent and hit hardest when the caller sorted early alphabetically.

### Changed
- **`--restart` (all) recycles protected non-caller sessions**: previously the blanket shutdown silently skipped protected sessions, so a `--restart` left them untouched. Restart now forces through protection for non-caller sessions (protection guards `--shutdown` accidents, not intentional restarts). The single-named `--restart SESSION` path still honors `--force` for protected sessions.
- **Sessions relaunch interleaved** (`shutdown -> create` per session) instead of all-shutdown-then-all-relaunch, so each session's recovery starts ~10s sooner.

### Added
- **`.claudemux-running` is preserved through a restart** (new `preserve_marker` path in `shutdown_single_session`), and a new transient `.claudemux-restarting` lock (atomic `mkdir`/`rmdir`) marks an in-flight restart. If a restart crashes mid-way, the auto-restore tick consumes the lock on sight, defers one tick, then recovers the session from the preserved marker - turning the old "stranded forever" failure into ~120s self-healing.
- **Resume-failure diagnostics in the launch wrapper**: the primary `claude -c` (resume) now captures stderr instead of discarding it (`2>/dev/null`). When a session can't resume and falls back to a fresh conversation, the wrapper logs the exit code, elapsed time, and stderr tail to `claude-mux.log` (`Primary resume launch for 'NAME' failed: rc=... after Ns; falling back to fresh session`). Surfaces *why* a restart occasionally comes up fresh (e.g. a Remote-Control session re-registration race) instead of leaving it silent.

## [2.0.3] - 2026-06-10

### Added
- **`--install-hooks`**: backfills claude-mux's hooks - including the v2.0.1 `PreCompact` `--on-compact` RC-reconnect hook - into every project's `.claude/settings.local.json` that is missing them. Idempotent; edits on-disk files only (no session restart). Prints a summary (`Scanned N project(s): patched M, K already current.`). Conversational trigger: "install hooks" / "backfill hooks" / "repair hooks".

### Fixed
- **PreCompact hook not reaching pre-v2.0.1 projects**: projects whose `settings.local.json` was last written before v2.0.1 lacked the `PreCompact` hook and got no RC reconnect after `/compact`. `--update` now backfills the hook into all projects after a successful version change, and `--install-hooks` does it on demand. Closes the gap without requiring a manual restart of each affected session.

## [2.0.2] - 2026-06-09

### Added
- **`-L --status STATUS` filter**: `claude-mux -L --status idle` (or `running`, `protected`, `stopped`, `queued`, `failed`, `hidden`) returns only rows matching that status. The `<assistant-must-display>` tags survive intact since there is no pipe, fixing the root cause of Claude reformatting filtered session lists. Injection trigger rules added: "list idle sessions", "list stopped sessions", "list running sessions", and the general pattern "list \<status\> sessions" all use `--status` instead of `| grep`.

## [2.0.1] - 2026-06-09

### Fixed
- **Universal `/compact` RC reconnect via PreCompact hook**: `/compact` typed directly in the pane, triggered by auto-compact, or sent via `claude-mux -s SESSION /compact` all now reconnect Remote Control. A new `PreCompact` hook (`--on-compact`) fires before every compact regardless of trigger, spawning a disowned monitor that polls for the prompt to return (up to 120s) then sends `Ready?`. The previous v1.14.2 fix only covered the `-s /compact` path; the new hook covers all cases universally.

### Removed
- The `-s /compact` special-case monitor (v1.14.2). RC reconnect is now handled entirely by the `PreCompact` hook registered in each project's `settings.local.json`.

## [2.0.0] - 2026-06-08

### Added
- **Auto-restore (self-healing)**: the keystone of the v2.0 self-healing milestone. Sessions now record a `.claudemux-running` marker, and the LaunchAgent tick (re-fired ~every 60s) brings back any session that should be alive but whose Claude process has died. One mechanism covers both reboot recovery and a mid-day-crash watchdog (zombies included, since liveness is a process-tree check, not `tmux has-session`).
  - A clean in-pane `/exit` (or `--shutdown`) removes the marker so the session stays down; a crash or kill leaves it, so the tick restores it. The generated launch script distinguishes a resume-that-failed-to-start (retried fresh within ~10s) from a real crash.
  - **Crash-loop guard**: after 3 fast deaths (within 5 min of a restore attempt) a session is tripped, shown as `failed` in `-l`, with a one-shot notice to the home session; say "restart X fresh" to recover. State lives in `~/.claude-mux/restore-state/`.
  - **Staggering** via `STAGGER_CONCURRENCY` (default 3) per `STARTING_WINDOW` (default 90s) avoids a reboot thundering-herd; home is launched first.
  - New config: `AUTORESTORE` (default `true`), `STAGGER_CONCURRENCY`, `STARTING_WINDOW`. New `-l` statuses: `queued` and `failed`.
  - **Activation:** auto-restore engages per session at (re)launch. After upgrading, restart your sessions ("restart all sessions", or `update claude-mux` which restarts automatically) so each one gets the marker and the new launch wrapper. Already-running sessions are not retroactively protected until restarted; the tick does not backfill markers onto live sessions.
- **Launch-wrapper hardening**: (1) the session's system prompt is now passed to Claude via `--append-system-prompt-file <path>` instead of `--append-system-prompt "<text>"`, so the full prompt is no longer visible in `ps`; (2) the prompt temp file is deleted right after the ready handshake (Claude reads it once at startup), shrinking its on-disk lifetime from the whole session to the startup window (the launch script's trap remains a backstop); (3) a clean in-pane `/exit` (rc 0) now tears down the tmux session, so a `create_claude_session` pane no longer lingers at a shell prompt after exit (a crash still leaves it for the restore tick).
- **Reliable ready-handshake**: the launch/restart poller no longer fires `Ready?` while a session is still busy. Previously it treated "the `❯` prompt is drawn" as ready, but on a `claude -c` resume large enough to auto-compact, the prompt is drawn for the whole compaction (~50s) while Claude is working, so `Ready?` misfired (and the 10s timeout expired mid-compaction). A new shared `poll_until_ready` detector waits for the session to be genuinely idle (no `esc to interrupt` busy signal in the status line, plus a quiescence check), with a ~120s timeout. The home/`-d` path runs it backgrounded so attach is never blocked.
- **Claude Code upgrade detection**: a running session keeps the `claude` binary it launched with, so a `brew upgrade` (or npm/curl upgrade) of Claude Code doesn't take effect until the session restarts. claude-mux now records the binary identity (`realpath:mtime`, covering both cask symlink repoints and in-place upgrades) at launch in a `@claude-mux-claude-id` tmux option, and the existing on-prompt hook injects a one-shot "Claude Code was upgraded since this session started; say 'restart this session'" notice when it changes. Always-on, notify-only (never auto-restarts or auto-upgrades), decoupled from auto-restore.

### Changed
- **Behavior change**: a crashed session or `tmux kill-session` now resurrects within ~60s while `AUTORESTORE` is on. To truly stop a session, use a clean `/exit` or `claude-mux --shutdown` (both remove the marker), or set `AUTORESTORE=false`.
- The hook-injected notices (daily tip, update-available, Claude Code upgrade) now instruct Claude to relay them in the user's conversation language, matching the explicit "tip of the day" command. Previously only the explicit command localized; the automatic per-prompt notices were English-only.

## [1.15.1] - 2026-06-05

### Added
- Two tip-of-the-day entries: automatic update notices (claude-mux now surfaces an "update available" notice in-conversation, including Remote Control) and starting an idle project by name (`start the api-server session`), reinforcing the names-not-paths convention.

## [1.15.0] - 2026-06-05

### Fixed
- **Tips now actually appear.** The tip-of-the-day was delivered via a Stop hook whose stdout is transcript-only (never surfaced in the conversation or Remote Control), and a global daily gate let the invisible path starve the one visible path. Tips are now injected via a `UserPromptSubmit` hook (the only delivery path proven to surface in RC) and gated per session, so each active session shows one tip per day.
- **Update notices now reach running sessions.** The TTY-gated update check never ran under Claude's Bash tool, and the in-session notice was built only at launch, so a running session never learned of a release mid-session. The same `UserPromptSubmit` hook now injects an "update available" notice from the cached release info, throttled to once per 7 days per session.

### Changed
- The tip-of-the-day Stop hook is replaced by a `UserPromptSubmit` hook (`--on-prompt`). `setup_claude_mux_permissions` registers the new hook and removes the legacy Stop hook automatically at the next session launch. The hook is registered when either `TIP_OF_DAY` or `UPDATE_CHECK` is enabled.
- The GitHub release check that the notice depends on now runs as a disowned background process (`--update-check-bg`) so the per-prompt hook never blocks on the network. An in-flight lock (`~/.claude-mux/.update-checking`, with a 5-minute stale guard) prevents duplicate checks when prompts arrive rapidly.
- `--tip` on demand now always works regardless of `TIP_OF_DAY` (previously it was incorrectly suppressed when tips were disabled).
- Session-start tips (sent via `send-keys` after launch) are removed; tips now arrive through the on-prompt hook instead.

### Removed
- The `--tipotd` Stop-hook command is retired (kept as a silent no-op so pre-upgrade sessions do not error until they restart).

## [1.14.2] - 2026-06-02

### Fixed
- **`/compact` RC reconnect**: instead of restarting the session after compact, the monitor now sends `Ready?` to the pane, which reconnects the RC WebSocket without disrupting the session.

## [1.14.1] - 2026-06-02

### Fixed
- **`/compact` RC hang**: sending `/compact` via `claude-mux -s SESSION /compact` (or "compact this session") now monitors for compact completion and recovers the RC connection. A background monitor polls the pane for compact completion, waits 2s, then sends a reconnect ping. Sessions typed into directly still require a manual `--restart SESSION`.

## [1.14.0] - 2026-05-30

### Added
- **Session start transparency**: Claude now reports its model and permission mode in the ready response:
  ```
  Session ready!
  Running Sonnet 4.6 in auto mode.
  ```
  The permission mode is passed from the launch command into the injection so Claude can report it accurately. Claude self-reports its model name.
- **Restart warning**: `--restart` and `--restart SESSION` now print a summary line before tearing down sessions, noting that RC connections will need to reconnect:
  ```
  Restarting 3 session(s) to apply updated injection. RC will need to reconnect in ~10s.
  ```

## [1.13.2] - 2026-05-30

### Fixed
- **Injection: silent resume**: after a resume/compaction continuation with no concrete pending action, Claude no longer emits filler text like "No response requested." The `ready` trigger rule was also tightened to explicitly forbid any additional turn after "Session ready!" until the user sends a new message.

## [1.13.1] - 2026-05-29

### Fixed
- **`--move` smart destination detection**: previously `--move SESSION /path/to/SESSION` errored because the command only accepted the parent directory. The command now also accepts the full destination path and strips the trailing session name when its basename matches `SESSION`. The error message now hints at the expected form when the parent does not exist.
- **`--move` injection clarification**: trigger rule and CLI help now explicitly state that the path argument is the destination's PARENT directory (must already exist), not the new full project path.
- **Listing output not summarized**: `-l` and `-L` now emit a row-count footer like `<!-- N rows above. Output must contain all N verbatim. -->` inside the `<assistant-must-display>` block, and the injection rule explicitly forbids collapsing visually-similar consecutive rows (e.g. multiple sessions in the same parent directory). Prevents Claude from rendering ranges like `"35-49 idle (15 work sessions)"`.

## [1.13.0] - 2026-05-10

### Added
- **Fresh-start restart**: `--restart SESSION --fresh` restarts a session without resuming the prior conversation. Useful after installing a new MCP or making global config changes that only take effect in a new Claude Code session.
  - Conversational triggers: "restart this session fresh", "restart SESSION fresh", "kill this session"
  - Works with `--restart` (named or all sessions) and `-d`
  - Caller-last ordering preserved: when restarting from inside the target session, the background handoff also passes `--fresh`
- **Tip #39**: teaches users the "restart this session fresh" / "kill this session" triggers

### Fixed
- **Injection: phantom replay mitigation**: Claude will no longer re-execute a command that was already handled earlier in the conversation when a system message appears to repeat prior exchange text
- **Injection: suppress `! <command>` suggestions**: Claude will not suggest the `!` shell passthrough syntax, which Remote Control users cannot use and terminal users do not need

## [1.12.6] - 2026-05-08

### Fixed
- **Template validation**: `--template NAME` now errors with a helpful message when the template doesn't exist, instead of silently creating the project without it

### Changed
- **README restructured** as a landing page: Install, Why, What You Can Do, Talking to Claude, More links
- **Reference docs moved to docs/**: CLI.md, guide.md, INSTALL.md, FAQ.md, ISSUES.md
- Replaced em dashes with regular dashes across all documentation

## [1.12.5] - 2026-05-08

### Fixed
- **Injection: gh auth for multi-account GitHub**: when multiple SSH accounts are configured, the injection now tells Claude to run `gh auth switch --user <account>` before `gh` CLI operations (repo create, PR create, etc.) and to verify the active account via `gh auth status` before any `gh` command. Previously only SSH remote aliases were mentioned, causing `gh` commands to use the wrong account.

## [1.12.4] - 2026-05-08

### Fixed
- **CLAUDE_MUX_BIN resolution**: restored `command -v` lookup before `dirname` fallback so the binary path resolves correctly when invoked via PATH.
- **install.sh pipe detection**: explicit check for pipe mode instead of relying on `/dev/stdin` path side-effect.
- **tty_in declaration order**: moved `tty_in` setup above first use in `do_install()` so the reconfigure prompt works in curl-pipe mode.
- **Portable sed in set_tip_config**: replaced macOS-only `sed -i ''` with portable `sed > tmp && mv` pattern.
- **Uninstall counter**: Python cleanup script now exits 2 for no-op so the counter only reports actually-modified files.
- **Uninstall completeness**: `do_uninstall` now cleans `additionalDirectories` entries alongside `allow` rules.
- **Uninstall message**: uses resolved `$CLAUDE_MUX_BIN` instead of redundant `command -v` lookup.
- **Tip text**: replaced CLI-flag tip with conversational "update claude-mux" tip.

### Added
- **FAQ.md**: 20 entries covering common questions (fork/update, Linux, home session, Remote Control, permission modes, templates, tips, SSH multi-account, Homebrew, uninstall, and more).

## [1.12.3] - 2026-05-08

### Fixed
- **Injection: absolute path rule**: added rule telling Claude to always use the full binary path from the injection header. Bare `claude-mux` fails when `~/bin` is not in PATH (e.g. LaunchAgent-started sessions).

## [1.12.2] - 2026-05-08

### Fixed
- **Interactive install via curl pipe**: `do_install()` skipped all interactive prompts when piped via `curl | bash` because stdin is the pipe, not a TTY. Now falls back to `/dev/tty` for user input, matching the standard pattern used by other curl-piped installers.

## [1.12.1] - 2026-05-08

### Fixed
- **install.sh curl pipe**: `BASH_SOURCE[0]` is unset when piped via `curl | bash` with `set -u`, causing an "unbound variable" error. Now defaults to `/dev/stdin`.

## [1.12.0] - 2026-05-06

### Added
- **`--tipotd`**: daily-gated tip command for use as a Stop hook. Exits in ~6ms on fast path (date already matches today). Falls through to print a tip once per day.
- **Tip-of-the-day Stop hook**: registered in each project's `.claude/settings.local.json` so long-running sessions that never restart still see tips. Managed automatically on session create/restart.
- **`--enable-tips` / `--disable-tips`**: register or remove the tip Stop hook across all known projects. Conversational triggers: "enable tips", "disable tips".
- **`--uninstall`**: removes tip hooks and claude-mux permission rules from all projects, unloads the LaunchAgent, and optionally removes `~/.claude-mux/`.

## [1.11.1] - 2026-05-05

### Changed
- **Tips rewrite**: all tips now focus on conversational commands instead of CLI flags or internal implementation details. Reduced from 44 to 37 tips.

## [1.11.0] - 2026-05-05

### Changed
- **Session names everywhere**: `--hide`, `--show`, `--protect`, `--unprotect`, `--delete`, `--rename`, and `--move` now accept session names instead of directory paths. No-arg defaults to the calling session. Resolves running sessions via tmux and idle projects via `PROJECT_DIRS` scan. Replaces `resolve_project_dir()` + `resolve_session_to_dir()` with a single `resolve_session_dir()`.

## [1.10.1] - 2026-05-05

### Changed
- **Session list output**: markdown table format when consumed by Claude (non-TTY), printf-aligned columns when in terminal (TTY). Both formats now include row numbers.
- **Session list sorting**: rows sorted by directory path instead of session name. Groups projects by category folder (development, personal, work).
- **Numbered session references**: injection prompt now supports "stop 1-3", "restart 5", "compact 2 and 4" - Claude maps numbers to session names from the most recent list.

## [1.10.0] - 2026-05-05

### Added
- **`--tip`**: prints one tip from the embedded tips array (42 tips). Standalone, ungated, works from any context.
- **Tip of the day**: first session started each day receives a tip via the injection prompt. Daily gate uses `~/.claude-mux/.tip-date`. Subsequent sessions that day skip it. Tips are stored in English; Claude renders them in the user's conversation language.
- **`TIP_OF_DAY` config option** (default: `true`): set to `false` to disable daily tips. `--tip` always works regardless.
- **`TIP_MODE` config option** (default: `daily`): `random` picks a non-deterministic tip each time; `daily` picks the same tip all day via day-of-year hash.
- **`--save-template NAME [DIR]`**: copies `CLAUDE.md` from a project directory to `~/.claude-mux/templates/<name>.md`. Name is lowercased and sanitized (non-alphanumeric → `-`). Refuses if `CLAUDE.md` is absent; warns on overwrite (bypass with `--force`). Supports `--dry-run`.
- **`--rename OLD NEW`**: renames a project directory, migrates `~/.claude/projects/` conversation history to the new encoded path, and updates the homunculus `projects.json` and per-project `project.json` registries. Stops a running session before rename and restarts it in the new location. Requires `--force` if the project is protected. Supports `--dry-run`.
- **`--move SRC DEST`**: moves a project into a new parent directory with the same behavior as `--rename`. `DEST` is the parent; the project keeps its name.
- **curl install**: `install.sh` now works when piped from curl. Detects curl-pipe vs local clone (checks for sibling binary); downloads the binary from GitHub releases when no local copy is found. Platform detection: on Linux, LaunchAgent setup is skipped with a note (full Linux support in v2.0).
- **`release-assets.yml`**: new GitHub Actions workflow uploads `claude-mux` and `install.sh` as release assets on every published release. Enables curl install and `--update` binary download.
- **`encode_claude_path()`**: encodes an absolute path to the format Claude Code uses for `~/.claude/projects/` folder names (every non-alphanumeric character → `-`). Verified empirically against real entries.
- **Conversational triggers**: `rename this project to NAME` → `--rename . NAME`; `move this project to PATH` → `--move . PATH`; `save this as a template named NAME`; `tip / tip of the day`.

### Fixed
- **`delete_command` force isolation** (M3): `shutdown_single_session` now accepts an optional `force` argument rather than reading the global `FORCE`. Prevents unintended global mutation.
- **`move_to_trash` TOCTOU** (M4): name collision suffix uses `$$` (PID) instead of second-granularity timestamp, guaranteeing uniqueness under rapid successive calls.
- **Startup polling loop** (M9/L8): after accepting the workspace trust prompt, the polling loop continues (`continue` not `break`) so a subsequent `bypassPermissions` confirmation prompt is also handled. Fixes session startup in new project dirs with bypassPermissions mode.
- **`bypassPermissions` detection** (L9): `grep -qi "yes.*accept"` replaces `grep "Yes, I accept"` for resilience to UI text changes.
- **`ensure_gitignore_entry` double-append** (L3): skips append if the pattern already appears in `.gitignore`.

### Changed
- **Quick Start** (README): curl one-liner is now the primary install method. Homebrew moved to "macOS alternative".
- **`install.sh` description**: updated to reflect curl-pipe support and platform detection.

## [1.9.1] - 2026-05-04

### Changed
- **Ready trigger**: claude-mux now sends `Ready?` (was `ready`) after a session starts. Expected response is `Session ready!` (was `Ready.`).

### Fixed
- **`--hide` on home directory**: `--hide` now refuses with an error if the target directory is `$BASE_DIR`. Hiding the home session from listings served no useful purpose and removed the always-on anchor from `-L` output.

## [1.9.0] - 2026-05-01

### Added
- **LaunchAgent KeepAlive**: home session is now resilient to crashes, manual shutdowns, and sleep/wake disruption. If home dies, the LaunchAgent relaunches it within ~60 seconds via the idempotent `--autolaunch` path. Note: `--shutdown home --force` will also be reversed by the LaunchAgent. To disable permanently: `claude-mux --install --launchagent-mode none`.
- **Per-project marker files** using the `.claudemux-*` naming convention. State follows the project folder across renames, moves, and syncs. Markers are auto-added to `.gitignore` when created in a git-tracked project.
- **`.claudemux-protected`** - session protected at launch. Created by default in `$BASE_DIR` during `claude-mux --install`.
- **`.claudemux-ignore`** - project hidden from `claude-mux -L` listings.
- **`--hide` / `--show`**: write or remove `.claudemux-ignore` for a project. Defaults to current directory.
- **`--protect` / `--unprotect`**: write or remove `.claudemux-protected` and toggle the runtime tmux marker on running sessions.
- **`--delete DIR`**: trash-safe project deletion (macOS only). Moves the project folder to `~/.Trash/` - never `rm -rf`. Recoverable via Finder. Requires `--yes` or interactive confirmation. Honors protection (requires `--force` to override). Refuses paths outside `$HOME`.
- **`-L --hidden`** / **`-L --include-hidden`**: list only hidden projects, or list all projects including hidden ones.
- **`--config-help`**: prints all valid config options with defaults, types, and descriptions.
- **`--commands`**: prints the full CLI reference. Replaces the inline Commands block in the session injection.
- **Home session permissions for `~/.claude-mux/**`**: home session can now read/edit/write its own config and templates without permission prompts.
- **Conversational triggers**: hide/show/protect/unprotect/delete project; in home session: show/set config, list/add/edit/delete templates.
- **Session ownership marker** (`@claude-mux-managed = 1`): tmux user option set on every session created by claude-mux. Used to detect collision with user-created tmux sessions that share a name.
- **Collision detection**: if a session name already exists but was not created by claude-mux, `--autolaunch` refuses to overwrite it and logs a warning.
- **`bypassPermissions` / `yolo` mode** (formerly broken): switching a session to yolo/bypassPermissions now works without hanging. Every session launches with `--allow-dangerously-skip-permissions`, so bypassPermissions is always in the Shift+Tab cycle. The startup polling loop now detects and auto-accepts the confirmation prompt. Subsequent switches use Shift+Tab navigation - no restart needed.
- **`--get-mode [SESSION]`**: prints the current permission mode of a session (`bypassPermissions`, `acceptEdits`, `plan`, `default`, or `unknown`). Defaults to current session when called from inside a tmux session. Mode is detected from the last few lines of pane content.

### Changed
- **`.ignore-claudemux` renamed to `.claudemux-ignore`**. No automatic migration. Users with the old file should rename:
  ```
  mv .ignore-claudemux .claudemux-ignore
  ```
- **Home session protection** is no longer hardcoded by session name. It is now driven by `$BASE_DIR/.claudemux-protected`, which `claude-mux --install` creates by default. Users can opt out by deleting the marker.
- **Injection prompt slimmed**: removed inline guide expansion and full Commands block. Replaced with a Reference lookups meta-block (`claude-mux --guide`, `--commands`, `--config-help`, `--list-templates`) and a compressed feature list. Saves ~800 tokens per session.
- **`--force` validation** extended: now also required with `--delete` (in addition to `--shutdown`) to override session protection.
- **`setup_claude_mux_permissions()`** now adds `~/.claude-mux/**` access rules and `additionalDirectories` entry for the home session's project.

## [1.8.1] - 2026-04-28

### Added
- **Version in session prompt**: each session now receives the running claude-mux version (`claude-mux version: X.Y.Z`) in its system prompt injection. Claude can report the current version without running shell commands.
- **Update notification in session**: if `~/.claude-mux/.update-check` contains a newer available version, the injection prompt instructs Claude to tell the user and suggest they say "update claude-mux".
- **"update claude-mux" trigger**: new conversational command. Claude warns that all sessions will be restarted, asks for confirmation, then runs `claude-mux --update` followed by `claude-mux --restart`.
- **`--install` and `--update` in session commands block**: both commands are now listed in the injection prompt's Commands reference so Claude knows about them.

## [1.8.0] - 2026-04-28

### Added
- **`claude-mux --install`**: interactive setup command that creates `~/.claude-mux/config` and installs the LaunchAgent. Self-contained - no separate scripts or files needed. Same prompts as the previous `install.sh` flow.
- **First-run prompt**: when a config-requiring command runs without `~/.claude-mux/config`, claude-mux prompts to run setup (TTY) or exits with a hint (non-TTY). No more silent config auto-creation.
- **Install flags**: `--non-interactive`, `--base-dir DIR`, `--launchagent-mode {none,home}`, `--home-model {sonnet,haiku,opus}`, `--no-launchagent`, `--permission-mode MODE`, `--cross-session-control` - all valid only with `--install`.
- **`protected` session status**: protected sessions (home) now show `protected` in the status column instead of `running*`. Clearer and consistent with other status values.
- **Current session marker**: the calling session is marked with `>` in the session name column (e.g. `> home`), making it easy for agents and users to identify which session is running the command.

### Changed
- **`install.sh` simplified**: now copies the binary to `~/bin/`, ensures PATH, and delegates to `claude-mux --install` for config and LaunchAgent setup. All install-flow logic moved into the script itself.
- **Plist template**: now generated by `claude-mux --install` from a heredoc in the script (`generate_plist`), with `${CLAUDE_MUX_BIN}` interpolation. Standalone `com.user.claude-mux.plist` removed from the repo - single source of truth.
- **`--no-launchagent`** is now an alias for `--launchagent-mode none`. Both skip the plist write entirely; no point installing a no-op plist.
- **Config behavior**: explicit `--install` always reconfigures (with confirmation prompt unless `--non-interactive`); first-run prompt only fires if config is absent. Previously, the script silently wrote a default config on every fresh run.
- **Reconfigure-from-home-session warning**: when `--install` is run from inside the home tmux session, prints a note that LaunchAgent changes take effect at next login but the current session continues.
- **First-run exits after setup**: after completing setup via the first-run prompt, claude-mux exits and asks you to re-run your command. Previously it would fall through and execute the original command with stale variable state.
- **`--non-interactive --install` requires `--force` to overwrite existing config**: prevents silent data loss when re-running install scripts against an existing setup.
- **`--permission-mode` validated on install**: accepted values are `default`, `acceptEdits`, `plan`, `auto`, `dontAsk`, `bypassPermissions`. Invalid values now error immediately.
- **`--base-dir` validated on install**: rejects shell metacharacters and requires the parent directory to exist before attempting to create the base directory.
- **Stopped protected sessions**: a protected session where Claude is not running now shows `stopped` rather than `protected`, reflecting actual state.

### Fixed
- **`install.sh` crash on no-arg invocation**: empty `INSTALL_ARGS` array under `set -u` triggered "unbound variable" before `claude-mux --install` was reached. Fixed with safe array expansion.
- **`launchagent_set` not set in interactive branch**: a user who answered "no" to the home session prompt had their choice silently overridden to `home` by the defaults block. Now correctly preserved.
- **`BIN_DIR` shell profile write**: replaced heredoc with `printf` to eliminate heredoc injection risk when writing PATH export to `~/.zshrc`/`~/.bashrc`.
- **Config write robustness**: `write_install_config` now uses `printf '%s\n'` instead of an unquoted heredoc, so user-supplied values cannot affect config file structure.
- **XML escaping in `generate_plist`**: `CLAUDE_MUX_BIN` is now XML-escaped before interpolation into the plist `<string>` element.
- **PATH hint box alignment**: the `source <profile>` line in the post-install PATH hint is now properly padded to align with the box border.

### Removed
- **`com.user.claude-mux.plist`** standalone file: replaced by the `generate_plist` heredoc in the script.

## [1.7.4] - 2026-04-27

### Fixed
- **Bash syntax error in injection prompt**: unescaped double quotes in the start-session confirmation example were terminating the `local prompt="..."` assignment in `build_system_prompt`, causing `--restart` and any other operation that builds the system prompt to fail with `local: ... not a valid identifier`. Reworded the example to avoid nested double quotes.

## [1.7.3] - 2026-04-27

### Fixed
- **`--restart` with `--no-attach`**: injection prompt now explicitly states `--no-attach` must not be added to `--restart` or `--shutdown`. Claude was over-applying the `-d`/`-n` rule, causing `--restart` to fail with exit code 1.
- **Silent command failure**: injection prompt now instructs Claude to report errors when a command fails, not just print verbatim output on success.

## [1.7.2] - 2026-04-27

### Fixed
- **Start session confirmation**: injection prompt now instructs Claude to confirm by session name only (not directory path), since sessions appear by name in Remote Control. Removes hedged "should now be running" wording.
- **`start new session` confirmation**: same name-only confirmation applied to the `start new session in FOLDER` trigger.

### Changed
- **Home session self-identification**: home session injection prompt now includes a line identifying itself as the always-on tmux session in the base directory, its protected status, and its role as the default Remote Control entry point.

## [1.7.1] - 2026-04-27

### Fixed
- **`--update` mv not checked**: installing the downloaded binary now fails loudly if `$install_path` is not writable, instead of printing a false success message.
- **`--update` VERSION validation**: downloaded script must contain `VERSION="<expected>"` exactly, not just any `VERSION=` string.
- **`--update` brew exit code**: `brew upgrade` failure now exits with an error instead of printing a false success message.

## [1.7.0] - 2026-04-26

### Added
- **Update notifications**: cached daily check against GitHub releases API. Displays one-line notification on interactive TTY when a newer version is available. Re-notifies weekly. Configurable via `UPDATE_CHECK=true/false`.
- **`--update` self-update**: downloads latest release from GitHub (or delegates to `brew upgrade` if installed via Homebrew). Offers to restart running sessions after update.
- **Dynamic path detection**: `tmux` and `claude` resolved via `command -v` at startup instead of hardcoded `/opt/homebrew/bin` paths. Supports Intel Mac, custom installs, and future Linux. Override via `TMUX_BIN`/`CLAUDE_BIN` in config.
- **Installer dependency warnings**: warns (non-blocking) if tmux or claude are not found at install time.
- **Installer upgrade mode**: detects existing `~/.claude-mux/config` and skips interactive prompts on reinstall, preserving user settings.

### Fixed
- **`send-keys` key-name injection**: all `tmux send-keys` calls now use `-l` (literal) flag for content, preventing tmux from interpreting text as key names.
- **`-s` command validation**: slash commands sent via `-s` must start with `/` and cannot contain newlines, preventing accidental or malicious injection into other sessions.
- **`perm_flags` shell injection**: permission mode flags in generated launch scripts are now split into name/value variables, preventing word-splitting or injection from a malformed mode value.
- **TMPDIR guard**: expanded from single-quote check to reject spaces, dollar signs, backticks, and double quotes in TMPDIR.
- **Temp file permissions**: explicit `chmod 600` on launch and prompt temp files after `mktemp`.
- **JSON escaping for `CLAUDE_MUX_BIN`**: permissions.allow entry now passes the path directly to Python instead of interpolating into a JSON string literal, correctly handling backslashes and quotes in the path.
- **Restart caller session**: `--restart` (all) now correctly recreates the calling session via a background handoff process instead of silently dropping it after SIGHUP.

### Changed
- CLI Reference section moved to end of README (before Troubleshooting), reinforcing that conversational usage is primary.

## [1.6.2] - 2026-04-26

### Added
- **`<assistant-must-display>` output tags**: listing commands (`-l`, `-L`, `--list-templates`) wrap output in XML tags when stdout is not a TTY, instructing Claude to display the full output verbatim. Fixes Sonnet summarizing session listings instead of showing them.
- **Table headers on session listings**: `-l` and `-L` output now includes STATUS, SESSION, DIRECTORY column headers.

### Changed
- **README restructured**: "Talking to Claude" section now leads after Quick Start, emphasizing conversational usage as the primary interface. CLI flags moved to "CLI Reference" section. "What It Does" simplified from 12 numbered items to 8 concise bullets.
- **Caller-last restart ordering**: when `--restart` (all) is invoked from inside a session, the calling session restarts last so it can finish restarting the others first.

### Fixed
- **Spanish translation fully regenerated** to match restructured English README.

## [1.6.1] - 2026-04-25

### Added
- **`ready` trigger on session start**: claude-mux sends `ready` after Claude finishes loading; Claude responds with "Ready." confirming the session is alive and the injection is working. Replaces the old "No response requested." behavior.

### Changed
- **Faster session restarts**: reduced typical restart time from ~12s to ~2s by replacing fixed `sleep` waits with 0.5s polling loops that detect Claude's input prompt and send `ready` immediately.
- **Faster shutdown polling**: reduced max shutdown wait from 30s to 10s, polling every 0.5s instead of 1s.

## [1.6.0] - 2026-04-24

### Added
- **Multi-CLI-coder integration**: claude-mux now creates `AGENTS.md` and `GEMINI.md` as symlinks of `CLAUDE.md` so Codex CLI, Gemini CLI, and other AI coders pick up the same project instructions. Auto-applies on every session start (new or existing project), idempotent. Configurable via `MULTI_CODER_FILES`; opt-out per-project with `--no-multi-coder` (with `-n`).
- **"Why" section in README**: short motivation paragraph above Quick Start to help new readers understand the problem solved.
- **CONTRIBUTING.md**: dev workflow, testing requirements, version bump policy, deprecation policy, translation contribution guide.
- **GitHub issue and PR templates**: `.github/ISSUE_TEMPLATE/` for bug, feature, and translation; `.github/PULL_REQUEST_TEMPLATE.md`.
- **CHANGELOG.md** (this file): backfilled from prior releases, maintained going forward.
- **Deprecation policy** documented in `CLAUDE.md`: features deprecated for one or two minor versions before removal, with warnings.

### Changed
- Installer prints clearer warnings about LaunchAgent autostart and auto-approval permissions so new users understand what's being enabled.

## [1.5.0] - Internationalization (2026-04-23)

### Added
- **12 README translations**: Spanish, French, German, Brazilian Portuguese, Japanese, Korean, Italian, Russian, Simplified Chinese, Hebrew, Arabic, Hindi. Files live in `translations/` with a language switcher at the top of each.
- **Language-agnostic injection rule**: trigger phrases like "help", "status", "stop this session", "switch to plan mode" work in any language. Claude infers intent from the user's native language and runs the matching command. Output stays in its original format.
- **Translation standards** documented in `CLAUDE.md`: covers what stays in English (CLI flags, product names, status keywords, system prompt block), what gets translated (prose, headers, conversational labels, inline shell comments, table descriptions), and script-aware placeholder rules.

### Fixed
- **Permission auto-approval matching**: session permission patterns now include both bare-name (`Bash(claude-mux *)`) and absolute-path (`Bash(/path/to/claude-mux *)`) forms so Claude Code's permission matcher recognizes commands regardless of how they're invoked. Migrated all existing project `.claude/settings.local.json` files.

### Removed
- **`LAUNCHAGENT_MODE=batch`**: removed (was deprecated). Existing configs warn and fall back to `home`. Legacy `LAUNCHAGENT_ENABLED=true` now maps to `home` (was `batch`).

### Deprecated
- **`-a` flag**: still functional, marked internally as a candidate for future removal. Home session plus conversational on-demand starts cover most use cases at lower resource cost.

## [1.4.0] (2026-04-19)

### Added
- **`--guide` command**: lists all conversational trigger phrases for use within sessions. Available as both a CLI flag and an in-conversation "help" command.
- **Conversational trigger phrases**: 15 natural-language commands baked into every session injection (help, status, list active/all sessions, start/stop/restart sessions, start new session, switch mode/model, compact, clear, list templates).
- **`--permission-mode MODE SESSION`**: switch a session's Claude permission mode (`plan`, `auto`, `bypassPermissions`, `dontAsk`, `dangerously-skip-permissions`, etc.) without leaving the conversation. Injection prompt teaches Claude that "yolo" is an alias for `dangerously-skip-permissions`.
- **Status injection rule**: saying "status" in any session reports session name, current model, current permission mode, context usage, then runs `-l`.
- **MIT License**.

### Fixed
- Template path traversal: templates are now bounds-checked against `TEMPLATES_DIR` before being applied.
- Installer plist substitution: replaced `sed` with Python to handle paths containing `|`.
- Temp file cleanup: prompt file is now removed on send-keys failure.
- Exit codes: all dispatch paths return explicit `exit 0`.
- Dry-run accuracy for `--restart`: reports "Would restart" instead of simulating kill.

## [1.3.0] (2026-04-15)

### Added
- Slash command rule in injection prompt: explicit instruction that Claude can send slash commands via `-s` and should never claim it cannot.
- `ISSUES.md`: known issues log.

### Fixed
- Multiple commands returned exit code 1 despite success - added explicit `exit 0` to all dispatch paths.
- Communication standards in CLAUDE.md: no LLM-stereotype writing, no em dashes in human-facing content.

## [1.2.0] (2026-04-12)

### Added
- **Home session**: an always-running protected session in `$BASE_DIR` that launches at login. Defaults to Sonnet (configurable via `HOME_SESSION_MODEL`). Always protected from accidental shutdown - `--shutdown home` requires `--force`.
- **`LAUNCHAGENT_MODE`**: configures LaunchAgent at-login behavior (`none`, `home`, `batch` - `batch` later removed in 1.5).
- **Auto-approve claude-mux in project permissions**: `setup_claude_mux_permissions()` adds claude-mux to each project's `.claude/settings.local.json` allow list.
- **Interactive installer**: `install.sh` prompts for install location, base directory, home session, and model. `--non-interactive` mode for scripted setups.
- **Restart improvements**: `--restart` remembers which sessions were running and only relaunches those. Bypasses home protection.
- **`--force` flag**: required to shut down protected sessions.
- **Multiple session arguments**: `--shutdown` and `--restart` accept multiple session names.

### Fixed
- `$TMUX` variable shadowing tmux's environment variable - renamed to `$TMUX_BIN`.
- Bash 3.2 incompatibility with associative arrays - replaced with string-based collision detection.
- `pgrep -P` unreliable on macOS - replaced with `ps -eo` + `awk`.

## [1.1.0] (2026-04-08)

### Added
- **CLAUDE.md template system**: maintain `~/.claude-mux/templates/*.md`, apply to new projects via `--template NAME` or default.
- **`-n DIRECTORY`**: create a new Claude project (git init, .gitignore, permission mode, template).
- **`-p` flag**: with `-n`, create directory and parents if they don't exist.
- **`--no-template`, `--no-git`, `--no-permission-mode`**: opt-out flags for `-n`.
- **Tmux quality-of-life**: mouse, 50k scrollback, clipboard (OSC 52), 256-color, reduced escape delay, extended keys (Shift+Enter), activity monitoring, terminal tab titles. All configurable.
- **`-s SESSION COMMAND`**: send a slash command to a running session via tmux send-keys.
- **`-L`**: list all projects (active + idle).
- **Session statuses**: active, running, stopped, idle.
- **Three-column status display**: status, name, path.
- **`-d DIRECTORY`**: explicit single-directory launch.
- **`-t SESSION`**: attach to a session by name.
- **`-l`**: list active sessions.
- **GitHub SSH account awareness**: detects accounts in `~/.ssh/config`, injects host aliases into the session prompt.

### Changed
- Renamed from `claude-autorc` to `claude-mux`.
- Default behavior changed from batch to single-directory launch; `-a` opt-in for batch mode.

## [1.0.0] (2026-04-05)

### Added
- Initial release as `claude-autorc`: persistent Claude Code sessions in tmux with Remote Control enabled.
- LaunchAgent for auto-start at login.
- Conversation resume via `claude -c`.
- Stray process migration: pulls non-tmuxed Claude processes into managed sessions.
- `--shutdown`, `--restart` flags.
- `--dry-run` for previewing actions.
- User config at `~/.claude-autorc` (later `~/.claude-mux/config`).
- Logging to `~/Library/Logs/claude-autorc.log` (later `claude-mux.log`).

[Unreleased]: https://github.com/pereljon/claude-mux/compare/v1.12.6...HEAD
[1.12.6]: https://github.com/pereljon/claude-mux/compare/v1.12.5...v1.12.6
[1.12.5]: https://github.com/pereljon/claude-mux/compare/v1.12.4...v1.12.5
[1.12.4]: https://github.com/pereljon/claude-mux/compare/v1.12.3...v1.12.4
[1.12.3]: https://github.com/pereljon/claude-mux/compare/v1.12.2...v1.12.3
[1.12.2]: https://github.com/pereljon/claude-mux/compare/v1.12.1...v1.12.2
[1.12.1]: https://github.com/pereljon/claude-mux/compare/v1.12.0...v1.12.1
[1.12.0]: https://github.com/pereljon/claude-mux/compare/v1.11.1...v1.12.0
[1.11.1]: https://github.com/pereljon/claude-mux/compare/v1.11.0...v1.11.1
[1.11.0]: https://github.com/pereljon/claude-mux/compare/v1.10.1...v1.11.0
[1.10.1]: https://github.com/pereljon/claude-mux/compare/v1.10.0...v1.10.1
[1.10.0]: https://github.com/pereljon/claude-mux/compare/v1.9.1...v1.10.0
[1.9.1]: https://github.com/pereljon/claude-mux/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/pereljon/claude-mux/compare/v1.8.1...v1.9.0
[1.8.1]: https://github.com/pereljon/claude-mux/compare/v1.8.0...v1.8.1
[1.8.0]: https://github.com/pereljon/claude-mux/compare/v1.7.4...v1.8.0
[1.7.4]: https://github.com/pereljon/claude-mux/compare/v1.7.3...v1.7.4
[1.7.3]: https://github.com/pereljon/claude-mux/compare/v1.7.2...v1.7.3
[1.7.2]: https://github.com/pereljon/claude-mux/compare/v1.7.1...v1.7.2
[1.7.1]: https://github.com/pereljon/claude-mux/compare/v1.7.0...v1.7.1
[1.7.0]: https://github.com/pereljon/claude-mux/compare/v1.6.2...v1.7.0
[1.6.2]: https://github.com/pereljon/claude-mux/compare/v1.6.1...v1.6.2
[1.6.1]: https://github.com/pereljon/claude-mux/compare/v1.6.0...v1.6.1
[1.6.0]: https://github.com/pereljon/claude-mux/compare/v1.5.0...v1.6.0
[1.5.0]: https://github.com/pereljon/claude-mux/compare/v1.4.0...v1.5.0
[1.4.0]: https://github.com/pereljon/claude-mux/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/pereljon/claude-mux/compare/v1.2.0...v1.3.0
[1.2.0]: https://github.com/pereljon/claude-mux/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/pereljon/claude-mux/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/pereljon/claude-mux/releases/tag/v1.0.0
