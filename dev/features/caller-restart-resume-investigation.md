---
kind: investigation
feature: caller-restart-resume-investigation
status: RESOLVED in v2.0.6 via restart-in-place (see restart-in-place.md). Root cause confirmed: killing the caller's pane SIGHUP'd the in-pane restart script before recreate. Fix: looped wrapper relaunches the caller in-pane instead of killing it. The "helper session" candidate was abandoned in favor of this.
severity: HIGH (context loss on a common action)
supersedes: caller-restart-resume-race.md (that hypothesis was wrong; reverted)
---

# Investigation: "restart all sessions" from home brings home back as a FRESH conversation

Long-running, still-open investigation. This doc captures the symptom, every hypothesis
tried, each fix attempt and its result, what we proved, and where it stands, so the next
person (or session) does not repeat the dead ends.

## Symptom

Running "restart all sessions" **from the home session** (i.e. home is the caller of a
restart-all) brings home back as a **brand-new conversation** - its history/context is
lost. Every *other* session resumes correctly. Restarting home **from a different
session** (`claude-mux --restart home`) resumes correctly. Reproduced many times
2026-06-16/17.

At the file level: each failed restart abandons home's transcript
(`~/.claude/projects/-Users-jonathan-Claude/<id>.jsonl`) and a new one appears, instead of
the existing one continuing to grow.

## How it surfaced (regression context)

It became visible after the **v2.0.4** restart-stranding fix (commit b9577f0). Before
v2.0.4, restart-all from home hit the stranding bug: the blanket `shutdown_claude_sessions`
SIGHUP-killed the restart script before the caller handoff ran, so home was revived ~60s
later by the **LaunchAgent autolaunch** - which resumed it. v2.0.4 made the handoff
actually run, and the handoff's relaunch forks. So v2.0.4 didn't *cause* a new bug so much
as **stop masking** this one. ("It didn't used to happen" = the LaunchAgent used to do the
relaunch.)

## The core reproducible finding (holds across everything)

> **A relaunch issued by a process INDEPENDENT of the dying caller resumes.
> A relaunch issued by the caller's own handoff (a descendant of the killed pane) forks.**

Evidence:
| Relaunch issued by | Caller state | Result |
|---|---|---|
| Another live session (`claude-mux --restart home` from claude-mux session) | idle | **resume** (proven ~6x) |
| launchd (LaunchAgent autolaunch = `claude-mux -d ~/Claude`) | n/a | **resume** (pre-v2.0.4 behavior) |
| `claude-mux -d ~/Claude` run by hand from another session | idle | **resume** |
| A tmux-server-spawned helper session | (killed) | **resume** (validated) |
| The caller's own background handoff subshell | (killed) | **FORK** |

The handoff's relaunch command is *identical* to the resuming ones (`claude-mux -d
~/Claude`, same flags incl. `--model`); only the **issuing process** differs.

## Hypotheses tried and RULED OUT

1. **Active Remote Control connection on home.** Ruled out: with an RC client actively
   attached to home, `claude-mux --restart home` from another session still resumed.
2. **The `--model` flag** (home launches with `--model sonnet`; others don't). Ruled out:
   `claude -c --model sonnet` (and the full flag set `-c --remote-control --permission-mode
   auto --model sonnet --allow-dangerously-skip-permissions`) resumed in headless tests.
3. **The launch wrapper** (`launch_single_session` vs `create_claude_session`). Ruled out:
   a throwaway session launched via `claude-mux -d` (launch_single_session), killed, and
   relaunched via `claude-mux -d` **resumed**.
4. **Relaunch timing / racing the dying process's conversation lock.** Ruled out: added a
   `poll_until_ready` before `/exit` (wait for the caller to be idle) plus an "ensure the
   old session is fully gone + settle" wait before relaunch (28s observed). Still forked.
   (This was the "caller-restart-resume-race" fix - reverted.)
5. **Inherited Claude env identity** (`CLAUDE_CODE_SESSION_ID`, `CLAUDECODE`, etc. exported
   into child processes). Ruled out: `unset`ing them in the launch script ("env-scrub") did
   not help. (Note: tmux new-session panes inherit the tmux *server's* env, not the
   client's, so these were likely never reaching the new claude anyway.)
6. **Stale `TMUX`/`TMUX_PANE` pointing at the killed pane.** Ruled out: `env -u TMUX -u
   TMUX_PANE claude-mux -d` from the handoff still forked (and unsetting them from a clean
   context is harmless - confirmed).
7. **Conversation ends mid-tool-use (dangling restart tool_use makes it unresumable).**
   Not supported: the abandoned transcripts end with normal user/meta records, not a
   dangling assistant tool_use.

## What's actually different about the handoff (the open question)

`claude` is spawned by the **tmux server** in every path (via `tmux new-session`), so the
new claude is not literally a child of the handoff. Yet the handoff path forks and the
others resume. The remaining difference is the **lineage / session / controlling-terminal
of the process that ISSUES `tmux new-session`**: the handoff subshell was spawned inside
home's pane (even after being reparented to init and with `TMUX` unset, it carries that
context); the resuming issuers (other session, launchd, tmux-server helper) do not. The
*exact* carried factor (process session id, controlling tty, or something tmux copies at
new-session time) was not isolated. On Linux `setsid` would sever this cleanly; macOS has
no `setsid`.

## Leading candidate (KEPT in code, WIP): tmux-server helper relaunch ("option B")

The handoff now issues the relaunch from a **short-lived tmux-server-spawned helper
session** (`_cmrestart-<caller>`) instead of doing it itself. The helper has a clean
lineage (like the resuming paths), runs `claude-mux -d <caller>`, clears the restart
marker, stays alive ~125s so `claude-mux -d`'s backgrounded ready-handshake
(`poll_until_ready` -> "Ready?", which also reconnects Remote Control) can fire in the
helper's pane, then self-destructs. No LaunchAgent dependency (the tmux server is always
present).

**Status: promising but NOT reliable yet.**
- First version (helper kills itself immediately) -> home **RESUMED** on disk (transcript
  grew, no fork) - the breakthrough - but RC never reconnected and no "Ready?" fired,
  because the helper killed its pane before `claude-mux -d`'s backgrounded handshake ran.
- Added `sleep 125` so the handshake can fire -> next run produced **two** continuation
  transcripts and home landed on a fresh one. Unstable; root cause of the double-transcript
  not yet understood (possible interaction between the helper's lifetime, `claude-mux -d`'s
  own clean-exit/relaunch logic, and/or a second launch).

So the helper is the best lead (it's the only thing that achieved a real resume) but needs
more work to be deterministic.

## Safe fallback (NOT implemented): "option A"

Make restart-all **not self-restart the caller** at all: restart every other session, leave
the caller running, and tell the user ("home left running to preserve its conversation;
restart it from another session, or 'restart this session' to restart fresh"). Guarantees
no history loss, no fork, no race, no helper, no LaunchAgent dependency. Cost: the caller
doesn't pick up the update from that command; the user restarts it explicitly (resumes).
This is the reliable escape hatch if the helper can't be made deterministic.

## Reliable workaround available today

To restart everything without home losing history: restart the others, then restart home
**from another session** (`claude-mux --restart home`, or ask the home-orchestrator from a
different session). That path always resumes.

## What was reverted vs kept (2026-06-17)

- **Reverted:** resume-race change (poll_until_ready before /exit + ensure-gone/settle);
  env-scrub (`unset CLAUDE_CODE_*` in launch scripts); standalone TMUX/TMUX_PANE unset.
  None fixed it.
- **Kept (solid wins, unrelated to this bug):** session-target-disambiguation (named
  session commands ask instead of defaulting to current); the injection quote-escaping fix.
- **Kept (WIP candidate):** the tmux-server helper relaunch in the caller handoff.

## Next steps

1. Make the helper deterministic: understand the double-transcript (does `claude-mux -d`
   from the helper sometimes both resume *and* fresh-fallback? does home's own clean-exit
   wrapper re-trigger? is there a second launch?). Add targeted logging in the helper
   (capture which session id `claude -c` continues vs creates).
2. Decide handshake handling cleanly (helper sends "Ready?" itself after a bounded poll,
   vs relying on `claude-mux -d`'s backgrounded sender + keeping the pane alive).
3. If the helper can't be made reliable, ship **option A** (don't self-restart the caller).
4. Isolate the exact lineage factor (controlling tty vs process session) to confirm the
   mechanism, ideally with a minimal repro that does NOT need the full restart-all.
