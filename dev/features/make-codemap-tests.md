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
- **T1.4 Sanity assertion (regression, NOT "every module > 0").** The generator fails
  loudly if a module yields 0 functions where the committed baseline had >0 (broken grep
  pattern / renamed-away module). It must NOT fail on the three legitimately-0-function
  modules (`00-defaults`, `20-config`, `90-dispatch`) — those are 0 from the first run.
- **T1.5 No absolute-line column.** The generated index emits `module:within-module-line`
  only (no absolute built line) — there is no second, drift-prone line source.
- **T1.5b Empty-function modules render cleanly.** `00-defaults`, `20-config`,
  `90-dispatch` (0 functions each) appear in the generated output without erroring — either
  as an empty function set or omitted from the Function Index, never a crash or short-index.

## Feature index (`make features-index` → `dev/features/INDEX.md`) + lifecycle/kind

- **T1.6 Separate target.** `make features-index` is its OWN target (distinct from
  `make codemap`); it reads `dev/features/*.md` frontmatter and emits `dev/features/INDEX.md`
  with one row per `kind: feature` doc, each carrying `feature`, `lifecycle`,
  `target_version`, `status`, `severity`, and a working link.
- **T1.7 Grouped + deterministic.** Rows grouped by `lifecycle` (ready → building →
  designing → idea → shelved → superseded → shipped) then sorted by `feature`; two runs
  byte-identical.
- **T1.8a Unknown lifecycle FAILS.** A doc with `lifecycle: bogus` makes
  `make features-index` / `check-features-index` **exit non-zero**, naming the doc.
- **T1.8b Missing lifecycle FAILS (not warns).** A `kind: feature` doc with **no**
  `lifecycle` **fails** the guard (a warning would let a malformed row ship).
- **T1.8c `superseded` is valid.** `caller-restart-resume-race` (`lifecycle: superseded`)
  generates a row in the `superseded` group, not an error.
- **T1.9 The build queue is reachable.** `dev/features/INDEX.md` shows `make-codemap`,
  `notice-delivery-reliability`, `model-handling-derot` as `ready`, `inter-agent-messaging`
  as `designing` (reopened) — a fresh post-clear session reads it and finds the `ready` work.
- **T1.10a Exclusions applied FIRST (the ordering trap).** `*-tests.md` AND
  `kind: investigation` docs (e.g. `caller-restart-resume-investigation`) are filtered
  **before** the missing-lifecycle check, so they do NOT trip the FAIL even though they have
  no `lifecycle`; and they do NOT appear as index rows.
- **T1.10b `kind` enforced.** A doc with `kind: bogus` fails; default (absent `kind`) is
  treated as `feature`.

## Drift guard

- **T2.1 `check-codemap` passes when in sync.** After `make codemap` + commit,
  `make check-codemap` exits 0.
- **T2.2 FAILS on source drift.** Add/rename/move a function in a `src/*.sh` without
  regenerating → `make check-codemap` exits non-zero and names `dev/CODEMAP.index.md`.
- **T2.3 FAILS on a hand-edited index.** Hand-edit `dev/CODEMAP.index.md` → next
  `make codemap` overwrites it and the diff flags the divergence (index is generated, not
  authoritative).
- **T2.4 Both checks folded into `make check`.** `make check` depends on `check-codemap`
  AND `check-features-index`; it fails if `claude-mux`, `dev/CODEMAP.index.md`, OR
  `dev/features/INDEX.md` is stale.
- **T2.5 Pre-commit enforces it — all directions.** With the hook installed, each is blocked:
  (a) a `src/` function move without regenerating; (b) a hand-edit of `dev/CODEMAP.index.md`
  ALONE; (c) a hand-edit of `dev/features/INDEX.md` ALONE; (d) a `dev/features/*.md`
  `lifecycle`/`kind` change without regenerating. Whether via the **unconditional** index
  check (recommended) or the **widened path filter**, the b/c/d cases (which today's
  `^(src/|claude-mux$|Makefile$)` filter would skip) are caught.
- **T2.6 The exact historical bug is caught.** Hand-edit the CODEMAP index to mislabel a
  function's module → `make check-codemap` fails. (Generation makes the *original* mislabel
  impossible; the check catches a manual one.)
- **T2.7 Two separate targets.** `check-codemap` diffs only `dev/CODEMAP.index.md`;
  `check-features-index` diffs only `dev/features/INDEX.md`; a stale feature index fails
  `check-features-index` (and `make check`) independently of the CODEMAP index.
- **T2.8 One-commit migration (hook-brick guard).** Verify the migration (add `kind`/`lifecycle`
  to all docs) + the generator + the guard land together: a state where the guard is live but
  a `kind: feature` doc lacks `lifecycle` must FAIL — proving a partial migration would brick
  the hook, which is why it ships in one commit.

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
