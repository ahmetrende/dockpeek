import AppKit
import DockPeekCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = PreviewSettings()
    private let watcher = DockWatcher()
    private lazy var thumbnailer = Thumbnailer(limit: settings.cacheLimit)
    private lazy var panel = PreviewPanel(gap: settings.panelGap)
    private lazy var machine = HoverStateMachine(openDelay: settings.openDelay, closeDelay: settings.closeDelay)
    private lazy var settingsWindow = SettingsWindowController()
    private let updateChecker = UpdateChecker()
    private var timer: Timer?
    private var iconFrame: CGRect = .zero
    private var lastHoveredPID: pid_t?
    private var hoverStartedAt: TimeInterval = 0
    private var shown: (pid: pid_t, windows: [CGWindowID: AppWindow])?
    private var prefetch: Prefetch?
    private var settleTask: Task<Void, Never>?
    private var pointerMonitor: Any?
    private var pointerAway = false

    private var now: TimeInterval { ProcessInfo.processInfo.systemUptime }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.app.notice("launched")
        AX.configureTimeout()
        wireCallbacks()
        observeTerminations()
        settingsWindow.onAccessibilityChanged = { [weak self] in self?.updateWatcher() }
        // After an update the settings window shows once, with the new version number.
        let justUpdated = UpdateInstaller.takeJustUpdated()
        if !Permissions.accessibility {
            Log.app.notice("accessibility permission missing")
        }
        if !Permissions.accessibility || justUpdated {
            settingsWindow.show()
        }
        updateWatcher()
        updateChecker?.onWillPrompt = { [weak self] in
            guard let self else { return }
            apply(machine.dismiss())
        }
        updateChecker?.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Log.app.notice("reopen received")
        // Also restarts a Dock watcher that gave up retrying.
        updateWatcher()
        settingsWindow.show()
        return false
    }

    /// Runs the Dock watcher only while Accessibility is granted.
    private func updateWatcher() {
        if Permissions.accessibility {
            watcher.start()
        } else {
            watcher.stop()
            apply(machine.dismiss())
        }
    }

    // MARK: - Events

    private func wireCallbacks() {
        watcher.onChange = { [weak self] hover in
            guard let self else { return }
            if let hover, hover.pid != ProcessInfo.processInfo.processIdentifier {
                if hover.pid != lastHoveredPID {
                    lastHoveredPID = hover.pid
                    hoverStartedAt = now
                }
                iconFrame = hover.iconFrame
                machine.iconHovered(pid: hover.pid, now: now)
            } else {
                lastHoveredPID = nil
                machine.iconLeft(now: now)
            }
            reschedule()
        }
        panel.onPointerEntered = { [weak self] in
            guard let self else { return }
            machine.pointerEnteredPanel()
            reschedule()
        }
        panel.onPointerExited = { [weak self] in
            guard let self else { return }
            machine.pointerExitedPanel(now: now)
            reschedule()
        }
        panel.onSelect = { [weak self] id in
            guard let self else { return }
            if let shown, let window = shown.windows[id] {
                WindowActivator.activate(window, pid: shown.pid)
            }
            apply(machine.dismiss())
        }
    }

    private func observeTerminations() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let pid = app.processIdentifier
            MainActor.assumeIsolated { self?.thumbnailer.removeAll(owner: pid) }
        }
    }

    // MARK: - Timing

    private func reschedule() {
        syncPrefetch()
        timer?.invalidate()
        timer = nil
        guard let deadline = machine.nextDeadline else { return }
        let next = Timer(timeInterval: max(deadline - now, 0) + 0.001, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.timerFired() }
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func timerFired() {
        apply(machine.advance(to: now))
        reschedule()
    }

    private func apply(_ actions: [HoverStateMachine.Action]) {
        for action in actions {
            switch action {
            case .show(let pid):
                present(pid)
            case .close:
                stopTracking()
                panel.close()
                shown = nil
                // The next hover, even of the same app, starts a new open-time measurement.
                lastHoveredPID = nil
            }
        }
        syncPrefetch()
    }

    // MARK: - Prefetch

    /// Keeps one prefetch, for the app whose panel is about to open or is open.
    private func syncPrefetch() {
        let wanted = machine.pendingShowPID ?? machine.shownPID
        if prefetch?.pid != wanted {
            prefetch = nil
        }
        if let pid = machine.pendingShowPID, prefetch == nil {
            let windows = WindowLister.windows(of: pid, minSide: settings.minWindowSide)
            let next = Prefetch(pid: pid, windows: windows)
            prefetch = next
            capture(windows, owner: pid) { [weak next] id, image in next?.images[id] = image }
        }
    }

    // MARK: - Panel content

    private func present(_ pid: pid_t) {
        // Normally the prefetch already listed the windows and started their capture during the open delay.
        let ready = prefetch?.pid == pid ? prefetch : nil
        let windows = ready?.windows ?? WindowLister.windows(of: pid, minSide: settings.minWindowSide)
        thumbnailer.prune(owner: pid, keeping: Set(windows.map(\.id)))
        guard !windows.isEmpty else {
            Log.panel.notice("pid \(pid) has no windows")
            apply(machine.dismiss())
            return
        }

        let icon = NSRunningApplication(processIdentifier: pid)?.icon ?? NSImage()
        let items = windows.map { window in
            // Minimized windows are captured too (design document, section 6.3).
            // The cached image shows until the capture arrives and stays if the capture fails.
            PanelItem(
                id: window.id,
                title: window.title,
                thumbnailSize: thumbnailSize(for: window),
                icon: icon,
                image: ready?.images[window.id] ?? thumbnailer.cachedImage(for: window.id)
            )
        }

        shown = (pid, Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }))
        if let frame = watcher.selectedIconFrame() {
            iconFrame = frame
        }
        panel.show(items, iconFrameAX: iconFrame)
        startTracking(pid)
        let elapsed = (now - hoverStartedAt) * 1000
        Log.panel.notice("panel shown for pid \(pid) after \(elapsed, format: .fixed(precision: 1)) ms, prefetched \(ready?.images.count ?? 0) of \(windows.count)")

        // Images from a running prefetch reach the panel as they arrive.
        if ready == nil {
            capture(windows, owner: pid)
        }
    }

    private func thumbnailSize(for window: AppWindow) -> CGSize {
        ThumbnailSizing.fit(window.size, maxWidth: settings.thumbnailWidth, maxHeight: settings.thumbnailMaxHeight)
    }

    /// Captures the windows in the background. Each image goes to `store`, and to the panel while it shows this app.
    private func capture(_ windows: [AppWindow], owner pid: pid_t, store: ((CGWindowID, CGImage) -> Void)? = nil) {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let requests = windows.map { CaptureRequest(id: $0.id, pointSize: thumbnailSize(for: $0), scale: scale) }
        guard Permissions.screenRecording, !requests.isEmpty else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            await thumbnailer.capture(requests, owner: pid) { id, image in
                store?(id, image)
                guard self.shown?.pid == pid else { return }
                self.panel.setImage(image, for: id)
            }
        }
    }

    // MARK: - Panel tracking

    /// While the panel is open, follows the Dock's slide-in and notices when the pointer leaves the Dock.
    private func startTracking(_ pid: pid_t) {
        stopTracking()
        settleTask = Task { @MainActor [weak self] in
            // An auto-hidden Dock may still be sliding in. Follow the icon until its frame stops changing.
            var stableReads = 0
            for _ in 0..<12 {
                try? await Task.sleep(for: .milliseconds(50))
                guard let self, self.shown?.pid == pid else { return }
                guard let frame = self.watcher.selectedIconFrame(), frame != self.iconFrame else {
                    stableReads += 1
                    if stableReads >= 2 { return }
                    continue
                }
                stableReads = 0
                self.iconFrame = frame
                self.panel.reposition(iconFrameAX: frame)
            }
        }
        pointerAway = false
        pointerMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.pointerMoved() }
        }
    }

    private func stopTracking() {
        settleTask?.cancel()
        settleTask = nil
        if let pointerMonitor {
            NSEvent.removeMonitor(pointerMonitor)
        }
        pointerMonitor = nil
    }

    /// The Dock does not always report that the pointer left it.
    /// A pointer above the icon row and outside the panel counts as leaving.
    private func pointerMoved() {
        guard shown != nil, let primary = NSScreen.screens.first else { return }
        let point = NSEvent.mouseLocation
        let icon = ScreenGeometry.appKitRect(fromAX: iconFrame, primaryScreenHeight: primary.frame.height)
        let away = point.y > icon.maxY && !panel.frame.contains(point)
        guard away != pointerAway else { return }
        pointerAway = away
        if away {
            machine.iconLeft(now: now)
        } else if let pid = lastHoveredPID {
            // Back on the icon row: the Dock may keep the same selection and send no new event.
            machine.iconHovered(pid: pid, now: now)
        }
        reschedule()
    }
}

/// Windows and images for the app whose panel is about to open (design document, section 6.3).
/// The capture starts during the open delay, so the panel usually opens with images instead of app icons.
@MainActor
private final class Prefetch {
    let pid: pid_t
    let windows: [AppWindow]
    var images: [CGWindowID: CGImage] = [:]

    init(pid: pid_t, windows: [AppWindow]) {
        self.pid = pid
        self.windows = windows
    }
}
