#!/bin/bash
# claude-mux - Claude Code Multiplexer
# Persistent Claude Code sessions for all your projects.

VERSION="2.0.14"

# ── Defaults ──────────────────────────────────────────────────────────────────
# Override any of these in ~/.claude-mux/config

# Root directory to scan for Claude projects (directories containing .claude/).
BASE_DIR="$HOME/Claude"

# Directory for log files.
LOG_DIR="$HOME/Library/Logs"

# When set to a valid mode, create/update .claude/settings.local.json
# to set permissions.defaultMode for the project.
# Valid values: "" (disabled), "default", "acceptEdits", "plan", "auto", "dontAsk", "bypassPermissions"
DEFAULT_PERMISSION_MODE="auto"

# When true, each Claude session is told it can send slash commands to OTHER
# sessions via tmux send-keys. When false (default), sessions can only send
# commands to themselves — safer, prevents one session affecting others.
ALLOW_CROSS_SESSION_CONTROL=false

# ── tmux session options ──────────────────────────────────────────────────────

# Enable tmux extended-keys for Shift+Enter and other modified keys.
TMUX_EXTENDED_KEYS=true

# Set the terminal/tab title to the session name. Uses tmux format variables.
# '#S' = session name. Set to "" to disable.
TMUX_TITLE_FORMAT='#S'

# Enable mouse support (scroll, select, resize panes).
TMUX_MOUSE=true

# Scrollback buffer size (lines). Default tmux is 2000 which fills fast.
TMUX_HISTORY_LIMIT=50000

# Enable system clipboard integration (OSC 52).
TMUX_CLIPBOARD=true

# Set terminal type for proper color rendering.
TMUX_DEFAULT_TERMINAL="tmux-256color"

# Reduce escape key delay (milliseconds). Default tmux is 500ms.
TMUX_ESCAPE_TIME=10

# Monitor for activity in other sessions.
TMUX_MONITOR_ACTIVITY=true

# ── Templates ─────────────────────────────────────────────────────────────────

# Directory containing CLAUDE.md template files.
TEMPLATES_DIR="$HOME/.claude-mux/templates"

# Default template applied to new projects (-n). Set to "" to disable.
# "none" is reserved and cannot be used as a template name.
DEFAULT_TEMPLATE="default.md"

# ── LaunchAgent ───────────────────────────────────────────────────────────────

# LaunchAgent mode — what happens at login:
#   none  — do nothing
#   home  — launch a single 'home' session in $BASE_DIR (protected from shutdown)
LAUNCHAGENT_MODE=home

# Model for the home session. Set to "" to use the default model.
HOME_SESSION_MODEL="sonnet"

# Legacy: LAUNCHAGENT_ENABLED=true is treated as LAUNCHAGENT_MODE=home (was
# LAUNCHAGENT_MODE=batch before batch was removed).
LAUNCHAGENT_ENABLED=false

# ── Auto-restore (self-healing) ─────────────────────────────────────────────────
# When true, the LaunchAgent tick restores sessions that should be alive (those
# with a .claudemux-running marker) but whose Claude process has died, after a
# reboot or a mid-day crash. Markers are always written/removed; this flag only
# gates whether the tick acts on them. Set false to disable self-healing.
# A clean in-pane /exit (or --shutdown) removes the marker so the session stays
# down; a crash or kill leaves it, so the tick brings the session back.
AUTORESTORE=true

# Max sessions the restore tick launches per STARTING_WINDOW (thundering-herd cap
# after a reboot). Local cost per idle session is small (~80-110 MB); this is
# mainly insurance against API rate/burst limits. Tune from real reboot experience.
STAGGER_CONCURRENCY=3

# Window (seconds) over which STAGGER_CONCURRENCY is counted, via each session's
# last restore-attempt timestamp in ~/.claude-mux/restore-state/.
STARTING_WINDOW=90

# ── Update check ──────────────────────────────────────────────────────────────
# Check GitHub releases for newer versions. Set to false to disable.
UPDATE_CHECK=true

# ── Multi-CLI-coder integration ────────────────────────────────────────────────
# Files to create as symlinks pointing at CLAUDE.md so other AI CLI coders
# (Codex CLI reads AGENTS.md, Gemini CLI reads GEMINI.md, etc.) pick up the
# same project instructions. Set to empty string "" to disable entirely.
MULTI_CODER_FILES="AGENTS.md GEMINI.md"

# ── Tip of the day ─────────────────────────────────────────────────────────────

# Inject a tip once per day per session (via the UserPromptSubmit hook).
# Set to false to disable entirely. --tip on demand always works.
TIP_OF_DAY=true

# Tip selection mode: "daily" (same tip all day, hash-based) or "random".
TIP_MODE=daily

