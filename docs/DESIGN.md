# DockPeek design notes

**TL;DR** Watch the Dock with Accessibility. List the hovered app's windows. Capture each window once with ScreenCaptureKit. Show them in a small panel. A click brings that window to the front.

## Parts

| Part | Job |
| --- | --- |
| `DockWatcher` | Finds the Dock icon under the pointer. Reattaches when the Dock restarts. |
| `WindowLister` | Lists the app's windows on this desktop, plus minimized ones. |
| `Thumbnailer` | Captures each window once, small. Keeps the last 20 images. |
| `HoverStateMachine` | Opens after 150 ms. Closes 200 ms after the pointer leaves. |
| `PreviewPanel` | One row of thumbnails above the icon. Follows the Dock while it slides in. |
| `WindowActivator` | Brings the clicked window to the front. Unminimizes it first. |
| `SettingsWindowController` | Login item, language, permissions, about, quit. Opens when you open DockPeek again. |

Pure logic lives in `DockPeekCore` and has unit tests. AppKit, Accessibility and ScreenCaptureKit code lives in `DockPeek`.

## Rules

- Only network use: release builds check GitHub for a new version. No third-party code.
- One private call: `_AXUIElementGetWindow`.
- No menu bar icon. The Dock icon shows only while the settings window is open.
- Language: Automatic, English or Türkçe. Automatic picks Turkish when the Mac's first language is Turkish, else English.
- Without Screen Recording, a thumbnail shows its last captured image, or the app icon if there is none.
- Memory is measured as `phys_footprint` (what Activity Monitor shows), not `ps` RSS.

## Distribution and updates

- Releases: `scripts/release.sh` publishes `DockPeek.dmg` (people) and `DockPeek.zip` (updates, agents) on GitHub.
- DMG window: DockPeek, an arrow and Applications on `Resources/DMGBackground.tiff` (drawn by `scripts/make-dmg-background.swift`). `scripts/make-dmg.sh` lets Finder write the layout, then stops if `.DS_Store` names the user or the per-user temp folder. The path bar is a global Finder setting, so the script leaves it alone; the background keeps its bottom 30 pt empty for it.
- Signing: every build is signed with the self-signed "DockPeek Signing" certificate (20 years, no email). macOS keeps permissions because the signature requirement stays the same.
- No notarization: the first launch from the DMG needs "Open Anyway". `scripts/install.sh` downloads with curl, which sets no quarantine flag, so it does not.
- Update check: release builds only (`DockPeekReleaseBuild` in Info.plist). 10 s after launch, then every 24 h. `GET api.github.com/repos/ahmetrende/dockpeek/releases/latest`, no login.
- Question: Update Now or Later. Later silences that version for 24 h.
- Check Now: the Updates row in the settings window (release builds only) checks at once and restarts the 24 h timer. It asks even about a version put off with Later. The row shows Checking…, Up to date, the new version, or Could not check; the reason goes to the log.
- Install: download the zip, unpack it, check that the signature meets the running app's designated requirement and that the version is newer, swap the bundle, restart through a small shell helper. The settings window opens once after an update.
- Nested code: installed copies check updates with kSecCSCheckNestedCode. Any helper, framework or XPC service added later must be signed on its own, or every installed copy refuses the update.
- Errors: a failed check only logs. A failed install shows the reason and keeps the installed version.
- Private data: builds are stripped of debug paths. `scripts/check-package.sh` blocks a release with user paths, an email in the certificate or unknown Info.plist keys.
- Local update test: `defaults write io.github.ahmetrende.dockpeek UpdateFeedURL http://localhost:PORT/feed.json`. Plain HTTP is accepted for localhost and 127.0.0.1 only.

## Results (2026-10-31, macOS 27)

| Check | Target | Result |
| --- | --- | --- |
| Panel open time | under 300 ms | 156–273 ms, median 165 ms (85 opens) |
| Capture time | under 150 ms | 56–106 ms |
| Memory (`phys_footprint`) | under 50 MB | 27 MB, peak 29 MB |
| Idle CPU | about 0 % | 0.29 % average, 1.2 % peak (60 s, settings window open) |

## Learned on macOS 27

- A minimized window reports the subrole `AXDialog`. So do all windows of a hidden (Cmd+H) app. Minimized windows skip the subrole check. Hidden apps show only their minimized windows.
- The Dock is a UIElement app, so macOS sends no launch notification for it. DockPeek watches `NSWorkspace.runningApplications` instead.
- The Dock does not always clear its selection when the pointer leaves. A mouse monitor runs while the panel is open.
- ScreenCaptureKit can capture minimized windows.
- With only Command Line Tools, Swift Build sometimes drops the Swift Testing macro plugin. `Package.swift` passes it explicitly.

## Open questions

- Show the windows of hidden (Cmd+H) apps?
- Start capturing during the 150 ms wait, so the first thumbnail is ready when the panel opens?
- Dock on the left or right, and more than one display: not tested.
