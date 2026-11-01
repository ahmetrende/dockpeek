import AppKit
import ApplicationServices
import DockPeekCore

struct AppWindow {
    let id: CGWindowID
    let title: String
    let size: CGSize
    let isMinimized: Bool
    let element: AXUIElement
}

@MainActor
enum WindowLister {
    /// Upper bound for listing one app, in seconds. AX calls run on the main thread.
    static let listBudget: TimeInterval = 0.5

    static func windows(of pid: pid_t, minSide: CGFloat) -> [AppWindow] {
        let appElement = AXUIElementCreateApplication(pid)
        let app = NSRunningApplication(processIdentifier: pid)
        let appName = app?.localizedName ?? ""
        let appIsHidden = app?.isHidden ?? false
        // A slow app keeps answering within the per-call timeout, so the whole list also has a time limit.
        let elements = AX.elements(appElement, kAXWindowsAttribute)
        return Budgeted.map(elements, budget: listBudget, now: { ProcessInfo.processInfo.systemUptime }) { element -> AppWindow? in
            guard let id = AX.windowID(element) else { return nil }
            let candidate = WindowCandidate(
                id: id,
                title: WindowTitle.display(AX.string(element, kAXTitleAttribute), appName: appName),
                size: AX.frame(element)?.size ?? .zero,
                subrole: AX.string(element, kAXSubroleAttribute),
                isMinimized: AX.bool(element, kAXMinimizedAttribute) ?? false,
                appIsHidden: appIsHidden
            )
            guard WindowFilter.keep(candidate, minSide: minSide) else { return nil }
            return AppWindow(
                id: id,
                title: candidate.title,
                size: candidate.size,
                isMinimized: candidate.isMinimized,
                element: element
            )
        }
    }
}
