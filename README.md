# DockPeek

Hover an app in the Dock. See its windows. Click one to bring it to the front.

**TL;DR**

- Small macOS app, like window previews on the Windows taskbar.
- Free and open source. No third-party code.
- Runs in the background. No menu bar icon.
- Only network use: checking GitHub for a new version.

## Requirements

- macOS 27 or later, Apple silicon

## Install

1. Download `DockPeek.dmg` from [Releases](https://github.com/ahmetrende/dockpeek/releases/latest).
2. Open it. Drag DockPeek to Applications.
3. Open DockPeek. macOS blocks the first launch. Do "Open Anyway" below.
4. Allow Accessibility and Screen Recording. See [Permissions](#permissions).

### Open Anyway

DockPeek is not notarized by Apple, because that needs a paid account. So macOS blocks the first launch. The code is open, and every release is signed with the same certificate.

1. Open DockPeek. macOS shows *"DockPeek" Not Opened*. Click **Done**.
2. Open **System Settings > Privacy & Security**.
3. Scroll down to **Security**. Find *"DockPeek" was blocked to protect your Mac.* Click **Open Anyway** next to it.
4. Confirm with your password or Touch ID.

After each update, macOS blocks the new version once. Do these steps again.

Or, before the first launch, run this once in Terminal instead:

```bash
xattr -dr com.apple.quarantine /Applications/DockPeek.app
```

Then macOS does not block DockPeek, also after updates.

## Install with an AI agent

Give your agent this text:

> Install DockPeek from https://github.com/ahmetrende/dockpeek.
> Read `scripts/install.sh` first. Then run:
> `curl -fsSL https://raw.githubusercontent.com/ahmetrende/dockpeek/main/scripts/install.sh | bash`
> When it finishes, tell me to allow Accessibility and Screen Recording for DockPeek.

The script downloads the latest release and checks its signature. It installs DockPeek to `/Applications` and opens it. This way needs no "Open Anyway" step. An agent cannot grant permissions. You do that.

## Permissions

DockPeek needs two. Its settings window shows both and opens the right page.

- **Accessibility**: to see which Dock icon is under the pointer and to bring windows to the front.
- **Screen Recording**: to capture window thumbnails. Without it, previews show the app icon.

macOS may also ask to let DockPeek *bypass the system private window picker*. Click **Allow**.

## Use

- Hover a running app in the Dock. A panel shows its windows.
- Click a thumbnail. That window comes to the front.
- Open DockPeek again, for example from Spotlight, to see settings and to quit.

It shows windows on the current desktop, minimized windows and windows of hidden apps.

## Updates

- DockPeek checks GitHub 10 seconds after launch, then once a day.
- To check now, open DockPeek again. Click **Check Now** next to **Updates**.
- When there is a new version, it asks: **Update Now** or **Later**.
- **Update Now**: it downloads the new version and checks that it is signed with the same certificate. Then it replaces itself and restarts. Permissions stay. If you installed with Open Anyway, macOS blocks the new version once. Do [Open Anyway](#open-anyway) again.
- **Later**: it asks again after a day.
- It talks only to GitHub: `api.github.com` for the check, and the release download for an update. No account, no tracking.

## Build from source

For developers. You do not need this to use DockPeek.

1. Install Command Line Tools: `xcode-select --install`
2. Create a signing certificate once: `scripts/make-certificate.sh`
3. Build and install to `/Applications`: `scripts/build-app.sh`

Why the certificate: macOS ties permissions to the app's signature. A fixed certificate keeps them after each rebuild. Builds from source do not check for updates.

Test:

```bash
swift test --scratch-path ~/Library/Caches/DockPeek-build
```

Release (maintainer only): raise the version in `Resources/Info.plist`, commit and push to main, then run `scripts/release.sh`.

## Notes

- One private macOS call: `_AXUIElementGetWindow`. It maps a window to its ID.
- Language: Turkish or English. Automatic follows the Mac. Change it in settings.
- App icon: `swift scripts/make-icon.swift` draws it into `Resources/AppIcon.icns`.
- Design notes and measurements: `docs/DESIGN.md`
- License: MIT
