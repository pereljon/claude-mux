# FAQ

## What is claude-mux?

A shell script that wraps Claude Code in tmux for persistent sessions. Sessions survive terminal closes, resume conversation context on restart, and are accessible from the Claude mobile app via Remote Control. You manage everything by talking to Claude inside a session.

## Does it work on Linux?

Not yet. macOS only (Apple Silicon and Intel). Linux support is planned for v2.0. The installer runs on Linux but skips LaunchAgent setup and prints a note. The binary itself works, but there is no systemd service or equivalent auto-start mechanism yet.

## What is the home session?

The home session is a general-purpose Claude session that lives in your base directory (`~/Claude` by default). When `LAUNCHAGENT_MODE=home` (the default), it launches automatically at login and stays running all day. It is **protected** by default, meaning `--shutdown home` refuses to stop it without `--force`.

Use the home session as your always-available entry point from the Claude mobile app. From there you can list projects, start other sessions, manage config, and do general work that does not belong to a specific project.

## What is Remote Control?

Remote Control (RC) is a Claude Code feature that lets you connect to a running Claude session from the Claude mobile app or Claude Desktop. claude-mux launches every session with `--remote-control` enabled, so all sessions appear in the RC list automatically. Once connected, you talk to Claude the same way you would in a terminal. claude-mux also works around RC limitations like slash commands not working natively, by routing them through tmux.

## What are permission modes?

Claude Code has four permission modes that control how much autonomy Claude has:

| Mode | Behavior |
|------|----------|
| `default` | Claude asks before running commands or editing files |
| `acceptEdits` | Claude auto-applies file edits but asks before shell commands |
| `plan` | Claude can only read and plan, no writes or commands |
| `bypassPermissions` | Claude runs everything without asking (requires confirmation on first launch) |

Set the default for all projects via `DEFAULT_PERMISSION_MODE` in config. Switch a running session by saying "switch this session to plan mode" (or any mode name). "yolo" is an alias for `bypassPermissions`.

Switching to `bypassPermissions` from another mode uses Shift+Tab navigation and does not require a restart. Switching from `bypassPermissions` to another mode requires a restart, which claude-mux handles automatically.

## How do I reset a session?

Three options, depending on what you want:

- **Clear** ("clear this session"): sends `/clear` to the session. Wipes conversation history and starts fresh. The session stays running.
- **Compact** ("compact this session"): sends `/compact` to the session. Summarizes the conversation into a shorter context, freeing up the context window. History is preserved in compressed form.
- **Restart** ("restart this session"): shuts down Claude and relaunches it with `claude -c`, which resumes the last conversation. Use this when you need a clean process (e.g., after changing permission modes or when Claude is stuck).

## What are templates?

Templates are reusable CLAUDE.md files stored in `~/.claude-mux/templates/`. When you create a new project with `-n`, the default template (or one you specify with `--template NAME`) is copied to the project as its CLAUDE.md.

Create a template: "save this as a template named web" (copies the current project's CLAUDE.md to `~/.claude-mux/templates/web.md`).

Use a template: `claude-mux -n ~/projects/my-app --template web` or from inside a session: "create a new project called my-app using the web template".

List templates: "list templates" or `claude-mux --list-templates`.

## How does the tip-of-the-day work?

A Claude Code `UserPromptSubmit` hook in each project's `.claude/settings.local.json` calls `claude-mux --on-prompt` on each prompt. As of v2.0.15 the tip shows **once per day, in the `home` session only**: the first `home` prompt of the day injects one tip and stamps a single global date file (`~/.claude-mux/tip-state/tip.json`); every later prompt that day, in any session or after any `/clear`/restart, injects nothing. Project sessions never show the tip. (Before v2.0.15 the gate was keyed on the per-conversation `session_id`, which rotated on every `/clear`/restart and re-showed the tip many times a day.) Because the hook injects into context (not a Stop hook, whose output is transcript-only), the tip is visible in the conversation and in Remote Control.

Tips are enabled by default (`TIP_OF_DAY=true`). Toggle with "enable tips" or "disable tips" inside any session. `TIP_MODE=daily` shows the same tip all day; `TIP_MODE=random` picks a random tip.

The `--tip` command always works regardless of the daily gate (and regardless of `TIP_OF_DAY`), so you can say "tip" anytime.

(Before v1.15.0 this used a Stop hook whose output never surfaced; the switch to `UserPromptSubmit` is what made tips actually appear.)

## Can I use this with multiple GitHub accounts?

Yes. claude-mux detects `Host github.com-*` entries in `~/.ssh/config` and injects them into each session's system prompt. Claude knows which SSH aliases are available and can use the correct one when setting up git remotes.

Example `~/.ssh/config` setup:

```
Host github.com-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_work

Host github.com-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_personal
```

Claude will then know to use `git@github.com-work:org/repo.git` for work repos and `git@github.com-personal:user/repo.git` for personal ones.

## Where is state stored?

| Location | What lives there |
|----------|-----------------|
| `~/.claude-mux/config` | User configuration (sourced as bash) |
| `~/.claude-mux/templates/` | CLAUDE.md template files |
| `~/.claude-mux/tip-state/tip.json` | Global daily tip date (home session), v2.0.15+ |
| `~/.claude-mux/.update-check` | Cached version check result |
| `~/.claude-mux/.update-checking` | In-flight lock for the background update check |
| `~/Library/Logs/claude-mux.log` | Log file (configurable via `LOG_DIR`) |
| `~/Library/LaunchAgents/com.user.claude-mux.plist` | LaunchAgent plist (generated by `--install`) |
| `.claudemux-protected` (per project) | Marks a session as protected from shutdown |
| `.claudemux-ignore` (per project) | Hides a project from listings |

Marker files (`.claudemux-*`) live in each project's root directory and travel with the folder across renames, moves, and syncs. They are auto-added to `.gitignore`.

Conversation history is managed by Claude Code itself, stored under `~/.claude/projects/`.

## What happens with auto-update if I fork claude-mux?

The update check and `--update` command hardcode `pereljon/claude-mux` as the GitHub repo. If you fork it, update checks will still compare against the upstream release, and `--update` will overwrite your fork's binary with upstream. Set `UPDATE_CHECK=false` in `~/.claude-mux/config` to disable, or change the repo URL in the `check_for_update()` and `do_update()` functions in the script.

## How do I access my project files from my phone?

Remote Control gives you access to the session - you can talk to Claude from the Claude mobile app from anywhere. But files Claude creates or modifies stay on your desktop.

A peer-to-peer sync tool like [Resilio Sync](https://www.resilio.com/sync/) or [Syncthing](https://syncthing.net/) complements this well: sync your Claude projects folder to your mobile device and you can read outputs, open files, and review notes alongside the RC session, with no cloud service required. Resilio has native apps for iOS, Android, macOS, Windows, and Linux; Syncthing is open-source but has no native iOS app.

## Why don't running sessions pick up changes after `brew upgrade`?

claude-mux is a shell script, not a compiled binary. Any new `claude-mux` command after `brew upgrade` immediately uses the updated script - there is nothing cached in memory.

The issue is the injection prompt. Each session has a system prompt baked in at creation time (via `--append-system-prompt`). Running sessions keep the old prompt until restarted, regardless of what version is on disk.

Restarting also does more than refresh the prompt: it is what **activates auto-restore** for a session. At launch a session writes its `.claudemux-running` marker and installs the current launch wrapper, so a session that has not been restarted since upgrading carries no marker and is **not protected against a crash or reboot**. The restore tick does not retroactively mark a still-running session.

After upgrading, restart sessions to pick up the updated injection and activate auto-restore:
- Say **"restart all sessions"** inside any running session, or
- Run `claude-mux --update` (which upgrades and restarts automatically)

Avoid running `brew upgrade claude-mux` directly from a terminal and skipping the restart step - sessions will be running with a mismatched injection prompt and without crash/reboot protection. See the guide's "Updating and upgrading" section for the full picture (including Claude Code binary upgrades).

## After upgrading Claude Code, a session won't relaunch / seems stuck on first launch?

When the `claude` binary itself is upgraded (Homebrew, npm, a fresh download), macOS may mark the new copy as downloaded from the internet and show a Gatekeeper trust dialog the first time it runs. Because claude-mux restarts and auto-restores sessions non-interactively (the LaunchAgent tick has no one watching), that first launch can stall waiting for an approval nobody sees.

If a session does not come up right after a Claude Code upgrade, launch `claude` once in a normal terminal and approve the dialog, or clear the quarantine flag on the binary:

```bash
xattr -dr com.apple.quarantine "$(realpath "$(command -v claude)")"
```

After approving once, subsequent launches (including auto-restore) work normally. (Homebrew often strips quarantine automatically, so this mainly affects direct downloads.)

## Why does Remote Control disconnect when a session restarts?

RC connections are tied to the tmux session process. When a session is restarted (via `--restart`, `--update`, or a crash), the session process dies and the RC connection drops.

The session comes back on its own within ~5-10 seconds. Just reconnect RC manually after that. This is expected behavior, not a bug.

## How do I install via Homebrew?

```bash
brew tap pereljon/tap
brew trust pereljon/tap
brew install claude-mux
claude-mux --install
```

Run `brew trust pereljon/tap` once. Recent Homebrew skips updating untrusted third-party taps (`Warning: Skipping pereljon/tap because it is not trusted` on `brew update`), which would stop `brew upgrade claude-mux` from seeing new releases.

Update with `brew upgrade claude-mux`. Note: if you installed via Homebrew, `--update` delegates to `brew upgrade` automatically.

## How is this different from `claude --worktree --tmux`?

`claude --worktree --tmux` creates a tmux session for an isolated git worktree, designed for parallel coding tasks. claude-mux manages persistent sessions for your actual project directories, with Remote Control enabled, system prompt injection for self-management, conversation resume, and session lifecycle management. They solve different problems.

## How is this different from Claude Cowork Dispatch?

Dispatch launches tasks from the Claude desktop app, but requires the app to be running and isn't bound to a specific project. claude-mux manages persistent, project-bound sessions that survive reboots and are accessible from anywhere via Remote Control - no desktop app required.

## Why do sessions show "Not logged in"?

This happens on first launch if the macOS keychain is locked, which is common when the LaunchAgent starts before you unlock the keychain after login. Fix it by running `security unlock-keychain` in a regular terminal, then attach to any session (`claude-mux -t <name>`) and run `/login` to complete the browser auth flow. After that, restart all sessions and they will pick up the stored credential.

## Can multiple terminals attach to the same session?

Yes. This is standard tmux behavior. Running `claude-mux` in a directory that already has a running session attaches to it. Multiple terminals see the same session content in real time.

## How do I stop the home session permanently?

The LaunchAgent has `KeepAlive: true`, so killing the home session triggers a respawn within about 60 seconds. To stop it permanently, disable the LaunchAgent:

```bash
claude-mux --install --launchagent-mode none
```

## What does the "Session ready!" message mean?

When a session starts or restarts, claude-mux sends a `Ready?` prompt after Claude finishes loading. The injection tells Claude to respond with "Session ready!" and nothing else. This confirms the session is alive and the system prompt injection is working. You can ignore it.

## How do I hide a project from listings?

Say "hide this project" inside any session, or run `claude-mux --hide my-project`. This creates a `.claudemux-ignore` marker file. The project will not appear in `claude-mux -L` output. To see hidden projects: `claude-mux -L --hidden`. To unhide: "show this project" or `claude-mux --show my-project`.

## How do I uninstall claude-mux?

```bash
claude-mux --uninstall
```

This removes tip hooks and permission rules from all projects, unloads the LaunchAgent, and optionally removes `~/.claude-mux/`. It reports the binary path so you can delete it manually (or `brew uninstall claude-mux` if installed via Homebrew).

## Do slash commands work over Remote Control?

Not natively. Claude Code does not support slash commands (`/model`, `/clear`, etc.) in RC sessions. claude-mux works around this by injecting each session with `claude-mux -s` so Claude can send slash commands to itself via tmux. Just say "switch to Haiku" or "compact this session" and Claude handles it.

## I can't select text in a session

Hold **Option** (macOS) or **Shift** (Linux/Windows terminals) while clicking and dragging. This bypasses tmux's mouse capture and copies the selection to your system clipboard. No config changes needed.

## What languages are supported for conversational commands?

All of them. The trigger phrases ("help", "status", "list sessions", etc.) work in any language. Claude infers the intent from the user's natural language and runs the matching command. The README is also translated into 12 languages.
