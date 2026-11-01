import AppKit
import ApplicationServices
import DockPeekCore

/// The application icon under the pointer. `iconFrame` uses AX coordinates (top-left origin).
struct DockHover: Equatable {
    let pid: pid_t
    let iconFrame: CGRect
}

private let dockBundleID = "com.apple.dock"

private let selectionCallback: AXObserverCallback = { _, _, _, refcon in
    guard let refcon else { return }
    let watcher = Unmanaged<DockWatcher>.fromOpaque(refcon).takeUnretainedValue()
    // The observer's run loop source is on the main run loop.
    MainActor.assumeIsolated { watcher.selectionChanged() }
}

@MainActor
final class DockWatcher {
    var onChange: ((DockHover?) -> Void)?

    private var observer: AXObserver?
    private var list: AXUIElement?
    private var appsObservation: NSKeyValueObservation?
    private var attachTask: Task<Void, Never>?
    /// About 30 seconds of attempts, for a login-item start before the Dock is ready.
    private let retry = RetryPolicy(interval: 2, maxAttempts: 15)

    func start() {
        if appsObservation == nil {
            // The Dock is a UIElement app, so NSWorkspace posts no didLaunchApplication notification for it.
            appsObservation = NSWorkspace.shared.observe(\.runningApplications, options: [.old, .new]) { [weak self] _, change in
                let oldPIDs = Set((change.oldValue ?? []).map(\.processIdentifier))
                let newDock = (change.newValue ?? []).contains {
                    $0.bundleIdentifier == dockBundleID && !oldPIDs.contains($0.processIdentifier)
                }
                guard newDock else { return }
                Task { @MainActor in self?.dockRelaunched() }
            }
        }
        if observer == nil, attachTask == nil {
            attachOrRetry(attempt: 1)
        }
    }

    func stop() {
        appsObservation?.invalidate()
        appsObservation = nil
        attachTask?.cancel()
        attachTask = nil
        detach()
    }

    private func dockRelaunched() {
        Log.dock.notice("Dock relaunched, reattaching")
        detach()
        // The new Dock process needs a moment to build its AX tree.
        scheduleAttach(after: 1, attempt: 1)
    }

    /// Attaches now. On failure, tries again on the retry schedule, so one failure does not stop previews for good.
    private func attachOrRetry(attempt: Int) {
        attachTask = nil
        guard !attach() else { return }
        guard let delay = retry.delay(afterFailedAttempt: attempt) else {
            Log.dock.error("giving up attaching to the Dock after \(attempt) attempts")
            return
        }
        scheduleAttach(after: delay, attempt: attempt + 1)
    }

    private func scheduleAttach(after delay: TimeInterval, attempt: Int) {
        attachTask?.cancel()
        attachTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            self?.attachOrRetry(attempt: attempt)
        }
    }

    /// Returns false when any step fails. Detaches first, so a second call never leaves an old observer behind.
    @discardableResult
    private func attach() -> Bool {
        detach()
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: dockBundleID).first else {
            Log.dock.error("Dock process not found")
            return false
        }
        let pid = dock.processIdentifier
        let dockElement = AXUIElementCreateApplication(pid)
        guard let iconList = AX.elements(dockElement, kAXChildrenAttribute)
            .first(where: { AX.string($0, kAXRoleAttribute) == kAXListRole }) else {
            Log.dock.error("Dock icon list not found")
            return false
        }
        var created: AXObserver?
        guard AXObserverCreate(pid, selectionCallback, &created) == .success, let created else {
            Log.dock.error("AXObserverCreate failed")
            return false
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        let result = AXObserverAddNotification(created, iconList, kAXSelectedChildrenChangedNotification as CFString, refcon)
        guard result == .success else {
            Log.dock.error("AXObserverAddNotification failed: \(result.rawValue)")
            return false
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .commonModes)
        observer = created
        list = iconList
        Log.dock.notice("attached to Dock pid \(pid)")
        return true
    }

    private func detach() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        observer = nil
        list = nil
    }

    /// The current frame of the selected icon. It changes while an auto-hidden Dock slides in.
    func selectedIconFrame() -> CGRect? {
        guard let list, let item = AX.elements(list, kAXSelectedChildrenAttribute).first else { return nil }
        return AX.frame(item)
    }

    fileprivate func selectionChanged() {
        guard let list else { return }
        guard let item = AX.elements(list, kAXSelectedChildrenAttribute).first,
              DockItem.isApplication(subrole: AX.string(item, kAXSubroleAttribute)),
              let url = AX.url(item, kAXURLAttribute),
              let frame = AX.frame(item) else {
            onChange?(nil)
            return
        }
        let path = DockItem.normalizedPath(url.path(percentEncoded: false))
        let app = NSWorkspace.shared.runningApplications.first { running in
            guard let bundleURL = running.bundleURL else { return false }
            return DockItem.normalizedPath(bundleURL.path(percentEncoded: false)) == path
        }
        guard let app else {
            onChange?(nil)
            return
        }
        onChange?(DockHover(pid: app.processIdentifier, iconFrame: frame))
    }
}
