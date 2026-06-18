---
feature: src-module-split
---

# Test Plan: `src/` module split with build-time concatenation

Tests for `src-module-split.md`. Decisive metric: **the built `claude-mux` is
byte-identical to the pre-split file**, and every existing command behaves
exactly as before. Because the refactor changes no behavior, the test plan is
dominated by *equivalence* checks plus a behavior smoke pass.

## Pre-build verification (confirm before slicing)

- **V0.1 Boundaries are clean cut points.** For every proposed boundary line,
  confirm it is a blank line or a `# ──` banner (never mid-function, mid-heredoc,
  or mid-`case`). Spot-check the three risky ones: the flag-parse region
  (113-694, contains `guide`/`commands_help`/`config_help` defs and large
  heredocs), the launch-wrapper heredocs (in 50/60 — `create_claude_session` and
  `launch_single_session` emit launch scripts via heredoc; a cut inside one would
  corrupt it), and the Main `case` (3251-EOF must stay one module).
- **V0.2 No `set -euo pipefail`.** Confirmed 2026-06-17 — there is no global
  error-mode that a reordered concat could subtly alter. Re-confirm if added.
- **V0.3 Partition covers 1..EOF with no gaps/overlaps.** The slice ranges must
  tile the file exactly (each line in exactly one module).

## The equivalence proof (the core test)

- **T1.1 Byte-identical build.** From the tagged pre-split `claude-mux`:
  `make build` then `diff <built> <pre-split>` → **empty**. This is the whole
  ballgame; if it passes, behavior cannot have changed.
- **T1.2 `cmp` confirms no invisible diffs.** `cmp claude-mux <pre-split>` →
  identical (catches trailing-newline / whitespace bytes a line `diff` might
  gloss).
- **T1.3 Executable bit + shebang.** Built `claude-mux` is `chmod +x` and line 1
  is `#!/bin/bash`.
- **T1.4 Idempotent rebuild.** `make build` twice → no diff between runs; the
  artifact is stable.

## Build-system behavior

- **T2.1 `make check` passes when in sync.** After `make build` + commit,
  `make check` (build + `git diff --exit-code claude-mux`) exits 0.
- **T2.2 `make check` FAILS on drift.** Edit a `src/*.sh` (e.g. add a comment)
  without rebuilding the committed artifact → `make check` exits non-zero and
  names `claude-mux`. (Proves the guard works.)
- **T2.3 `make check` FAILS on direct artifact edit.** Edit `claude-mux` directly
  → next `make build` overwrites it and `make check` flags the divergence from
  `src/`.
- **T2.4 Module order is explicit.** Reorder two entries in the Makefile `MODULES`
  list → built output differs from committed → `make check` fails. (Proves order
  is pinned, not glob-dependent.)
- **T2.5 `bash -n` on the built file** passes (syntax valid after concat).
- **T2.6 shellcheck on the built file** runs (warnings triaged, not necessarily
  zero); shellcheck on an individual fragment is NOT part of the gate (expected
  cross-module false positives).

## Behavior smoke (prove runtime identical)

Run against the built `claude-mux` (these are the CI smoke set + a few extra):

- **T3.1 Read-only commands** produce identical output to the pre-split binary:
  `--guide`, `--commands`, `--config-help`, `--list-templates`, `-l`, `-L`,
  `-L --status idle`, `--get-mode <session>`, `--tip`. Diff each against the
  pre-split file's output.
- **T3.2 `--dry-run`** paths (`--dry-run` launch, `--dry-run --restart`) log the
  same "Would …" lines.
- **T3.3 Flag parsing intact.** A bad flag errors the same way; `--version` /
  `VERSION` reports `2.0.x`; combined flags (e.g. `-n DIR --no-attach
  --template X`) parse as before.
- **T3.4 Hook entrypoints.** `--on-prompt` (handshake no-op + real-prompt tip),
  `--on-compact`, `--await-ready`, `--print-system-prompt` behave identically
  (these are dispatch cases in the Main module — confirm the case didn't get
  split).
- **T3.5 One real session lifecycle.** Start a throwaway session, confirm ready
  handshake + RC, `--restart` it, `--shutdown` it. End-to-end unaffected.

## Regression

- **T4.1 Install paths unaffected.** The committed single-file `claude-mux` is
  still what curl/Homebrew fetch; `install.sh` is unchanged and still installs the
  one file. (No `src/` shipped to users.)
- **T4.2 Release artifact.** A dry-run of the release steps targets the committed
  `claude-mux`; rebuild-and-clean (`make check`) is green before a tag would be
  cut.
- **T4.3 `.gitignore` / repo hygiene.** `claude-mux.built` or any temp build
  output is gitignored; `src/` and `Makefile` are tracked.

## Acceptance

- **T1.1-T1.4 are mandatory and sufficient for correctness** — byte-identical
  build means zero behavior change by construction.
- T2.x: build + drift guard work (the durable safety net for future `src/` edits).
- T3.x: spot-checked runtime behavior matches (defense-in-depth on top of the
  byte diff).
- T4.x: distribution, release, and repo hygiene unregressed.

## Cleanup

Remove throwaway test sessions and any `claude-mux.built` scratch file. Keep the
pre-split tagged commit until T1.1/T3.x have all passed, as the equivalence
baseline.
