---
feature: status-filter
status: shipped
version: 2.0.2
---

# Feature: `--status STATUS` filter for `-L`

## Problem

When Claude is asked "list idle sessions," it runs `claude-mux -L 2>&1 | grep idle`. The pipe strips the `<assistant-must-display>` tags and header row. Claude receives raw pipe-table lines with no context and reformats them, losing status, numbers, and paths.

## Solution

Add `--status STATUS` flag to `-L` so Claude can filter without piping. Tags survive intact.

```bash
claude-mux -L --status idle
claude-mux -L --status running
claude-mux -L --status stopped
```

Valid values: `idle`, `running`, `protected`, `stopped`, `queued`, `failed`, `hidden`.

---

## Implementation

### 1. `status_claude_sessions()` signature (~line 1813)

Change signature from `([show_all])` to `([show_all] [status_filter])`.

After `sorted_rows` is built (after the sort at ~line 1932), before the print loop:

```bash
local status_filter="${2:-}"
if [[ -n "$status_filter" ]]; then
    sorted_rows=$(echo "$sorted_rows" | awk -F'|' -v s="$status_filter" '$1 == s')
fi
```

Summary line: when `status_filter` is set, replace the counter-based summary with a simple filtered count:

```bash
if [[ -n "$status_filter" ]]; then
    local _fcount
    _fcount=$(printf '%s' "$sorted_rows" | grep -cv '^$')
    echo "${status_filter}: ${_fcount}"
else
    echo "$summary"   # existing counter-based summary unchanged
fi
```

The row-count footer (non-TTY, ~line 1971) already uses `sorted_rows` after filtering, so it naturally reflects the filtered count - no change needed there.

### 2. Dispatch table (`list-all` case)

Currently:
```bash
"list-all") status_claude_sessions true ;;
```

Change to:
```bash
"list-all") status_claude_sessions true "${STATUS_FILTER:-}" ;;
```

### 3. Argument parsing (main arg loop)

Add `--status` alongside `--hidden` / `--include-hidden`. Include validation:

```bash
--status)
    shift
    case "$1" in
        idle|running|protected|stopped|queued|failed|hidden) STATUS_FILTER="$1" ;;
        *) echo "Unknown --status filter: '$1'. Valid: idle running protected stopped queued failed hidden" >&2; exit 1 ;;
    esac
    ;;
```

### 4. Injection trigger rules

Add to the trigger block (near "list all sessions"):

```
- When user says: list idle sessions — run claude-mux -L --status idle
- When user says: list stopped sessions — run claude-mux -L --status stopped
- When user says: list idle/stopped/failed/queued sessions — run claude-mux -L --status <value>
```

---

## Dry Run (observational - no side effects)

1. `claude-mux -L --status idle` - only idle rows, header present, summary says `idle: N`, footer matches N
2. `claude-mux -L --status running` - only running rows
3. `claude-mux -L --status bogus` - error + exit 1
4. `claude-mux -L` (no flag) - existing behavior unchanged
5. Non-TTY: `claude-mux -L --status idle | cat` - `<assistant-must-display>` tags present, row-count footer reflects filtered N

---

## Test Plan

| Test | Expected |
|---|---|
| `-L --status idle` | Only idle rows; header present; summary `idle: N`; footer matches N |
| `-L --status running` | Only running rows; no idle/stopped/protected |
| `-L --status protected` | Only protected rows (home session) |
| `-L --status idle` when 0 idle | Header only (no data rows); summary `idle: 0` |
| `-L --status bogus` | Error: "Unknown --status filter: 'bogus'..."; exit 1 |
| `-L` (no flag) | Existing behavior completely unchanged |
| Non-TTY `-L --status idle` | `<assistant-must-display>` tags wrap filtered output; footer N = filtered count |
| Claude trigger "list idle sessions" | Claude runs `-L --status idle`, not `-L \| grep idle` |

---

## Docs / Checklist

- [ ] `claude-mux` script: `status_claude_sessions` signature + filter logic + dispatch + arg parsing
- [ ] Injection trigger rules (in `build_system_prompt`): add `--status` trigger lines
- [ ] `docs/CLI.md`: add `--status STATUS` to the `-L` entry
- [ ] `dev/CODEMAP.md`: update `status_claude_sessions` signature; add `STATUS_FILTER` var
- [ ] `dev/SKELETON.md`: update `-L` dispatch line
- [ ] `CHANGELOG.md`: patch entry
- [ ] `docs/ISSUES.md`: mark `-L | grep` bug resolved

## Not in scope

- No short flag alias (`-s` is taken by `--send`)
- No `--status` on `-l` (active-only already filtered by definition)
- No multi-value filter (`--status idle,stopped`) - add later if needed
