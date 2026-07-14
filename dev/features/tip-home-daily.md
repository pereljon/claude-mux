---
kind: feature
lifecycle: ready
feature: tip-home-daily
status: DESIGNED 2026-06-22 (verified root cause; pre-build). Reported live ("seeing the tip A LOT today").
target_version: 2.0.14 (patch) — a real bug fix
severity: MEDIUM — the daily tip re-shows on every compact/clear/restart, defeating the once-per-day intent
related: tip-ready-handshake.md, notice-delivery-reliability.md
---

# Feature: the daily tip re-shows on every conversation rotation (make it home-only, once per day globally)

## Problem (verified 2026-06-22)

The tip-of-the-day is supposed to appear "once per day per session," but in practice it
re-shows many times a day in a single tmux session. Root cause: the daily gate is keyed
on Claude Code's **`session_id`** (the conversation UUID from the hook's stdin JSON),
stored at `~/.claude-mux/tip-state/<session_id>.json`. That UUID is **not stable** across
the things claude-mux does constantly — `/clear` starts a new conversation (new id),
restart/resume cycles can mint a new id. Each rotation produces a brand-new gate key,
so the throttle finds no stamp and re-emits the tip.

### Evidence

`~/.claude-mux/tip-state/` on 2026-06-22 held **seven distinct `<uuid>.json` files
stamped today**, four of them inside an 18-minute window (00:00, 00:03, 00:16, 00:18) —
matching the home session's compact/clear/restart activity that night, not seven
separate organic once-a-day events:

```
05c6ef4b  07:09   ← current session
ebe44b40  05:31
0701daff  00:18
8ec4da3d  00:16
80a37c51  00:03
17d7f33f  00:00
aedbb832  00:00
```

The stamp is written correctly; the **key rotates**. This is the same class of issue as
`tip-ready-handshake.md` (the gate firing on the wrong turn) — here the gate fires on the
wrong *identity*.

## Decision (2026-06-22)

Drop "per session" entirely. The tip becomes:

1. **Once per day, globally** — a single stamp, not one per conversation.
2. **Home session only** (`#S == "home"`) — tips are orchestration-themed
   ("switch the api-server session to Haiku", "stop all sessions", "list all sessions"),
   home is where that vocabulary applies, and home is always running (LaunchAgent), so it
   is a reliable daily home for the tip. Project sessions stay clean.

Because it is home-only, **session identity is irrelevant**: there is exactly one home
tmux session, so a single global daily stamp suffices and `session_id` drops out of the
tip path completely.

No new config knob (lean over featureful). If a user disables tips, `TIP_OF_DAY=false`
already covers that.

## Design

In `on_prompt` (`src/75-tip-notices.sh`), after the existing `Ready?` handshake no-op:

1. Compute the tmux session name once (reuse the `#S` lookup that
   `detect_claude_upgrade` already performs — lift it so both paths share it, or just do
   the `display-message -p '#S'` read in `on_prompt`).
2. **Gate the tip on `#S == "home"`.** If not home → skip the tip branch entirely
   (notices still run in every session, unchanged).
3. If home → read one **global** stamp `~/.claude-mux/tip-state/tip.json`
   (`{"tip_date": "YYYY-MM-DD"}`). If `tip_date != today` → emit the tip and write
   today's date to that file.

`session_id` is no longer needed for the tip. The stdin parse shrinks to just the
`is_handshake` flag (still required). The per-session `<sid>.json` read/write is removed.

### Sketch

```bash
on_prompt() {
    # Parse stdin once: only the Ready? handshake flag is needed now.
    local _is_handshake
    _is_handshake=$(/usr/bin/python3 -c '
import json,sys
try: obj=json.load(sys.stdin)
except Exception: obj={}
print("1" if (obj.get("prompt","") or "").strip()=="Ready?" else "0")' 2>/dev/null)

    [[ "$_is_handshake" == "1" ]] && exit 0

    # Session name (shared by upgrade detection + the home gate).
    local _sess
    _sess=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null)

    local _bin_notice
    _bin_notice=$(detect_claude_upgrade)   # all sessions, unchanged

    local _out=""

    # ── Daily tip: HOME only, once per day GLOBALLY ──────────────────────────
    if [[ "${TIP_OF_DAY:-true}" == "true" && "$_sess" == "home" ]]; then
        local _state_dir="$CLAUDE_MUX_DIR/tip-state"
        local _tip_file="$_state_dir/tip.json"
        local _today _tip_date
        _today=$(date +%Y-%m-%d)
        _tip_date=$(/usr/bin/python3 -c '
import json,sys,os
try: print(json.load(open(sys.argv[1])).get("tip_date","") or "_")
except Exception: print("_")' "$_tip_file" 2>/dev/null)
        if [[ "$_tip_date" != "$_today" ]]; then
            local _tip; _tip=$(tip_of_day 2>/dev/null || true)
            if [[ -n "$_tip" ]]; then
                _out+="<assistant-must-display>claude-mux tip: $_tip</assistant-must-display>"$'\n'
                mkdir -p "$_state_dir" 2>/dev/null
                /usr/bin/python3 -c 'import json,sys
json.dump({"tip_date": sys.argv[2]}, open(sys.argv[1],"w"))' \
                    "$_tip_file" "$_today" 2>/dev/null || true
            fi
        fi
    fi

    # ── Update notice: ALL sessions, persist-while-relevant (unchanged) ──────
    # ... existing UPDATE_CHECK block, no session_id dependency ...

    [[ -n "$_bin_notice" ]] && _out="${_bin_notice}"$'\n'"${_out}"
    [[ -n "$_out" ]] && printf '%s' "$_out"
    exit 0
}
```

Note the cheap "both features off" guard from today can stay (flush `_bin_notice` and
exit). The update-notice block is unchanged: it never used `session_id` (it is
persist-while-relevant, gated on the cached version vs `VERSION`), so it keeps firing in
every session.

### Orphaned per-session files

The ~40 existing `~/.claude-mux/tip-state/<uuid>.json` files become dead once the key
changes. They are harmless (never read again). **Recommendation: sweep them on the first
home run** — when writing `tip.json`, also `rm -f` the `<uuid>.json` siblings (anything
matching the 8-4-4-4-12 UUID shape, i.e. not `tip.json`). One-time cleanup, no separate
command. Alternative: leave them (harmless clutter). Decide at build; default to sweep.

## Edge cases

| Case | Behavior |
|---|---|
| Home, first real prompt today | Tip fires, stamps `tip.json` = today. |
| Home, later prompts today (same or rotated conversation) | No tip — global stamp already today. **This is the fix.** |
| Home, compact/clear/restart, then a real prompt | No tip — `tip.json` is global, survives conversation rotation. |
| Project (non-home) session | Never shows the tip. Notices still fire. |
| `Ready?` handshake (home or not) | No-op, as today (precedes the home gate). |
| `TIP_OF_DAY=false` | No tip anywhere (unchanged). Update notice still fires if `UPDATE_CHECK=true`. |
| Home not prompted all day | No tip that day. Accepted (it's a tip; home is the always-on session anyway). |
| `tmux display-message` fails (no `$TMUX`) | `_sess` empty → not "home" → no tip. Safe: the hook only runs inside a session anyway. |
| Day rolls over while home stays up | Next real home prompt after midnight re-emits (date differs). Correct. |

## Why low-risk

- Single function (`on_prompt`); no change to handshake senders, restart, launch, or the
  update/upgrade notices.
- Home detection is a literal `#S == "home"` (the name is fixed; `src/35-validate-deps.sh:41`).
- Strictly *reduces* surface: removes the per-session state read/write and `session_id`
  dependency from the tip path.
- Falls back to "no tip" on any failure (empty `_sess`, parse error) — never spams.
- No config, no injection-prompt, no new CLI flag. Tip content/array unchanged.

## Version

Proposed **2.0.14 (patch)** — self-contained bug fix. `claude-mux` changes (the
`on_prompt` body), so it is a release-gated change (the artifact users download). Bump
`VERSION=` in `src/00-defaults.sh`.

## Files to update (Change Checklist)

- `src/75-tip-notices.sh`: rewrite the tip branch of `on_prompt` (home gate + global
  stamp); drop `session_id` parse + per-session `<sid>.json` I/O; optional one-time sweep
  of orphaned `<uuid>.json` files. `make build`.
- `src/00-defaults.sh`: `VERSION=2.0.14`.
- `dev/CODEMAP.md`: update the `on_prompt` purpose row (home-gated, global daily stamp,
  no `session_id`).
- `dev/SKELETON.md`: `on_prompt` logic-flow — handshake no-op → home gate → global stamp.
- `dev/IMPLEMENTATION-SPEC.md`: tip-delivery section — once/day global, home-only;
  `tip.json` replaces `<session_id>.json` for the tip gate.
- `CHANGELOG.md`: Fixed — daily tip re-showed on every compact/clear/restart; now fires
  once per day in the home session only.
- `docs/ISSUES.md`: add + resolve the "tip re-shows per conversation" entry.
- `docs/GUIDE.md`: if it documents tip-of-day gating, update "per session" → "once/day,
  home session".
- No README / translations / config.example / injection / tips-array changes (delivery
  gating, not tip content or a user-facing command).

## Out of scope

- Changing *how* tips surface (still injected for the model to relay).
- A config knob for tip scope (`home|all`) — not adding unless requested.
- The actionable notices (update-available, Claude-upgrade) — unchanged, all-sessions.
- The `Ready?` handshake no-op — already shipped (`tip-ready-handshake.md`), reused here.
