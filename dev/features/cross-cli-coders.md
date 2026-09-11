---
kind: feature
lifecycle: designing
feature: cross-cli-coders
status: planned (REVISED 2026-09-04: Codex 0.153.2 now has a native hook system, close in shape to Claude Code's - the "hooks are Claude-only" premise is outdated; see "Verified facts: Codex hooks now exist". Also found a live hazard - Codex's native `/import` migration copies claude-mux's own Claude-only hook commands into Codex projects verbatim (confirmed via Codex's own import ledger, not just timestamps), which can misfire; see "Hazard" section. Skills: migration exists but is one-time (manually re-runnable, not auto-synced); per-skill symlinks are mechanically viable but not recommended for existing content; see "Skills" section. If/when claude-mux launches Codex sessions itself (this feature), it should AUTHOR Codex-native hooks directly rather than sync/translate Claude's - see "Design: CLI-adapter abstraction". PRIOR: REVISED 2026-06-27 folded in the Codex mobile / remote-connections landscape - resolves open question #5 and sharpens the value prop; see "Landscape: Codex mobile" and "Why now")
milestone: v2.x (dovetails with v2.2 agent network)
---

# Feature: Cross-CLI coders (launch + inject Gemini CLI / Codex CLI, not just Claude)

Implementable design spec. Assumptions about Gemini/Codex injection were verified empirically against installed binaries (Gemini 0.45.2, Codex 0.138.0) plus official docs - see "Verified facts" before trusting anything here. Test plan: `cross-cli-coders-tests.md`.

## Goal

Let claude-mux launch and manage non-Claude AI coding CLIs (Gemini CLI, Codex CLI, and future ones) as first-class persistent sessions - persistence, context injection, and auto-restore - while keeping Claude-only runtime control (slash routing, ready-handshake, permission modes) gracefully degraded rather than broken. The differentiating principle: **the portable layer is file-based, the Claude-only layer is runtime-based.**

## Why now

- `MULTI_CODER_FILES` already symlinks `AGENTS.md`/`GEMINI.md` → `CLAUDE.md`, so the *static* instruction layer is already cross-CLI. Users have confirmed Gemini/Codex launch fine in claude-mux folders (passive: their context-file conventions pick up the symlink).
- The v2.2 agent network is designed file-based (delete-on-read inbox). A CLI-agnostic launch+inject path means Gemini/Codex sessions can join the network *by pull* for free - same architectural bet. Build the adapter and the inbox on the same "portable = file-based" foundation.
- codemap (JordanCoin) is prior art: its Agent-Aware Handoff is CLI-agnostic precisely because it never *controls* the CLI - it writes a file the CLI reads on start. Confirms the principle.
- **Codex now has first-party mobile (2026-05); its weakness is exactly claude-mux's strength.** Native Codex mobile keeps the host reachable only while it is awake and Codex is open ("if the host sleeps, loses connectivity, or closes Codex, remote access terminates"). claude-mux's tmux + LaunchAgent + auto-restore is the persistence layer that gap is begging for: a `codex` CLI kept alive in tmux survives precisely the conditions that kill native Codex mobile. So the cross-CLI value prop is **persistence + fleet management under someone else's mobile transport**, not providing mobile access ourselves - the same shape as Claude Code, where Anthropic's RC is the transport and claude-mux supplies persistence. See "Landscape: Codex mobile" below.

## Landscape: Codex mobile (investigated 2026-06-27)

Two ways to reach Codex from a phone, both relevant to how a claude-mux-managed Codex session would be surfaced on mobile:

- **OpenAI first-party (ChatGPT app, iOS+Android, preview, all plans).** Phone is a remote control for a running **Codex App** instance on macOS/Windows (Windows "coming soon"), or an SSH host. A **secure relay** keeps trusted machines reachable across your authorized ChatGPT devices without exposing them to the public internet, and syncs active session state across devices. Setup: host shows a QR code -> scan -> ChatGPT account auth. No persistent daemon; spawns an app server on demand (for SSH, over `ssh`, auto-discovering `~/.ssh/config` aliases). **Host must stay awake/online.** Also has Computer Use (drive desktop apps/Chrome), device-to-device handoff that preserves git state via worktrees, voice. Key nuance: it targets the **Codex App** (the GUI/app-server), not necessarily a `codex` CLI running in a tmux pane.
- **codex-relay (gronxb, community OSS).** The CLI-first analog: a Node.js relay on the host (port 8787) bridges the mobile app to the local **Codex CLI**. QR + approval-code pairing; code/git/session stay local; phone reaches it over Wi-Fi/LAN/Tailscale. `npx codex-relay@latest`. This is "claude-mux's local-first philosophy, for Codex."

**Consequence for this feature:** claude-mux manages CLI processes in tmux, so the natural mobile bridge for a claude-mux-launched Codex session is **codex-relay (CLI-based)**, not OpenAI's first-party app (App/GUI-based). The compelling stack is: claude-mux = persistence + fleet, codex-relay = phone transport -> "Codex mobile that survives a sleeping host." Whether OpenAI's first-party app can also attach to a CLI session (vs only the App) is unverified; assume the CLI/relay path. Either way, claude-mux does **not** implement the mobile transport - it supplies the persistent session the transport attaches to.

## Current state (what's Claude-hardcoded)

The passive layer works today. The active layer does not. Grounded in the script:

| Touchpoint | Function / line (approx, see `dev/CODEMAP.md`) | Claude coupling | Cross-CLI difficulty |
|---|---|---|---|
| Launch invocation | `create_claude_session` ~2960, `launch_single_session` ~3279 | `claude -c --remote-control --permission-mode ... --allow-dangerously-skip-permissions --model X --name S --append-system-prompt-file F` - every flag Claude-specific | per-CLI launch template |
| Liveness | `claude_running_in_session` ~1342/1348 | greps process tree for `/claude/` | trivial - parameterize regex |
| Dynamic per-session inject | launch line `--append-system-prompt-file` | additive per-launch file; no direct equivalent elsewhere | per-CLI file mechanism (below) |
| Ready-handshake | `poll_until_ready` | scrapes Claude TUI `esc to interrupt` busy signal | per-CLI TUI scraping (brittle) - Tier 2 |
| Slash routing | `-s` send + injection triggers | `/model`, `/compact`, `/clear` | per-CLI vocab or n/a - Tier 2 |
| Permission modes | `--permission-mode`, Shift+Tab, "Yes, I accept" detect | Claude mode names + confirm prompt | per-CLI approval flag (below) |
| Upgrade detection | `claude_binary_id` ~3410 | `claude` binary `realpath:mtime` | parameterize per binary |
| Stray-process adoption | `pgrep -f "$CLAUDE_BIN"` ~3025/3172 | matches Claude binary | parameterize per binary |

**Important nuance:** the user's "it worked" test launched Gemini/Codex *manually in a prepared folder*. claude-mux's own launch path (`-d`/`-n`) hardcodes the `claude` binary and Claude flags, and auto-restore's liveness greps for `claude` - so a claude-mux-launched Gemini session would launch the wrong binary with rejected flags and be declared dead by the restore tick. Cross-CLI launch is net-new work, not a config tweak.

## Verified facts: injection mechanisms (the core finding)

Claude's `--append-system-prompt-file` is **per-launch, additive, non-destructive** - bolts our instructions onto the built-in prompt without discarding CLI defaults. Neither competitor has that exact primitive. Each has two mechanisms:

| Mechanism | Claude | Gemini CLI (0.45.2) | Codex CLI (0.138.0) |
|---|---|---|---|
| **Additive** (append, keeps defaults) | `--append-system-prompt-file` | `GEMINI.md` context files (hierarchical, auto-loaded) | `AGENTS.md` + `AGENTS.override.md` (hierarchical, auto-loaded) |
| **Override** (replaces whole system prompt) | n/a | `GEMINI_SYSTEM_MD` env var → file (`1`/`true` → `.gemini/system.md`; else = abs path) | `model_instructions_file` in `config.toml` (formerly `experimental_instructions_file`) |

**Rule: use the additive path, never the override path.** Both override mechanisms *replace* the entire built-in system prompt ("none of the original core instructions apply unless you include them yourself"), discarding the CLI's own tool-use scaffolding. Gemini's override offers `${AgentSkills}`/`${SubAgents}`/`${AvailableTools}` placeholders to re-inject defaults, but it's fragile and version-coupled. Not worth it.

**The additive files are exactly what `MULTI_CODER_FILES` already symlinks.** So the *static* injection (session-management trigger rules, identical for every session) is already portable. The gap is *dynamic per-session* injection.

### Dynamic per-session injection (the real engineering)

Claude injects different content per session (this session's tmux name for self-reference, permission mode, version/upgrade notices) via a unique per-session temp file. Gemini/Codex additive files are folder-scoped. In claude-mux's model session maps 1:1 to folder, so folder-scoped is *mostly* fine - but the symlink occupies the `GEMINI.md`/`AGENTS.md` filename (it *is* `CLAUDE.md`), so we can't write dynamic bits there without editing `CLAUDE.md`. Per-CLI hooks:

- **Codex: clean.** `AGENTS.override.md` takes priority over `AGENTS.md` and is a *separate* file. Write the per-session dynamic block there; `AGENTS.md` (→ `CLAUDE.md`) stays the shared static layer. Two-layer split, no override risk. Auto-gitignore it (not a `.claudemux-*` file, so add an explicit ignore entry or document it).
- **Gemini: workable, messier.** No additive override-file equivalent. Options, least-bad first:
  1. Additional hierarchical `GEMINI.md` in a subdir/parent that Gemini also loads, carrying only the dynamic block (keeps the symlinked root `GEMINI.md` for static). Verify Gemini's hierarchical load order picks it up.
  2. `.gemini/system.md` + `GEMINI_SYSTEM_MD=1` with `${AgentSkills}`/`${AvailableTools}` placeholders to preserve defaults. This is the override path - heavier, version-coupled, last resort.
- **Claude: unchanged.** Keep `--append-system-prompt-file`.

## Verified facts: Codex hooks now exist (updated 2026-09-04)

The "Current state" table's assumption that hooks are Claude-only is **outdated**. Original research (2026-06-27) verified against **Codex 0.138.0**, which had no hook system. Installed Codex as of 2026-09-04 is **0.153.2**; hooks were added in the interim (GitHub PR "Add compact lifecycle hooks"; a v0.148.0 changelog covers "Async Hooks and MCP Tool Hooks"). Verified against the official docs (`developers.openai.com/codex/hooks`, redirects to `learn.chatgpt.com/docs/hooks`) plus live config on this machine:

- **Config:** `~/.codex/hooks.json` (global) and `<repo>/.codex/hooks.json` (project) - both load and **compose** ("higher-precedence config layers don't replace lower-precedence hooks"), unlike a single-file override.
- **Schema is the same shape as Claude Code's**: `{"hooks": {"<Event>": [{"matcher": ..., "hooks": [{"type": "command", "command": ..., "timeout": ...}]}]}}`. Confirmed identical structure in real installed plugin hook files (e.g. `~/.codex/.tmp/plugins/plugins/figma/hooks.json`).
- **Events, with real per-event limits** (not 1:1 with Claude Code - verify before relying on any of these for a Tier-1/2 design):

  | Event | Fires | Can block/inject | Key limit |
  |---|---|---|---|
  | `PreToolUse` / `PostToolUse` | around a tool call | yes | **shell commands only** - not Read/Edit/Write |
  | `UserPromptSubmit` | user submits a prompt | inject context / block | ignores `matcher`, no `if` filters |
  | `SessionStart` | session begins | inject context | matcher on `source`: **`startup`, `resume`, `clear`, `compact`** (confirmed - `clear` is valid) |
  | `PreCompact` / `PostCompact` | around history compaction | `continue:false` blocks | matcher on `trigger` (`manual`/`auto`); plain stdout ignored |
  | `Stop` | turn ends | can request continuation | ignores `matcher` |
  | `SessionEnd` | archive/delete/30-min-idle-no-clients | **advisory only, cannot block** | doesn't run for subagents; timeout **defaults to 1s, max 3s** |
  | `PermissionRequest` | approval needed (shell escalation, network, etc.) | `behavior: allow/deny`, deny wins | matcher on `tool_name` |
  | `SubagentStart` | a subagent begins | inject context only | `continue:false` is parsed but does **not** stop the subagent |
  | `SubagentStop` | a subagent ends | can request continuation | must emit valid JSON on exit 0 - plain text is invalid (opposite of most other events) |

- **Trust gating:** unlike Claude Code, every hook must be explicitly reviewed/trusted (tracked by content hash); a TUI panel shows Installed vs Active counts, and new/changed hooks sit at 0 Active until trusted (`--dangerously-bypass-hook-trust` exists for automation but is flagged DANGEROUS).

This changes the Tier-1/2 split's premise: Codex now has a real per-event hook mechanism for the two events claude-mux actually keys on (`SessionStart` clear-matcher, `UserPromptSubmit`), not just TUI-scraping. Re-evaluate `poll_until_ready`'s "skip + settle delay" default against this before finalizing the build - a hook-based ready signal may now be viable for Codex specifically (Tier 1, not Tier 2), even though it likely still isn't for Gemini.

## Hazard: claude-mux's own hook commands, reused blindly by the official Codex migrator (found 2026-09-04)

OpenAI ships **two separate, parallel migration paths** from Claude Code config into Codex's own: the native **`/import` TUI slash command** (Rust, `tui/src/external_agent_config_migration/*` + `app-server/src/external_agent_migration/processor.rs`) and the bundled **`migrate-to-codex` Python skill** (a distinct implementation of similar functionality - initially conflated as one thing during this research, corrected below). Both convert `.claude/settings.json` hooks -> `.codex/hooks.json` **verbatim, by command string**. Observed in the wild: a claude-mux project (`dynavlan`) has a `.codex/hooks.json` with the *exact* three hooks claude-mux installs for Claude Code - `PreCompact -> claude-mux --on-compact`, `SessionStart:clear -> claude-mux --on-clear`, `UserPromptSubmit -> claude-mux --on-prompt` - copied verbatim. **claude-mux itself did not write this file** (confirmed: zero `codex`/`.codex` references anywhere in `src/`); Codex's own native `/import` produced it (see database-level proof below), unprompted by and unknown to claude-mux.

Read the actual handler bodies (`src/75-tip-notices.sh`) to assess what happens when these fire inside a Codex turn instead of a Claude Code one:

- **`on_compact` / `on_clear`** call `spawn_ready_handshake_monitor`, which scrapes **Claude Code's own TUI busy/idle text** to know when to send a synthetic `Ready?` and reconnect **Claude Code's** Remote Control. Under Codex: the TUI text pattern won't match (different UI chrome), so the monitor most likely times out silently (harmless no-op) - or, if it has any fallback path, could type a literal `Ready?` into the Codex pane, which Codex has no concept of as a synthetic handshake and would answer as a real user message, producing a stray, confusing turn. Either way there is nothing to actually "reconnect" - Codex's own `remote-control` subcommand is an unrelated mechanism from Claude Code's `--remote-control`. Best case: no-op. Worst case: UX noise, not destructive.
- **`on_prompt`**: the background `--update-check-bg` spawn is harmless and CLI-agnostic. But the tip-of-day and update-available notices are emitted as `<assistant-must-display>...</assistant-must-display>`-tagged stdout - a convention taught **only** by claude-mux's Claude-Code system-prompt injection (`build_system_prompt`, delivered via `--append-system-prompt-file` to the `claude` binary specifically). A Codex session **never receives that instruction**, so if this fires there, the raw tags will most likely leak into the visible chat as garbled literal text, or be silently dropped/paraphrased - unpredictable either way. This is the same class of problem already tracked as an open soft spot in project memory (tag-relay hardening: raw `<assistant-must-display>` tags leaking into chat), but **guaranteed rather than occasional** here, since Codex has zero training on the convention at all.
- **Structural root cause:** none of the three handlers verify (a) that the invoking session was actually launched/is managed by claude-mux, or (b) which CLI is running in the pane. They act purely on the tmux session name (`#S`) plus whatever JSON shape the hook happens to receive. That blind trust was a reasonable bet while claude-mux was the only thing that could install these hooks - the official Codex migrator's blind-copy behavior invalidates it.

**Origin doubly confirmed (2026-09-04, second source: the dynavlan Claude Code peer session cross-checked with the live Codex CLI session running in that same project).** OpenAI's own docs have a section literally titled "Hooks -> Codex hooks" describing this exact import/migration feature. The `dynavlan/.codex/hooks.json` was generated 2026-08-04 12:17:49, ~20 minutes *before* the first Codex CLI session ever touched that repo - i.e. during Codex's project-setup/import flow, not a later manual action. File is untracked and excluded via `.git/info/exclude` (confirmed empty `git ls-files .codex/` / `git status --porcelain .codex/`), consistent with local-only migration output.

**Third source, asked directly (2026-09-04): Codex itself confirms the same origin**, attributing the import to "Codex Desktop's project/setup import flow" (a self-report, superseded in precision by the ledger proof below), citing `.claude/settings.local.json` created Aug 3, `.codex/hooks.json` created Aug 4 12:17:49, hook definitions "semantically identical, only event ordering differs."

**Fourth source, database-level proof (2026-09-04) - supersedes all timestamp-correlation reasoning above.** Codex persists every `/import` outcome in its own local state db. Queried read-only (`sqlite3 ~/.codex/state_5.sqlite`, table `external_agent_config_imports`): a real import record, `import_id df528792-74b3-404d-8ece-abc875772bf5`, `completed_at` **2026-08-04 12:17:49 local - an exact match to `hooks.json`'s mtime, to the second** - with `successes` listing all three hooks explicitly (`HOOKS / PreCompact -> PreCompact`, `HOOKS / SessionStart -> SessionStart`, `HOOKS / UserPromptSubmit -> UserPromptSubmit`) and zero failures. **This confirms the creator was the native `/import` command specifically**, not the `migrate-to-codex` skill (both exist, but only one actually produced this artifact) - correcting an attribution conflation in this doc's earlier revision. Four independent lines of evidence (claude-mux's own investigation, the dynavlan peer's file/doc cross-check, Codex questioned directly, and now Codex's own import ledger) all agree on origin and mechanism.

**New discrepancy found via the ledger, not yet resolved:** `/import` logged `PreCompact` as a **success** (source and target both literally `PreCompact`) - but the separate `migrate-to-codex` skill's own `references/differences.md` lists `PreCompact` as having "No direct equivalent... Codex does not expose matching lifecycle coverage today." Two explanations, not yet distinguished: (a) `differences.md` is simply stale relative to current `/import` behavior - plausible, since it's self-dated "last checked 2026-04-20" and the *authoritative live docs* fetched directly earlier in this research (`developers.openai.com/codex/hooks`) describe `PreCompact` as a real, currently-documented, fully-functional event with genuine block/inject behavior, which would mean the ledger's "success" is simply correct and up to date; or (b) `/import` logs success merely for writing the config entry, without verifying a matching lifecycle trigger actually exists - i.e. a cosmetic success. Reading (a) is more consistent with everything else verified this session, but only a live-fire test (does the hook script actually execute on a real compact) fully closes it - deliberately not forced, to avoid injecting input into another live session. `SessionStart`'s `matcher: "clear"` has a similar-shaped open question for a different, already-known reason (Codex's public docs confirm `clear` as a valid matcher value, so that one is not actually in doubt - only `PreCompact`'s liveness is).

**Mitigating factor found, tempers urgency without closing the design gap:** Codex hooks require a **persisted trust grant** before they execute, not just file presence - confirmed via the `--dangerously-bypass-hook-trust` flag's own description ("DANGEROUS... run enabled hooks without requiring persisted hook trust") and the TUI's Installed-vs-Active distinction seen earlier. A search of `~/.codex/config.toml` and other local config for `hook_trust`/`trusted_hook`/`hooksTrust` keys found **no evidence this repo's hooks have ever been trust-granted** - consistent with (not proof of) the notices never having actually fired here. **Live-fire behavior remains genuinely unconfirmed**: the live Codex session in that project (pid 48202, started 2026-09-04 11:37am) hadn't triggered a compact in its short life, so there's no direct evidence either way, and the dynavlan session correctly declined to force one by injecting input into someone else's live interactive terminal - respecting session boundaries over completing the test.

**Net read:** the hazard is not necessarily live today in this specific case (trust may never have been granted), but it is **latent and real for the moment a user clicks "Trust all and continue"** on a migrated project - at which point the tag-leak risk in `on_prompt` applies at first fire with no additional gate. Doesn't change the recommendation, only its urgency.

**Recommendation (not implemented - discussion finding only):** harden `on_compact`/`on_clear`/`on_prompt` to detect they're actually running under a claude-mux-managed Claude Code session before acting (e.g. check the pane's running process, or a Claude-Code-only marker) and no-op cleanly otherwise. No destructive risk found either way. Worth a small standalone patch independent of whether cross-cli-coders itself ever gets built, since the exposure exists today via a tool claude-mux doesn't control, and activates silently the moment a user trusts the migrated hooks.

## Skills: defer to the official migrator; per-skill symlinking is mechanically viable but not recommended for existing content (found + tested 2026-09-04)

Claude skills (`.claude/skills/<name>/SKILL.md`) **do** migrate to Codex (`.agents/skills/<name>/SKILL.md`, support dirs copied) via either of Codex's two migration paths - the native **`/import`** TUI command or the bundled **`migrate-to-codex`** Python skill (see "Hazard" above for the attribution correction between the two) - part of a broader native agent-migration system introduced ~Codex 0.128-0.142. `/import` in particular imports instructions, MCP servers, skills, plugins, hooks, slash commands, subagents, and up to 50 recent chats in one pass. **Confirmed explicitly: this is not automatic/passive sync** - "no bidirectional sync... one-time migration operation." Matches the timestamp evidence found earlier (dynavlan's `.codex/hooks.json` was written once, at import time).

**But it IS manually re-runnable as a pull-on-demand update, verified against the actual script's `--help`.** `migrate-to-codex.py` has no "skip if already migrated" logic - re-invoking it (or `/import` again) re-reads whatever the Claude-side source says *right now* and regenerates the Codex-side target from that. `--merge` (default) keeps "orphan" generated skills/agents whose Claude-side source has since disappeared; `--replace` prunes them instead. So a claude-mux hook/skill change doesn't stay stale forever in a migrated project - it stays stale until someone deliberately re-runs the import, at which point it catches up. Nothing currently prompts a user to do that re-run, though - staleness is correctable, not self-healing.

**Symlink mechanics, tested empirically - corrects the initial finding below.** A symlinked **root** `.agents/skills` directory is confirmed broken and will stay that way: `openai/codex#11314`, closed "not planned" by OpenAI's own maintainers (Codex v0.98.0; "the tool doesn't traverse symlinked directories" at the root). But a **per-skill** symlink - `.agents/skills` a real directory, with an individual `.agents/skills/<name>` entry symlinked elsewhere - is a different code path and **works**: verified live with `codex debug prompt-input` in a throwaway test project, which correctly discovered and read a skill through the symlink (listed in Codex's own model-visible skill catalog, description read straight off the symlinked file). Unlike the official migrator, a live symlink would stay **continuously in sync** - the one thing the one-time import doesn't offer.

**Still, do not build a claude-mux symlink for *existing* skill content (superpowers, claude-md-management, etc.) the way we do for CLAUDE.md.** The mechanical blocker is gone for per-skill links, but the semantic objections below are unchanged - they're about content compatibility, not filesystem mechanics:

1. **The official migrator's own precedent argues against it.** Even for `CLAUDE.md` - far more provider-neutral than skill content usually is - its converter deliberately *breaks* the symlink and generates a rewritten copy whenever it detects Claude-only semantics (hook/agent/settings-path/permission-mode language) in the content. That's OpenAI's own team concluding blind symlinking is often wrong once content references Claude-specific mechanisms. Skill bodies are far denser with exactly that kind of reference than typical `CLAUDE.md` prose.
2. **Frontmatter incompatibility, verified against the official differences table:** `allowed-tools`, `user-invocable`, `model`/`effort`, `disable-model-invocation`, `argument-hint`/`context`/`agent`/`hooks`/`paths`/`shell` all have "no direct equivalent" in Codex. A symlinked `SKILL.md` carrying these either gets silently ignored (skill loads, doesn't behave as designed) or risks rejection - neither is verified-safe without per-skill review, which is exactly what the official tool does and a bare symlink can't.
3. **Separate invocation model.** Codex ships its own bundled system skills (`skill-creator`, `skill-installer`, `plugin-creator` under `~/.codex/skills/.system/`) - a structurally similar but distinct implementation, not literal interop with Claude's `Skill` tool. Skill body text written for Claude's exact tool names/invocation discipline doesn't translate verbatim.
4. **Most of what's actually installed here wouldn't be touched anyway.** `superpowers` and `claude-md-management` are **plugins**, not standalone skills. The official migrator's own docs: `.claude/plugins/` -> "manual_fix_required only... does not copy plugin trees." Only bare `.claude/skills/<name>/SKILL.md`-shaped items are auto-converted at all.

**Recommendation:** keep claude-mux's remit at the instruction-file layer only (the one surface the official migration paths also treat as safe-by-default, though note even they gate that on content "looking provider-neutral" - a slightly more conservative bar than claude-mux's own current *unconditional* `MULTI_CODER_FILES` symlink, worth a look separately). For skills/agents/hooks/MCP, point users at OpenAI's own `/import` or `migrate-to-codex` rather than reimplementing translation claude-mux has no comparative advantage at doing - **except** for hooks specifically in a claude-mux-launched Codex session, where authoring correct Codex-native hooks directly (not translating Claude's) is legitimately in scope; see "Design: CLI-adapter abstraction".

**Invocation syntax, confirmed against the primary docs (`learn.chatgpt.com/docs/build-skills`, 2026-09-04):** Codex CLI/IDE invokes a skill by direct mention, **`$skill-name`**, or lists them via **`/skills`**; ChatGPT itself uses `@skill-name` instead. Different trigger mechanism from Claude's own `Skill` tool call - another concrete point of non-interop, on top of the frontmatter/prose issues already covered.

**Narrower idea worth keeping on the table, not building now:** since per-skill symlinks genuinely work and stay live-synced (an advantage the official one-time migrator lacks), an opt-in mechanism for **user-authored, deliberately provider-neutral** custom skills - written without Claude-specific frontmatter fields or Claude-tool-name-dense prose, the same discipline `MULTI_CODER_FILES` already assumes of `CLAUDE.md` - could be symlinked per-skill for free. This is explicitly NOT a fit for existing plugin ecosystems like superpowers (dense with Claude-specific mechanism references, and plugins aren't even in the official migrator's auto-scope). Would need its own opt-in marker, analogous in spirit to `MULTI_CODER_FILES` but at skill granularity - out of scope for this feature's first cut. **Practical rule for anyone hand-authoring a skill meant to survive migration/symlinking either way** (matches OpenAI's own guidance, reported via Codex's self-knowledge, not independently re-verified against a fetched primary page): keep the main `SKILL.md` provider-neutral; isolate runtime-specific permissions, hooks, invocation syntax, and model assumptions into separate files/sections. Treat any imported or shared skill as "works after review," never "drop-in identical."

## Design: CLI-adapter abstraction

A per-CLI profile selected by a `CODER` config var (global default) and/or a `.claudemux-coder` project marker (per-folder override, marker-file philosophy). Default `claude` - zero behavior change for existing users.

```
profile: claude
  binary: claude
  launch: claude {resume:-c} --remote-control {perm} --allow-dangerously-skip-permissions {model} --name '{S}' --append-system-prompt-file '{F}'
  resume_flag: -c
  liveness_regex: /claude/
  inject_static: MULTI_CODER (CLAUDE.md, read directly)
  inject_dynamic: --append-system-prompt-file (per-session temp file)
  caps: slash_routing, permission_modes, ready_handshake, rc, upgrade_detect

profile: gemini
  binary: gemini
  launch: gemini {resume:-r latest} {approval} -m {model}        # NO --name, NO append flag
  resume_flag: -r latest   |  --session-id <uuid>
  liveness_regex: /gemini/
  inject_static: MULTI_CODER (GEMINI.md → CLAUDE.md symlink, existing)
  inject_dynamic: extra hierarchical GEMINI.md  (fallback: .gemini/system.md + GEMINI_SYSTEM_MD)
  approval_map: default→default, acceptEdits→auto_edit, plan→plan, bypassPermissions→yolo (-y)
  caps: permission_modes(approval-mode), resume, model, mcp      # NO slash_routing, NO claude-style ready-handshake

profile: codex
  binary: codex
  launch: codex {resume} {sandbox/approval} -c model={model}     # NO --name, NO append flag
  resume_flag: resume --last  (subcommand, not a flag)
  liveness_regex: /codex/
  inject_static: MULTI_CODER (AGENTS.md → CLAUDE.md symlink, existing)
  inject_dynamic: AGENTS.override.md  (separate file, priority over AGENTS.md)
  approval_map: codex sandbox/approval flags (verify exact names pre-build)
  caps: permission_modes(sandbox), resume(subcmd), model, mcp, rc?(remote-control subcmd) # NO claude slash vocab
```

Capability flags let `status`, `-l`, slash-routing, and ready-handshake **no-op gracefully** for CLIs lacking a feature instead of misfiring. E.g. `-l` shows a Gemini session as `running` via liveness, but "compact this session" returns "not supported for gemini sessions" rather than send-keys garbage.

### Tier split (where to stop)

- **Tier 1 - "persist any CLI" (portable, the target of this feature).** Parameterized binary + launch template + resume + liveness regex + static inject (existing symlinks) + dynamic inject (per-CLI file) + auto-restore + stray-adoption. Achievable for all three. A Gemini/Codex session persists, survives reboot, and receives session-management instructions.
- **Tier 2 - "manage any CLI like Claude" (per-CLI, brittle, explicitly OUT).** Slash routing, Claude-TUI ready-handshake, Claude permission-mode cycle, RC reconnect. Each needs bespoke TUI-scraping; features may not exist on target. Do NOT chase. Capability flags degrade these to no-ops.

### Ready-handshake for non-Claude CLIs

`poll_until_ready` scrapes Claude's `esc to interrupt`. For Tier 1, do NOT port the busy-signal scraper. Options: (a) skip the handshake for non-Claude profiles and use a fixed settle delay before declaring ready; (b) per-profile `ready_regex`/`busy_regex` if a stable signal is found (verify per CLI - risky, Tier 2). Default: skip + settle delay. Auto-restore liveness (process-tree, not TUI) already works profile-agnostically once the regex is parameterized.

## Bonus: non-Claude control surfaces are richer than first assumed

Both have direct analogues that make Tier-1 reachable (verify exact flag names at build time):

- **Resume**: Gemini `-r/--resume` (+ `--session-id <uuid>`, `--session-file`); Codex `resume`/`fork` subcommands. Map to Claude `-c`.
- **Permission modes**: Gemini `--approval-mode default|auto_edit|yolo|plan` (+ `-y/--yolo`); Codex sandbox/approval flags. Map to claude-mux mode names via `approval_map`.
- **Model**: Gemini `-m`; Codex `-c model=`.
- **MCP / hooks / skills**: both have them (`gemini mcp|hooks|skills`, `codex mcp|plugin`).
- **Remote-control-ish**: Codex has a `remote-control` subcommand; Gemini has `--acp` (Agent Client Protocol). NOT the same as Claude RC - do not assume mobile-app parity. **Update (2026-06-27):** Codex mobile is now real (OpenAI first-party relay + the community **codex-relay** CLI bridge). For a claude-mux-managed Codex session the realistic transport is **codex-relay** (it bridges the Codex CLI, which is what we run in tmux); OpenAI's first-party app targets the Codex App/GUI and may not attach to a tmux CLI session. Gemini `--acp` mobile reachability is still unconfirmed. See "Landscape: Codex mobile". claude-mux supplies the persistent session; it does not implement the transport.

## Ties to v2.2 agent network

If the inbox is file-based (it is - `~/.claude-mux/inbox/<name>/`, delete-on-read), a Gemini/Codex session whose static context file (`GEMINI.md`/`AGENTS.md` → `CLAUDE.md`) teaches it to poll the inbox joins the network **by pull** for free. Only the push-nudge (send-keys to an idle session) needs per-CLI prompt detection (Tier 2). Build the inbox format CLI-agnostic from the start. See ISSUES.md "Inter-agent messaging."

## Out of scope

- Tier-2 runtime control for non-Claude CLIs (slash routing, Claude-style ready-handshake/permission cycle, RC reconnect).
- The `GEMINI_SYSTEM_MD` / `model_instructions_file` override path (rejected: destroys CLI defaults).
- Auto-detecting which CLI a folder "wants" - selection is explicit via `CODER` / `.claudemux-coder`.
- Per-CLI upgrade-detection notices (parameterizable later; not in first cut).

## Open questions (resolve before finalizing build)

1. Gemini hierarchical `GEMINI.md` load order - does an extra dynamic file in a subdir/parent reliably load alongside the symlinked root? (Test empirically.)
2. Codex `AGENTS.override.md` - confirm it's additive-on-top vs full-replace, and confirm exact gitignore handling.
3. Exact Codex approval/sandbox flag names and whether a non-interactive equivalent of "auto mode" exists.
4. Does either CLI accept a session *name* we control (Gemini `--session-id` is a UUID; Codex naming?) so `-l`/restart can map name→session like Claude `--name`?
5. ~~RC reality for Codex `remote-control` / Gemini `--acp` - mobile-app reachable or not?~~ **RESOLVED 2026-06-27 (Codex):** Codex mobile exists; the claude-mux-compatible path is **codex-relay** (CLI bridge), since OpenAI's first-party app targets the Codex App/GUI, not a tmux CLI session. Remaining: (a) verify whether OpenAI's first-party app can attach to a `codex` CLI session at all; (b) Gemini `--acp` mobile reachability still unconfirmed. See "Landscape: Codex mobile".

## Change checklist (per CLAUDE.md)

- [ ] `claude-mux`: `CODER` config var + `.claudemux-coder` marker reader; adapter profile table; parameterize `create_claude_session`/`launch_single_session` launch lines; parameterize `claude_running_in_session` + stray-adoption regex; per-profile dynamic-inject writer; capability-gated slash/handshake.
- [ ] `config.example` + `config_help()`: `CODER` (default `claude`).
- [ ] Marker registry (`CLAUDE.md`, `dev/CODEMAP.md`): `.claudemux-coder`.
- [ ] Injection prompt: capability-aware (don't teach `/compact` to a gemini session).
- [ ] `dev/CODEMAP.md` / `dev/SKELETON.md`: new functions + parameterized launch flow.
- [ ] `docs/GUIDE.md` + `docs/CLI.md`: cross-CLI usage, per-CLI caveats, Tier-1/Tier-2 boundary.
- [ ] `README.md`: advertise multi-CLI launch (currently only "symlinks for shared instructions").
- [ ] `CHANGELOG.md`, `VERSION` (minor bump).
- [ ] `docs/ISSUES.md`: collapse this entry to STATUS + pointer once shipped.
