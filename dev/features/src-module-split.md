---
feature: src-module-split
status: IMPLEMENTED (2026-06-17)
target_version: 2.0.x (patch; no release - shipped artifact byte-identical)
severity: N/A (developer-ergonomics refactor, zero runtime behavior change)
related: test-suite-ci (ISSUES Planned Patches), language-runtime-reconsideration
---

## Implementation notes (2026-06-17)

Built as designed. Two deviations from the doc body below, both to protect byte-identity:

1. **Module 50 ends at line 2899, not 2903** (module 55 starts at 2900). Line 2900-2903
   is `await_ready_handshake`'s doc-comment; cutting at 2904 would have stranded the
   comment in module 50. Moving the boundary up keeps each function's leading comment
   with its function. (Byte-identity is unaffected either way — the partition still
   tiles 1..EOF.)
2. **No per-fragment `# shellcheck shell=bash` header.** The doc suggested adding one to
   each fragment for editors, but that injects bytes and would break the byte-identical
   build (T1.1, the core invariant). Skipped — `.sh` extension covers most editors;
   shellcheck runs on the built file (where cross-fragment refs resolve), as designed.

Verified: `cmp` built vs pre-split → identical; `make check` passes in sync and fails on
drift; `bash -n` clean; read-only commands (`--guide`/`--commands`/`--config-help`/
`--list-templates`) output-identical to the pre-split file. Module 50 was *not* further
subdivided (the `†` internal split) — left whole at 851 lines; subdividing is a clean
follow-up if the 800 guideline is enforced later.

# Feature: `src/` module split with build-time concatenation

## Goal

Split the single ~4897-line `claude-mux` script into ordered `src/*.sh` modules
plus a `make build` that concatenates them back into the **same** single-file
`claude-mux` that ships today. Distribution is unchanged (curl + Homebrew still
fetch one file). The wins: tractable files to edit, less merge pain, and the
`dev/CODEMAP.md` line-number-drift problem largely goes away.

**This is a behavior-preserving refactor.** Success = the built `claude-mux` is
**byte-identical** to the pre-split file. No feature, no flag, no config change.

**Scope of the safety claim (be honest):** byte-identity proves only the *initial
split is safe* — it is `cat` of an exact partition, so `diff built original` is
empty by construction. It does **not** make the post-split *structure* risk-free.
The moment a contributor edits a `src/` fragment, byte-identity is gone and you
are back to ordinary correctness with no test net (the ongoing exposures are
heredocs — `create_claude_session`/`launch_single_session` emit launch scripts —
and the two `case "$COMMAND"` blocks straddling future edits). So this refactor
is a one-time safe cut that *creates a new failure class* (src/artifact drift +
unguarded fragment edits); the CI guard below is not optional polish, it is the
thing that makes living with `src/` safe. (Architecture review, 2026-06-17.)

## The constraint that shapes everything: execution order is load-bearing

`claude-mux` is **not** "config block, then all functions, then dispatch." It
runs **top-to-bottom with imperative blocks interleaved between function
definitions** (verified 2026-06-17, no `set -euo pipefail` anywhere):

```
Defaults / config-var declarations        (imperative assignments)   ~1-112
Flag parsing                              (imperative; consumes "$@") 113-684
  (guide / commands_help / config_help defined in this region)
User config sourcing + auto-migration     (imperative; overrides defaults) 695-781
Constants                                 (imperative)               782-820
Helpers                                   (function defs)            821-1599
Attach helper / validate -d / validate -n / dependency check
  / managed session names                 (mix of imperative + defs) 1600-1718
Shutdown                                  (function defs)            1719-2048
Functions (create_claude_session, ...)    (function defs)            2049-2151
Restore-state + launch wrappers + ...     (function defs)            2152-3149
Migrate / discover / ensure base dir      (function defs)            3150-3250
Main: start_sessions() + the dispatch case (defs + terminal exec)    3251-4897
```

Because flag parsing consumes `$@` early, config sourcing must land *after*
defaults to override them, validation must precede dispatch, and the `case` must
run last, **the modules must be contiguous ordered slices of the current file**,
concatenated in a fixed order. You cannot re-group by topic. This is a
limitation but also a gift: it makes the refactor **byte-exact and trivially
verifiable**.

## Design

### Modules = ordered slices, cut at the existing `# ──` banners

The script has natural section banners (`# ── Defaults ──`, `# ── Helpers ──`,
...); cut there where they exist, and at clean function boundaries inside the two
banner-less regions (the old "Functions"/"Restore-state" block and the "Main"
grab-bag). Locked partition (boundaries confirmed 2026-06-17 against the v2.0.8
script; every cut lands on a blank line, with each function's leading doc-comment
travelling with it):

| Module | Lines | ~Size | Contents |
|---|---|---|---|
| `src/00-defaults.sh` | 1-112 | 112 | shebang, `VERSION`, all default config-var declarations |
| `src/10-flags.sh` | 113-684 | 572 | flag-parsing loop + `guide`, `echo_hint`, `commands_help`, `config_help` |
| `src/20-config.sh` | 685-820 | 136 | legacy `--tipotd` no-op, user-config sourcing + auto-migration, constants |
| `src/30-helpers.sh` | 821-1599 | 779 | general helpers (`check_for_update` 855, `do_update` 903, `get_version_prompt_lines` 1415, `build_system_prompt` 1480, ...) |
| `src/35-validate-deps.sh` | 1600-1718 | 119 | attach helper, validate `-d`/`-n`, dependency check, managed-session names |
| `src/40-shutdown.sh` | 1719-2048 | 330 | shutdown functions |
| `src/50-restore-state.sh` | 2049-2903 | 855 † | "Functions" + restore-state bookkeeping (`restore_state_*`, `should_be_alive`, `poll_until_ready`) — over cap, one internal split needed |
| `src/55-session-launch.sh` | 2904-3149 | 246 | `await_ready_handshake` (2904), `restart_caller_in_place` (2918), `create_claude_session` (2942) |
| `src/60-discovery.sh` | 3150-3250 | 101 | migrate stray, discover projects, ensure base dir |
| `src/70-start-launch.sh` | 3251-3517 | 267 | `start_sessions` (3253), `launch_single_session` (3302) — both *call* `build_system_prompt` (defined in `30-helpers`) |
| `src/75-tip-notices.sh` | 3518-4252 | 735 † | `tip_of_day` (3521), `detect_claude_upgrade` (3598), `on_prompt` (3618), `on_compact`, update-check machinery — near cap, subdividable |
| `src/80-templates-restore.sh` | 4253-4515 | 263 | `list_templates` (4253), `apply_template` (4278), `autorestore_walk` (4405), `autolaunch_dispatch` |
| `src/90-dispatch.sh` | 4516-4897 | 382 | `check_for_update` call, first-run guard `case` (4524), the terminal dispatch `case` (4557) |

13 modules. Most 100-580 lines; two (`50` 855, `75` 735) sit at/over the 800
guideline — `50` takes one internal `†` split at a function boundary (~2500)
during implementation, `75` is left whole or split if a clean boundary exists.
This is **somewhat more topical than a coarse cut** — modules 70/75/80/90 break
the old ~1650-line "Main" grab-bag into start+launch, tip/notice machinery,
templates+auto-restore, and pure dispatch (pure-function-def moves;
behaviour-identical, arrangement-only byte change). But do **not** oversell it:
the split buys *navigation*, not *cohesion*. A given feature's defaults/helpers/
dispatch-arm stay scattered across `00`/`30`/`90` (e.g. update-check spans `00`
defaults, `30` `do_update`, `90` dispatch arm). True topical cohesion would need
a behaviour-changing reorder (bash global/local scoping hazards, no test net) —
correctly out of scope; the ordered slice is the right ceiling for now
(architecture review, 2026-06-17). Line numbers are the
*current* boundaries; the split is generated mechanically from them (see
"Migration"). Granularity is still tunable — **decision D1** below.

### Build: explicit ordered concat, not a glob

```makefile
# Makefile
MODULES = src/00-defaults.sh src/10-flags.sh src/20-config.sh \
          src/30-helpers.sh src/35-validate-deps.sh src/40-shutdown.sh \
          src/50-restore-state.sh src/55-session-launch.sh src/60-discovery.sh \
          src/70-start-launch.sh src/75-tip-notices.sh src/80-templates-restore.sh \
          src/90-dispatch.sh

build: $(MODULES)
	cat $(MODULES) > claude-mux
	chmod +x claude-mux

check: build
	git diff --exit-code claude-mux   # built artifact must match what's committed
```

**Explicit file list, not `cat src/*.sh`** — glob sort is lexical (`src/100-…`
would sort before `src/20-…`), and an explicit list makes the order reviewable
and immune to a stray file in `src/`. `cat` of an exact partition reproduces the
original byte stream.

### Shebang: lives in the first module; build is pure `cat`

`#!/bin/bash` stays as line 1 of `src/00-defaults.sh`. The other modules are
fragments with **no shebang**. `make build` is a plain `cat`, so the output's
first line is the shebang and the byte stream is identical to today. (Rejected
alternative: build injects the shebang and strips it from fragments — more
moving parts, no benefit.)

### The committed `claude-mux` is a build artifact

curl install and the Homebrew formula fetch the raw single `claude-mux` from the
repo/release, so **`claude-mux` must stay committed** (it is not generated at
install time). `src/` is the source of truth; `claude-mux` is the generated,
committed artifact. This inverts the current CLAUDE.md rule:

- **Today:** "edit the repo copy `claude-mux`, deploy with `cp claude-mux ~/bin/`."
- **After:** "edit `src/*.sh`, run `make build`, then `cp claude-mux ~/bin/`.
  **Never edit `claude-mux` directly.**"

### Drift guard (the real risk)

The failure mode is `src/` and the committed `claude-mux` diverging. It has two
directions, and they are not equally caught — the architecture review (2026-06-17)
flagged the second as the sharp one:
- **(a) edit `src/`, forget `make build`** — `make check` in CI catches this cleanly.
- **(b) edit `claude-mux` directly** — a maintainer merging fast can land the
  artifact edit, and the *next* unrelated `make build` then silently reverts it.
  CI `make check` alone does not reliably stop this; it needs a local gate.

Because of (b), the guards are **not "pick one"** — adopt all of these:

1. **`make check`** (above): `make build && git diff --exit-code claude-mux`,
   run in CI on every PR (alongside the Test-suite smoke job). Catches (a).
2. **Pre-commit hook — MANDATORY, not optional** (revised from D5): refuse a
   commit where `claude-mux` is staged without its `src/` sources, or where
   `make build` produces a diff. This is the only thing that catches (b) at the
   point of commit; the doc rule alone *will* be forgotten.
3. **Doc rule** in CLAUDE.md "Development Workflow": edit `src/`, never
   `claude-mux` directly. Mandatory, but a backstop to the hook, not a substitute.
4. **`.gitattributes` for the generated file:** a committed generated file
   produces merge conflicts in `claude-mux` on every concurrent branch. Mark it so
   tooling treats it as generated (e.g. `claude-mux linguist-generated=true`, and
   consider a merge strategy note) and document that conflicts in `claude-mux` are
   resolved by rebuilding from `src/`, never by hand-merging the artifact.
5. **Release gate (promoted from the edge-case table — this is the most important
   single guard):** the release checklist MUST run `make check` clean immediately
   before `git tag`, so a release can never tag a stale artifact. See "Files to
   update".

### shellcheck runs on the built file, not the fragments

Fragments reference vars/functions defined in *other* fragments, so shellcheck
on a single `src/*.sh` floods false "undefined" warnings. Run shellcheck on the
**built `claude-mux`** (which is what ships). Add `# shellcheck shell=bash` to
each fragment only so editors don't mis-detect the language. (This dovetails
with the Test-suite patch's shellcheck step — same target.)

### How this translates to CODEMAP and SKELETON

Both dev docs get *easier* to maintain, because the split is exactly the
structure they already describe.

**`dev/CODEMAP.md` (function index + dispatch table + config-var list).** Today
every row carries an absolute line number into the 4897-line file, so almost any
edit drifts dozens of rows — the headache this split exists to kill. After the
split the line-number column becomes **`module:line-within-module`**:

| Today | After |
|---|---|
| `restart_caller_in_place \| 2918 \| ...` | `restart_caller_in_place \| 55-session-launch.sh:15 \| ...` |
| `autorestore_walk \| 4405 \| ...` | `autorestore_walk \| 80-templates-restore.sh:153 \| ...` |
| `on_prompt \| 3618 \| ...` | `on_prompt \| 75-tip-notices.sh:101 \| ...` |

A within-module offset only moves when *that* module changes — an edit in
`30-helpers.sh` no longer renumbers `on_prompt` in `75`. The other CODEMAP
sections map cleanly: the **dispatch table** → `90-dispatch.sh`, the **config-var
list** → `00-defaults.sh`, the **marker-file registry** is prose (unaffected).
Add an `src/` layout table (the module table above) to the top of CODEMAP as the
new entry point. Decision **D4**: keep these as hand-maintained `module:line`
refs, *or* add a `make codemap` target that regenerates the index from `grep -n`
across `src/` (zero manual upkeep). Recommend `module:line` now, auto-gen later.
Either way the Change-Checklist item "significant line-range shifts" effectively
retires.

**`dev/SKELETON.md` (linear logic-flow pseudo-code + invariants).** The
execution flow is **byte-identically unchanged** — the build runs top-to-bottom
exactly as before — so SKELETON's *logic* needs no rewrite (no new conditions,
call sequences, or control paths; the Change-Checklist trigger for a SKELETON
edit is "logic-flow changes," and there are none). What it gains is a **1:1
module map**: because the modules are ordered slices of the same linear flow,
SKELETON's existing section order already equals the module order. So:
- Add a short "Source layout" preamble listing the 13 modules in order — SKELETON
  becomes a readable table-of-contents for `src/`.
- Annotate each flow phase with its module, e.g. "Flag parsing
  (`10-flags.sh`)", "User config + constants (`20-config.sh`)", "Main dispatch
  (`90-dispatch.sh`)". A reader following the flow knows which file to open at
  each step.
- Nothing in the pseudo-code bodies changes.

Net: CODEMAP stops drifting (the primary motivation), and SKELETON turns into a
navigational index over `src/` for free, since the module boundaries *are* its
section boundaries.

## Migration (how the initial split is performed safely)

The split is generated *from* the current file, so correctness is mechanical:

1. From a known-good `claude-mux` (tag the commit first), slice by the boundary
   lines: `sed -n '1,112p' > src/00-defaults.sh`, `sed -n '113,694p' >
   src/10-cli-help.sh`, ... covering every line 1..EOF with no gaps or overlaps.
2. `make build` → `claude-mux.built`.
3. `diff claude-mux.built claude-mux` **must be empty** (byte-identical). This is
   the equivalence proof: by construction `cat` of an exact partition reproduces
   the input.
4. Replace `claude-mux` with the built output (no-op if step 3 was clean), commit
   `src/` + Makefile + the (unchanged) `claude-mux` together.

After this, `claude-mux` is only ever regenerated via `make build`.

## Decisions

Resolved after the architecture review (2026-06-17) unless marked open.

- **D1 — granularity.** RESOLVED: the 13-module cut in the table above (the review
  endorsed it as "the right ceiling for now" and liked the numbering gaps
  `00/10/20...` so future inserts don't force a renumber). `50` takes one internal
  split; `75` left whole.
- **D2 — `claude-mux` stays a committed artifact** (curl/brew need the raw file).
  RESOLVED: yes; no install-time build.
- **D3 — build tool.** RESOLVED: a `Makefile` (`make` is conventional and
  ubiquitous on macOS/Linux; concat logic trivial enough to mirror in `build.sh`
  if ever wanted).
- **D4 — CODEMAP strategy.** RESOLVED for now: hand-maintained `module:line` refs;
  `make codemap` auto-gen is a later nicety.
- **D5 — drift guard.** RESOLVED (strengthened by the review): adopt **all** of CI
  `make check` + a **mandatory** pre-commit hook + the doc rule + `.gitattributes`
  + the release gate — not "pick one." See "Drift guard" above; direction (b)
  (direct artifact edits) is why the hook is mandatory.
- **D6 — CI sequencing.** RESOLVED (the review would block otherwise): stand up the
  **minimal CI alongside the split — non-negotiable**. The byte-diff proves the
  split itself, but the split *creates* the src/artifact-drift failure class, and
  you do not introduce a new failure class and defer its guard. Minimal CI =
  `make check` + `bash -n` + shellcheck-on-built-file + a read-only smoke job
  (`--dry-run`, `-l`/`-L --status`, `--guide`/`--commands`/`--config-help`). The
  full ~50-test bats suite is independent and can follow.

## Edge cases / risks

| Case | Handling |
|---|---|
| Boundary line lands mid-function | Banners sit between top-level defs, so cuts never split a function. Verify each boundary line is a blank line or a `# ──` banner before slicing. |
| Trailing newline at EOF / boundaries | Exact partition + `cat` preserves bytes; the empty `diff` in migration step 3 catches any slip. |
| A module accidentally reordered in the Makefile list | `make check` diff fails loudly (output != committed). |
| `src/` edited but not rebuilt before commit | `make check` in CI + the staged-without-rebuild pre-commit hook. |
| `claude-mux` edited directly (old habit) | The sharp case (direction (b)): a fast merge can land it and the next `make build` silently reverts. Caught by the **mandatory pre-commit hook**, not by CI alone; CLAUDE.md rule forbids it. |
| Merge conflict in the generated `claude-mux` | Expected on concurrent branches. Resolve by rebuilding from `src/` (`make build`), never by hand-merging the artifact; `.gitattributes` marks it generated. |
| Release tags a stale artifact | Prevented by the **release gate**: `make check` must pass clean immediately before `git tag`. |
| shellcheck false positives on fragments | Lint the built file only; `# shellcheck shell=bash` headers on fragments for editors. |

## Files to update (Change Checklist)

- **New:** `src/*.sh` (the slices), `Makefile` (build/check/optional codemap),
  a **pre-commit hook** (mandatory drift guard), `.gitattributes`
  (`claude-mux linguist-generated=true` + generated-file handling).
- `claude-mux`: regenerated, byte-identical, recommitted.
- `CLAUDE.md`: invert the "Development Workflow" edit rule (edit `src/`, `make
  build`, never edit `claude-mux` directly); add `make check` to the workflow
  pipeline; **promote a release-gate line** ("`make check` clean before `git
  tag`") into the release checklist, not buried; document the install-the-hook
  step and the "rebuild, don't hand-merge `claude-mux`" conflict rule.
- `dev/CODEMAP.md`: switch to per-module references (or add `make codemap`);
  document the `src/` layout + module table.
- `dev/SKELETON.md`: note the file is now built from `src/`; the logic flow is
  unchanged (same linear order).
- `dev/IMPLEMENTATION-SPEC.md`: add a "Build / source layout" section.
- `CHANGELOG.md`: a `### Changed` (dev-only) note, if released; otherwise a repo
  note. Likely **no GitHub release** (artifact functionally unchanged — decision
  per the release gate).
- `docs/ISSUES.md`: move the Planned-Patches entry to Resolved when done.
- CI config (GitHub Actions) — **non-negotiable, ships with the split (D6):**
  `make check` (build matches committed) + `bash -n` + shellcheck-on-built-file +
  a read-only smoke job (`--dry-run`, `-l`/`-L --status`, `--guide`/`--commands`/
  `--config-help`).
- No README / translations / config.example / injection / tips changes.

## Out of scope

- Any behavior, flag, config, or injection change (this is byte-identical by
  definition).
- Subdividing the large `30/60/90` modules further (follow-up if needed).
- The full bats unit suite (separate Planned-Patches entry; this split only needs
  the byte-diff proof + a CI guard).
- Any move toward Go / a language rewrite (the whole point is to defer that).
