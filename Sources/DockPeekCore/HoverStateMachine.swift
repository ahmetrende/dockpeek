import Foundation

/// Decides when the preview panel opens and closes. Time is passed in, so tests control the clock.
public struct HoverStateMachine: Sendable {
    public enum Action: Equatable, Sendable {
        case show(pid: Int32)
        case close
    }

    public let openDelay: TimeInterval
    public let closeDelay: TimeInterval
    public private(set) var shownPID: Int32?
    /// The app whose panel opens when the open delay ends. Its windows can be captured during the delay.
    public private(set) var pendingShowPID: Int32?

    private var hoveredPID: Int32?
    private var pointerInPanel = false
    private var pendingShowAt: TimeInterval?
    private var pendingCloseAt: TimeInterval?

    public init(openDelay: TimeInterval, closeDelay: TimeInterval) {
        self.openDelay = openDelay
        self.closeDelay = closeDelay
    }

    public var nextDeadline: TimeInterval? {
        [pendingShowAt, pendingCloseAt].compactMap { $0 }.min()
    }

    public mutating func iconHovered(pid: Int32, now: TimeInterval) {
        hoveredPID = pid
        pendingCloseAt = nil
        if shownPID == pid {
            clearPendingShow()
        } else if pendingShowPID != pid {
            pendingShowPID = pid
            pendingShowAt = now + openDelay
        }
    }

    public mutating func iconLeft(now: TimeInterval) {
        hoveredPID = nil
        clearPendingShow()
        if shownPID != nil, !pointerInPanel {
            pendingCloseAt = now + closeDelay
        }
    }

    public mutating func pointerEnteredPanel() {
        pointerInPanel = true
        hoveredPID = nil
        pendingCloseAt = nil
    }

    public mutating func pointerExitedPanel(now: TimeInterval) {
        pointerInPanel = false
        if shownPID != nil, hoveredPID == nil {
            pendingCloseAt = now + closeDelay
        }
    }

    public mutating func advance(to now: TimeInterval) -> [Action] {
        var actions: [Action] = []
        if let pid = pendingShowPID, let at = pendingShowAt, now >= at {
            clearPendingShow()
            shownPID = pid
            actions.append(.show(pid: pid))
        }
        if let at = pendingCloseAt, now >= at {
            pendingCloseAt = nil
            shownPID = nil
            pointerInPanel = false
            actions.append(.close)
        }
        return actions
    }

    public mutating func dismiss() -> [Action] {
        let wasShown = shownPID != nil
        shownPID = nil
        hoveredPID = nil
        pointerInPanel = false
        pendingCloseAt = nil
        clearPendingShow()
        return wasShown ? [.close] : []
    }

    private mutating func clearPendingShow() {
        pendingShowPID = nil
        pendingShowAt = nil
    }
}
