# Resilio Sync: Remote File Access Guide

Notes on using Resilio Sync to access files on a home or work computer from mobile devices and other computers, without using cloud services.

## Why This Matters for claude-mux Users

claude-mux keeps your Claude Code sessions running and accessible from anywhere via Remote Control - you can talk to Claude from your phone or any remote device. But RC gives you access to the *session*, not the *files*. If Claude creates or modifies files in a project, those files stay on your desktop.

Resilio Sync closes that gap. Sync your Claude projects folder to your mobile device and you can read outputs, review notes, and open files right alongside the RC session - without uploading anything to a cloud service.

## What It Is

Resilio Sync is a peer-to-peer file sync tool. Files transfer directly between your devices over the network. No central server, no cloud account, no monthly subscription for personal use.

Originally based on BitTorrent's sync protocol, now developed by Resilio Inc. Proprietary software (closed source).

## When Resilio Sync Is a Good Fit

- Mobile access to files on a desktop computer (iOS, Android, plus macOS, Windows, Linux)
- You want to keep data off cloud services
- Your data set is many small files (markdown, code, notes, configs) - P2P handles this better than vendor clouds
- You are okay with no central backup (peers are the backup)

## When Something Else Is Better

- Need real-time collaboration with multiple editors on the same file
- Need a web UI to access files from any browser anywhere
- Need integrated calendar, contacts, document collaboration (consider Nextcloud)
- Need offline access on iOS to be 100% continuous (Apple's background restrictions limit any sync app)
- The folder contains active git repos and you want to do git operations on multiple devices (sync of `.git/` is risky - see below)

## Cost

- **Sync Home (free)**: covers personal use across reasonable device counts
- **Sync Home Pro (~$60 one-time)**: removes device limits, adds selective sync improvements
- Business tiers exist; free tier is usually sufficient for personal use

## Platforms

Native apps for:
- macOS
- Windows
- Linux
- iOS
- Android

Pair devices by scanning a QR code or sharing a key string.

## Setup Overview

1. Install Resilio Sync on the primary computer
2. **macOS only**: grant Full Disk Access (see below) before adding folders
3. **Important**: Configure the IgnoreList before adding any folder (see below)
4. Add the folder(s) you actually want to share - not your entire home directory. Typically you pick one or a few top-level folders that contain the content you want remote access to. For people doing AI / LLM work, that's usually the AI projects folder (where prompts, notes, configs, agent files, and project content live).
5. Choose folder type:
   - **Read & Write (sendreceive)**: any peer can edit, edits propagate to others
   - **Read Only**: peers can read but not modify
6. Install Resilio Sync on mobile/secondary devices
7. Scan QR code or enter share key to pair
8. Configure selective sync on mobile to control which subfolders download by default

## Granting Full Disk Access on macOS

On modern macOS, system protection (TCC) blocks apps from reading many user folders by default (Documents, Desktop, Downloads, iCloud, and more). Without Full Disk Access, Resilio Sync may appear to work but silently fail to read or sync files in protected locations, or show files as missing/empty on peer devices.

**Grant it once, before adding folders:**

1. Open **System Settings** > **Privacy & Security** > **Full Disk Access**
2. Click the **+** button (you may need to unlock with Touch ID or password)
3. Navigate to `/Applications` and select **Resilio Sync.app**
4. Confirm the toggle is on
5. Quit Resilio Sync completely (Cmd+Q, or right-click the menu bar icon and Quit) and relaunch it for the permission to take effect

**Verify it took effect:**

- Add a test folder from Documents or Desktop
- Confirm files appear and counts match peer devices
- If files appear missing or sync stalls with no error, check the Full Disk Access setting again

This is a one-time setup step. Without it, you will hit confusing partial-sync issues that are easy to misdiagnose as Resilio bugs.

## Linking Devices via QR Code

After the primary device has Resilio Sync installed and the folder added, link other devices like this.

**On the primary device (Mac/Windows/Linux):**

1. In Resilio Sync, find the synced folder in the main view
2. Click the share icon next to the folder (often labeled "Share", or click the three-dot menu and choose Share)
3. A dialog appears with:
   - A QR code
   - A share key (long alphanumeric string)
   - A share link (starts with `https://link.resilio.com/`)
4. Choose the permission level for the peer:
   - **Read & Write**: peer can edit files; changes propagate to all devices
   - **Read Only**: peer can read but not modify
   - **Owner**: full control including changing other peers' permissions (rarely needed)

   For most personal use across your own devices, use **Read & Write** so any device can edit and have changes flow back to the others. Use Read Only only when you want a peer to consume content without being able to change it (e.g., a shared folder where one person publishes and others just read).
5. Optional: set an expiration on the share key, or limit how many devices can use it
6. Keep this dialog open while you scan from the other device

**On the mobile device (iOS/Android):**

1. Install Resilio Sync from the App Store or Play Store
2. Open the app and accept any initial prompts
3. Tap the **+** button (top right on iOS, bottom right on Android)
4. Choose **Scan QR code** (or **Add folder** > **Enter key**)
5. Point the camera at the QR code on the primary device's screen
6. The app picks up the share, prompts for a destination folder on the mobile device, and starts syncing
7. Optionally enable **Selective sync** so the device shows file placeholders and only downloads files when tapped, saving space

**On a second desktop computer:**

1. Install Resilio Sync
2. Click **+** in the main view, choose **Enter a key or link**
3. Paste the share key or open the share link from the primary device
4. Choose a local folder where the synced content will live
5. Confirm and Resilio begins the initial sync

**Verifying the link worked:**

- The new device appears in the **Peers** tab of the folder on the primary device
- Both devices show matching file counts (after initial sync completes)
- The primary device's folder view shows a peer count

**Sharing safely:**

- Treat the share key, QR code, and share link as secrets. Anyone with any of them can join the share at the permission level encoded in them.
- Use Read Only for peers you want to grant view access without write capability.
- Use expiring keys when sharing with a peer for a short time.
- If a key may have leaked, regenerate it from the share dialog; old keys are revoked.

## The `.sync/` Folder

Each synced folder gets a hidden `.sync/` directory containing:

- `ID` - folder identifier used for peer pairing. **Treat as sensitive**; anyone with this can join the share.
- `IgnoreList` - patterns excluded from sync
- `StreamsList` - whitelist for alternate streams, extended attributes, resource forks
- `Archive` - old versions of deleted or modified files (versioning)
- `*.!sync` - temporary in-progress transfer files

**Do not delete or move the `.sync/` folder**. Doing so causes a "Service files missing" error and breaks syncing for that share.

## RSLS Placeholder Files

When **Selective Sync** is enabled on a device (or the device is in Connected mode), Resilio creates `.rsls` placeholder files instead of downloading the actual content. Placeholders are 0-byte files that represent a file in the share without storing its data locally. The file downloads on demand when you tap or open it.

This is a **Sync Home Pro** feature. It is useful on mobile devices where storage is limited - you see the full folder structure and pull down only the files you actually need.

**Important for git repos:** `.rsls` files should never be committed. Add `*.rsls` to your repo's `.gitignore`. If a placeholder lands in a tracked folder before you gitignore it, remove it with `git rm --cached *.rsls`.

The `.sync/` folder should also be gitignored - it contains the share ID and internal state that should not be in version control.

## IgnoreList Syntax (verified)

Location: `<folder>/.sync/IgnoreList`. UTF-8 plain text, one rule per line.

**Wildcards:**
- `*` matches any sequence of characters
- `?` matches a single character
- `**` matches any number of intermediate directories (e.g., `a/**/b` matches `a/b`, `a/x/b`, `a/x/y/b`)

**Path semantics:**
- A bare name like `node_modules` matches files AND directories with that name, at any depth
- A pattern with a `/` separator anchors to the sync root: `src/secrets` matches only `<root>/src/secrets`
- Leading `/` also anchors: `/temp` matches only `<root>/temp`
- `FOO/*` ignores files inside `<root>/FOO`, but does not stop nested deeper `FOO/` folders

**Other rules:**
- **Case-sensitive** (even on macOS)
- `#` at line start is a comment
- To match a filename that literally starts with `#`, use `?recycle` instead of `#recycle`
- Use `/` on macOS/Linux, `\` on Windows

## Critical Behavior

**IgnoreList does not remove already-synced files.** If you add a folder to Sync first and then add patterns to IgnoreList later, files matching those patterns that have already replicated to peers stay there. They simply stop propagating future changes.

**Best practice**: configure `IgnoreList` BEFORE adding the folder to Sync.

**Applying changes**: Sync re-reads IgnoreList on file change or at `folder_rescan_interval`. Restart Resilio for immediate effect.

**Consistency**: keep the same IgnoreList on all peers to avoid confusing size differences between devices.

## Recommended IgnoreList Starter

Adapt to your folder's contents. Keys here are: never sync secrets, never sync git internals, never sync large rebuildable artifacts.

```
# Git internals - corruption risk with concurrent ops on multiple devices
.git
.gitignore
.gitattributes
.gitmodules

# Secrets and credentials - keep off mobile devices
.env
.env.*
*.env
*.pem
*.key
*.p12
*.pfx
id_rsa
id_rsa.*
id_ed25519
id_ed25519.*
credentials.json
secrets.json
service-account*.json
.aws
.ssh
.gnupg
.netrc

# Node / JavaScript
node_modules
.npm
.yarn
.next
.nuxt
.turbo
.parcel-cache
.vite

# Python
.venv
venv
__pycache__
*.pyc
.pytest_cache
.mypy_cache

# Build artifacts
dist
build
out
target
coverage

# Resilio Sync placeholders (selective sync / connected mode)
*.rsls

# Cache and OS junk
.cache
.tmp
.DS_Store
Thumbs.db
desktop.ini

# IDE state
.idea
.vscode
*.swp

# Logs
*.log
logs
```

## Working With Git Repos in Synced Folders

Do not sync `.git/` directories. Add `.git` to the IgnoreList before adding the folder.

Syncing `.git/` across devices is unsafe because concurrent git operations (a commit on one device while another device is mid-sync, for example) can corrupt repo state. Vendor clouds (iCloud, Google Drive, Dropbox, OneDrive) handle `.git/` even worse and have a long history of repo corruption.

With `.git/` excluded:
- The primary device (desktop) is the sole git operator
- Mobile and secondary devices receive working files only, no git history or status
- File edits on mobile sync back to the primary as working-tree modifications, committed manually there

## iOS Specific Notes

- Official Resilio Sync app, free
- Integrates with iOS Files (appears as a location alongside iCloud)
- Background sync is limited by iOS - app must be foregrounded or recently active for changes to propagate
- Not a "set and forget" experience on iOS; expect to open the app occasionally
- This is an iOS platform limitation, not specific to Resilio - any sync app faces it

## Android Specific Notes

- Official Resilio Sync app, free
- More flexible background sync than iOS
- Camera roll auto-upload available
- Selective sync works well

## Sync Conflicts

When the same file is edited on two devices while one is offline, Resilio keeps both copies:
- Original filename retains one version
- Other version saved as `filename.sync-conflict-DATE-TIME.ext`

Resolve manually by inspecting both files.

To reduce conflicts:
- Designate one device as the primary writer
- Use selective sync on mobile to limit which folders mobile can edit
- For shared collaboration, consider Read-Only mode on secondary devices

## Security Considerations

- The `.sync/ID` file is effectively the share secret. Anyone with this can join the share. Do not commit it to public repos or paste it publicly.
- QR codes generated for sharing contain the same secret. Do not screenshot and share publicly.
- Sync traffic is encrypted in transit (AES-128).
- Files at rest are not encrypted by Resilio. Combine with disk-level encryption (FileVault, BitLocker) or an encrypted vault tool (Cryptomator) if needed.
- Mobile-side: keep secrets and credentials out of synced folders. Mobile devices are more easily lost or stolen than desktops.

## Alternatives Briefly

- **Syncthing**: open source equivalent. No native iOS app (requires paid third-party wrapper). Otherwise comparable.
- **Nextcloud**: full self-hosted cloud platform. Requires server. Heavier setup, more features (calendar, contacts, docs).
- **Vendor clouds** (iCloud, Google Drive, Dropbox, OneDrive): central, easy, but bad with `.git/` and you pay storage costs at scale.
- **Tailscale + SMB**: direct remote file access over wireguard mesh. Not sync; no offline access. Free for personal use.

## References

- Resilio downloads: https://www.resilio.com/platforms/desktop/
- IgnoreList documentation: https://help.resilio.com/hc/en-us/articles/205458165-Ignoring-files-in-Sync-Ignore-List
- `.sync/` folder contents: https://help.resilio.com/hc/en-us/articles/206217185-What-is-sync-folder-and-StreamsList-IgnoreList-and-Archive-inside
