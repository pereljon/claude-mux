---
kind: feature
lifecycle: designing
feature: session-name-prefix
status: design drafted 2026-11-26; needs architect review before ready
---

# Feature: session name prefix (`.claudemux-name-prefix`)

Design doc and plan of record. Test plan: `session-name-prefix-tests.md`. Investigated against `main` at `d46d279` (v2.5.0).

A marker file in a parent folder adds a prefix to the session name of every project below it. Example: `clients/.claudemux-name-prefix` containing `cm-` turns the project `clients/home_network` into the session `cm-home-network`.

## Problem

A session name is the sanitized basename of its project folder. That name is also the tmux session name, the CLI address, the native agent name, and the Remote Control title.

The user runs about 85 projects. The `client-manager` session (2026-11-26) needs its client sessions to stand out in Remote Control, which shows only the session name. Avoiding name collisions with other projects is a secondary benefit. The user decided against putting the prefix in the folder name.

`client-manager` setup:

- One marker in `~/Claude/projects/client-manager/clients/`, containing `cm-`. One level only.
- `_scripts/new-client` builds each client in a staging folder `clients/_new-<name>-<pid>/`, renames it into place, and runs `claude-mux -d <client folder> --no-attach`. The prefix must apply at that launch.
- `_scripts/new-client` checks `claude-mux -L --include-hidden` for an existing name, so the listing must show the prefixed name.

## Current behavior (verified in source)

- `sanitize_session_name()` (`src/30-helpers.sh:602`) turns every character outside `[a-zA-Z0-9-]` into `-`. So `home_network` becomes `home-network`.
- `session_name_for_dir()` (`src/50-restore-state.sh:272`) returns `home` for `BASE_DIR` and the sanitized basename otherwise.
- Nine other sites compute `sanitize_session_name "$(basename ...)"` inline: `src/35-validate-deps.sh:43,62,119`, `src/40-shutdown.sh:337,360`, `src/50-restore-state.sh:221`, `src/80-templates-restore.sh:177`, `src/70-start-launch.sh:24`.
- `discover_projects()` (`src/60-discovery.sh`) finds projects by their `.claude/` folder.

## Design

1. The session name is `sanitize_session_name(prefix + basename)`. The prefix is used verbatim, so it carries its own separator (`cm-`).
2. The prefix is the first line of the nearest `.claudemux-name-prefix`, trimmed. The lookup walks up from the project's parent and stops at the first marker, never above `BASE_DIR`.
3. `session_name_for_dir()` implements this. The nine inline sites call it.
4. `discover_projects()` skips a project folder whose name starts with `_` when its parent folder holds the marker. This keeps staging folders from ever becoming sessions.
5. Add the marker before the projects below it are running. A session already running keeps its old name, and claude-mux no longer recognizes it by name, so stop it before adding the marker. The `--config-help` text says so.
6. An agent creates the marker by hand. In practice that is the home session, because agents write only inside their own project folder.
7. Docs: the marker paragraph in `--config-help`, one `--guide` line ("give projects under [FOLDER] the name prefix [PREFIX]"), `docs/GUIDE.md`, `dev/IMPLEMENTATION-SPEC.md`, `dev/CODEMAP.md` Marker File Registry, `CHANGELOG.md`, a tip.
8. Injection: no change.

Version: 2.6.0, because name derivation changes. No migration: no folder has a marker yet.

## Out of scope

- Renaming sessions that are running when a marker is added (rule 5 avoids it).
- The existing same-name collision bug, where launching a folder whose name matches another folder's running session misattributes that session. It is recorded in `docs/ISSUES.md`.

## Decisions

- 2026-11-26: a prefix, not a full name override (user, `firm`). Rejected: a full custom name; both.
- 2026-11-26: the marker lives in the parent folder (user, `firm`). Rejected: a mapping in `~/.claude-mux/config`. Reason: markers follow the folder across moves.
- 2026-11-26: nearest marker wins (user, `ok`). Rejected: stacked prefixes; highest marker wins. Reason: a deeper marker can spell out a stacked prefix, stacking cannot emulate nearest, and stacking renames everything below on any edit.
- 2026-11-26: claude-mux skips `_`-prefixed folders directly below a marker folder (user, `firm`). Rejected: `client-manager` naming staging folders `-new-...`; adding `_` to `IGNORE_PATH_PREFIXES`, which is global.
- 2026-11-26: an agent creates the marker by hand, documented in claude-mux help (user, `firm`). Rejected: a claude-mux command, which would take a folder path.
- 2026-11-26: keep the design to the use case; no handling for renaming running sessions (user: "Don't go nuts over edge cases", `firm`).
- 2026-11-26: no injection change (user approved the recommendation, `ok`). Rejected: a trigger line, which costs injection text in every session for a one-time setup step. The injection already tells the agent to consult `--guide` and `--config-help`.
