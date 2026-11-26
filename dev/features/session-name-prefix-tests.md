# Test plan: session-name-prefix

Companion to `session-name-prefix.md`. It holds the test procedures and the review findings. Run on a throwaway `BASE_DIR` with its own tmux socket and a short path, never on `~/Claude`.

## Tests

1. No marker: names unchanged in `-l`, `-L`, `-d`, `-n`, `-a`.
2. `clients/.claudemux-name-prefix` = `cm-`: `clients/home_network` is `cm-home-network` in `-L --include-hidden`, `-d`, `--start`, `--shutdown`, `--restart`, and after auto-restore.
3. Nested markers: the nearest one applies.
4. `clients/_new-x-123/` with a `.claude/` folder: not listed, not started by `-a`.
5. Simulated `_scripts/new-client`: staging folder, move into place, `-d <folder> --no-attach` starts `cm-<folder>`.
6. A hidden project below the marker shows its prefixed name in `-L --include-hidden`.
7. `-n -p` on a folder that does not exist yet, below the marker: the session gets the prefix.
8. `BASE_DIR` reached through a symlink (`/tmp` versus `/private/tmp`): the prefix applies; a marker above `BASE_DIR` is ignored.
9. `-d` on a folder outside `BASE_DIR`: no prefix, and the command returns.
10. `--config-help` and `--guide` show the marker text.
11. `make check` clean; `make codemap` and `make features-index` run.

## Review findings

Architect review, 2026-11-26 (Sonnet, high effort):
1. `session_name_for_dir()` is defined after the load-time `-d`/`-n` sites: fixed in design rule 4 (move it to `src/30-helpers.sh`). Trigger `-d`/`-n`; breaks the use case.
2. The walk needs physical paths and a stop outside `BASE_DIR`: fixed in design rule 3; tests 8 and 9 added. Trigger `-d` outside `BASE_DIR` or a symlinked path; breaks rule 2.
3. The site count was nine, actually eight: fixed. The `-a` "Sanitized session name" log noise and the weaker empty-name check: dropped, no requirement; rule 4 keeps the existing empty checks.
4. The `_` skip rule is correct and placed right: no change.
5. An empty marker gives an empty prefix: dropped, no trigger in the use case.
6. Remove the tip: dropped, because the project `AGENTS.md` Change Checklist requires a tip for a user-facing feature. Tests for a hidden project, `-n`, a symlinked `BASE_DIR` and an outside folder: added as tests 6-9.
