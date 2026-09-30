# ── AGENTS.md migration ───────────────────────────────────────────────────────
# Module: `claude-mux --migrate-agents-md [--apply] [--no-restart]`.
# Design: dev/features/agents-md-canonical.md (D2-D7). Tests: agents-md-canonical-tests.md.
#
# Claude Code falls back to AGENTS.md only when no CLAUDE.md / CLAUDE.local.md
# exists in cwd or any ancestor, so migration is tree-wide and all-or-nothing:
#   scan BASE_DIR (+ ancestors) -> classify every directory -> report (default,
#   read-only) -> on --apply: preflight, lock, manifest, operations, verify,
#   marker, restart. There is no --undo; the manifest is a recovery log.
#
# Records (parallel arrays, one entry per finding), filled by am_scan/am_enrich:
#   AM_CLASS  class name        AM_DIR   directory      AM_FILE  primary path
#   AM_DEST   AGENTS.md path    AM_LT    symlink target AM_METHOD  operation method
#   AM_SHA    sha256 of content AM_REPO  git repo root  AM_GITJ    git state JSON
#   AM_TRK    tracked-ness text AM_STATUS manifest status
# Bash 3.2 compatible (no associative arrays, no mapfile).

AM_ABORT_CLASSES=" CONFLICT LOCAL ANOMALY EXT-LINK BROKEN-LINK NOT-A-FILE CASE-VARIANT ABOVE UNWRITABLE LOCKED-INDEX DEST-EXISTS "
AM_ACTION_CLASSES=" MIGRATE LINK IDENTICAL INVERSE STUB GEMINI-LINK "
AM_LOCK_HELD=false
AM_MANIFEST=""

# Print $1 as a JSON string literal (quotes included).
am_json_str() {
    local s="$1" out="" i ch code n
    case "$s" in
        *[\\\"]*|*[[:cntrl:]]*) ;;
        *) printf '"%s"' "$s"; return 0 ;;
    esac
    n=${#s}
    for (( i = 0; i < n; i++ )); do
        ch="${s:i:1}"
        case "$ch" in
            '\') out="${out}\\\\" ;;
            '"') out="${out}\\\"" ;;
            $'\n') out="${out}\\n" ;;
            $'\r') out="${out}\\r" ;;
            $'\t') out="${out}\\t" ;;
            [[:cntrl:]])
                code=$(printf '%d' "'$ch")
                out="${out}$(printf '\\u%04x' "$code")" ;;
            *) out="${out}${ch}" ;;
        esac
    done
    printf '"%s"' "$out"
}

# JSON string, or null when empty.
am_json_or_null() {
    if [[ -z "$1" ]]; then printf 'null'; else am_json_str "$1"; fi
}

am_sha256() {
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 < "$1" 2>/dev/null | awk '{print $1}'
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum < "$1" 2>/dev/null | awk '{print $1}'
    fi
}

# "Tracked" = git ls-files --error-unmatch succeeds in DIR's own repo.
am_git_tracked() {
    git -C "$1" ls-files --error-unmatch -- "$2" >/dev/null 2>&1
}

# File kind by exact name: absent | file | dir | other | broken | link | linkdir
am_kind() {
    local p="$1"
    if [[ -L "$p" ]]; then
        if [[ ! -e "$p" ]]; then echo broken
        elif [[ -d "$p" ]]; then echo linkdir
        else echo link; fi
    elif [[ -d "$p" ]]; then echo dir
    elif [[ -f "$p" ]]; then echo file
    elif [[ -e "$p" ]]; then echo other
    else echo absent; fi
}

# JSON git state of DIR/NAME.
am_git_file_json() {
    local d="$1" n="$2" ex=false tr=false ig=false st=false un=false
    [[ -e "$d/$n" || -L "$d/$n" ]] && ex=true
    if git -C "$d" rev-parse --show-toplevel >/dev/null 2>&1; then
        if am_git_tracked "$d" "$n"; then
            tr=true
            git -C "$d" diff --cached --quiet -- "$n" >/dev/null 2>&1 || st=true
            git -C "$d" diff --quiet -- "$n" >/dev/null 2>&1 || un=true
        fi
        git -C "$d" check-ignore -q -- "$n" >/dev/null 2>&1 && ig=true
    fi
    printf '{"exists":%s,"tracked":%s,"ignored":%s,"staged_edits":%s,"unstaged_edits":%s}' "$ex" "$tr" "$ig" "$st" "$un"
}

am_add_record() {   # CLASS DIR FILE [DEST] [LINK_TARGET]
    local i=${#AM_CLASS[@]}
    AM_CLASS[$i]="$1"; AM_DIR[$i]="$2"; AM_FILE[$i]="$3"
    AM_DEST[$i]="${4:-}"; AM_LT[$i]="${5:-}"
    AM_METHOD[$i]=""; AM_SHA[$i]=""; AM_REPO[$i]=""; AM_GITJ[$i]=""
    AM_TRK[$i]=""; AM_STATUS[$i]="pending"
}

am_is_class() {   # CLASS LIST
    [[ "$2" == *" $1 "* ]]
}

# NUL-delimited names of the four interesting files directly inside DIR (case-insensitive).
am_list_names() {
    find "$1" -maxdepth 1 \( -iname 'CLAUDE.md' -o -iname 'CLAUDE.local.md' -o -iname 'AGENTS.md' -o -iname 'GEMINI.md' \) -print0 2>/dev/null
}

# Classify one directory; appends records. Names come from the directory listing
# and are compared exactly (case-insensitive FS: -e on CLAUDE.md is true for claude.md).
am_classify_dir() {
    local d="$1" p nm lower
    local hasC=0 hasCL=0 hasA=0 hasG=0
    local variants=()
    local in_dot_claude=false
    [[ "${d##*/}" == ".claude" ]] && in_dot_claude=true

    while IFS= read -r -d '' p; do
        nm="${p##*/}"
        [[ "$p" == "$AM_EXEMPT_1" || "$p" == "$AM_EXEMPT_2" ]] && continue
        case "$nm" in
            CLAUDE.md) hasC=1 ;;
            CLAUDE.local.md) hasCL=1 ;;
            AGENTS.md) hasA=1 ;;
            GEMINI.md) hasG=1 ;;
            *)
                lower=$(printf '%s' "$nm" | tr 'A-Z' 'a-z')
                case "$lower" in
                    claude.md|claude.local.md|agents.md) variants+=("$p") ;;
                esac ;;
        esac
    done < <(am_list_names "$d")

    local v
    if [[ "$in_dot_claude" == "true" ]]; then
        [[ $hasC -eq 1 ]] && am_add_record ANOMALY "$d" "$d/CLAUDE.md"
        [[ $hasA -eq 1 ]] && am_add_record ANOMALY "$d" "$d/AGENTS.md"
        [[ $hasCL -eq 1 ]] && am_add_record LOCAL "$d" "$d/CLAUDE.local.md"
        for v in "${variants[@]}"; do am_add_record ANOMALY "$d" "$v"; done
        return 0
    fi

    for v in "${variants[@]}"; do am_add_record CASE-VARIANT "$d" "$v"; done
    [[ $hasCL -eq 1 ]] && am_add_record LOCAL "$d" "$d/CLAUDE.local.md"

    local ck=absent ak=absent lt
    [[ $hasC -eq 1 ]] && ck=$(am_kind "$d/CLAUDE.md")
    [[ $hasA -eq 1 ]] && ak=$(am_kind "$d/AGENTS.md")

    # Structural problems: reported, then treated as absent for pairing.
    case "$ck" in
        dir|other) am_add_record NOT-A-FILE "$d" "$d/CLAUDE.md"; ck=absent ;;
        broken) am_add_record BROKEN-LINK "$d" "$d/CLAUDE.md" "" "$(readlink "$d/CLAUDE.md")"; ck=absent ;;
    esac
    case "$ak" in
        dir|other) am_add_record NOT-A-FILE "$d" "$d/AGENTS.md"; ak=absent ;;
        broken) am_add_record BROKEN-LINK "$d" "$d/AGENTS.md" "" "$(readlink "$d/AGENTS.md")"; ak=absent ;;
    esac

    if [[ "$ck" == "link" || "$ck" == "linkdir" ]]; then
        lt=$(readlink "$d/CLAUDE.md")
        if [[ "$lt" == "AGENTS.md" && "$ak" == "file" ]]; then
            am_add_record INVERSE "$d" "$d/CLAUDE.md" "" "$lt"
        else
            am_add_record EXT-LINK "$d" "$d/CLAUDE.md" "" "$lt"
        fi
    fi
    if [[ "$ak" == "link" || "$ak" == "linkdir" ]]; then
        lt=$(readlink "$d/AGENTS.md")
        if [[ "$lt" == "CLAUDE.md" && "$ck" == "file" ]]; then
            am_add_record LINK "$d" "$d/CLAUDE.md" "$d/AGENTS.md" "$lt"
        else
            am_add_record EXT-LINK "$d" "$d/AGENTS.md" "" "$lt"
        fi
    fi
    if [[ "$ck" == "file" && "$ak" == "file" ]]; then
        if [[ "$(tr -d '[:space:]' < "$d/CLAUDE.md" 2>/dev/null)" == "@AGENTS.md" ]]; then
            am_add_record STUB "$d" "$d/CLAUDE.md"
        elif cmp -s "$d/CLAUDE.md" "$d/AGENTS.md"; then
            am_add_record IDENTICAL "$d" "$d/CLAUDE.md" "$d/AGENTS.md"
        else
            am_add_record CONFLICT "$d" "$d/CLAUDE.md" "$d/AGENTS.md"
        fi
    elif [[ "$ck" == "file" && "$ak" == "absent" ]]; then
        am_add_record MIGRATE "$d" "$d/CLAUDE.md" "$d/AGENTS.md"
    elif [[ "$ck" == "absent" && "$ak" == "file" ]]; then
        AM_DONE_COUNT=$(( AM_DONE_COUNT + 1 ))
    fi

    if [[ $hasG -eq 1 && -L "$d/GEMINI.md" ]]; then
        lt=$(readlink "$d/GEMINI.md")
        if [[ "$lt" == "CLAUDE.md" || "$lt" == "AGENTS.md" ]]; then
            am_add_record GEMINI-LINK "$d" "$d/GEMINI.md" "" "$lt"
        fi
    fi
    return 0
}

# Files above BASE_DIR (ancestors up to /) that suppress every AGENTS.md below.
am_scan_above() {
    local d p
    d="$(dirname "$1")"
    [[ "$1" == "/" ]] && return 0
    while :; do
        while IFS= read -r -d '' p; do
            [[ "$p" == "$AM_EXEMPT_1" || "$p" == "$AM_EXEMPT_2" ]] && continue
            am_add_record ABOVE "$d" "$p"
        done < <(find "$d" -maxdepth 1 \( -type f -o -type l \) \( -iname 'CLAUDE.md' -o -iname 'CLAUDE.local.md' \) -print0 2>/dev/null)
        [[ "$d" == "/" || -z "$d" ]] && break
        d="$(dirname "$d")"
    done
}

# The user-level ~/.claude/CLAUDE.md is exempt (literal and physical path). The physical
# form is set only when ~/.claude exists (else it would degrade to "/CLAUDE.md").
am_set_exempt() {
    local _p
    AM_EXEMPT_1="$HOME/.claude/CLAUDE.md"
    AM_EXEMPT_2=""
    if _p="$(cd "$HOME/.claude" 2>/dev/null && pwd -P)"; then AM_EXEMPT_2="$_p/CLAUDE.md"; fi
}

# Scan BASE (physical path). Prunes .git, node_modules, -*, worktrees; does NOT
# prune .claude or other dot-dirs.
am_scan() {
    local base="$1" p d
    AM_CLASS=(); AM_DIR=(); AM_FILE=(); AM_DEST=(); AM_LT=(); AM_METHOD=(); AM_SHA=()
    AM_REPO=(); AM_GITJ=(); AM_TRK=(); AM_STATUS=()
    AM_DONE_COUNT=0
    am_set_exempt

    # Directories arrive in C-locale byte order (sort -zu): a parent is a strict prefix of
    # its children, so it always sorts first. Records are appended in that order, and
    # the apply loop relies on it (top-down, no re-sort).
    local dirs=()
    while IFS= read -r -d '' d; do
        dirs+=("$d")
    done < <(
        find "$base" \( -type d \( -name .git -o -name node_modules -o -name '-*' -o -name worktrees \) -prune \) -o \
            \( -iname 'CLAUDE.md' -o -iname 'CLAUDE.local.md' -o -iname 'AGENTS.md' -o -iname 'GEMINI.md' \) -print0 2>/dev/null \
        | while IFS= read -r -d '' p; do printf '%s\0' "${p%/*}"; done \
        | LC_ALL=C sort -zu
    )
    for d in "${dirs[@]}"; do
        [[ -z "$d" ]] && continue
        am_classify_dir "$d"
    done

    # Actionable directories must be writable (rename/unlink need the directory).
    local i seen=""
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
        d="${AM_DIR[$i]}"
        if [[ ! -w "$d" && "$seen" != *"|$d|"* ]]; then
            seen="${seen}|$d|"
            am_add_record UNWRITABLE "$d" "$d"
        fi
    done
    am_scan_above "$base"
}

# Git handling per actionable record: repo root, tracked-ness, method, sha256, git state JSON.
am_enrich() {
    local i c d f n ct at
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        c="${AM_CLASS[$i]}"; d="${AM_DIR[$i]}"; f="${AM_FILE[$i]}"
        am_is_class "$c" "$AM_ACTION_CLASSES" || continue
        AM_REPO[$i]=$(git -C "$d" rev-parse --show-toplevel 2>/dev/null) || AM_REPO[$i]=""
        n="${f##*/}"
        case "$c" in
            MIGRATE|LINK|IDENTICAL)
                ct=false; at=false
                am_git_tracked "$d" "CLAUDE.md" && ct=true
                am_git_tracked "$d" "AGENTS.md" && at=true
                if [[ $ct == true ]]; then AM_METHOD[$i]="git mv"
                elif [[ $at == true ]]; then AM_METHOD[$i]="mv + git add"
                else AM_METHOD[$i]="mv"; fi
                AM_SHA[$i]=$(am_sha256 "$d/CLAUDE.md")
                AM_GITJ[$i]="{\"CLAUDE.md\":$(am_git_file_json "$d" CLAUDE.md),\"AGENTS.md\":$(am_git_file_json "$d" AGENTS.md)}"
                if [[ $ct == true ]]; then AM_TRK[$i]="tracked"
                elif [[ $at == true ]]; then AM_TRK[$i]="untracked (AGENTS.md tracked)"
                elif [[ -z "${AM_REPO[$i]}" ]]; then AM_TRK[$i]="no repo"
                elif git -C "$d" check-ignore -q -- CLAUDE.md 2>/dev/null; then AM_TRK[$i]="ignored"
                else AM_TRK[$i]="untracked"; fi
                ;;
            INVERSE|STUB|GEMINI-LINK)
                if am_git_tracked "$d" "$n"; then
                    AM_METHOD[$i]="git rm --cached + unlink"; AM_TRK[$i]="tracked"
                else
                    AM_METHOD[$i]="unlink"
                    if [[ -z "${AM_REPO[$i]}" ]]; then AM_TRK[$i]="no repo"; else AM_TRK[$i]="untracked"; fi
                fi
                [[ "$c" == "STUB" ]] && AM_SHA[$i]=$(am_sha256 "$f")
                AM_GITJ[$i]="{\"$n\":$(am_git_file_json "$d" "$n")}"
                ;;
        esac
    done
    am_preflight_extra
}

# Extra preflight findings (abort classes), appended after the action records so a
# likely runtime failure aborts before the first change: a git index lock in any repo
# a git-based operation touches (LOCKED-INDEX, once per lock path), and a MIGRATE
# destination that already exists (DEST-EXISTS).
am_preflight_extra() {
    local i n=${#AM_CLASS[@]} d lk seen=""
    for (( i = 0; i < n; i++ )); do
        am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
        d="${AM_DIR[$i]}"
        if [[ "${AM_CLASS[$i]}" == "MIGRATE" && ( -e "${AM_DEST[$i]}" || -L "${AM_DEST[$i]}" ) ]]; then
            am_add_record DEST-EXISTS "$d" "${AM_DEST[$i]}"
        fi
        [[ "${AM_METHOD[$i]}" == *git* ]] || continue
        lk=$(git -C "$d" rev-parse --git-path index.lock 2>/dev/null) || continue
        [[ -n "$lk" ]] || continue
        [[ "$lk" == /* ]] || lk="$d/$lk"
        lk="$(cd "$(dirname "$lk")" 2>/dev/null && pwd -P)/${lk##*/}"   # normalize (../) for dedup
        if [[ ( -e "$lk" || -L "$lk" ) && "$seen" != *"|$lk|"* ]]; then
            seen="${seen}|$lk|"
            am_add_record LOCKED-INDEX "$d" "$lk"
        fi
    done
}

# Plan signature: class, path, dest, method and content hash of every record. Compared
# between the report scan and the post-lock rescan (TOCTOU guard).
am_signature() {
    local i
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        printf '%s|%s|%s|%s|%s|%s\n' "${AM_CLASS[$i]}" "${AM_FILE[$i]}" "${AM_DEST[$i]}" "${AM_LT[$i]}" "${AM_METHOD[$i]}" "${AM_SHA[$i]}"
    done
}

# Post-condition / pre-restart check: no CLAUDE.md or CLAUDE.local.md under BASE
# (same prune predicate) or in any ancestor. Prints offenders; returns 1 if any.
am_verify_walkup() {
    local base="$1" p rc=0 d
    while IFS= read -r -d '' p; do
        [[ "$p" == "$AM_EXEMPT_1" || "$p" == "$AM_EXEMPT_2" ]] && continue
        echo "$p"; rc=1
    done < <(find "$base" \( -type d \( -name .git -o -name node_modules -o -name '-*' -o -name worktrees \) -prune \) -o \
        \( -iname 'CLAUDE.md' -o -iname 'CLAUDE.local.md' \) -print0 2>/dev/null)
    d="$(dirname "$base")"
    if [[ "$base" != "/" ]]; then
        while :; do
            while IFS= read -r -d '' p; do
                [[ "$p" == "$AM_EXEMPT_1" || "$p" == "$AM_EXEMPT_2" ]] && continue
                echo "$p"; rc=1
            done < <(find "$d" -maxdepth 1 \( -type f -o -type l \) \( -iname 'CLAUDE.md' -o -iname 'CLAUDE.local.md' \) -print0 2>/dev/null)
            [[ "$d" == "/" || -z "$d" ]] && break
            d="$(dirname "$d")"
        done
    fi
    return $rc
}

# Running managed sessions. AM_RUN_IN: name|dir lines whose physical dir is under
# BASE (trailing-slash prefix match); AM_RUN_OUT: names of the rest.
am_running_sessions() {
    local base="$1" s d p
    AM_RUN_IN=""; AM_RUN_OUT=""
    [[ -n "$TMUX_BIN" && -x "$TMUX_BIN" ]] || return 0
    get_managed_session_names
    while IFS= read -r s; do
        [[ -z "$s" ]] && continue
        is_managed_session "$s" || continue
        claude_running_in_session "$s" || continue
        d=$(session_marker_dir "$s")
        [[ -z "$d" ]] && continue
        p=$(cd "$d" 2>/dev/null && pwd -P) || p="$d"
        if [[ "$p" == "$base" || "$p" == "$base"/* ]]; then
            AM_RUN_IN="${AM_RUN_IN}${s}|${d}
"
        else
            AM_RUN_OUT="${AM_RUN_OUT}${s}
"
        fi
    done < <("$TMUX_BIN" list-sessions -F '#{session_name}' 2>/dev/null)
}

# Lock state text: none | live (pid N) | stale (...)
am_lock_state() {
    local lock="$BASE_DIR/.claudemux-migrating" pid
    [[ -d "$lock" ]] || { echo none; return 0; }
    pid=$(cat "$lock/pid" 2>/dev/null)
    if migration_lock_active; then echo "live (pid ${pid:-unknown})"
    else echo "stale (pid ${pid:-none}; will be taken over by --apply)"; fi
}

am_release_lock() {
    if [[ "$AM_LOCK_HELD" == "true" ]]; then
        rm -rf "$BASE_DIR/.claudemux-migrating" 2>/dev/null
        AM_LOCK_HELD=false
    fi
}

# INT/TERM/HUP during apply: record status "interrupted" (when a manifest exists),
# release the lock, exit 130. Completed operations stay in place; there is no rollback.
am_on_signal() {
    if [[ -n "$AM_MANIFEST" && -e "$AM_MANIFEST" ]]; then
        am_write_manifest "interrupted" 2>/dev/null
    fi
    am_release_lock
    trap - EXIT
    exit 130
}

# Take the lock (mkdir mutex; pid first, then started). A stale lock is taken over.
am_take_lock() {
    local lock="$BASE_DIR/.claudemux-migrating"
    ensure_gitignore_entry "$BASE_DIR" ".claudemux-*"
    if [[ -d "$lock" ]]; then
        if migration_lock_active; then
            echo "ERROR: another migration holds $lock (pid $(cat "$lock/pid" 2>/dev/null)); refusing." >&2
            return 1
        fi
        echo "Stale migration lock found ($lock); taking it over."
        log "Taking over stale migration lock $lock"
        rm -rf "$lock"
    fi
    mkdir "$lock" 2>/dev/null || { echo "ERROR: could not take migration lock $lock" >&2; return 1; }
    AM_LOCK_HELD=true
    printf '%s\n' "$$" > "$lock/pid"
    date +%s > "$lock/started"
    trap 'am_release_lock' EXIT
    trap 'am_on_signal' INT TERM HUP
    return 0
}

# Write the manifest atomically (temp file in the same dir, then mv). Args: status.
am_write_manifest() {
    local status="$1" dir tmp i first=true
    dir="$(dirname "$AM_MANIFEST")"
    mkdir -p "$dir" || return 1
    tmp=$(mktemp "$dir/.agents-md-tmp.XXXXXX") || return 1
    {
        printf '{\n'
        printf '  "tool": "claude-mux",\n'
        printf '  "kind": "agents-md-migration",\n'
        printf '  "version": %s,\n' "$(am_json_str "$VERSION")"
        printf '  "started": %s,\n' "$(am_json_str "$AM_STARTED")"
        printf '  "updated": %s,\n' "$(am_json_str "$(date -u +%Y-%m-%dT%H:%M:%SZ)")"
        printf '  "base_dir": %s,\n' "$(am_json_str "$AM_BASE")"
        printf '  "claude_version": %s,\n' "$(am_json_str "$AM_CLAUDE_VER")"
        printf '  "status": %s,\n' "$(am_json_str "$status")"
        printf '  "operations": ['
        for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
            am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
            [[ $first == true ]] && first=false || printf ','
            printf '\n    {"index": %d, "class": %s, "path": %s, "dest": %s, "repo_root": %s, "method": %s, "link_target": %s, "sha256": %s, "git": %s, "status": %s}' \
                "$i" "$(am_json_str "${AM_CLASS[$i]}")" "$(am_json_str "${AM_FILE[$i]}")" \
                "$(am_json_or_null "${AM_DEST[$i]}")" "$(am_json_or_null "${AM_REPO[$i]}")" \
                "$(am_json_str "${AM_METHOD[$i]}")" "$(am_json_or_null "${AM_LT[$i]}")" \
                "$(am_json_or_null "${AM_SHA[$i]}")" "${AM_GITJ[$i]:-null}" "$(am_json_str "${AM_STATUS[$i]}")"
        done
        printf '\n  ]\n}\n'
    } > "$tmp" || { rm -f "$tmp"; return 1; }
    mv -f "$tmp" "$AM_MANIFEST" || { rm -f "$tmp"; return 1; }
}

# Run one operation by its recorded method. Sets AM_OP_ERR on failure.
am_run_op() {
    local i="$1" d f dest out sha mvflag="-f"
    d="${AM_DIR[$i]}"; f="${AM_FILE[$i]}"; dest="${AM_DEST[$i]}"
    AM_OP_ERR=""
    # MIGRATE never replaces: mv -n is the backstop (a silent rc 0 is caught by the
    # post-check below). LINK/IDENTICAL replace by design.
    [[ "${AM_CLASS[$i]}" == "MIGRATE" ]] && mvflag="-n"
    # Revalidate the plan's assumption immediately before the change (TOCTOU).
    case "${AM_CLASS[$i]}" in
        MIGRATE)
            if [[ -e "$dest" || -L "$dest" ]]; then AM_OP_ERR="AGENTS.md appeared since the scan; not overwriting"; return 1; fi ;;
        IDENTICAL)
            if [[ -L "$dest" || -L "$f" ]] || ! cmp -s "$f" "$dest"; then AM_OP_ERR="CLAUDE.md and AGENTS.md no longer identical since the scan"; return 1; fi ;;
        LINK)
            if [[ ! -L "$dest" || "$(readlink "$dest")" != "CLAUDE.md" ]]; then AM_OP_ERR="AGENTS.md is no longer a link to CLAUDE.md since the scan"; return 1; fi ;;
    esac
    case "${AM_METHOD[$i]}" in
        "git mv")
            out=$(git -C "$d" mv -f CLAUDE.md AGENTS.md 2>&1) || { AM_OP_ERR="git mv failed: $out"; return 1; } ;;
        "mv")
            out=$(mv $mvflag "$f" "$dest" 2>&1) || { AM_OP_ERR="mv failed: $out"; return 1; } ;;
        "mv + git add")
            out=$(mv $mvflag "$f" "$dest" 2>&1) || { AM_OP_ERR="mv failed: $out"; return 1; }
            out=$(git -C "$d" add -- AGENTS.md 2>&1) || { AM_OP_ERR="git add failed (file already renamed): $out"; return 1; } ;;
        "git rm --cached + unlink")
            out=$(git -C "$d" rm --cached -f -q -- "${f##*/}" 2>&1) || { AM_OP_ERR="git rm --cached failed: $out"; return 1; }
            out=$(rm -f "$f" 2>&1) || { AM_OP_ERR="unlink failed (removed from index): $out"; return 1; } ;;
        "unlink")
            out=$(rm -f "$f" 2>&1) || { AM_OP_ERR="unlink failed: $out"; return 1; } ;;
        *) AM_OP_ERR="unknown method '${AM_METHOD[$i]}'"; return 1 ;;
    esac
    case "${AM_CLASS[$i]}" in
        MIGRATE|LINK|IDENTICAL)
            if [[ -e "$f" || -L "$f" ]]; then AM_OP_ERR="CLAUDE.md still present after rename"; return 1; fi
            if [[ -L "$dest" || ! -f "$dest" ]]; then AM_OP_ERR="AGENTS.md is not a regular file after rename"; return 1; fi
            sha=$(am_sha256 "$dest")
            if [[ -n "${AM_SHA[$i]}" && "$sha" != "${AM_SHA[$i]}" ]]; then AM_OP_ERR="content hash changed during rename"; return 1; fi ;;
        *)
            if [[ -e "$f" || -L "$f" ]]; then AM_OP_ERR="file still present after removal"; return 1; fi ;;
    esac
    return 0
}

# Print the report. Args: gate_ok version
am_print_report() {
    local gate_ok="$1" ver="$2" i c n_act=0 n_abort=0 s d r
    echo "AGENTS.md migration report"
    echo "  Base dir:     $AM_BASE"
    local vshow="not found or unparseable"
    [[ -n "$ver" ]] && vshow="${ver%%[[:space:]]*}"
    if [[ "$gate_ok" == "true" ]]; then
        echo "  Claude Code:  $vshow (minimum $MIN_AGENTS_MD_VERSION): supported"
    else
        echo "  Claude Code:  $vshow (minimum $MIN_AGENTS_MD_VERSION): NOT supported; fails closed, keep CLAUDE.md"
    fi
    echo "  Lock:         $(am_lock_state)"
    echo
    echo "Findings:"
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        c="${AM_CLASS[$i]}"
        if [[ "$c" == "LINK" ]]; then printf '  %-12s %s' "$c" "${AM_DEST[$i]}"; else printf '  %-12s %s' "$c" "${AM_FILE[$i]}"; fi
        case "$c" in
            LINK|GEMINI-LINK|INVERSE|EXT-LINK|BROKEN-LINK) [[ -n "${AM_LT[$i]}" ]] && printf ' -> %s' "${AM_LT[$i]}" ;;
            CONFLICT) printf ' (differs from AGENTS.md)' ;;
            IDENTICAL) printf ' (same as AGENTS.md)' ;;
            ABOVE) printf ' (outside BASE_DIR; suppresses every AGENTS.md below it)' ;;
            UNWRITABLE) printf ' (directory not writable)' ;;
            LOCKED-INDEX) printf ' (git index lock present: another git process, or a stale lock to remove)' ;;
            DEST-EXISTS) printf ' (AGENTS.md already exists)' ;;
        esac
        [[ -n "${AM_TRK[$i]}" ]] && printf '  [git: %s; %s]' "${AM_TRK[$i]}" "${AM_METHOD[$i]}"
        printf '\n'
        if am_is_class "$c" "$AM_ACTION_CLASSES"; then n_act=$((n_act + 1)); fi
        if am_is_class "$c" "$AM_ABORT_CLASSES"; then n_abort=$((n_abort + 1)); fi
    done
    [[ ${#AM_CLASS[@]} -eq 0 ]] && echo "  (nothing found needing action)"
    echo "  DONE (AGENTS.md only): $AM_DONE_COUNT director$([[ $AM_DONE_COUNT -eq 1 ]] && echo y || echo ies)"
    echo

    echo "Running managed sessions under BASE_DIR (restarted by --apply unless --no-restart):"
    if [[ -z "$AM_RUN_IN" ]]; then echo "  none"; else
        while IFS='|' read -r s d; do [[ -n "$s" ]] && echo "  $s  ($d)"; done <<< "$AM_RUN_IN"
        echo "  Note: restart interrupts mid-turn sessions and force-restarts protected ones."
        echo "  (busy/idle state is not determined)"
    fi
    if [[ -n "$AM_RUN_OUT" ]]; then
        echo "Running managed sessions outside BASE_DIR (not touched):"
        while IFS= read -r s; do [[ -n "$s" ]] && echo "  $s"; done <<< "$AM_RUN_OUT"
    fi
    echo "Claude Code sessions outside claude-mux cannot be restarted by this command."
    echo

    if [[ $n_act -gt 0 ]]; then
        echo "Textual references to CLAUDE.md in the tree (listed, never edited; they break silently after the rename):"
        local refs cnt=0
        refs=$(grep -rIl -i -e 'CLAUDE\.md' --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=worktrees "$AM_BASE" 2>/dev/null | LC_ALL=C sort)
        if [[ -z "$refs" ]]; then echo "  none"; else
            while IFS= read -r r; do
                cnt=$((cnt + 1))
                (( cnt <= 40 )) && echo "  $r"
            done <<< "$refs"
            (( cnt > 40 )) && echo "  ... and $((cnt - 40)) more"
        fi
        echo
    fi

    if [[ "$gate_ok" != "true" ]]; then
        echo "Result: BLOCKED (Claude Code version gate). Nothing will change."
    elif [[ $n_abort -gt 0 ]]; then
        echo "Result: BLOCKED by $n_abort path(s) above in an abort class (CONFLICT, LOCAL, ANOMALY, EXT-LINK, BROKEN-LINK, NOT-A-FILE, CASE-VARIANT, ABOVE, UNWRITABLE, LOCKED-INDEX, DEST-EXISTS)."
        echo "        Resolve them by hand; --apply refuses until none remain. Nothing will change."
        for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
            if [[ "${AM_CLASS[$i]}" == "ABOVE" ]]; then
                echo "        A CLAUDE.md above BASE_DIR cannot be migrated: remove or merge it; claude-mux keeps CLAUDE.md canonical for this tree until then."
                break
            fi
        done
    elif [[ $n_act -eq 0 ]]; then
        echo "Result: nothing to do."
    else
        echo "Result: READY. $n_act operation(s) planned. Run 'claude-mux --migrate-agents-md --apply' to migrate (repos get uncommitted changes; nothing is committed)."
    fi
    AM_N_ACT=$n_act; AM_N_ABORT=$n_abort
}

# Failure block (failed op or failed verify). Args: done count, offenders text (verify only).
# Removes a stale migrated marker. No rollback: recovery is manual, from the manifest.
am_failure_block() {
    local done_n="$1" offenders="$2" i
    rm -f "$BASE_DIR/.claudemux-agents-migrated"
    echo
    echo "================================================================"
    echo "TREE IS MIXED: CLAUDE.md is being loaded in some walk-up paths so AGENTS.md is ignored there."
    echo "Sessions under the paths still holding CLAUDE.md silently miss the AGENTS.md instructions."
    echo "================================================================"
    echo "Completed ($done_n):"
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
        [[ "${AM_STATUS[$i]}" == "done" ]] && echo "  ${AM_CLASS[$i]} ${AM_FILE[$i]}"
    done
    echo "Pending or failed:"
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
        [[ "${AM_STATUS[$i]}" == "done" ]] || echo "  ${AM_CLASS[$i]} ${AM_FILE[$i]}"
    done
    if [[ -n "$offenders" ]]; then
        echo "Still present after verify:"
        echo "$offenders" | sed 's/^/  /'
    fi
    echo "Manifest: $AM_MANIFEST"
    echo "The migrated marker was removed. Fix the cause, then re-run --migrate-agents-md --apply"
    echo "(completed paths report DONE, the rest report their class), or reverse the recorded"
    echo "operations by hand. There is no automatic rollback."
}

migrate_agents_md() {
    local base_p ver gate_ok=false apply=false i s d
    base_p=$(cd "$BASE_DIR" 2>/dev/null && pwd -P) || { echo "ERROR: BASE_DIR '$BASE_DIR' not found" >&2; return 1; }
    AM_BASE="$base_p"
    ver=$(claude_version_line)
    AM_CLAUDE_VER="$ver"
    agents_md_supported && gate_ok=true
    [[ "$MIGRATE_APPLY" == "true" && "$DRY_RUN" != "true" ]] && apply=true

    am_scan "$base_p"
    am_enrich
    AM_PLAN_SIG="$(am_signature)"
    am_running_sessions "$base_p"

    echo_hint
    am_print_report "$gate_ok" "$ver"
    if [[ "$MIGRATE_APPLY" != "true" ]]; then
        echo_hint_end
        return 0
    fi
    if [[ "$DRY_RUN" == "true" ]]; then
        echo
        echo "Dry run (--dry-run): planned operations, nothing executed:"
        for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
            am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
            echo "  would ${AM_METHOD[$i]}: ${AM_FILE[$i]}"
        done
        echo_hint_end
        if [[ "$MIGRATE_NO_RESTART" != "true" && -n "$AM_RUN_IN" ]]; then
            restart_sessions_in "$AM_RUN_IN" "to load AGENTS.md instructions"
        fi
        return 0
    fi

    # Preflight (D4): abort with nothing changed.
    if [[ "$gate_ok" != "true" ]]; then
        echo; echo "ABORTED: Claude Code version gate failed. Nothing changed."
        echo_hint_end; return 1
    fi
    if [[ $AM_N_ABORT -gt 0 ]]; then
        echo; echo "ABORTED: $AM_N_ABORT blocking path(s) listed above. Nothing changed."
        echo_hint_end; return 1
    fi
    if [[ -d "$BASE_DIR/.claudemux-migrating" ]] && migration_lock_active; then
        echo; echo "ABORTED: another migration is running (lock $BASE_DIR/.claudemux-migrating). Nothing changed."
        echo_hint_end; return 1
    fi
    if [[ $AM_N_ACT -eq 0 ]]; then
        # Nothing to change and no abort class: the tree is already migrated (for example
        # renamed by hand). Record that so the home session stops suggesting a migration.
        if [[ -z "$(am_verify_walkup "$base_p")" ]]; then
            ensure_gitignore_entry "$BASE_DIR" ".claudemux-*"
            printf 'date: %s\nfiles: 0\nmanifest: none (already migrated)\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                > "$BASE_DIR/.claudemux-agents-migrated"
            echo "  Nothing to migrate: no CLAUDE.md or CLAUDE.local.md in any walk-up path. Marker written."
        fi
        echo_hint_end; return 0
    fi

    # (a) lock
    if ! am_take_lock; then echo_hint_end; return 1; fi

    # (a2) TOCTOU guard: the report steps (grep, tmux) were slow; rescan now, under the
    # lock, and refuse to proceed if anything differs from the plan the user saw.
    am_scan "$base_p"
    am_enrich
    if [[ "$(am_signature)" != "$AM_PLAN_SIG" ]]; then
        echo; echo "ABORTED: the tree changed between the scan and the lock. Nothing changed. Re-run to see the current plan."
        am_release_lock; echo_hint_end; return 1
    fi

    # (b) manifest, before any change
    AM_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    AM_MANIFEST="$CLAUDE_MUX_DIR/migrations/agents-md-$(date +%Y%m%dT%H%M%S).json"
    [[ -e "$AM_MANIFEST" ]] && AM_MANIFEST="${AM_MANIFEST%.json}-$$.json"
    if ! am_write_manifest "in-progress"; then
        echo; echo "ABORTED: could not write manifest $AM_MANIFEST. Nothing changed."
        am_release_lock; echo_hint_end; return 1
    fi

    # (c) operations, top-down (records are in parent-first directory order, see am_scan)
    local done_n=0 failed=false
    echo
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
        if am_run_op "$i"; then
            AM_STATUS[$i]="done"; done_n=$((done_n + 1))
            am_write_manifest "in-progress" || { echo "WARN: could not update manifest $AM_MANIFEST" >&2; }
        else
            AM_STATUS[$i]="failed: $AM_OP_ERR"
            am_write_manifest "failed"
            echo "FAILED: ${AM_CLASS[$i]} ${AM_FILE[$i]} (${AM_METHOD[$i]}): $AM_OP_ERR"
            failed=true
            break
        fi
    done
    if [[ $failed == true ]]; then
        am_failure_block "$done_n" ""
        am_release_lock; echo_hint_end; return 1
    fi

    # (d) verify by rescanning
    local offenders
    offenders=$(am_verify_walkup "$base_p")
    if [[ -n "$offenders" ]]; then
        am_write_manifest "failed: verify"
        echo "VERIFY FAILED: CLAUDE.md / CLAUDE.local.md still present in a walk-up path:"
        echo "$offenders" | sed 's/^/  /'
        am_failure_block "$done_n" "$offenders"
        am_release_lock; echo_hint_end; return 1
    fi
    am_write_manifest "complete"

    # (e) release lock, then marker
    am_release_lock
    trap - EXIT INT TERM HUP
    ensure_gitignore_entry "$BASE_DIR" ".claudemux-*"
    printf 'date: %s\nfiles: %d\nmanifest: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$done_n" "$AM_MANIFEST" \
        > "$BASE_DIR/.claudemux-agents-migrated"

    # Full summary FIRST (the caller's pane may be restarted afterwards).
    echo "Migration complete: $done_n operation(s) applied, verified (no CLAUDE.md / CLAUDE.local.md in any walk-up path)."
    echo "  Manifest: $AM_MANIFEST"
    echo "  Marker:   $BASE_DIR/.claudemux-agents-migrated"
    echo "  Git changes are uncommitted (nothing was committed). Repos touched:"
    for (( i = 0; i < ${#AM_CLASS[@]}; i++ )); do
        am_is_class "${AM_CLASS[$i]}" "$AM_ACTION_CLASSES" || continue
        echo "${AM_REPO[$i]}"
    done | LC_ALL=C sort -u | sed '/^$/d; s/^/    /'
    echo "  Textual references to CLAUDE.md listed above were not edited."

    # (f) restart
    am_running_sessions "$base_p"
    if [[ "$MIGRATE_NO_RESTART" == "true" ]]; then
        if [[ -n "$AM_RUN_IN" ]]; then
            echo "  --no-restart: these running sessions still hold the old instructions; restart them:"
            while IFS='|' read -r s d; do [[ -n "$s" ]] && echo "    $s"; done <<< "$AM_RUN_IN"
        fi
        echo_hint_end
        return 0
    fi
    if [[ -z "$AM_RUN_IN" ]]; then
        echo "  No running managed sessions under BASE_DIR to restart."
        echo_hint_end
        return 0
    fi
    offenders=$(am_verify_walkup "$base_p")
    if [[ -n "$offenders" ]]; then
        echo "  NOT restarting: a CLAUDE.md reappeared after verify (a live session may have run /init):"
        echo "$offenders" | sed 's/^/    /'
        echo_hint_end
        return 1
    fi
    echo "  Restarting running sessions under BASE_DIR:"
    while IFS='|' read -r s d; do [[ -n "$s" ]] && echo "    $s"; done <<< "$AM_RUN_IN"
    echo_hint_end
    if ! restart_sessions_in "$AM_RUN_IN" "to load AGENTS.md instructions"; then
        echo "Sessions that failed to return (the rename is not rolled back):"
        while IFS= read -r s; do [[ -n "$s" ]] && echo "  $s"; done <<< "$RESTART_FAILED_SESSIONS"
        return 1
    fi
    return 0
}

# Drift scan (design D7). Called from on_prompt. Home session only, at most once per
# day (stamp $1/agents-drift), and only when the migrated marker exists. Prints a
# <assistant-must-display> notice naming any CLAUDE.md / CLAUDE.local.md that reappeared
# in a walk-up path (a live /init, or a merge/checkout of an older branch). Silent
# otherwise. Cheap by construction: marker test, then date stamp, then the tmux home
# check, then one pruned find (same predicate as the scan). Always returns 0.
# Args: $1 = state dir (holds the stamp).
agents_md_drift_notice() {
    local state_dir="$1" stamp today sess base off n
    [[ -f "$BASE_DIR/.claudemux-agents-migrated" ]] || return 0
    stamp="$state_dir/agents-drift"
    today=$(date +%Y-%m-%d)
    [[ "$(cat "$stamp" 2>/dev/null)" == "$today" ]] && return 0
    sess=$("$TMUX_BIN" display-message -p '#S' 2>/dev/null)
    [[ "$sess" == "home" ]] || return 0
    mkdir -p "$state_dir" 2>/dev/null
    printf '%s\n' "$today" > "$stamp" 2>/dev/null || true
    base=$(cd "$BASE_DIR" 2>/dev/null && pwd -P) || return 0
    am_set_exempt
    off=$(am_verify_walkup "$base")
    [[ -z "$off" ]] && return 0
    n=$(printf '%s\n' "$off" | grep -c .)
    printf '<assistant-must-display>claude-mux: %d CLAUDE.md / CLAUDE.local.md file(s) reappeared after the AGENTS.md migration, so Claude Code ignores AGENTS.md under them: %s. Say "migrate to AGENTS.md" to re-check and fix.</assistant-must-display>\n' \
        "$n" "$(printf '%s\n' "$off" | head -5 | paste -sd ';' - | sed 's/;/; /g')"
    return 0
}
