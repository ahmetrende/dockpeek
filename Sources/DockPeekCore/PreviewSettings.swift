import CoreGraphics
import Foundation

/// Default values from the design document, section 7.
public struct PreviewSettings: Equatable, Sendable {
    public var openDelay: TimeInterval = 0.150
    public var closeDelay: TimeInterval = 0.200
    public var thumbnailWidth: CGFloat = 240
    public var thumbnailMaxHeight: CGFloat = 180
    public var panelGap: CGFloat = 8
    public var minWindowSide: CGFloat = 50
    public var cacheLimit: Int = 20

    public init() {}
}
