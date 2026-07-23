---
kind: investigation
feature: orchestrator-hub
status: PARKED brainstorm (home-session origin 2026-07-22) + claude-mux maintainer review added 2026-07-22. Revisit AFTER model-switch-confirm (v2.0.14) ships. NOT a buildable spec — a design direction that must be scoped/split before any feature spec is lifted from it.
related: model-switch-confirm, v2-agents-first
---

# Cross-Project Orchestrator Hub — Design Direction (PARKED)

> **Relocated into the claude-mux repo 2026-07-22** (from `~/Claude/orchestrator-hub-design-direction.md`) for review after the current `model-switch-confirm` work. Classified `kind: investigation` (design direction, not a single buildable feature — it spawns sub-specs A–E). See the maintainer review below before speccing.

---

## claude-mux maintainer review (2026-07-22)

**Verdict: one piece of this is genuinely claude-mux; most of it isn't, and the doc's "general feature + personal data as config" reconciliation is weaker than it reads. Carve it hard before speccing.**

**What legitimately fits claude-mux:**
- **The sessions dashboard — a multi-panel evolution of `claude-mux -l`.** Direct extension of something claude-mux already owns and renders, RC-friendly as a printed view, every user benefits. This is the real claude-mux feature in the doc.

**The core problem — the reconciliation doesn't hold:** the doc justifies inclusion via "feature = generic shipped code, personal = config/data." But:
- **Aggregating `context/todo.md` is coupled to the analytical-project template**, which is NOT part of claude-mux (it lives in `~/.claude-mux/templates/`, a personal convention). An external open-source claude-mux user has no `context/todo.md`, no `comms/index.md`, no Dropbox `~/Claude/shared/`. So the "general feature" reads a structure that only exists because of a separate, non-shipped template. That is a feature hardcoded to a personal workflow convention, not personal-data-as-config. The tension the doc claims to resolve is still present.
- **Calendar sync, reminders bridge, email drafting (subsystems C/D/E)** are exactly what the project's principles push out: "Lean over featureful. Don't duplicate what Claude Code or tmux already handle," plus the recorded scope guidance — *don't build in claude-mux what isn't specific to it and can be done elsewhere* (the `/handoff` → global-skill precedent). A cross-project todo aggregator and a Google/Apple calendar bridge are not specific to keeping tmux sessions alive; they are an application layer.
- **"claude-mux provisions and manages the hub into each home session"** adds real weight to `install.sh`, `--update`, and per-user managed state, for a capability most external users will not use. That is "eliminate complexity, don't relocate it" pointed the wrong way.
- North star check: *"infrastructure, not a framework. Keep sessions alive, get out of the way."* The hub (aggregation + external sync + email) is a framework/application on top of the infrastructure. The dashboard-of-sessions is infrastructure.

**Recommended split (achieves the doc's stated goal instead of asserting it):**
1. **In claude-mux:** `claude-mux --dashboard` = the sessions panel PLUS a *generic panel mechanism* — panels fed by a user-configured source command (e.g. `HUB_TODO_SOURCE=<cmd>` whose stdout is rendered), NOT by claude-mux knowing what `context/todo.md` is. claude-mux renders; it does not aggregate. Zero coupling to any template.
2. **Outside claude-mux (a skill or a small companion tool in `~/Claude/`):** the actual aggregation of `context/todo.md`, the `~/Claude/shared/` store, external calendar/reminders sync, email drafting. This is where the personal workflow + analytical-project convention legitimately live, and it can be the source command the dashboard renders.

**Resolve before speccing (in addition to the doc's own two open questions):**
- **Generality test:** would an external claude-mux user with NO analytical-project template get value from `--dashboard`? If value requires the template, the aggregation does not belong in claude-mux.
- **Where aggregation logic lives** (claude-mux shipped code vs companion skill) — the real fork, more consequential than the doc's "which external system" / "how much automation" questions.
- **Relation to the v2.2 "Agent network" milestone** in `docs/ISSUES.md` — a cross-project hub overlaps that thread; decide if this IS v2.2 or a separate track.

---

## Architecture direction (2026-07-22 follow-up — landscape scan + three refinements)

Follow-up discussion after the review above. Three findings that reshape the direction. **All still parked behind `model-switch-confirm`.**

### 1. Landscape scan — what exists, and the real gap
GitHub research (2026-07-22) of multi-session Claude Code orchestrators:
- Most are **ephemeral parallel-worker** orchestrators — fan out N throwaway agents on ONE task via git worktrees, merge, done. Different problem from claude-mux's **persistent cross-project sessions**. Examples: `primeline-ai/claude-tmux-orchestration`, `claude-flow`, `Martian-Engineering/claude-team` (MCP).
- Closest cousins: `obra/claude-session-driver` (controller delegates to workers via tmux, but **observation-only — no inter-session messaging, no routing, no shared store**) and `craftzdog/tmux-claude-session-manager` (persistent per-project sessions + status picker ≈ `claude-mux -l`, nothing more).
- **Nobody routes external events (email) to specific project sessions.** That idea is unoccupied.
- **The universal gap** across all of them = a **message bus / routing between persistent named sessions**. That is exactly claude-mux's v2.2 "Agent network" thread, and its differentiated opportunity — NOT another parallel-worker swarm (crowded; Anthropic is moving in with TeammateTool/Agent Teams). The email-forwarder is an application on top of that primitive: `claude-mux -s <session> '<msg>'` is already ~80% of delivery; the router is the new part.

### 2. CORRECTION — native Claude Code "Tasks" is NOT a PIM (my earlier claim was wrong)
An earlier note here said "lean on native Tasks instead of rebuilding the shared todo." That was wrong for this use case. Native Claude Code surfaces:
- **Routines** = cron/webhook-triggered automated *runs* (scheduled/repeating tasks). Not a list.
- **Tasks (v2.1.16)** = persistent evolution of the agent's ephemeral TodoWrite list — *engineering work the coding agent executes/coordinates* across sessions (shared via `CLAUDE_CODE_TASK_LIST_ID`). It's the agent's work queue.

Neither is a **personal information manager**: no calendar events, no due dates, no priorities, no reminders/notifications. Three things that got conflated:

| Need | Right home | Not this |
|---|---|---|
| Sessions sharing *agent work items* | Native Tasks (`CLAUDE_CODE_TASK_LIST_ID`) | don't rebuild |
| *Human* calendar events + reminders (dated, mobile notifications) | a real PIM — Google/Apple Calendar+Reminders/Tasks | don't rebuild a PIM in markdown |
| *Human* cross-project todo (dated/undated, priorities) | the genuinely open middle | — |

### 3. Calendar/reminders want a REAL PIM as MASTER — not a markdown mirror
The original brainstorm's "files canonical, external is a projection" is **backwards for calendar + reminders specifically**: markdown in `~/Claude/shared/*.md` can't fire a 9am reminder on your phone/watch. Those external systems exist precisely to do dated events, priorities, and push notifications. So:
- **Calendar + reminders:** external PIM (Google/Apple, you already have the Google Calendar/Tasks MCP) is the **master**; a **PIM-bridge plugin** talks to it and renders a read-view into `--dashboard`. Do not reinvent dates/priorities/reminders.
- **Notes + maybe the cross-project human todo:** files-first is fine.
- **The one deliberate open question:** does the human cross-project todo want PIM semantics (→ push to Google Tasks/Apple Reminders) or freeform-with-context (→ markdown aggregation)? Reframes the brainstorm's "which external system" question into "does the todo need PIM semantics at all."

### 4. Cross-CLI ⇒ an INTERNAL, harness-neutral extension mechanism (not Claude Code plugins)
Earlier I recommended building the application features as **Claude Code plugins** over claude-mux's CLI. **That only holds if claude-mux stays Claude-Code-specific.** If claude-mux becomes the harness-agnostic persistence/orchestration layer (the codex-mux direction — persistence is the moat across CLIs; see `reference_codex_mobile_landscape`, cross-cli-coders in `dev/features/`), then building features as Claude Code plugins re-couples them to one harness and abandons Codex sessions. The extension layer must be as harness-agnostic as the core.

**Corrected recommendation — an internal, harness-neutral extension seam, kept thin enough to not become the framework claude-mux refuses to be:**
- **Discovery, git-style:** `plugins/` dir or `claude-mux-<name>` executables on PATH → `claude-mux <name>` dispatches. No runtime, no SDK.
- **Dumb data contract:** plugins are ANY-language executables talking stdin/stdout/exit-code. Harness- and language-agnostic by construction.
- **A few named extension points** matched to claude-mux's job: **panel sources** for `--dashboard` (`HUB_TODO_SOURCE=<cmd>` generalized); **injection contributors** (emit *harness-neutral* prompt content; claude-mux's existing per-harness launch adapter delivers it — this is where cross-CLI pays off); **event/message handlers** (subscribe to session lifecycle + the inter-session bus; the email-router registers here); **CLI verbs**.
- This is "config + hooks + CLI" (claude-mux's existing character) plus a discovery convention — NOT a plugin framework. The moment it needs a manifest spec / plugin SDK, it has gone too far.

**Cautions:**
- **Do not build the plugin seam speculatively.** "Eliminate complexity, don't relocate it." Justified only when (a) the cross-CLI commitment is firm AND (b) ≥2–3 real features would use it. Build the first feature (dashboard) monolithically, then **extract** the seam when the second (email router / PIM bridge) needs the same shape.
- **Hybrid stays available:** the internal harness-neutral mechanism is the substrate; on Claude Code you can *additionally* package the reference extensions as a Claude Code plugin for discoverability. Substrate neutral; Claude-plugin packaging optional sugar.

### Unifying line for the whole hub
**Core (harness-agnostic primitives):** persistent named sessions, the inter-session message/routing bus (v2.2), `--dashboard` rendering, injection, hooks.
**Everything else (harness-neutral internal plugins over those primitives):** orchestrator hub, email→session router, PIM bridge, shared todo aggregation, briefings.
Decision rule: **if it's a primitive, it's core; if it's a workflow, it's a plugin.** This supersedes the top review's Claude-Code-plugin framing wherever cross-CLI is in scope.

---

## Dashboard dev notes (UI-pattern references — folded in from `~/Claude/claude-mux-dashboard-notes.md` 2026-07-22)

Dashboard-specific references for building the central dashboard (one feature within the hub — the home-session view: active-sessions panel extending `claude-mux -l` + todos/reminders/notes + calendar).

**Prior art / UI reference: ECC's dashboard** (`~/Claude/extensions/everything-claude-code`) — a **UI-pattern precedent only**, solves a different problem:
- `ecc_dashboard.py` (ECC repo root) — cross-platform **TkInter desktop GUI** scanning ECC's `agents/`/`skills/`/`commands/` dirs for browse/manage. Run: `npm run dashboard`.
- `scripts/dashboard-web.js` — **browser variant, no Tkinter** (`npm run dashboard:web`). Crib layout/interaction ideas.
- A component-catalog artifact (same idea as `ecc_dashboard.py`, rendered as a web page): https://claude.ai/code/artifact/16a9fb39-e789-424c-adae-617877071e75 — reference for the "searchable panel of items" pattern.

**Do NOT conflate:** ECC's dashboard = browse ECC's OWN components (agents/skills/commands), scoped to the ECC repo, an authoring/reference tool. The claude-mux central dashboard = cross-project home-session view (sessions + todos/reminders/notes + calendar). Different data, different purpose. ECC's dashboard contributes NOTHING functionally — it is only a visual/pattern reference (proof the pattern is reasonable + a browser-render example).

**Form-factor open question (unchanged):** printed `claude-mux --dashboard` (RC-friendly — lean this first) vs live TUI vs web view. Note the architecture direction above: the dashboard *renders* panels; panel *content* comes from harness-neutral source commands (generic `HUB_TODO_SOURCE=<cmd>`-style seam), so the render layer stays generic regardless of form factor.

---

## Original brainstorm (home-session, 2026-07-22) — unedited below this line

Status: **Parked — revisit later.** This is an early brainstorm captured for future work, not an approved spec. Two open questions remain (see below).
Origin: home-session brainstorm, 2026-07-22.
**Target: build the orchestrator hub as a set of new claude-mux features for the home session. The central dashboard is ONE of those features (the unified view).** Build location: `~/Claude/development/claude-mux` (its own session), NOT the home/ECC session.

---

## The orchestrator hub = a home-session feature set in claude-mux

The **orchestrator hub** is the umbrella: the home session's feature set for shared cross-project activities. Its capabilities (subsystems A–E below) are the shared todo/reminders/notes store, unified calendar, external calendar/reminders sync, email drafting, and other shared services.

The **central dashboard is one feature within the hub** — the home-session *view/surface* that presents the hub's state in one place. It extends claude-mux's existing session-listing (`claude-mux -l`) into a multi-panel view:

- **Active sessions** — what `claude-mux -l` already shows (status, session, directory), as the first panel.
- **Todos / reminders / notes** — aggregated cross-project (from each project's `context/todo.md`, plus a shared notes/reminders store).
- **Calendar** — cross-project deadlines + external calendar mirror.
- (extensible: add panels for other hub services later.)

Relationship: the hub *owns the state and logic* (aggregation, storage, sync); the dashboard *renders* it. Other hub features (e.g. email drafting, the external sync itself) are siblings of the dashboard, not part of it.

## Deployment & ownership model

- **Developed in** the claude-mux project (`~/Claude/development/claude-mux`) — it is standard claude-mux feature code.
- **Deployed + managed by claude-mux into each user's home session.** Just as the deployed claude-mux already generates the home-session prompt, protects the session, and manages `~/.claude-mux/` config/templates, it will **provision and manage the hub** into the home session: create/maintain the shared-state location, wire the `--dashboard` command, set home-session conventions, and keep them updated on `claude-mux --install` / `--update`.
- **Consequence — this is a general, shipped claude-mux capability, not a Jonathan-specific build.** Every deployed claude-mux instance can stand up the hub in its own home session. The user's specific projects/todos/calendar/external-account are **per-user config + data** the managed feature reads; the feature code stays generic and reusable. (This is the final resolution of the earlier "keep personal logic out of claude-mux" tension: personal = config/data, feature = shipped code.)
- **Open sub-question:** where the managed shared state lives — under claude-mux's own managed dir (`~/.claude-mux/hub/`) vs the user's synced workspace (`~/Claude/shared/`). Trade-off: claude-mux-managed/portable vs user-visible/Dropbox-synced. Decide at spec time.

**Why this fits claude-mux (resolves the earlier "keep personal logic out" caution):** the hub features are *general* — any claude-mux user with a home session benefits, and the dashboard is a direct evolution of the session list claude-mux already renders. The user's specific projects/todos/calendar are **data/config the features read**, not hardcoded logic. General features + personal data as config = claude-mux stays reusable.

Dashboard form factor is an open sub-question: a `claude-mux --dashboard` command (printed view, RC-friendly, like `-l`) vs a live TUI vs a web view (claude-mux already has `dashboard-web.js` precedent elsewhere). Lean printed-view first for RC compatibility.

---

## The idea

Evolve the home/orchestrator so it joins all projects under `~/Claude/` together in their shared activities: a unified todo list and calendar, a bridge to an external calendar/todo/reminders app (Google / Apple), shared email drafting, and other services any project would want to share up to the top level.

## What already exists (build on, don't rebuild)

- **Per-project live-state files** (analytical-project template): every project already maintains `context/todo.md`, `context/status.md`, `context/open_questions.md`, `context/decisions.md`, `context/contacts.md`, `comms/index.md` + threads, `meetings/`. "Unify" = **aggregate these up**, not start from scratch.
- **`~/Claude` is Dropbox-synced** (`.sync`, `.dbxignore`) → any top-level shared files travel across machines for free.
- **claude-mux owns the home/orchestrator session** — launches it, protects it, generates its system prompt. The orchestrator is a claude-mux-managed *session*, not just `~/Claude/CLAUDE.md`.
- **Ancestor CLAUDE.md loading**: `~/Claude/CLAUDE.md` loads into every session under `~/Claude/` (walk-up-the-tree), layered beneath each project's own CLAUDE.md.
- **Connected MCPs available**: Superhuman Mail, Gmail, Google Calendar, Google Drive, Airtable, monday.com, QuickBooks, Make.

## Decisions made in this brainstorm

1. **Source of truth = hybrid, files-first.** `~/Claude/shared/` markdown files are the canonical working store Claude reads/writes (Dropbox-synced). A **sync bridge mirrors them OUT** to the user's external calendar/todo/reminders (Google/Apple). External app is a projection for mobile/notifications, not the master.

2. **Centralized aggregation model** (chosen over distributed). The **home/orchestrator session is the hub**: only it aggregates per-project `context/todo.md` into `~/Claude/shared/`, and runs the external sync. Individual project sessions stay untouched — no new obligations, no per-session context cost, no template changes. (Distributed model — every session participates live — was rejected as too coupled for now.)

3. **Placement / how claude-mux fits. (UPDATED 2026-07-22)**
   - **Build as a new claude-mux feature — the central dashboard for the home session** (see top section). This supersedes the earlier "keep domain logic out of claude-mux core" stance.
   - Reconciliation: the earlier caution was about baking *personal workflow* into a *general/shared* tool (claude-mux is versioned, has translations, install.sh). Resolved by designing the **dashboard as a general feature** (session panel + configurable todo/calendar/notes sources) while the **user's specific data stays as config/files** the feature renders. General feature + personal data-as-config keeps claude-mux reusable.
   - Shared state still lives as `~/Claude/shared/` markdown files (Dropbox-synced); the external sync remains a separable concern the dashboard/home session drives.
   - Build happens in the **claude-mux project** (`~/Claude/development/claude-mux`), not the home/ECC session.

## Subsystems (each its own future spec → plan → build)

- **A. Cross-project todo aggregation** — roll each `context/todo.md` into a unified `~/Claude/shared/todo.md`.
- **B. Unified calendar / deadlines** — cross-project schedule view.
- **C. External calendar/reminders bridge** — files ↔ Google (have MCP) or Apple (AppleScript). Mirror, not master.
- **D. Shared email drafting** — common service over Superhuman/Gmail MCPs.
- **E. Other shared services** — TBD (shared contacts? daily briefing? meeting prep?).

## Open questions (answer before speccing)

1. **Which external system is the mirror?** Google Calendar/Tasks (already have MCP, online) vs Apple Calendar/Reminders (native, mobile, needs AppleScript/MCP). Possibly both.
2. **How much automation?** passive files → on-demand `/briefing` command → auto-injection at session start (claude-mux SessionStart hook). Trade-off: magic vs per-session cost/complexity.

## Recommended first slice (when resumed)

**Dashboard v1 = sessions panel + todos panel, printed view.** Concretely: a `claude-mux --dashboard` command (in the claude-mux project) that renders (1) the existing `claude-mux -l` session list as the first panel, and (2) an aggregated todo panel built from each project's `context/todo.md` (optionally written through to `~/Claude/shared/todo.md`). **No external calendar sync, no auto-injection, no live TUI yet.** Printed view keeps it RC-friendly like `-l`. Reversible, proves the aggregation + panel model. Then add calendar panel (subsystem B), external bridge (C), and richer form factors once v1 is validated.

## Explicitly deferred (YAGNI for now)

- External sync bridge (subsystem C) until the file layer works.
- Auto-injection into project sessions.
- Distributed model.
- Email drafting + "other services" (D/E) — after A/B land.
