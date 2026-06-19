---
feature: launched-version-detection
status: PLANNED
target_version: 2.x (minor; notify-only behavior)
severity: LOW (a running session silently keeps stale injection/wrapper after an
  out-of-band claude-mux upgrade until manually restarted; this only nudges)
related: claude-code-upgrade-detection (the precedent), src-module-split
---

# Feature: detect a session running a stale claude-mux (launched-version nudge)

## Goal

When the claude-mux script on disk is upgraded but a running session was launched
by an **older** version, that session keeps running the older injection prompt and
launch wrapper (baked in at creation) until it is restarted. Detect this and inject
a one-shot "this session was started by an older claude-mux; restart it to pick up
the new version" notice into the conversation - mirroring the existing Claude Code
upgrade nudge.

Notify-only. No auto-restart (restarting drops Remote Control and interrupts the
user; the decision stays theirs).

## Research finding that set the mechanism (verified 2026-06-17)

The idea began as "stamp the launching version into the marker file"
(`.claudemux-running-2.0.7`). Verifying the assumptions against the code reversed
the recommendation:

1. **`--update` already restarts.** `do_update` (`src/30-helpers.sh`) ends with
   `exec "$install_path" --restart`, so the in-tool upgrade path re-launches every
   session and re-bakes injection. The stale-injection window therefore exists
   **only for out-of-band upgrades**: `brew upgrade claude-mux`, a manual file
   replace, or editing the script without restarting. (CLAUDE.md "Script, not
   binary" documents exactly this window.)
2. **A relaunch re-bakes injection automatically.** Both launch wrappers regenerate
   the system prompt on every in-place relaunch via
   `--print-system-prompt ... > "$_prompt.new"` (`src/55-session-launch.sh:192`,
   `src/70-start-launch.sh:199`), and the auto-restore tick relaunches dead sessions
   through `launch_single_session`, which calls `build_system_prompt` fresh. So a
   **dead → restored** session always comes back on the *current* injection.

Consequence: the only session that ever runs stale injection is a **live** one.
A dead session's launching version is irrelevant (restore re-bakes). That removes
the one advantage the marker-filename had over a tmux option ("it survives the
process"), because surviving the process is not needed here. → use a tmux user
option, exactly like `@claude-mux-claude-id`.

## Design (recommended): a `@claude-mux-launched-version` tmux option

Direct mirror of the Claude Code upgrade detector (`detect_claude_upgrade`,
`src/75-tip-notices.sh:81`), which already stores the launch-time `claude` binary
id in `@claude-mux-claude-id` and compares it each prompt.

**1. Stamp at launch.** Wherever the session options are set
(`@claude-mux-dir` / `@claude-mux-claude-id`), also set
`@claude-mux-launched-version` to the launching script's `$VERSION`. Both the
fresh-launch and the live-session backfill branches set it:
- `src/55-session-launch.sh:73-74` (backfill) and `:92-93` (fresh)
- `src/70-start-launch.sh:95-96` (backfill) and `:234-235` (fresh)

**2. Detect on each prompt.** Add `detect_claudemux_upgrade()` next to
`detect_claude_upgrade()`, called from `on_prompt` in the same place (after the
`Ready?` handshake no-op, before the cheap tip/update guard so it is always-on):

```sh
detect_claudemux_upgrade() {
    local _sess _v0
    _sess=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null) || return 0
    [[ -z "$_sess" ]] && return 0
    _v0=$("$TMUX_BIN" show-options -t "$_sess" -v @claude-mux-launched-version 2>/dev/null)
    [[ -z "$_v0" ]] && return 0                 # pre-feature session: silent no-op
    if version_gt "$VERSION" "$_v0"; then        # on-disk script is newer than the launcher
        echo "[claude-mux — tell the user, in their conversation language]: this session was started by claude-mux $_v0 but $VERSION is now installed; say \"restart this session\" to load the new version."
        "$TMUX_BIN" set-option -t "$_sess" @claude-mux-launched-version "$VERSION" 2>/dev/null
    fi
}
```

- `version_gt` already exists (`src/30-helpers.sh:22`); use the existing comparator.
- One-shot per change: ack by overwriting the option to `$VERSION`, same as the
  Claude Code detector. The user is nudged once per upgrade; if they ignore it, the
  session keeps running stale (their choice) and is not nagged every prompt.
- Always-on, independent of `TIP_OF_DAY` / `UPDATE_CHECK` (it is correctness, not a
  tip). Wire it exactly like `_bin_notice`: compute after the handshake check, and
  prepend to `_out` so it surfaces even when tips/updates are off.

**3. on_prompt wiring.** Compute alongside `_bin_notice`
(`src/75-tip-notices.sh:141`), and include it in every flush path (both-off guard
at :146, no-sid path at :154, and the final prepend at :227). Cleanest: fold both
notices into one "always-on notices" string so the three flush sites stay in sync.

## Considered alternative (rejected): version in the marker filename

`.claudemux-running-<version>` instead of the bare `.claudemux-running`. Rejected:

- **Migration cost across every marker reader.** Today readers use a fixed-name
  existence test: `should_be_alive` (`src/50:169`), `autorestore_status`
  (`src/50:182`), and the wrapper teardown `rm -f "$_marker"` (`src/55`/`src/70`).
  All would have to become globs (`compgen -G "$dir/.claudemux-running-*"`), and the
  writer would need a "remove any existing `.claudemux-running-*` then touch the new
  name" step to preserve the single-marker invariant. More surface, more sharp edges.
- **The benefit isn't load-bearing.** The only thing the filename buys over a tmux
  option is a launching-version that outlives the process - and per the research
  finding above, a dead session's launching version is irrelevant (restore re-bakes
  injection). So the cost buys nothing the live-session use case needs.
- **Mixes semantics.** The marker is a pure presence flag whose meaning is its
  location (folder = which session). Encoding data in its name erodes that and the
  marker-file philosophy in CLAUDE.md ("boolean flags: empty `touch`-ed file").

If a *post-death* launching version is ever genuinely needed (e.g. crash diagnostics
"it died under 2.0.7"), the right home is the per-session restore-state JSON
(`$RESTORE_STATE_DIR/<name>.json`), which already carries structured runtime state -
not the marker filename.

## Edge cases / risks

| Case | Handling |
|---|---|
| Session launched before this feature (no option set) | `show-options -v` returns empty → silent no-op (same as `detect_claude_upgrade` for a pre-feature session). |
| `Ready?` handshake turn | The handshake no-op (`on_prompt` exits at `_is_handshake == 1`, `src/75:136`) runs first, so the nudge never fires on a handshake and never burns its one-shot ack. MUST stay ordered after that check. |
| In-tool `--update` | Auto-restarts (`exec ... --restart`), which re-stamps the option to the new `$VERSION` at relaunch → notice never fires for the in-tool path. Correct: there is nothing stale to nudge. |
| Downgrade (on-disk older than launcher) | `version_gt "$VERSION" "$_v0"` is false → no notice. Intended. |
| Not in tmux / option unset | `display-message`/`show-options` fail → `return 0`, no output. |
| Home session | Gets the option like any session; restart nudge applies (home is restartable). No marker is involved, so no special-casing needed. |

## Files to update (Change Checklist)

- **`make build`**: edits are in `src/55-session-launch.sh`, `src/70-start-launch.sh`
  (stamp), `src/75-tip-notices.sh` (detector + `on_prompt` wiring). Rebuild + `make check`.
- `src/00-defaults.sh`: none (no new config var; always-on).
- `dev/CODEMAP.md`: add `detect_claudemux_upgrade` to the function index; note the
  new `@claude-mux-launched-version` tmux option in the marker/option registry.
- `dev/SKELETON.md`: add the detector to the `on_prompt` always-on-notice flow (it
  is a new branch in an existing function - a logic-flow change).
- `dev/IMPLEMENTATION-SPEC.md`: document `@claude-mux-launched-version` alongside
  `@claude-mux-claude-id` in the session-runtime-state / non-obvious-behaviors area.
- `CLAUDE.md`: extend the "Claude Code upgrade detection" non-obvious-behavior note
  with the parallel claude-mux launched-version nudge (same shape, compares `$VERSION`).
- `README.md` + translations: the Session System Prompt / behaviors section if the
  upgrade nudges are described there; otherwise no user-doc change (it is an
  injected notice, not a command).
- `CHANGELOG.md`: `### Added` under the release that ships it.
- `docs/ISSUES.md`: move/close the corresponding entry.
- `internal/tips.md` + `tip_of_day` array: no - this is not a conversational trigger
  to teach; the nudge teaches itself in-context.
- `VERSION=` (`src/00-defaults.sh`): minor bump.

## Out of scope

- Auto-restart on detection (notify-only by design).
- Changing the `.claudemux-running` marker in any way (it stays a bare presence flag).
- A `-l`/`-L` column showing each session's launched version (possible follow-up;
  the option makes it cheap, but it is display polish, not the nudge).
- Detecting wrapper/injection changes specifically (we use the coarse `$VERSION`;
  a version bump is the proxy for "something a restart would pick up," which is the
  same proxy the Claude Code detector uses with the binary id).
