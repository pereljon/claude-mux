---
kind: feature
lifecycle: designing
feature: cross-cli-coders
status: planned
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
- **Remote-control-ish**: Codex has a `remote-control` subcommand; Gemini has `--acp` (Agent Client Protocol). NOT the same as Claude RC - do not assume mobile-app parity. Investigate separately before promising RC for non-Claude.

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
5. RC reality for Codex `remote-control` / Gemini `--acp` - mobile-app reachable or not?

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
