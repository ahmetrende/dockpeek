import CoreGraphics
import Foundation

public struct WindowCandidate: Equatable, Sendable {
    public let id: UInt32
    public let title: String
    public let size: CGSize
    public let subrole: String?
    public let isMinimized: Bool
    public let appIsHidden: Bool

    public init(id: UInt32, title: String, size: CGSize, subrole: String?, isMinimized: Bool, appIsHidden: Bool = false) {
        self.id = id
        self.title = title
        self.size = size
        self.subrole = subrole
        self.isMinimized = isMinimized
        self.appIsHidden = appIsHidden
    }
}

public enum WindowFilter {
    public static func keep(_ window: WindowCandidate, minSide: CGFloat) -> Bool {
        // macOS 27 reports minimized windows and all windows of a hidden app with the AXDialog subrole,
        // so those skip the subrole check.
        (window.subrole == "AXStandardWindow" || window.isMinimized || window.appIsHidden)
            && window.size.width >= minSide
            && window.size.height >= minSide
    }
}

public enum DockItem {
    public static func isApplication(subrole: String?) -> Bool {
        subrole == "AXApplicationDockItem"
    }

    public static func normalizedPath(_ path: String) -> String {
        var result = path
        while result.count > 1, result.hasSuffix("/") {
            result.removeLast()
        }
        return result
    }
}

public enum WindowTitle {
    public static func display(_ title: String?, appName: String) -> String {
        let trimmed = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? appName : trimmed
    }
}
