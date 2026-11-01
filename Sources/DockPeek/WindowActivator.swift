import AppKit
import ApplicationServices

@MainActor
enum WindowActivator {
    /// Brings one window to the front. If the window is gone, only the app is activated.
    static func activate(_ window: AppWindow, pid: pid_t) {
        if AX.bool(window.element, kAXMinimizedAttribute) == true {
            let result = AX.set(window.element, kAXMinimizedAttribute, false)
            if result != .success {
                Log.panel.error("unminimize failed for window \(window.id): \(result.rawValue)")
            }
        }
        // A window of a hidden (Cmd+H) app cannot come to the front until the app is shown again.
        if let app = NSRunningApplication(processIdentifier: pid), app.isHidden {
            app.unhide()
        }
        let appElement = AXUIElementCreateApplication(pid)
        let frontmost = AX.set(appElement, kAXFrontmostAttribute, true)
        let main = AX.set(window.element, kAXMainAttribute, true)
        let raise = AX.perform(window.element, kAXRaiseAction)
        Log.panel.notice("activate window \(window.id): frontmost \(frontmost.rawValue), main \(main.rawValue), raise \(raise.rawValue)")
        if raise != .success {
            _ = NSRunningApplication(processIdentifier: pid)?.activate(options: [])
        }
    }
}
