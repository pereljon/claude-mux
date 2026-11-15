# Test plan: `IGNORE_PATH_PREFIXES`

Test plan and review findings for `ignore-path-prefixes.md`. It does not restate the design.

## Method

claude-mux has no unit test suite; `make check` and `make lint` guard the build. Each case below runs the built repo copy (`bash ./claude-mux`) with `HOME` set to a temporary folder. That folder holds its own `.claude-mux/config` and a test project tree under its `BASE_DIR`. The real config and real sessions are never touched. Listing cases use `-L` and `-L --hidden`; migration cases use `--migrate-agents-md` without `--apply`, which only reports.

Test tree under the temporary `BASE_DIR`:

- `alpha/.claude/`: a normal project
- `-dash/.claude/` and `-dash/inner/.claude/`: a dash folder and a project below it
- `_under/.claude/` and `_under/inner/.claude/`: the same for `_`
- `nest/_deep/.claude/`: an underscore folder below a normal folder
- `hid/.claude/` with `hid/.claudemux-ignore`: a hidden project
- `.dot/.claude/`: a dot folder
- `CLAUDE.md` files in `-dash/`, `_under/`, and `alpha/`, for the migration report

## Happy path

1. Setting unset: `-L` lists `alpha` and `_under`, `_under/inner`, `nest/_deep`; it does not list `-dash` or anything below it. Output matches the 2.4.5 build on the same tree.
2. `IGNORE_PATH_PREFIXES="-_"`: `-L` lists only `alpha`. `-L --hidden` lists `hid` and nothing from `-dash`, `_under`, or `nest/_deep`.
3. `IGNORE_PATH_PREFIXES="_"`: `-L` lists `alpha`, `-dash`, and `-dash/inner`, and nothing from `_under` or `nest/_deep`.
4. Migration report with `"-_"`: lists `alpha/CLAUDE.md` only.

## Edge cases

5. `IGNORE_PATH_PREFIXES=""`: `-L` lists every project except `hid` (hidden) and `.dot`.
6. `.dot` is never listed, under any value.
7. Duplicate characters (`"--_"`) behave like `"-_"`.
8. A project whose own folder starts with a listed character, directly under `BASE_DIR` and nested, is skipped (`_under`, `nest/_deep`).

## Validation

9. Each rejected character exits non-zero with the error naming `IGNORE_PATH_PREFIXES` and the allowed set: `*`, `?`, `[`, `\`, `/`, `.`, a space, and a letter.
10. Every allowed character (`- _ ~ @ # + = % ^ ,`) is accepted and skips a folder that starts with it.

## Config, interface, and migration

11. No config migration: existing configs lack the setting and get the default `"-"` (case 1).
12. `--config-help` shows the setting with its default, type, and description; `config.example` has a commented entry.
13. No injection prompt change and no display format change.

## Build checks

14. `make check` and `make lint` pass.

## Results

Run 2026-11-14 on branch `ignore-path-prefixes` with the harness described under Method (macOS, `/bin/bash` 3.2, BSD find).

- Cases 1-8 and 10 pass. Case 1 output is identical to the deployed 2.4.5 build on the same tree.
- Case 9 passes: all nine rejected values (`*`, `?`, `[`, `\`, `/`, `.`, a space, `a`, `-a`) exit 1 with the error.
- Case 4: with `"-_"` the report lists only `alpha/CLAUDE.md`; unset lists `_under` and `alpha`; `""` lists all three.
- Added case: a `BASE_DIR` named `_base` with `"-_"` lists its project. The 2.4.5 build lists zero projects for a `BASE_DIR` named `-base`; the new build lists one.
- Case 12: `--config-help` and `config.example` carry the setting. Case 13: no injection or display change.
- `make smoke` passes. shellcheck reports the same 40 findings as on `main`, none new.
- Not tested: GNU find on Linux. The reviewer checked the predicates against documented GNU semantics only.

## Review findings

Reviewer subagent (Sonnet, medium), 2026-11-14, scope `git diff main -- src/`. No CRITICAL or HIGH findings. It ran the predicates under `/bin/bash` 3.2.57 with BSD find, and checked every caller of the three scans.

- MEDIUM: the setting was not yet documented in `config_help()`, `config.example`, and the reference docs. Resolved: documented in all checklist files.
- LOW: a double blank line in `discover_projects()` (`src/60-discovery.sh`). Resolved: removed.
- Note: an empty `"${IGNORE_NAME_TESTS[@]}"` would fail under `set -u` on bash 3.2. The script does not use `set -u`, so no change.
