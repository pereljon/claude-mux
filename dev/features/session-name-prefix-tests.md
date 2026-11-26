# Test plan: session-name-prefix

Companion to `session-name-prefix.md`. It holds the test procedures and the review findings. Run on a throwaway `BASE_DIR` with its own tmux socket and a short path, never on `~/Claude`.

## Tests

1. No marker: names unchanged in `-l`, `-L`, `-d`, `-n`, `-a`.
2. `clients/.claudemux-name-prefix` = `cm-`: `clients/home_network` is `cm-home-network` in `-L --include-hidden`, `-d`, `--start`, `--shutdown`, `--restart`, and after auto-restore.
3. Nested markers: the nearest one applies.
4. `clients/_new-x-123/` with a `.claude/` folder: not listed, not started by `-a`.
5. Simulated `_scripts/new-client`: staging folder, move into place, `-d <folder> --no-attach` starts `cm-<folder>`.
6. `--config-help` and `--guide` show the marker text.
7. `make check` clean; `make codemap` and `make features-index` run.

## Review findings

None yet.
