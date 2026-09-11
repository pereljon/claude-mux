---
kind: investigation
feature: hermes-claude-p-skill
status: DRAFTED 2026-09-11, REVISED 2026-09-11 (incoming/ + atomic marker-file async
  delivery). Instruction content for an EXTERNAL, non-claude-mux tool (Hermes) to build its
  own skill for calling `claude -p` directly. No claude-mux code required or touched.
  Companion/interim path alongside the still-designed, unbuilt `external-prompt-routing`
  (`--route`) feature - not a replacement for it. **This file is an EXAMPLE / reference
  requirements document, not a drop-in skill file.** Its format may not match whatever
  native skill-definition format Hermes actually uses (unknown at time of writing - the
  claude-mux side has no visibility into Hermes's own skill schema). Whoever hands this off
  should have Hermes (or its maintainer) WRITE AN APPROPRIATE, NATIVELY-FORMATTED skill file
  based on the content and rules below, not assume this markdown file is consumable as-is.
related: external-prompt-routing
---

# Hermes skill: talking to Claude Code sessions via `claude -p`

This is not a claude-mux feature - it's instruction content to hand to Hermes (or any
other external, non-Claude agent) so it can build its own skill for calling the official
`claude` CLI directly in non-interactive mode. No claude-mux code is involved in this path;
claude-mux is only the source of the shared safety template both this path and the future
`--route` feature use (`dev/features/external-agent-untrusted-framing.txt`).

> **EXAMPLE CONTENT, NOT A DROP-IN FILE.** The rules below are the *requirements* a Hermes
> skill needs to satisfy - self-identification, the framing file, the async delivery
> contract, the usage-scope constraint, etc. They are written as plain instructional prose,
> not in any particular skill-definition syntax. If Hermes has its own native skill format
> (its own frontmatter conventions, invocation model, file layout - unknown from the
> claude-mux side), **translate this content into that format rather than using this file
> verbatim.**

## The instruction content (give this to Hermes)

---

**Calling Claude Code sessions from Hermes**

You can delegate a discrete task or question to a Claude Code session by invoking the
`claude` CLI directly in non-interactive mode. Follow these rules:

1. **Always identify yourself in the prompt itself.** Start every prompt you send with a
   clear statement of who you are, e.g. `"I am Hermes, an autonomous agent, not a human
   operator or another Claude Code session."` This is in addition to, not instead of, the
   untrusted-content framing below - self-identification tells the receiving worker WHO is
   asking; the framing tells it HOW to treat what you're asking.

2. **Always pass the untrusted-content framing file.** Every call must include:
   `--append-system-prompt-file <path-to-external-agent-untrusted-framing.txt>`
   using the exact template maintained at
   `dev/features/external-agent-untrusted-framing.txt` in the claude-mux repo (get a current
   copy - don't hand-roll your own wording, so this stays in sync with the canonical
   version). This tells the worker to treat your prompt as external, untrusted input rather
   than blindly-trusted instructions - a real safety property, not a formality.

3. **Optionally pass a handoff file for extra context.** If you have more context to supply
   than fits naturally in the prompt string itself (background, prior state, structured
   data), write it to a file and pass it as a SECOND, separate
   `--append-system-prompt-file <handoff-file>` argument (or merge it into one file with the
   framing content, in that order, if your invocation only supports one instance of the
   flag - verify which before relying on it; this was not confirmed either way during
   design). Keep the framing content's protection intact regardless of how you merge -
   don't let handoff content dilute or precede it.

4. **Run in the target project's directory.** `cd` (or otherwise set the working directory)
   to the specific Claude Code project you're targeting before invoking `claude`. CLAUDE.md
   and project context load automatically from the working directory - you do not need to
   supply project context yourself.

5. **Choose sync or async per call:**
   - **Synchronous** - `claude -p --output-format json "prompt"`, wait for it to exit, read
     the `result` field from its JSON stdout. Use this when you need the answer before your
     own next step.
   - **Asynchronous** - background the call. Deliver the result **only into your own
     `incoming/` folder** (wherever your own configuration keeps it - this instruction
     doesn't assume a path, since that folder is yours to own, not claude-mux's). Write the
     captured `result` text to `incoming/[FILENAME].txt` (or whatever extension you
     prefer). **Only after that file is completely written**, `touch` a companion marker
     file `incoming/.[FILENAME]` - the same base filename as a hidden dotfile, empty, no
     content needed. The marker's mere existence, not its content, is the completion
     signal.
   - **When polling for an async result, wait for the `.[FILENAME]` marker to appear -
     never poll `[FILENAME].txt` directly.** A file being written (e.g. via shell
     redirection) can exist on disk before it's fully flushed; reading it mid-write risks a
     partial or corrupt result. Touching a separate marker only after the write completes
     gives an atomic, race-free signal - read `[FILENAME].txt` only once its `.[FILENAME]`
     marker exists.

6. **This is for specific work and questions - not a continuous processing pipeline.**
   Treat each call as a discrete, bounded delegation a human would otherwise type into
   Claude Code directly - not sub-second bulk automation, not a polling/streaming loop, not
   a substitute for a real integration. This isn't an arbitrary style preference: Anthropic's
   Consumer Terms restrict "automated or non-human means" access except via an API key or
   where explicitly permitted, and the official CLI's own "script and automate" support is
   the reason this works at all. Staying at the scale of "occasional, purposeful delegation"
   keeps this squarely inside that intended use; turning it into a continuous pipeline is the
   kind of usage pattern that has drawn account-level enforcement for other tools. If your
   use case genuinely needs continuous/high-volume automation, that needs its own design
   (e.g. an Anthropic API key for that workload) - don't scale this pattern up to meet it.

7. **Each call is stateless unless you carry context yourself.** `claude -p` does not
   remember prior calls. If you need continuity across a sequence of related requests,
   include what the worker needs to know in the prompt or handoff file yourself (e.g. "on
   <date> you told me X") - there is no built-in session memory in this direct-calling
   pattern.

8. **Handle failures explicitly, don't retry in a loop.** If a call errors, times out, or
   the target project doesn't exist, surface that clearly and stop - don't auto-retry
   rapidly, which would itself become the "continuous pipeline" pattern rule 6 warns against.

---

## Why these specific rules, for whoever maintains this instruction later

- **Rules 1-2 (self-ID + framing file)** were the user's original request, confirmed against
  live testing during this feature's design: `claude -p` does NOT load any framing on its
  own - if Hermes doesn't apply this itself, nothing does, since no claude-mux code sits in
  this path.
- **Rule 3 (handoff file)** was the user's original idea. Whether `--append-system-prompt-file`
  genuinely composes across two separate invocations of the flag (vs. the later one silently
  winning) was being tested empirically during design and was interrupted before a
  conclusive result landed - **this is unverified, flagged explicitly in the rule text
  rather than asserted as fact.** Re-verify before relying on it; see Open Questions.
- **Rule 4 (CLAUDE.md loads automatically)** confirmed live during design - `claude -p` in a
  project directory correctly reflected that project's own CLAUDE.md content with no extra
  flags.
- **Rule 5 (sync/async)** was revised 2026-09-11: async delivery now writes to the caller's
  own `incoming/` folder with an atomic `.` marker-file completion signal, replacing an
  earlier draft that used a shared `/tmp/claude-mux/<id>.txt` path. `external-prompt-routing.md`
  was updated the same day to match (its `--wait`-less mode now takes a required
  `--incoming-dir DIR` argument and uses the identical `<id>.txt` + `.<id>` marker
  contract) - the two paths are consistent again as of this revision. (The divergence
  existed only briefly, between the two edits on 2026-09-11 - noted here for the record,
  not as an open problem.)
  The marker-file pattern (write the payload, then atomically signal completion via a
  separate empty file) mirrors what claude-mux's own codebase already does for similar
  races elsewhere (e.g. `mkdir`-based atomic locks) - the same shape of problem, applied to
  file *delivery* instead of *locking*: a reader must never be able to observe a
  partially-written payload.
- **Rule 6 (not a pipeline)** operationalizes the account-suspension risk research from the
  `external-prompt-routing` design - the same reasoning applies here, arguably more directly,
  since there's no claude-mux authorization gate in this path to enforce restraint
  mechanically. The instruction has to carry that discipline on its own.
- **Rules 7-8** are additions beyond the original ask, worth flagging as new: stateless-by-
  default (this pattern has no continuity mechanism at all, unlike the designed `--route`
  feature's single-slot cache) and no-auto-retry (a failure-handling gap that, left
  unaddressed, could accidentally violate rule 6).

## Open questions (resolve before treating this as final)

1. **Does `--append-system-prompt-file` actually compose across two invocations**, or does
   the second one win/overwrite? Testing this was interrupted mid-design. Rule 3 is written
   defensively (verify first) rather than asserting an unconfirmed behavior.
2. **Distribution mechanism**: how does Hermes actually obtain a current copy of
   `external-agent-untrusted-framing.txt`? Not yet decided - options include: a stable URL,
   a file Hermes is given once at setup, or something else. Left open.
3. **Should this doc get folded into `external-prompt-routing.md`'s scope, or stay a
   separate, standalone deliverable?** Kept as its own `kind: investigation` doc for now
   since it has a different audience (external agent maintainers, not claude-mux
   implementers) and a different build status (usable today vs. designed-but-unbuilt).
4. ~~`incoming/` vs `/tmp/claude-mux/` divergence~~ - **RESOLVED 2026-09-11**:
   `external-prompt-routing.md` updated the same day to the matching `--incoming-dir` +
   marker-file contract. See "Why these specific rules" above.
5. **Where exactly is "its own `incoming/` folder"?** This instruction deliberately does not
   assume a path, since claude-mux has no visibility into Hermes's directory layout - but
   whoever translates this into Hermes's native skill format needs to resolve this to an
   actual, concrete path (or a config value Hermes already has) before it's usable.
