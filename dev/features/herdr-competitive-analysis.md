---
kind: investigation
feature: herdr-competitive-analysis
status: RESEARCH 2026-08-08 (fetched herdr.dev landing + docs + GitHub README; secondary reviews). Some published figures conflict across sources — flagged inline as UNVERIFIED. No hands-on install or code read.
related: session-activity-timestamps, inter-agent-messaging, orchestrator-hub, cross-cli-coders
---

# Investigation: Herdr (herdr.dev) vs claude-mux

Analysis-only. Establishes what Herdr is, where it overlaps claude-mux, what is worth
adopting, and what the strategic exposure actually is — so the v2.1/v2.2 milestones rest on
a read of the landscape rather than a guess.

## Sources

- https://herdr.dev/ (landing, fetched 2026-08-08)
- https://herdr.dev/docs (fetched 2026-08-08)
- https://github.com/herdrdev/herdr (README, fetched 2026-08-08)
- https://www.bitdoze.com/herdr-agent-multiplexer/ (third-party review)

**Conflicting/unverified figures.** The landing page and the search-surfaced README summary
disagree on license (Apache-2.0 vs AGPL-3.0-or-later) and on GitHub stars (~25.9k vs ~15k).
Install count (362k) and plugin count (528) come from the vendor's own landing page only.
None of these were independently confirmed; do not cite them as fact.

## What Herdr is

A **terminal multiplexer replacement**, written in Rust, with first-class awareness of AI
coding agents. Not a wrapper around tmux — a competitor to tmux and zellij.

- Background server owns the ptys; sessions survive lid-close, network loss, reboot.
- Single Rust binary, no Electron; runs in any terminal. macOS/Linux native, Windows beta.
- Mouse-first UI: click panes, drag borders, split and switch from right-click menus.
  Keyboard prefix is `ctrl+b` (tmux-compatible muscle memory).
- **Agent state detection**: reads terminal output and labels each pane
  **working / blocked / idle**.
- **Socket API + CLI as one surface that agents themselves drive**: spawn panes, prompt
  another agent, block until another agent is genuinely blocked.
- ~19 supported agents (Claude Code, Codex, Cursor, opencode, grok, …). Explicitly does not
  wrap or replace them: "it just owns their terminals."
- Plugin marketplace (local executable workflow plugins, shared via GitHub).
- Install: `curl -fsSL https://herdr.dev/install.sh | sh`, also Homebrew and binaries.
- v0.8.0, ~105 days old at time of research, YC-backed, one full-time developer.

## What claude-mux is (v2.2.0), for contrast

Shell script + macOS LaunchAgent **on top of** tmux. Claude-Code-specific. The interface is
the conversation, not the terminal.

## Axis-by-axis

| Axis | Herdr | claude-mux |
|---|---|---|
| Layer | Replaces the multiplexer | Sits above tmux |
| Interface | Terminal UI, mouse + keys | Natural language, in-session |
| Primary client | Local terminal / SSH | Phone (Remote Control) |
| Unit of work | Pane | Project |
| Agent scope | ~19 agents, agent-agnostic | Claude Code first-class |
| Platform | macOS, Linux, Windows (beta) | macOS only |
| Implementation | Rust binary | Bash + tmux + LaunchAgent |
| Backing | YC, 1 FTE | Solo maintainer |

**Genuine overlap:** persistence across lid-close/crash/reboot, and multi-CLI-coder support.
That is the whole of it.

**Herdr does not do:** remote/mobile access without SSH; slash-command routing over Remote
Control; project scaffolding (git init + CLAUDE.md templates); auto-restore-on-login as an
OS service; the agent managing its own sessions conversationally; project lifecycle
(rename/move/delete/hide/protect) with history preserved.

**claude-mux does not do:** pane/window management; agent state detection; agent-to-agent
coordination via a socket API; cross-platform; non-Claude agents as first-class.

## What is worth adopting

1. **Agent state detection (working / blocked / idle)** — the strongest idea here, and it
   lands directly on an existing claude-mux gap. `claude-mux -l` today reports
   running/idle/stopped/protected, which is *process* liveness, not *work* state. A mobile
   user's actual question is "which session is stuck waiting on me?" — Herdr answers that,
   claude-mux does not. Plausible mechanism: `tmux capture-pane` over the last N lines of
   each pane, pattern-matched for the prompt-waiting vs streaming states. Feeds
   `session-activity-timestamps` (which already owns the recency/staleness half of
   situational awareness) rather than duplicating it. **Recommend promoting to a feature
   doc.**
2. **A "wait until session X is idle" primitive** — the socket-API idea reduced to the one
   piece that matters for claude-mux. `-s` already sends; there is no way to *await*. This
   is the missing sequencing primitive for the v2.2 Agent network milestone and for
   `orchestrator-hub`. Depends on (1): you cannot await idle without detecting idle.
3. **Mouse-first pane UX** — out of scope. claude-mux does not own the terminal UI and
   should not start (Design Principles: "Lean over featureful", "don't duplicate what tmux
   already handles").
4. **Plugin marketplace** — reject. Direct conflict with "Infrastructure, not a framework."

## Strategic read

Herdr competes with **tmux**, not with claude-mux. Its value is the substrate; claude-mux's
value (conversational self-management, Remote Control plumbing, project lifecycle) sits a
layer above and is orthogonal. In principle claude-mux could one day run on Herdr instead of
tmux — that is a substrate swap, not a displacement.

The real exposure is velocity, not overlap: a funded project shipping fast could absorb the
mobile/remote layer, which is where claude-mux's differentiation lives. The moat remains
**Remote Control integration + the Claude-manages-Claude injection model** — the same moat
identified against Codex mobile in the `codex-mobile-landscape` note. Herdr does not
currently threaten it; it has no mobile story beyond SSH.

Watch for: Herdr shipping a phone client or a hosted relay. That would be the signal to
re-evaluate.

## Open questions (not researched)

- How does Herdr's state detection actually classify panes — output-pattern heuristics, or
  per-agent adapters? Determines how cheaply claude-mux can approximate it over tmux.
- Does the socket API expose an await/block primitive, or only fire-and-forget spawn?
- License, genuinely (see the Apache/AGPL conflict above) — matters if any code is ever read
  for reference.
