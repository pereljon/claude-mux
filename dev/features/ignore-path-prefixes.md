---
kind: feature
lifecycle: shipped
feature: ignore-path-prefixes
status: SHIPPED in v2.5.0 on 2026-11-14
version: 2.5.0
---

# Feature: configurable ignored folder prefixes (`IGNORE_PATH_PREFIXES`)

Design doc and plan of record. Test plan: `ignore-path-prefixes-tests.md`. Investigated against `main` at `574ab04`.

## Problem

claude-mux skips every folder whose name starts with `-`, and every folder below it, when it looks for projects. The `-` is hard-coded. The user wants to choose the characters, for example to also skip folders that start with `_`. A `.claudemux-ignore` marker does not cover this need: it hides one project, while a prefix hides a whole folder tree.

## Current behavior (verified in source)

- `discover_projects()` (`src/60-discovery.sh`) finds projects by their `.claude/` folder. Its `find` prunes `.`-prefixed folders (except `.claude`) and `-`-prefixed folders. A second check skips a project folder whose own name starts with `-`.
- The AGENTS.md migration prunes `-*` in two scans in `src/65-agents-md-migration.sh`: `am_scan()` and `am_verify_walkup()`. Both also prune `.git`, `node_modules`, and `worktrees`.
- `dev/IMPLEMENTATION-SPEC.md` ("Exclusion rules") documents the `-` rule. README and `docs/GUIDE.md` do not mention it.

## Design

1. Add the config setting `IGNORE_PATH_PREFIXES`, default `"-"`, in `src/00-defaults.sh`.
2. The value is a string of single characters. Each character is a folder-name prefix. A folder whose name starts with one of them is skipped, with every folder below it.
3. The setting is the whole list. `"-_"` skips `-` and `_` folders. `"_"` skips only `_` folders, so `-` folders are found again. `""` skips no prefix folders.
4. `.`-prefixed folders stay pruned whatever the setting says. The setting does not need to list `.`.
5. Validate the value at config load in `src/20-config.sh`, next to the other checks. Each character must be one of `- _ ~ @ # + = % ^ ,`. Any other character stops claude-mux with an error that names the setting and the allowed set.
6. Build the prune predicate once from the value, as a bash array of `find` arguments: `\( -name '<c>*' -o ... \)` per character. Pass it to `find` as array elements. Never `eval` it.
7. Apply the predicate in all three scans: `discover_projects()`, `am_scan()`, and `am_verify_walkup()`. `build_ignore_name_tests()` (`src/60-discovery.sh`) builds it, and each scan calls it. The prune makes the old project-name check in `discover_projects()` redundant, so that check is removed.
8. Start all three scans with `-mindepth 1`, so the scan start (`BASE_DIR`) is never pruned by its own name.
9. Document the setting in `config_help()`, `config.example`, `dev/IMPLEMENTATION-SPEC.md` ("Exclusion rules"), `dev/CODEMAP.md` (config vars), `docs/GUIDE.md` (config table), and `CHANGELOG.md`.

## Decisions

- 2026-11-12: the setting is the full list; `-` is not always skipped (user, `firm`). Rejected: keeping `-` mandatory, which would leave one prefix outside the user's control.
- 2026-11-12: name `IGNORE_PATH_PREFIXES` (user, `firm`). Rejected: `IGNORE_PREFIXES`.
- 2026-11-12: default `"-"`, so existing installs see no change. Rejected: adding `_` to the default, which would hide external users' `_`-named projects after an update.
- 2026-11-12: the migration scans follow the same setting. Reason: the migration should touch the same folders that claude-mux manages. Rejected: keeping `-*` hard-coded in the migration, which would migrate files in folders the user chose to ignore.
- 2026-11-14: add `-mindepth 1` to the three scans. Reason: `find` applies `-name` tests to the start folder, so a `BASE_DIR` named `_work` with `"_"` listed would find nothing. The same bug exists for `-` in 2.4.5 (verified: a `BASE_DIR` named `-base` lists zero projects).
- 2026-11-12: a fixed allowed set of characters. Reason: glob characters (`*`, `?`, `[`, `]`, `\`), `/`, `.`, and whitespace would break the `find` predicate or match too much.

## Out of scope

- The informational list of textual `CLAUDE.md` references in the migration report (`grep -r` in `src/65-agents-md-migration.sh`) still searches ignored folders, as it did before.
- Launching with `-d` or `-n` into an ignored folder still works, and the session is not discovered afterwards. This matches today's `-` behavior.
- Hiding single projects stays with the `.claudemux-ignore` marker.

## Version

Minor: a new config setting. It ships in 2.5.0 with the unreleased work on `main`.
