---
kind: investigation
feature: language-migration
status: INVESTIGATION 2026-07-23 (Fable assessment, prompted by "at what point does claude-mux become too big to continue as a shell script?"). No decision made; captures the analysis so it survives context clears. Revisit when the v2.5 Windows goal is scheduled.
related: cross-cli-coders.md, project_v25_windows (memory)
---

# Investigation: when does claude-mux outgrow shell, and to what?

Prompted 2026-07-23: "At what point does claude-mux become too big to continue
developing as a shell script? What should it move to — Go? Rust? C++? Swift?"

Not a decision. This is the reasoning, parked for when the question becomes live
(most likely: the v2.5 Windows milestone).

## Bottom line

- The trigger is **not size** (line count). It is the **kind of logic**.
- If/when we move, it is **Go**.
- Do **not** big-bang rewrite. Let the **Windows goal (v2.5) be the forcing function**;
  until then, treat each new Python-in-bash site as a tick on the meter and, if one area
  gets too painful, extract just that into a small Go helper (strangler).

## The ceiling isn't line count

A ~4,000-line shell script that mostly runs `tmux`, `git`, `launchctl`, and `claude` is
fine — orchestrating other processes is exactly what shell is good at. A compiled rewrite
would call those same commands via subprocess and gain little for the orchestration
itself. So "it's getting long" is not the signal.

## The real signals (claude-mux already shows two)

1. **Structured data.** Every hook install/check/remove is a `python3` heredoc embedded in
   bash, because bash can't do JSON. The clear-ready-handshake feature (v2.2.0) added a
   *third* such site (install / desired-state / uninstall in
   `setup_claude_mux_permissions` + the uninstall removal). That is the loudest canary:
   the tool already isn't pure shell — it drops into a second language whenever anything is
   structured. **Watch: more Python-in-bash = the part shell can't carry.** The
   settings-JSON manipulation is the single leading candidate for extraction.

2. **Stateful/concurrent control flow + testability.** The restart-in-place loop,
   caller-last ordering, the marker-file state machine, `mkdir` locks, the disowned
   background pollers (`spawn_ready_handshake_monitor` is one) — genuine concurrent,
   stateful logic that bash fights. It is nearly untestable: this feature's Python was
   verified by *awk-extracting heredocs*, which is fragile. The whole
   CODEMAP/SKELETON/features-index apparatus exists largely to compensate for shell's
   opacity. That maintenance tax is the cost of staying in bash.

What shell is **not** failing at: process orchestration, and distribution (see below).

## Why staying in shell is still defensible today

- claude-mux's core job *is* shelling out. A compiled binary shells out to the same tools.
- **"Script, not binary" is load-bearing** (documented in CLAUDE.md): instant upgrades
  (every invocation reads fresh from disk, no stale binary), no per-arch builds, no macOS
  code-signing / Gatekeeper friction, users can read and audit the script. A binary loses
  all of that.
- Runtime performance is a non-issue; it's not compute-bound.

## Language choice, if we move

- **Go — yes.** Single static binary, trivial cross-compile, real stdlib JSON (kills the
  Python heredocs), goroutines/proper daemons instead of disowned background pollers, easy
  testing, clean `os/exec` subprocess story, natural Homebrew/`go install` distribution.
  Decisive factor: the **v2.5 Windows goal** — bash-to-Windows is the painful WSL-vs-native
  mess; Go compiles natively for macOS/Linux/Windows. Keeps the "shell out to tmux/git"
  model intact.
- **Rust** — viable but overkill. Its wins (memory safety, fearless concurrency) don't pay
  off for an orchestrator that mostly spawns subprocesses; you pay in ceremony and dev
  speed. Pick only if the team already lives in Rust.
- **C++** — no. Manual memory management and portability pain for zero gain here.
- **Swift** — only if claude-mux committed to Mac-only forever (great launchd/Foundation
  integration, path to a menubar app). Its Linux/Windows story is second-class, so the
  Windows goal rules it out.

## Pragmatic path (do NOT big-bang rewrite a released OSS tool with users)

1. **Strangler extraction.** Pull the gnarliest piece into a small Go helper the shell
   calls, attacking real pain first. Order of candidates: (a) settings-JSON manipulation
   (the Python heredocs) → a `claude-mux json`-style helper; (b) the background monitors.
2. **Let Windows force the full move.** v2.5 Windows support is where bash genuinely breaks;
   that's the natural moment to rewrite in Go and pay off both the language ceiling AND the
   platform goal in one effort.

So: staying in shell is defensible now; the JSON heredocs are the thing to watch; Go is the
destination; Windows is *when*, not "when it feels big."
