---
kind: feature
lifecycle: building
feature: shutdown-fresh
status: BUILT on branch shutdown-fresh, live-tested 2026-10-01 (kill, busy, protected, self-refusal, multi-name); pending code review and commit approval; resume-after-clear behavior verified live 2026-09-30; flag decided: --fresh extended to --shutdown (architect review agreed); chat confirmation for all fresh/clear triggers added
target_version: 2.5.0 (minor): new flag on --shutdown + injection vocabulary
severity: N/A (enhancement)
related: clear-ready-handshake.md, restart-in-place.md
---

# Feature: `--shutdown SESSION --fresh` ("kill")

## Problem

"stop" ends a session and the next start resumes the conversation. There is no way to end a session so the next start is fresh. `--restart --fresh` starts fresh but relaunches immediately.

## Vocabulary

- **stop / shut down**: `--shutdown SESSION`; next start resumes.
- **kill**: `--shutdown SESSION --fresh`; next start is fresh.
- **end this session**: unchanged (`--restart --fresh`, relaunches now).

## Mechanism (no marker file)

Send `/clear`, wait for the `--on-clear` handshake to finish, then shut down as usual. Verified 2026-09-30 on a scratch session: after clear + shutdown + start, Claude Code resumed the post-clear transcript (the `/clear` command plus the handshake turn) and left the pre-clear transcript untouched.

Dependency: the `--on-clear` hook's `Ready?` handshake is what writes the post-clear transcript. Without it, resume could fall back to the pre-clear conversation.

## Confirmation (injection rule, not CLI)

The CLI never prompts. For conversational triggers, the injection tells Claude to state in one line what will happen and get a yes/no in chat before running, for every trigger that discards context or starts a new conversation:

- **kill SESSION**: "Kill X? It stops now; its next start is a new conversation, not a resume."
- **end this session**: "End this session? Unsaved work is saved first, then it restarts as a new conversation." (keeps the existing save-first check; one combined question)
- **restart SESSION fresh** / **restart this session fresh**: "Restart X fresh? It relaunches as a new conversation; history will not be resumed."
- **clear this session** / **clear session X**: "Clear X? Its conversation context is wiped; the session keeps running."

Changes shipped behavior for restart-fresh (previously warn only) and clear (previously none). Plain stop, restart (resume) and compact stay unconfirmed. Applies in both launch paths; README injection section must match.

## Design points

- Wait for the handshake reply before `/exit`; otherwise the monitor's `Ready?` races the shutdown.
- `/clear` lands only at an idle prompt; a busy session needs an interrupt first, or a timeout that falls back to plain shutdown with a warning.
- `--fresh` is currently valid only with `--start`, `--restart`, `-d`; extend the validation to `--shutdown`.
- Caller (self) case: `/clear` + `/exit` on the calling session would SIGHUP the script; define behavior (likely refuse, point to "end this session").
- Protected sessions: same rule as `--shutdown` (`--force` required).
- No-arg `--shutdown --fresh` (all sessions): allowed; same skip rules.
- `.claudemux-running` marker removed as for `--shutdown`.

## Change checklist

`src/` edit (arg parse, `shutdown_single_session`), injection in `create_claude_session` and `launch_single_session`, `commands_help()`, `build_system_prompt()` feature list, README + injection section, SKELETON, CODEMAP, IMPLEMENTATION-SPEC, CHANGELOG, tip, `make features-index`.
