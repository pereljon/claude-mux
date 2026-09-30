# bypassPermissions launch behavior

Moved from the "Known Issues / Hypotheses" section of `AGENTS.md` on 2026-09-30.

- **`bypassPermissions` confirmation prompt**: Claude shows a warning with "No, exit" / "Yes, I accept" when launched with `bypassPermissions`. The startup poller detects "Yes, I accept", sends Down (to move from option 1 to option 2), waits 1s for the UI to register the selection, then sends Enter. The 1s pause is critical - without it the keystrokes race and confirm "No, exit" instead.
- **`bypassPermissions` requires restart to enter**: cannot switch a running session to `bypassPermissions` mid-session - must restart with the flag. Once in the Shift+Tab cycle, re-entry from other modes is silent (no prompt). Confirmation prompt only fires on initial launch.
