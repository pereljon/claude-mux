---
feature: make-codemap
---

# Test Plan: `make codemap` + `make check-codemap`

Tests for `make-codemap.md`. Decisive properties: **the generated index is authoritative
(matches `grep` over `src/`)**, and **a stale committed index fails the drift guard** —
the same contract as `make check` for `claude-mux`.

## Generation correctness

- **T1.1 Index matches source.** `make codemap`; every `^funcname()` in `src/*.sh` appears
  in `dev/CODEMAP.index.md` with the correct `module:within-module-line`. Spot-check the
  two that were historically wrong: `build_system_prompt` → `30-helpers` (not 70),
  `check_for_update` → `30-helpers` (call site noted separately if generated).
- **T1.2 No phantom / missing entries.** The count of functions in the index equals
  `grep -c '^[a-z_][a-z0-9_]*()' src/*.sh` summed — no function dropped, none invented.
- **T1.3 Deterministic + MODULES-ordered.** `make codemap` twice → byte-identical output;
  the generator iterates the explicit `MODULES` list (not a `src/*.sh` glob), so a stray
  file dropped in `src/` does NOT reorder or pollute the index.
- **T1.5 No absolute-line column.** The generated index emits `module:within-module-line`
  only (no absolute built line) — there is no second, drift-prone line source.
- **T1.4 Sanity assertion.** The generator errors/ warns if it finds an implausible count
  (e.g. 0 functions in a non-trivial fragment) — guards against a broken grep pattern.

## Drift guard

- **T2.1 `check-codemap` passes when in sync.** After `make codemap` + commit,
  `make check-codemap` exits 0.
- **T2.2 FAILS on source drift.** Add/rename/move a function in a `src/*.sh` without
  regenerating → `make check-codemap` exits non-zero and names `dev/CODEMAP.index.md`.
- **T2.3 FAILS on a hand-edited index.** Hand-edit `dev/CODEMAP.index.md` → next
  `make codemap` overwrites it and the diff flags the divergence (index is generated, not
  authoritative).
- **T2.4 Folded into `make check`.** `make check` now fails if *either* `claude-mux` *or*
  the index is stale (one drift command guards both).
- **T2.5 Pre-commit enforces it — both directions.** With the hook installed: (a)
  committing a `src/` function move without regenerating the index is blocked; (b)
  committing a **hand-edit of `dev/CODEMAP.index.md` ALONE** (no `src/` change) is ALSO
  blocked — i.e. the hook's engage filter includes the generated index path (the gap the
  architect flagged: today's filter is `^(src/|claude-mux$|Makefile$)` and would skip
  case (b)).
- **T2.6 The exact historical bug is caught.** Reproduce: label a function under the wrong
  module by hand-editing the index → `make check-codemap` fails. (Generation makes the
  *original* mislabel impossible; the check catches a manual one.)

## Regression / hygiene

- **T3.1 `claude-mux` unaffected.** `make codemap` touches only docs; `make check` still
  shows `claude-mux` byte-identical.
- **T3.2 Prose preserved.** CODEMAP.md keeps How-to-Use / How-to-Maintain / marker
  registry / purpose prose; only the Function Index + Source Layout contents move to the
  generated file.
- **T3.3 No new dependency.** Generation uses shell/awk only (no node/python required at
  build time).

## Acceptance

- T1.x: the index is a faithful, deterministic projection of `src/`.
- T2.x: drift is impossible-to-author (generated) and caught if stale (guarded), via the
  existing `make check` / pre-commit / CI machinery.
- T3.x: artifact untouched, prose intact, no new deps.

## Cleanup
Remove scratch edits used to exercise T2.2/T2.3; restore the committed index via `make codemap`.
