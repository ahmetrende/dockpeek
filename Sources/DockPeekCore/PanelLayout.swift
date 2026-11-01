import CoreGraphics

public struct PanelMetrics: Equatable, Sendable {
    public var padding: CGFloat = 12
    public var spacing: CGFloat = 12
    public var titleHeight: CGFloat = 18
    public var edgeMargin: CGFloat = 8

    public init() {}
}

public struct PanelLayoutResult: Equatable, Sendable {
    public let panelFrame: CGRect
    /// Panel coordinates, bottom-left origin.
    public let imageFrames: [CGRect]
    /// Panel coordinates, bottom-left origin.
    public let titleFrames: [CGRect]
}

public enum PanelLayout {
    /// Places one row of thumbnails above the icon. Thumbnails shrink when the row does not fit the screen.
    public static func compute(
        thumbnails: [CGSize],
        iconFrame: CGRect,
        visibleFrame: CGRect,
        gap: CGFloat,
        metrics: PanelMetrics
    ) -> PanelLayoutResult {
        let spacingTotal = metrics.spacing * CGFloat(max(thumbnails.count - 1, 0))
        let naturalWidth = thumbnails.reduce(0) { $0 + $1.width }
        let available = visibleFrame.width - 2 * metrics.edgeMargin - 2 * metrics.padding - spacingTotal
        let scale = naturalWidth > available && naturalWidth > 0 ? max(available, 0) / naturalWidth : 1
        let sizes = thumbnails.map {
            CGSize(width: ($0.width * scale).rounded(.down), height: ($0.height * scale).rounded(.down))
        }

        let imageAreaHeight = sizes.map(\.height).max() ?? 0
        let width = 2 * metrics.padding + sizes.reduce(0) { $0 + $1.width } + spacingTotal
        let height = 2 * metrics.padding + imageAreaHeight + metrics.titleHeight

        let minX = visibleFrame.minX + metrics.edgeMargin
        let maxX = max(visibleFrame.maxX - metrics.edgeMargin - width, minX)
        let x = min(max(iconFrame.midX - width / 2, minX), maxX)
        let panelFrame = CGRect(x: x, y: iconFrame.maxY + gap, width: width, height: height)

        var imageFrames: [CGRect] = []
        var titleFrames: [CGRect] = []
        var cursor = metrics.padding
        for size in sizes {
            let imageY = metrics.padding + metrics.titleHeight + (imageAreaHeight - size.height) / 2
            imageFrames.append(CGRect(x: cursor, y: imageY, width: size.width, height: size.height))
            titleFrames.append(CGRect(x: cursor, y: metrics.padding, width: size.width, height: metrics.titleHeight))
            cursor += size.width + metrics.spacing
        }
        return PanelLayoutResult(panelFrame: panelFrame, imageFrames: imageFrames, titleFrames: titleFrames)
    }
}
