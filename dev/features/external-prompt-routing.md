---
kind: feature
lifecycle: designing
feature: external-prompt-routing
status: DESIGNED via brainstorm 2026-09-11, verified against live `claude -p` behavior and primary-source Anthropic ToS research. REVISED 2026-09-11 - async delivery reworked to caller-owned `--incoming-dir` + atomic `.` marker-file completion signal (replaces an earlier `/tmp/claude-mux/<id>.txt` draft), for consistency with `hermes-claude-p-skill.md`'s direct-calling path - a caller now sees the same delivery contract whether it goes through `--route` or calls `claude -p` itself. Pending architect review before `ready`.
target_version: unscheduled minor (new capability, not a bug fix)
severity: N/A (new capability)
related: inter-agent-messaging, cross-cli-coders, hermes-claude-p-skill
---

# Feature: external prompt routing (`--route`)

Let external, non-Claude agents (Hermes named as the motivating example; not exclusive to
it) send a prompt into a claude-mux-managed project and get the result back, synchronously
or asynchronously - without those agents needing to know Claude Code's CLI flags, project
paths, or safety framing themselves.

## Why this belongs in claude-mux, not in Hermes

Considered directly: if the only caller is one Hermes instance calling occasionally, Hermes
could just shell out to `claude -p` itself - less code, nothing new to maintain. The
feature only earns its place because the goal is the **reusable, multi-caller,
eventually-MCP-exposed** version: one shared safety default (untrusted-content framing)
enforced centrally instead of trusted to every caller; one integration point multiple
external agents (present and future) can use instead of each reimplementing project
resolution + continuity + async delivery; and a foundation an MCP server can wrap later
without new callers reinventing this logic. If ever reduced to "just Hermes, once," revisit
whether this is still worth carrying as a maintained feature.

## Verified facts (checked live on this machine, 2026-09-11, not assumed)

- **`claude -p` / `--print` skips the workspace-trust dialog entirely** ("the workspace
  trust dialog is skipped when Claude is run in non-interactive mode" - `claude --help`).
  The trust-dialog bug class fixed in v2.3.1 does not apply to this feature's mechanism.
- **`--output-format json` gives structured output** - no `tmux capture-pane`, no TUI
  parsing, no quiescence polling. Confirmed live: `claude -p --output-format json "..."`
  returns a JSON object with a `result` field containing the plain-text answer.
- **CLAUDE.md loads automatically from the working directory in `-p` mode**, same as
  interactive mode - Claude Code's own hierarchical file discovery, unrelated to
  `--append-system-prompt-file`. Confirmed live: asked `claude -p` (no extra flags) to
  quote a design principle from this repo's own CLAUDE.md; it answered correctly
  ("Lean over featureful"). **No claude-mux action is needed to deliver project context**
  to a routed worker - running it in the right directory is sufficient.
- **`--append-system-prompt-file` is a separate, additive mechanism**, confirmed from
  claude-mux's own source (`src/55-session-launch.sh`, `src/70-start-launch.sh`): it
  carries claude-mux's OWN injected instructions (`build_system_prompt()` output - the
  interactive session-management rules: `-s` handling, ready-handshake, peer messaging).
  It is unrelated to CLAUDE.md and additive on top of Claude Code's own defaults. For a
  routed one-shot worker, the *interactive*-session injection is inapplicable (no `-s`
  self-reference, no ready-handshake, nothing to restart) - routed workers get their own,
  much smaller system-prompt file (see "Untrusted-content framing" below), not
  `build_system_prompt()`'s output.
- **`--append-system-prompt`, `--permission-mode`, `--allow-dangerously-skip-permissions`
  all compose with `-p`** (general launch flags, not print-mode-specific per `claude --help`).

## Account-suspension risk research (primary sources, 2026-09-11)

Investigated before committing to this design, since automating calls via a non-interactive
CLI at the request of an external agent is a materially different usage pattern from
interactive use.

- **What actually caused documented bans (OpenClaw/OpenCode/Cursor-type tools):** extracting
  a Claude Pro/Max subscription's OAuth token and feeding it into a *different,
  non-Anthropic* client/reimplementation. Anthropic's own words (quoted via The Register's
  coverage): *"Using OAuth tokens obtained through Claude Free, Pro, or Max accounts in any
  other product, tool, or service ... is not permitted."* Detection signal cited: traffic
  that looks like Claude Code usage but is **missing the telemetry the real Claude Code
  harness emits** - i.e. a different program impersonating the client.
- **Primary Consumer Terms clause** (quoted exactly, from `anthropic.com/legal`): *"Except
  when you are accessing our Services via an Anthropic API Key or where we otherwise
  explicitly permit it, [you may not] access the Services through automated or non-human
  means, whether through a bot, script, or otherwise."* Claude Code's own documented
  "Pipe, script, and automate with the CLI" section functions as that "explicitly permit
  it" carve-out - for the official CLI, scripted by its owner.
- **Why this design is NOT the banned pattern:** it spawns the actual, official `claude`
  binary as a subprocess via its own documented `-p` flag - not a token extracted into a
  separate reimplementation. Architecturally identical to what claude-mux already does for
  every other feature (launch the real binary), just a different invocation shape.
- **Genuine remaining ambiguity, not resolved by any primary source found:** no language
  either explicitly permits or restricts an *external, independent agent* (Hermes)
  triggering calls into the CLI as a callable backend, at whatever volume it wants - a
  different framing from "a developer scripting their own CI pipeline." Anthropic is
  actively watching for "unusual traffic patterns" as a signal, separate from the
  token-reuse issue. The Feb 2026 "clarification" (their word, not a new rule) signals
  active enforcement attention on subscription-automation patterns generally.
- **Resulting design constraints (load-bearing, not cosmetic):**
  1. Scope this as a **personal, single-user, low-volume local bridge** - not built,
     marketed, or documented as "a service other agents can hit." Matches claude-mux's
     existing philosophy anyway.
  2. **Auth must be swappable to an Anthropic API key later** without redesigning the
     feature - the "except via an Anthropic API Key" clause is the unambiguous safe
     harbor if Hermes-driven volume ever grows or this starts looking service-like. Not
     built in the first cut (adds real complexity - API key handling, billing
     implications), but the design must not make this swap hard later (see Open
     Questions).

## Architecture

**Plain subprocess, no tmux session.** A routed request is one-shot and non-interactive -
architecturally different from every other claude-mux session (persistent, interactive,
human-attachable). It gets a direct subprocess call, not a managed tmux session:

```
claude -p --output-format json \
  --permission-mode auto \
  --append-system-prompt-file <routed-worker-prompt-file> \
  "<prompt, with prior-exchange context prepended if --id has a cached exchange>"
```

run with cwd = the target project's directory (resolved via claude-mux's existing
project-name -> path resolution, the same machinery `-l`/`-L` use - no new lookup logic).

**Rejected alternative:** reusing the tmux+TUI machinery (send-keys inject, poll for
quiescence, `tmux capture-pane`) - the shape `inter-agent-messaging.md` assumed, since it
was designed for peer *sessions*. Rejected: needs the trust/ready-handshake dance v2.3.1
just hardened (irrelevant to `-p`), pane-scraping is fragile (ANSI chrome, status lines,
box-drawing), heavier (a full tmux session for a one-shot need), and slower.

## Interface

```
claude-mux --route PROJECT "prompt text" [--wait | --incoming-dir DIR] [--id THREAD-ID] [--timeout N]
```

- **`--wait`** -> synchronous: blocks, prints the JSON result's `result` field to stdout
  when the worker finishes.
- **`--incoming-dir DIR`** (required for async - no `--wait`) -> asynchronous: returns
  immediately; **claude-mux delivers into the CALLER's own directory, not a claude-mux-owned
  path.** This mirrors `hermes-claude-p-skill.md`'s revised delivery contract (2026-09-11)
  exactly, so both the claude-mux-mediated (`--route`) and direct-calling (Hermes calling
  `claude -p` itself) paths behave identically from a caller's point of view - a caller that
  learns one learns both:
  1. The result text is written to `DIR/<id-or-guid>.txt` (the JSON result's `result`
     field, not the raw JSON envelope).
  2. **Only after that file is completely written**, claude-mux touches a companion marker
     `DIR/.<id-or-guid>` - same base name, hidden dotfile, empty, no content needed.
  3. **The caller must wait for the `.<id-or-guid>` marker, never poll `<id-or-guid>.txt`
     directly** - the marker's existence, not its content, is the atomic completion signal;
     reading the `.txt` file before its marker exists risks a partial/mid-write read.
  - **No `--wait` and no `--incoming-dir`** is a usage error (previously implied a
    claude-mux-owned `/tmp/claude-mux/` default - that default is removed; delivery
    location must always be caller-specified now, matching "the caller's own folder, not
    claude-mux's" from the Hermes-skill revision).
- **`--id THREAD-ID`** (optional) - if given, used as BOTH (a) the async result/marker
  filename base (`DIR/<id>.txt` + `DIR/.<id>` instead of a random GUID) and (b) the
  continuity cache key. Omitted -> a random GUID is generated for the filename base, and no
  continuity is engaged (a genuinely stateless one-shot call).
- **`--timeout N`** - proposed default 120s (matches `poll_until_ready`'s existing
  convention elsewhere in the codebase for consistency, though this call has no TUI to
  poll - it is a subprocess wait/kill timeout instead).

## Continuity (single-slot cache, not a growing history)

A small durable cache at `~/.claude-mux/routes/<id>/last.json`: `{prompt, response,
timestamp}`. On a call with a known `--id` that has a cached entry, that prior exchange is
prepended into the new prompt as context (e.g. "On <datetime> you were asked: <prompt>. You
replied: <response>. New request: <new prompt>"), then the cache is overwritten with the
new exchange after the call completes. Deliberately not full history.
**Framing precision (avoids an ambiguity a future implementer could resolve either way):**
the replayed prior *prompt* is external input, same untrusted-content framing as the new
prompt; the replayed prior *response* is Claude's own earlier output, not external input -
it does not need (and should not get) untrusted-content framing. Both are still clearly
labeled as "prior exchange, for context" so the worker doesn't confuse replayed context with
the actual new request.

## Untrusted-content framing (a shared template, not claude-mux-private)

Per the "verified facts" above, routed workers do NOT get `build_system_prompt()`'s
interactive-session injection (irrelevant to a one-shot call). They get a small, dedicated
file via `--append-system-prompt-file` whose only job is: mark the prompt content as
external, untrusted input from a non-Claude agent, to be treated as data, not instructions
- the same principle already adopted (on paper, unbuilt) in `inter-agent-messaging.md` for
peer messages. Same risk class (arbitrary text from outside injected into a session), same
mitigation.

**This is not a claude-mux-internal artifact.** The exact text lives at
`dev/features/external-agent-untrusted-framing.txt` as one canonical, reusable template -
because the same principle applies whether the caller goes through a future `--route`
implementation (claude-mux applies the file itself) or an external agent calls `claude -p`
directly with no claude-mux code in the path at all (the agent must apply the file itself,
via its own `--append-system-prompt-file`). Both consumers point at the same file rather
than each carrying their own copy that can drift.

## Authorization

**One global switch**, `EXTERNAL_ROUTING_ENABLED` in `~/.claude-mux/config`, default
**off** - matching Claude Code's own precedent for cross-session messaging (coarse,
global), not per-project markers. `--route` errors clearly if the switch is off, or if
PROJECT does not resolve to a claude-mux-managed project. **Fine-grained authorization
(which agents, which projects) is explicitly out of scope** - deferred to the orchestrator,
consistent with the existing claude-mux (write-plane/launcher) vs. orchestrator
(read/coordinate-plane/policy) split established elsewhere in this project's planning.

## Out of scope (this build)

- **MCP server exposure.** The transport decision was CLI-first, MCP as a later target.
  The core routing logic (resolve project, build the worker prompt, invoke `claude -p`,
  capture/store the result) should live in one internal function the CLI wraps thinly, so
  an MCP server can wrap the SAME function later without re-architecting - but building
  the MCP server itself is a separate, future feature.
- **Anthropic API-key billing path.** Noted as the unambiguous safe harbor if volume grows,
  but not built now (see Open Questions - the design must not preclude it).
- **Per-project authorization granularity.** Deferred to the orchestrator.
- **Result/marker-file cleanup/retention policy** - since delivery now lands in the
  caller-specified `--incoming-dir`, cleanup is arguably the caller's responsibility, not
  claude-mux's, but this hasn't been explicitly decided.

## Open questions (resolve before `ready`)

1. **API-key swappability:** what's the minimal config shape that lets `--route`'s
   subprocess call bill against an Anthropic API key instead of the ambient
   subscription-authenticated `claude` binary, without redesigning the feature later? (e.g.
   an env var claude-mux sets before invoking the subprocess - needs verifying against how
   `claude` actually selects between subscription-OAuth and API-key auth.)
   **Unresolved: not because it's a security afterthought, but because it needs its own
   verification pass (this session confirmed only that an API key IS the documented safe
   harbor, not the exact mechanics of wiring one through `claude -p`) - the risk this
   protects against is architecture-level, not just a config nicety, so it must be closed
   here even though nothing is built in this cut.**
2. **Command name:** `--route` used throughout this doc as a working name - confirm or
   rename before implementation.
3. **Model/permission-mode for routed workers:** default proposed `--permission-mode auto`
   (matches claude-mux's own default), not `bypassPermissions`. Confirm.
4. **Error semantics:** unresolved PROJECT name, `EXTERNAL_ROUTING_ENABLED=false`, and
   subprocess timeout should each produce a clear, distinct error - exact wording TBD at
   implementation time.
5. **New module placement:** this is a new category of functionality (subprocess-based
   one-shot invocation) distinct from tmux session launch - proposed new `src/*.sh` module
   rather than folding into `55-session-launch.sh`/`70-start-launch.sh`. Exact numbering at
   implementation time.
6. **`--incoming-dir` validation:** what happens if the given directory doesn't exist, isn't
   writable, or isn't absolute? claude-mux's `--route` and Hermes's direct-calling skill are
   NOT symmetric here: Hermes's own `incoming/` folder is presumably something Hermes
   already manages as part of its own setup (so the Hermes-skill doc doesn't need a
   create-if-missing instruction, and doesn't have one). claude-mux, by contrast, is being
   handed an arbitrary caller-specified path it has no prior relationship with - error and
   require the caller to have created it first (safer default: don't have claude-mux create
   directories at caller-supplied paths it doesn't otherwise own), or create it? Not yet
   decided - pick one and state it explicitly before `ready`, don't leave both behaviors
   plausible.

## Files touched (Change Checklist, per CLAUDE.md)

- New `src/*.sh` module (routing logic + `--route`/`--route-status`-style CLI wiring).
- `src/10-flags.sh` - new flag(s), `commands_help()`.
- `config.example` + `config_help()` - `EXTERNAL_ROUTING_ENABLED`.
- `dev/CODEMAP.md` + `make codemap` - new functions.
- `dev/SKELETON.md` - new logic flow (subprocess-based, distinct from the tmux launch flow
  documented there today).
- `docs/CLI.md`, `docs/GUIDE.md` - new command reference.
- `CHANGELOG.md`, `VERSION` bump (minor - new capability).
- **Injection prompt is NOT touched** - routed workers get their own separate,
  purpose-built system-prompt file, not `build_system_prompt()`.
