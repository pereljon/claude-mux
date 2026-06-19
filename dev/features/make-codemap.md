---
feature: make-codemap
kind: feature
lifecycle: shipped
status: IMPLEMENTED 2026-06-19 (dev-tooling; claude-mux artifact byte-identical, no release)
target_version: 2.0.x (patch; dev-tooling, no runtime change)
severity: N/A (developer-tooling) — but it closes the structural-doc-drift class that produced a real, propagated error (build_system_prompt mislabeled module 70 instead of 30 across 5 docs, 2026-06-17→19)
related: src-module-split (this is its deferred decision D4), test-suite-ci
---

# Feature: `make codemap` — generate the drift-prone doc indexes from source, guard them like the artifact

Two generated indexes, one machine: **(1) the CODEMAP function→module:line index** (from
`src/`), and **(2) the feature index** `dev/features/INDEX.md` (from each feature doc's
frontmatter — the "what's queued to build, of any size" view). Both are
generate-then-guard, same as `make check` guards the built `claude-mux`.

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

## Generated index #2: the feature index (`dev/features/INDEX.md`)

> **Framing (architect): this is NOT the same class of artifact as the CODEMAP index.**
> The CODEMAP index is a projection of *ground truth* (`src/` — you cannot mistype a grep
> result). The feature index is a projection of *author-asserted opinions* (the `lifecycle:`
> frontmatter), so generating it does **not** close a mechanical drift class. What it
> guards is only "the INDEX.md table matches the frontmatter values someone typed" — a real
> but thin guarantee. Its actual value is a **convenience projection**: after a context
> clear, a fresh session gets a sorted, grouped, one-glance build queue without reading 20
> files. Generate it (vs hand-maintain) for the cheap reason — a hand index goes stale
> every time you flip a status and forget — but **do not sell it as drift-prevention.**
> **It is a SEPARATE Make target from `make codemap` (see "Two targets, not one").**

### Standardized frontmatter: `lifecycle:` + `kind:`

Today each feature doc has free-text `status:` ("PLANNED — pre-build", "SHELVED (pending…)",
"IMPLEMENTED (date)", a full paragraph for inter-agent) — human-readable but **not
machine-aggregatable**. Add two normalized fields; keep `status:` as the free-text
detail/history line.

**`kind:` — controlled vocab `feature | investigation`** (architect). Some `dev/features/`
docs are *investigations/analysis*, not buildable features (e.g.
`caller-restart-resume-investigation.md`). Those have no build lifecycle and must be
**excluded from the build queue** — exactly as `*-tests.md` are. `kind: investigation` rows
are dropped from INDEX.md; `kind: feature` is the default and the only kind that needs a
`lifecycle`.

**`lifecycle:` — controlled vocab (exactly these values):**

| `lifecycle` | Meaning |
|---|---|
| `idea` | raw idea; no design doc body yet |
| `designing` | design doc being written; not build-blessed (incl. reopened-from-shelved) |
| `ready` | design complete **and** architect-reviewed; build-ready |
| `building` | implementation in progress |
| `shipped` | released / implemented in the live script (a "pending real-world test" caveat still counts as shipped; put it in `status:`) |
| `shelved` | deliberately parked / won't-build-now (may carry gates) |
| `superseded` | abandoned / reverted-wrong / replaced — kept for the record, never building |

- **History/transient state lives in `status:`, NOT in a new lifecycle value.** "Reopened
  from shelved" → `lifecycle: designing` + `status:` carries the story. Do not invent
  `reopened`.
- **Validator: FAIL (not warn) on a missing `lifecycle` for a `kind: feature` doc, and FAIL
  on an unknown value.** A warning in a drift guard is worthless (pre-commit/CI pass with a
  warning → a malformed row ships). `*-tests.md` and `kind: investigation` are excluded
  **by a filename/kind filter applied FIRST**, before the missing-lifecycle check, so they
  never trip it.

### Migration (one-time, explicit) — every current `dev/features/*.md`

Land this migration + the generator + the guard in **ONE commit** (a partial migration
bricks the pre-commit hook for everyone, since a `kind: feature` doc missing `lifecycle`
now fails). Verified mapping:

| Doc | `kind` | `lifecycle` |
|---|---|---|
| make-codemap | feature | ready |
| notice-delivery-reliability | feature | ready |
| model-handling-derot | feature | ready |
| launched-version-detection | feature | designing |
| cross-cli-coders | feature | designing |
| inter-agent-messaging | feature | designing (status: reopened from shelved) |
| restart-all-throttle | feature | shelved (tabled pending measurement) |
| caller-restart-resume-race | feature | superseded (reverted-wrong hypothesis) |
| caller-restart-resume-investigation | **investigation** | — (excluded) |
| auto-restore | feature | shipped |
| ready-handshake | feature | shipped |
| claude-code-upgrade-detection | feature | shipped |
| precompact-hook-backfill | feature | shipped |
| restart-caller-shutdown-fix | feature | shipped (v2.0.4) |
| restart-in-place | feature | shipped (status: pending restart-all-from-home test) |
| session-target-disambiguation | feature | shipped (v2.0.5) |
| src-module-split | feature | shipped |
| start-by-name | feature | shipped (v2.0.7) |
| status-filter | feature | shipped |
| tip-ready-handshake | feature | shipped (v2.0.8) |

(`*-tests.md` files carry no `kind`/`lifecycle` and are excluded by glob.)

**Migration wrinkle (verified 2026-06-19): three docs have NO YAML frontmatter at all** —
`auto-restore.md`, `claude-code-upgrade-detection.md`, `ready-handshake.md` open directly
with `# Feature:`. For these the migration must **create a full frontmatter block** (at
minimum `feature` + `kind` + `lifecycle`), not append two fields. The remaining docs
already have a `---` block with a free-text `status:` to preserve; there the migration
only adds `kind` + `lifecycle`. Don't assume a `---` block exists everywhere.

### Generation — `make features-index`

`make features-index` reads each `dev/features/*.md` frontmatter (excluding `*-tests.md` and
`kind: investigation` **first**), validates `kind`/`lifecycle` against the controlled vocab
(FAIL on missing/unknown), and emits `dev/features/INDEX.md` — a table grouped by
`lifecycle` (ready → building → designing → idea → shelved → superseded → shipped) then
sorted by `feature`, each row: `feature | lifecycle | target_version | status (free-text) |
severity | link`. Deterministic ordering so the diff is meaningful; generated + committed,
guarded by `check-features-index` (see below).

This gives the persistent, size-agnostic build queue: after a context clear, a fresh
session reads `dev/features/INDEX.md` and knows exactly what's `ready` to build.

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

**D5 (impl) — pass `$(MODULES)` into the generator; do NOT re-parse the Makefile.** The
`MODULES` variable spans 5 lines with `\`-continuations; re-parsing it in shell/awk is
fiddly and duplicative. Instead the `codemap:` recipe invokes the generator with
`$(MODULES)` as positional arguments — Make expands the list, the script iterates `"$@"`.
Same single-source-of-truth guarantee (the list still lives only in the Makefile), zero
Makefile-parsing code.

**D6 (impl) — three modules legitimately have ZERO functions** (verified 2026-06-19:
`00-defaults`, `20-config`, `90-dispatch` — vars / config-sourcing / dispatch-`case`
only). The generator MUST render these gracefully (list the module with an empty function
set, or omit from the Function Index but never error). The per-module "contents" that the
hand-table carried as prose ("shebang, `VERSION`, default config vars") is NOT
generatable — only the function list is; those three modules simply have no functions to
emit. **This directly shapes the sanity check below: it must be a _regression_ check, not
"every module > 0."**

### Two targets, not one (architect HIGH — decouple)

`make codemap` and the feature index have **two unrelated inputs** (`src/*.sh` vs
`dev/features/` frontmatter), **two unrelated outputs**, for **two unrelated audiences**
(code navigation vs build planning). They share only the *pattern*, which is not a reason
to share a target — and "codemap" is a misleading name for the build queue. So **two
separate Make targets** (one feature doc is fine; two targets is not optional):

```makefile
codemap:           ; # src/*.sh        -> dev/CODEMAP.index.md
features-index:    ; # dev/features/*  -> dev/features/INDEX.md
check-codemap:        codemap        ; git diff --exit-code dev/CODEMAP.index.md
check-features-index: features-index ; git diff --exit-code dev/features/INDEX.md
check: build check-codemap check-features-index   # one drift command guards artifact + both indexes
```

Decoupling also **de-risks the weaker half**: the feature index is the later-justified,
opinion-projection addition — if the `lifecycle` convention proves annoying you can drop
`features-index` without touching the proven CODEMAP guard. Folding them would weld the
unproven half to the proven one. Ship `codemap` first; `features-index` can follow.

### Guard wiring

- **`make check` gains BOTH `check-codemap` and `check-features-index`** (today it only
  diffs `claude-mux`, `Makefile:29`). Mandatory.
- **Pre-commit `.githooks/pre-commit`.** Today it engages only on `^(src/|claude-mux$|Makefile$)`
  (`:18`), so a hand-edit of a generated index alone, or a `dev/features/*.md` frontmatter
  change, would skip the hook. Two options:
  - **(recommended, clean) Make the index-freshness check UNCONDITIONAL** — the hook always
    runs `make check-codemap` + `check-features-index` (regenerate + `git diff --quiet`)
    regardless of which files staged. Regen is cheap; a clean diff is a fast no-op. This
    avoids widening the path regex and the over-trigger below.
  - **(blunt, fails-safe) Widen the engage filter** to add `dev/CODEMAP.index.md`,
    `dev/features/INDEX.md`, and `dev/features/.*\.md`. **Caveat (architect):** this
    over-triggers — editing *prose* in any feature doc now forces a regen even though the
    index didn't change. It fails safe (redundant regen = no-op diff), but it couples
    "edited a feature doc" to "run the codemap machinery." If you take this option, document
    that the over-trigger is intentional. The unconditional check above is cleaner.
- **CI** (`.github/workflows/ci.yml`) runs `make check` → covers both indexes.
- Both generated files are **committed, not gitignored** (GitHub/at-rest browsing + a
  committed baseline to diff). A stale index fails the commit/CI — whether from a `src/`
  move, a frontmatter `lifecycle` flip, or a hand-edit of a generated file.

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
  **TRAP (impl, see D6): this is a _regression_ check, NOT "every module > 0."** Three
  modules (`00-defaults`, `20-config`, `90-dispatch`) are legitimately 0-function; a naive
  "fail if any module is empty" assertion would be wrong from the first run. Compare
  per-module counts against the committed baseline, not against zero.
- **The dispatch/config generation is more than a grep** (parsing `case` arms / assignment
  lines) — defer to a later increment; ship the function index first.
- **The feature index reflects declared `lifecycle`, not reality.** It can't detect a doc
  that *says* `ready` but isn't, or `shipped` that wasn't released — `lifecycle` is
  author-asserted (semantic, like prose). Generation only guarantees the index *matches the
  frontmatter*, not that the frontmatter is *true*. (Mitigation: the migration verifies each
  initial value against the script/CHANGELOG; thereafter the Change Checklist owns accuracy.)

## Files to update (Change Checklist)

- **New (generated, committed):** `dev/CODEMAP.index.md`, **`dev/features/INDEX.md`**; the
  `codemap`, `features-index`, `check-codemap`, `check-features-index` Make targets (and the
  two generator scripts if separate).
- **Migration (land in ONE commit with the generator + guard, else the hook bricks):** add
  `kind:` (default `feature`) and `lifecycle:` to **every** `dev/features/*.md` per the
  explicit mapping table above; `kind: investigation` docs need no `lifecycle`. `make-codemap.md`
  itself is already migrated (`lifecycle: ready`).
- `Makefile`: add the four targets (each `check-*` diffs its one generated file); `check`
  depends on `build` + both `check-*`.
- `.githooks/pre-commit`: **recommended** — run both `check-*` unconditionally (don't widen
  the path regex); **or** widen the engage filter to both index paths + `dev/features/.*\.md`
  (over-triggers, fails safe). See "Guard wiring."
- `.github/workflows/ci.yml`: covered via `make check`.
- `dev/CODEMAP.md`: move the Function Index + Source Layout contents to the generated file;
  link to it; update "How to Maintain" (index is generated).
- `dev/IMPLEMENTATION-SPEC.md`: note both generated indexes under "Build / Source Layout."
- `CLAUDE.md`: Change Checklist — "run `make codemap` after a function move; run
  `make features-index` after adding a feature doc or changing its `lifecycle`/`kind`"
  (pre-commit/CI now enforce both); document the `kind` + `lifecycle` controlled vocabs and
  that new `kind: feature` docs MUST declare a `lifecycle`.
- **Feature-doc convention** (Documentation Roles): every `dev/features/<feature>.md` MUST
  carry `kind:` (default `feature`); every `kind: feature` doc MUST carry a `lifecycle:` from
  the controlled vocab. `kind: investigation` docs are analysis-only and excluded from the
  build queue.
- `docs/ISSUES.md`: mark the src-module-split D4 ("auto-gen CODEMAP") resolved; point its
  roadmap prose at the generated `dev/features/INDEX.md` for the build queue.

## Out of scope
- Generating prose/purpose descriptions (not derivable).
- Semantic-drift detection (prose vs behavior; truthfulness of a declared `lifecycle`) — stays manual.
- A full bespoke doc-lint beyond the index/dispatch/config facts.
