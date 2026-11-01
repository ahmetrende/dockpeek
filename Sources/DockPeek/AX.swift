import ApplicationServices
import CoreGraphics
import Foundation

// The only private API in DockPeek (design document, section 4).
@_silgen_name("_AXUIElementGetWindow")
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Typed wrappers around the Accessibility C API.
enum AX {
    /// Upper bound for one AX request to another app, in seconds.
    static let messagingTimeout: Float = 0.5

    /// Sets the global timeout so that a hung app cannot block DockPeek for long.
    static func configureTimeout() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), messagingTimeout)
    }

    static func copy(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    static func string(_ element: AXUIElement, _ attribute: String) -> String? {
        copy(element, attribute) as? String
    }

    static func bool(_ element: AXUIElement, _ attribute: String) -> Bool? {
        copy(element, attribute) as? Bool
    }

    static func url(_ element: AXUIElement, _ attribute: String) -> URL? {
        copy(element, attribute) as? URL
    }

    static func elements(_ element: AXUIElement, _ attribute: String) -> [AXUIElement] {
        copy(element, attribute) as? [AXUIElement] ?? []
    }

    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = axValue(element, kAXPositionAttribute),
              let size = axValue(element, kAXSizeAttribute) else { return nil }
        var point = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(position, .cgPoint, &point),
              AXValueGetValue(size, .cgSize, &extent) else { return nil }
        return CGRect(origin: point, size: extent)
    }

    @discardableResult
    static func set(_ element: AXUIElement, _ attribute: String, _ value: Bool) -> AXError {
        AXUIElementSetAttributeValue(element, attribute as CFString, NSNumber(value: value) as CFTypeRef)
    }

    @discardableResult
    static func perform(_ element: AXUIElement, _ action: String) -> AXError {
        AXUIElementPerformAction(element, action as CFString)
    }

    static func windowID(_ element: AXUIElement) -> CGWindowID? {
        var id: CGWindowID = 0
        guard _AXUIElementGetWindow(element, &id) == .success, id != 0 else { return nil }
        return id
    }

    private static func axValue(_ element: AXUIElement, _ attribute: String) -> AXValue? {
        guard let value = copy(element, attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return unsafeBitCast(value, to: AXValue.self)
    }
}
