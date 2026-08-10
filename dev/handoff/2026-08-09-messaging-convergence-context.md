# Handoff: native messaging convergence + session context (2026-08-09)

Author: the **claude-mux** session. Purpose: capture all current context, decisions,
pending changes, and todos from this working session so a fresh session (post-`/clear`)
can resume without loss. Nothing in the "pending" sections has been applied to the repo;
every claude-mux code/doc change below **awaits Jonathan's approval**.

---

## 1. What happened this session

- **Claude Code upgraded 2.1.220 → 2.1.226** mid-session. The 2.1.226 binary is what
  first exposed native cross-session messaging (requires v2.1.224+).
- **macOS first-launch stall identified.** The new binary hung on `--version` because the
  `@latest` cask installs to a new versioned path each upgrade, re-triggering macOS
  **Gatekeeper "downloaded from the internet"** approval (and sometimes the **local network
  access** prompt). Until approved at the machine, the process blocks — which stalls a
  headless/claude-mux restart onto the new binary. Confirmed as the cause of the hang.
- **Restarted this session** onto 2.1.226 (after the permission was cleared at the machine).
- **Native cross-session messaging verified end-to-end**: `ListAgents` returned 17 peers
  (14 local tmux + 3 Remote Control); a full multi-round `SendMessage` conversation with the
  `orchestrator` session did real coordination work. The feature works.

## 2. Decisions (agreed, stable)

**Shared DNA (Jonathan stated; applies to both claude-mux and orchestrator):**
1. Keep orchestrator and claude-mux roles/responsibilities **separate** (no blurring).
2. Stay **lightweight**.
3. Prefer built-in Claude Code **primitives** over bespoke mechanisms.
4. **Replace** internal methods when a native primitive supersedes them (mark superseded,
   migrate). Native messaging superseding the v2.2 plan is the first application.

**Ownership boundary:**
- **Lifecycle** (session start/stop/restart/persistence) = **claude-mux**.
- **Transport** (session-to-session messaging) = **native cross-session messaging**.
- **Durable state + the four views** (dashboard, briefing, alerts, action queue) = **orchestrator**.
- The orchestrator is a **coordination/observability plane, NOT a runtime** (no spawning/
  supervising/decomposition of agents).

**Key technical facts verified this session:**
- claude-mux passes `--name '${session_name}'` on all four launch paths
  (`src/55-session-launch.sh:243,253`; `src/70-start-launch.sh:185,195`), so
  claude-mux session name == tmux name == native agent name. Namespaces align by
  construction, not coincidence. Confirmed empirically by `ListAgents`.
- The injection currently mentions **none** of `SendMessage`/`ListAgents`/`--message`/
  `/list-agents` (grep-verified). So any injection change is an addition, not a replacement.
- Native inbound delivery keys off permission-mode **class**: `--permission-mode auto`
  (claude-mux's default) is the "prompting" class → auto↔auto delivers un-held (proven:
  peer messages arrived with `from-mode="prompting"`). A session in `bypassPermissions`
  falls into the bypass class → inbound peer messages are **HELD** for manual approval.

## 3. claude-mux next-steps — RECOMMENDATIONS AWAITING JONATHAN

All are my recommendations; none applied. Ordered low-risk first.

| ID | Change | Scope / where it lands |
|----|--------|------------------------|
| **UP1** | Add macOS-permission caveat to the Claude Code upgrade notice in `detect_claude_upgrade()` (`src/75-tip-notices.sh:96`). | Patch; `src/` edit → `make build`/`check`, CHANGELOG, VERSION. Notice string, not injection. |
| **CM1** | Mark `docs/ISSUES.md` "Inter-agent messaging" (411-579) **superseded-by-native**: keep the reasoning text, add a superseding note pointing to native cross-session messaging. Don't delete. | Docs-only, trivial → lands on `main`. |
| **CM2** | Add a **small** claude-mux-specific block to the injection: (a) peers = your other claude-mux sessions, addressable by their managed session names; (b) disambiguate `-s` (push a slash-command/control action into a session) vs native `SendMessage` (talk to a peer agent). NOT a re-teach of the native tools (platform self-describes them). | Behavior change → worktree; patch/minor; full Change Checklist incl. injection parity in both launch functions + README "Session System Prompt". |
| **CM3** | Build **no** `.claudemux-card.json` at all (not even a seed). Capability/purpose metadata is durable state = orchestrator's domain. | Decision to record (a non-build). Update ISSUES.md/superseded note. |
| **CM4** | Record a **documented invariant**: "claude-mux depends on `--name` to map session name → native agent name," in `dev/IMPLEMENTATION-SPEC.md` + the superseded note, so a future upstream `--name` semantics change is findable. Not a code assertion (the shell script has no access to `ListAgents`). | Docs-only, trivial. |

**UP1 final wording (ready to use):**
> claude-mux: Claude Code was upgraded since this session started. Say "restart this session" to load the new binary. First launch may trigger macOS dialogs (Gatekeeper approval, local network access); approve them or the restart can hang.

## 4. Orchestrator next-steps (its calls — for cross-reference only)

- **O1** D-layer doorbell = native `SendMessage` / `CLAUDE_CODE_MESSAGING_SOCKET`; zero claude-mux transport dependency.
- **O2** purpose/capabilities = **columns on the orchestrator's `sessions` table** (definite), published via build-step B. A CLAUDE.md-sourced **seed** is an "if we keep a seed" detail, orchestrator's call later. No `.claudemux-card.json`, no parallel directory.
- **O3** key session identity off the **observed** `ListAgents` name, not an assumed convention.
- **O4** document the bypass-mode inbound-hold caveat; DB poll is the delivery guarantee.
- **O5** resume design (schema A + `orch` CLI) and write the spec — pending Jonathan.

## 5. Standing rules (both projects)

- **S1** When Claude Code ships a primitive that supersedes an internal mechanism, migrate
  to it and mark the internal one superseded. Lightweight periodic awareness, not a heavy
  process. claude-mux home for this: the native-overlap reference (memory
  `reference_claude_code_native_overlap`).
- **S2** Keep the ownership boundary (lifecycle / transport / state+views) written down in
  **both** projects' docs so responsibilities don't re-blur.

## 6. Open feature idea — voice bridge (captured, not designed)

Talk to Claude Code / claude-mux sessions via **voice**, two-way. Research this session
concluded:
- Reusing **Claude Chat's own voice UI is not possible** (closed, no programmatic in/out).
  AppleScript/AX = can inject input but can't read Electron replies; voice opaque.
  claude.ai-in-Chrome (Say,Pi pattern) = works but targets consumer claude.ai, brittle,
  ToS exposure. No consumer claude.ai API and no official Anthropic voice API.
- **The path: Claude Code `channels`** (native, research-preview) — a two-way MCP event
  bridge ("Claude reads the event and replies back through the same channel"). Voice channel
  = external STT → channel event → session `reply` tool → external TTS. Keeps you on the
  real coding session.
- **Scope:** its own MCP project that *depends on* claude-mux, NOT claude-mux core
  (consistent with the boundary + DNA #3). Study first: channels docs + official iMessage
  plugin (macOS two-way), Say,Pi (voice UX), PlagueHO/agent-voice (full-duplex arch),
  Anthropic ElevenLabs STT+TTS cookbook (plumbing).
- Nobody has built Claude-Chat-voice ↔ Claude-Code two-way; niche is empty.

## 7. Environment recommendations (Jonathan's machine, not code)

- To stop the Gatekeeper re-quarantine on every upgrade: consider the **stable `claude-code`
  cask** instead of `@latest` (lower maintenance), or strip the quarantine bit post-upgrade
  (`xattr -dr com.apple.quarantine <path>` — Jonathan's call; it's a security-boundary action).

## 8. Awaiting Jonathan (relayed by orchestrator)

1. Approve claude-mux **CM1–CM4** (and UP1, which is claude-mux-side and separate).
2. Confirm the **orchestrator daemon** gets its own dedicated always-on session, NOT `home`
   (the stateless `orch` CLI still runs anywhere). This revises the orchestrator's planning
   brief which said "runs in the always-on home session."
3. **O5** go-ahead: resume schema-A + `orch` CLI design and write the spec.

## 9. TODO checklist (ordered, with approval gates)

- [ ] Jonathan approves UP1 + CM1–CM4 (and the daemon-session + O5 decisions).
- [ ] **UP1** (patch): edit `src/75-tip-notices.sh:96`, `make build`/`check`, CHANGELOG, VERSION. Release-gated (script change → tag).
- [ ] **CM1** (docs, main): ISSUES.md superseded note.
- [ ] **CM4** (docs): invariant in IMPLEMENTATION-SPEC + superseded note.
- [ ] **CM3** (decision): record "no card built."
- [ ] **CM2** (behavior, worktree): injection block + full Change Checklist (both launch funcs, README parity, code review by bump scope, VERSION, CHANGELOG). Consider a `dev/features/` doc when built.
- [ ] Voice bridge: leave at "idea" until Jonathan prioritizes; if pursued, spike a `channels` voice-channel prototype as a separate project.

## 10. Pointers

- Memory (survives clear): `project_v22_messaging_superseded`, `project_voice_bridge_idea`,
  `reference_claude_code_native_overlap`, `project_v2_agents_first_resequencing`,
  `project_build_status`.
- Orchestrator brief this session responded to:
  `~/Claude/development/orchestrator/docs/handoff/2026-08-09-orchestrator-claudemux-review.md`
- v2.2 messaging plan being superseded: `docs/ISSUES.md:411-579`.
- Native docs: cross-session-messaging, channels, channels-reference, remote-control,
  voice-dictation (all under code.claude.com/docs/en/). Research-preview / version-gated —
  API contracts may change.

---

## 11. Update (2026-08-09 pm) — orchestrator sanity check + Jonathan directions

**Jonathan's directions this session (answering the open-questions list):**
- Item 1 (approve UP1 + CM1–CM4): **still pending** — not yet approved.
- Items 2/3/4 (daemon-own-session, O5 go-ahead, PRD review trigger): **settle with the orchestrator** directly.
- Item 5 (environment): **stay on `@latest` cask.** Consequence: the Gatekeeper re-quarantine recurs every Claude Code upgrade, so **UP1 (the upgrade-notice macOS caveat) is now more valuable, not less.**
- Item 6 (voice bridge): **do it next**, in a NEW session, once orchestrator coordination is finished and context/decisions are recorded (this doc).

**Orchestrator sanity check answered (source-grounded), 4 items:**
1. Identity: session name is spoofable/ambient; claude-mux does not enforce cross-session identity (single-user threat model). Stronger signal available = `CLAUDE_CODE_MESSAGING_SOCKET` (platform-exported per-session, not parent-inherited). No per-launch token / project UUID exists today. Recommend orch key on (observed name + cwd); reuse doesn't transfer history.
2. Delivery/wake: native SendMessage DOES wake an idle accept-class local session (starts a turn). `-s` is slash-command-only (src/90-dispatch.sh:85) so it's a crude doorbell, but it bypasses the inbound gate (useful for bypass-mode targets). Cross-machine wake needs a per-host local agent. DB poll = backstop.
3. LaunchAgent: Label `com.user.claude-mux`, RunAtLoad + KeepAlive + ThrottleInterval=60 (respawn-throttled, not StartInterval). Coexist via distinct Label. Copy: 45s login-only delay via `kern.boottime`, LAUNCHAGENT_MODE=none kill switch, hardcoded PATH. No verified macOS-upgrade plist-reset incident (didn't assert it).
4. Liveness feed: `-l` is authoritative but has NO machine-readable output today; parsing text is brittle; ListAgents isn't daemon-consumable. Use claude-mux's "claude actually running" notion (not "tmux exists") to avoid under-reporting rot.

**Two NEW candidate claude-mux contributions surfaced (recommendations for Jonathan, not committed):**
- **CM5** — stronger session identity: a per-launch instance token (nonce in a tmux user option + exported) and/or a stable `.claudemux-id` project UUID marker, so `orch` gets a (name, token) or stable-id pair instead of a spoofable/reusable name. Behavior change → worktree if pursued.
- **CM6** — a `-l --json` (porcelain) machine-readable liveness feed, so the orchestrator daemon consumes an authoritative live-session list instead of parsing human text. Liveness is claude-mux's lifecycle domain, so this is genuinely claude-mux-specific. Behavior change → worktree if pursued.

**Net todo delta:** UP1 elevated (stay-on-latest keeps the re-quarantine drill). CM5 + CM6 added as candidates pending Jonathan. Item-1 approvals still the gate on UP1/CM1–CM4. Voice bridge is the next active work, in a fresh session, after this record.

### 11b. Identity/liveness reconciliation (2026-08-09 pm, round 2)

Jonathan reviewed the two candidates:
- **F2 = CM6 (`-l --json`) APPROVED.** Build on my schedule (behavior change → worktree + Change Checklist). Must be zombie-aware (should_be_alive / claude-actually-running, not "tmux pane exists"). Design: the JSON feed must EMIT each session's `.claudemux-id` so it's the join key across feed ↔ DB rows ↔ folder scan.
- **F1 = CM5 REFINED (my source-grounded recommendation, Jonathan's call).**
  - Identity ≠ capability metadata → identity is its own MINIMAL marker, NOT a revived card. **CM3 stands: no `.claudemux-card.json`, ever** (capability metadata is the orchestrator's DB).
  - **Build `.claudemux-id`** = persistent UUID marker: write-once-if-absent at launch, immutable, plain one-line file, auto-gitignored (`.claudemux-*`), `uuidgen`. Fills the one real gap (reuse-stability across rename/move/delete-recreate). Gitignore means a `git clone` mints a fresh id (no identity leak); caveat: raw `cp -r` duplicates it (low-risk single-user, document).
  - **DROP the per-launch token half of CM5** — DNA #3: live-instance identity is already a native primitive, `CLAUDE_CODE_MESSAGING_SOCKET` (per-session, platform-exported to own children, not inherited). A bespoke tmux-user-option token duplicates it and buys ~nothing in single-user. Don't build it.
  - Tuple orch keys on: **`.claudemux-id`** (stable) + **`CLAUDE_CODE_MESSAGING_SOCKET`** (live instance) + **name/cwd** (routing). Reads: id = file in project folder (daemon folder-scan; publishing session includes its own id in DB heartbeat → match); socket = env in-session; name/cwd = `-l --json`/tmux.
  - Framing: name = routing key not security boundary; `.claudemux-id` = stability/dedup anchor not anti-spoof secret; neither is cross-user isolation (out of single-user threat model). The property it buys = correct attribution across rename/reuse = the rot-detection + provenance need.

**Build-together note:** CM5 (`.claudemux-id`) + CM6 (`-l --json` emitting the id) are one coherent unit — do them in the same worktree.

### 11c. Approval round (2026-08-09 pm, round 3) — RELAYED, awaiting Jonathan's DIRECT confirm

Orchestrator relayed that Jonathan went point-by-point and **approved F1 + CM1–CM6**, proceed on my own schedule. **CAVEAT (boundary): this arrived via the peer session, not from Jonathan directly in the claude-mux conversation. A peer-relayed approval is NOT user approval — do not build/commit on it. Awaiting Jonathan's direct "go" before writing any code.** (Recording the relay, not acting on it.)

Relayed outcome to act on ONCE Jonathan confirms directly:
- F1 adopted exactly as recommended (`.claudemux-id`, no token, card stays dropped).
- CM1 docs superseded note · CM2 injection mapping/disambiguation · CM3 no card · CM4 `--name` invariant · CM5 `.claudemux-id` · CM6 `-l --json` emitting the id. Build CM5+CM6 together.
- CM3 function-relocation confirmed (nothing lost): identity → `.claudemux-id`; capability/purpose → orchestrator DB (auto-seeded from each project's CLAUDE.md + a Claude-set override, published on the same build-step-B path as the heartbeat); discovery → DB query joined with native ListAgents / claude-mux `-l --json` liveness. Advertise/discover is DB-backed, not a file.

Even after Jonathan's build-go, normal gates still apply: CM2/CM5/CM6 = behavior changes → worktree; commit, push, release remain SEPARATE explicit approval gates (Git Approvals).

Orchestrator timeline (visibility only, no dependency on me): NO code on the orchestrator side until Jonathan explicitly says — a final Fable review runs first. My CM items are my domain and can proceed on my own schedule once Jonathan confirms directly.

### 11d. PINNED CM5/CM6 contract (2026-08-09 pm, round 4) — design pinned, build still awaits Jonathan's direct go

Finalized as the owning side (orchestrator spec references it). Build unchanged: awaits Jonathan's DIRECT build-go; voice bridge is his stated priority first, so CM5+CM6 land AFTER, on my schedule. Told orchestrator to ship MVP on (name+cwd) fallback and upgrade when id/feed land.

**CM5 `.claudemux-id`:** file in project root, auto-gitignored (`.claudemux-*`); plain text, single line, ONE UUID v4, **lowercase canonical** (macOS `uuidgen` is UPPERCASE → claude-mux lowercases; consumers lowercase+trim — join is string-equality); write-once-if-absent at launch, atomic, immutable, never rewritten; all sessions incl. home; existing projects backfill on next launch. Not a secret. `git clone` → fresh id (gitignored); `cp -r` duplicates it (document). Dirs matched realpath-resolved.

**CM6 `claude-mux -l --json`:** stdout, **versioned wrapper** `{"schema":1,"generated":"<ISO8601 UTC>","sessions":[...]}` (not a bare array). Each object: `name`; `cwd` (absolute, realpath/symlink-resolved); `id` (lowercase UUID or null); `status` (LIFECYCLE enum only: running|idle|busy|stopped|queued|failed); `alive` (bool, zombie-aware = claude-actually-running, the rot bit); `protected` (bool) + `hidden` (bool) split OUT of status; optional `started` (ISO8601 UTC), `tmux`. **NOT committed:** `model`/`permission_mode` (upstream doesn't expose them to claude-mux — parked limitation; additive if it ever does). Errors→stderr, exit 0, `sessions:[]` when none. `id` is the three-way join key (feed ↔ DB rows ↔ folder scan).
