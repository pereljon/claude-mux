---
feature: make-codemap
status: PLANNED — pre-build
target_version: 2.0.x (patch; dev-tooling, no runtime change)
severity: N/A (developer-tooling) — but it closes the structural-doc-drift class that produced a real, propagated error (build_system_prompt mislabeled module 70 instead of 30 across 5 docs, 2026-06-17→19)
related: src-module-split (this is its deferred decision D4), test-suite-ci
---

# Feature: `make codemap` — generate the CODEMAP index from source, guard it like the artifact

## Why (the incident this exists to prevent)

The `src/` module split was sold as "reduces `dev/CODEMAP.md` drift." It only reduced
**line-number** drift (within-module offsets are stable). The thing that actually drifted
was the function→**module label**: `build_system_prompt` (defined at line 1480, in
`src/30-helpers.sh`) was hand-labeled under `src/70-start-launch.sh` in the module-split
partition table — wrong from its first commit (`b4d9a07`) — and that error was then
**copied into CODEMAP, IMPLEMENTATION-SPEC, SKELETON, and the inter-agent doc** during
implementation. A *correct* record sat in CODEMAP's Function Index the whole time
(`1435`), un-reconciled.

Root cause: **hand-maintained duplicates of source-derivable facts always drift.** The
function→module:line mapping is 100% derivable from `src/` by `grep`, yet it was
hand-copied. The fix is to stop hand-maintaining it.

## Principle: generate the drift-prone facts; guard them like `claude-mux`

- **Generate > check.** A check only catches drift *after* it happens (you still fix it by
  hand). **Generation makes the drift-prone part impossible to get wrong** — you cannot
  mislabel a `grep` result.
- **Then guard generation the same way `make check` guards the built artifact**: regenerate
  and fail if the committed copy is stale ("forgot to regenerate" == "forgot to rebuild").
- **Prose stays hand-written.** Purpose descriptions and control-flow narration can't be
  generated; they drift slowly and carry no line numbers or module labels (the drift-prone
  part). Generation owns the *index*; humans own the *prose*.

## What is generatable (all greppable from `src/`)

Proof-of-concept verified 2026-06-19: `grep -n '^[a-z_][a-z0-9_]*()' src/*.sh` yields an
authoritative `module:within-module-line` index (it even places `check_for_update` under
`30-helpers` correctly — generation can't make the build_system_prompt mistake).

- **Function index** — every `^funcname()` in `src/*.sh` → `module : within-module line`.
  **This is the part that drifted; ship it first.** **Decision D2 (architect): emit ONLY
  `module:within-module-line` — drop the absolute built-line column.** The absolute line is
  itself drift-prone duplication (it requires summing prior-module line counts in `MODULES`
  order, and re-`grep`ing the built `claude-mux` for it would create a second source of
  truth that can drift from the src-derived number). CODEMAP prose notes "absolute line =
  within-module line + the module's offset" for anyone who needs it; the generated index
  stays purely src-derived.
- **Per-module "contents"** — the Source Layout table's function list per module (a
  group-by of the above). This is the exact table that held the error.
- **Later (incremental):** the **dispatch table** (parse the `case "$COMMAND" in` arms in
  `src/90-dispatch.sh`), and **config vars** (variable assignments in `src/00-defaults.sh`).

## Design

### `make codemap` — regenerate the index

A `codemap` Make target that scans `src/*.sh` and writes the generated index. **Decision
D1 — where the generated content lives:**
- **(recommended) A dedicated generated file**, e.g. `dev/CODEMAP.index.md`, regenerated
  *wholesale* by `make codemap`. CODEMAP.md keeps the prose and links to it. Cleanest:
  the generated file is 100% machine-owned (never hand-edited), trivially diffable, no
  in-place section surgery, no marker-corruption risk.
- (alternative) An `<!-- AUTOGEN:functions START/END -->` delimited block *inside*
  CODEMAP.md that the target rewrites in place — keeps one navigable file, but needs
  sed/awk block-replacement and risks a hand-edit corrupting the markers.

Recommend the dedicated file for implementation simplicity + clean diffs.

Generation is a shell/awk loop (no new dependency). **It MUST iterate the explicit
`MODULES` list from the `Makefile` (architect), NOT a `src/*.sh` glob** — the glob is
lexical and a stray file in `src/` would silently reorder the index (the Makefile avoids
the glob for exactly this reason). Per module in `MODULES` order: emit each `^funcname()`
with its module name and within-module line; group for the per-module table. Output is
**deterministic** (modules in `MODULES` order, then by line) so the diff is meaningful.
Read the `MODULES` list from the Makefile (single source of truth) rather than hardcoding
it a second time.

The generated file is **committed, not gitignored** — so GitHub/at-rest browsing still
shows the index, and `make check-codemap` has a committed baseline to diff against.

### `make check-codemap` — guard it (the "hook")

```makefile
check-codemap: codemap
	git diff --exit-code dev/CODEMAP.index.md   # committed index must match a fresh generation
```

- **Fold into the existing drift guard**, not a bespoke hook. Two MANDATORY wiring details
  the architect flagged (the guard does not work without them):
  - **`make check` MUST gain `check-codemap`** as a dependency (today `make check` only
    diffs `claude-mux`, `Makefile:29`). This is mandatory, not "or just call `make check`."
  - **The `.githooks/pre-commit` engage filter MUST add the generated index path.** Today
    the hook only engages when staged files match `^(src/|claude-mux$|Makefile$)`
    (`.githooks/pre-commit:18`). As-is, a commit that **hand-edits `dev/CODEMAP.index.md`
    alone** (no `src/` change) would **skip the hook entirely** → the manual-edit case is
    unguarded. Add `dev/CODEMAP.index.md` (and the generator script, if separate) to the
    regex, and run `make codemap` + `git diff --quiet dev/CODEMAP.index.md` in the hook body
    (or call `make check`, now that it includes `check-codemap`).
  - **CI** (`.github/workflows/ci.yml`) runs `make check`, which now also covers the index.
- This mirrors the artifact guard exactly: a stale committed index fails the commit/CI —
  whether the staleness came from a `src/` move (forgot to regenerate) or a hand-edit of
  the generated file.

### CODEMAP.md adjustment

- The hand-maintained **Source Layout "contents"** and **Function Index** become the
  generated `dev/CODEMAP.index.md`; CODEMAP.md links to it and keeps the **prose** (How to
  Use, How to Maintain, purpose descriptions, marker registry).
- Update the "How to Maintain" section: *the function index is generated — run `make
  codemap`; never hand-edit `CODEMAP.index.md`.* (Same inversion as "edit `src/`, not
  `claude-mux`.")

## Honest limits

- **Closes structural drift only** — function→module:line, dispatch table, config vars —
  the greppable facts. It does **not** catch **semantic** drift ("does this prose still
  describe the behavior"); that still needs the Change Checklist + review.
- **Depends on the grep pattern matching the codebase's function-def style.** The POC
  pattern `^[a-z_][a-z0-9_]*()` matched cleanly, but a function defined unusually (e.g.
  `function foo {`) would be missed. The generator must use the project's actual
  convention and **assert a concrete sanity check (architect):** the total emitted count
  equals `grep -c '^[a-z_][a-z0-9_]*()' $(MODULES)` summed, AND no module yields 0
  functions where the previously-committed index had >0 — else fail loudly (a broken grep
  pattern or a renamed-away module must not silently produce an empty/short index).
- **The dispatch/config generation is more than a grep** (parsing `case` arms / assignment
  lines) — defer to a later increment; ship the function index first.

## Files to update (Change Checklist)

- **New:** `dev/CODEMAP.index.md` (generated), the `codemap` + `check-codemap` Make targets.
- `Makefile`: add `codemap`, `check-codemap`; fold `check-codemap` into `check`.
- `.githooks/pre-commit`: run `make codemap` + diff (or call `make check`).
- `.github/workflows/ci.yml`: covered via `make check` (no change if it already runs `make check`).
- `dev/CODEMAP.md`: move the Function Index + Source Layout contents to the generated file;
  link to it; update "How to Maintain" (index is generated).
- `dev/IMPLEMENTATION-SPEC.md`: note the generated index under "Build / Source Layout."
- `CLAUDE.md`: Change Checklist — "run `make codemap` after adding/renaming/moving a
  function" (and the pre-commit/CI now enforce it).
- `docs/ISSUES.md`: mark the src-module-split D4 ("auto-gen CODEMAP") as resolved by this.

## Out of scope
- Generating prose/purpose descriptions (not derivable).
- Semantic-drift detection (prose vs behavior) — stays manual.
- A full bespoke doc-lint beyond the index/dispatch/config facts.
