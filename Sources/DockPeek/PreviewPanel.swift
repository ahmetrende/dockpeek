import AppKit
import DockPeekCore

struct PanelItem {
    let id: CGWindowID
    let title: String
    let thumbnailSize: CGSize
    let icon: NSImage
    let image: CGImage?
}

@MainActor
final class PreviewPanel {
    var onPointerEntered: (() -> Void)?
    var onPointerExited: (() -> Void)?
    var onSelect: ((CGWindowID) -> Void)?

    private let gap: CGFloat
    private let metrics = PanelMetrics()
    private let panel: NSPanel
    private let background = TrackingEffectView()
    private var views: [CGWindowID: ThumbnailView] = [:]
    private var thumbnailSizes: [CGSize] = []

    var frame: CGRect { panel.frame }

    init(gap: CGFloat) {
        self.gap = gap
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        // DockPeek is never the active app, so the panel must not hide on deactivation.
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]

        background.material = .hudWindow
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 12
        background.layer?.masksToBounds = true
        background.onEnter = { [weak self] in self?.onPointerEntered?() }
        background.onExit = { [weak self] in self?.onPointerExited?() }
        panel.contentView = background
    }

    func show(_ items: [PanelItem], iconFrameAX: CGRect) {
        thumbnailSizes = items.map(\.thumbnailSize)
        guard let layout = layout(iconFrameAX: iconFrameAX) else { return }

        removeThumbnails()
        for (index, item) in items.enumerated() {
            let view = ThumbnailView(item: item, imageFrame: layout.imageFrames[index], titleFrame: layout.titleFrames[index])
            view.onClick = { [weak self] in self?.onSelect?(item.id) }
            background.addSubview(view)
            views[item.id] = view
        }
        panel.setFrame(layout.panelFrame, display: true)
        panel.orderFrontRegardless()
    }

    /// Moves the open panel above the icon's new frame. The thumbnails keep their size.
    func reposition(iconFrameAX: CGRect) {
        guard panel.isVisible, let layout = layout(iconFrameAX: iconFrameAX) else { return }
        panel.setFrame(layout.panelFrame, display: true)
    }

    private func layout(iconFrameAX: CGRect) -> PanelLayoutResult? {
        guard let primary = NSScreen.screens.first else { return nil }
        let iconFrame = ScreenGeometry.appKitRect(fromAX: iconFrameAX, primaryScreenHeight: primary.frame.height)
        let center = CGPoint(x: iconFrame.midX, y: iconFrame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? primary
        return PanelLayout.compute(
            thumbnails: thumbnailSizes,
            iconFrame: iconFrame,
            visibleFrame: screen.visibleFrame,
            gap: gap,
            metrics: metrics
        )
    }

    /// Images for windows that are not in the current panel are ignored.
    func setImage(_ image: CGImage, for id: CGWindowID) {
        views[id]?.setImage(image)
    }

    func close() {
        panel.orderOut(nil)
        removeThumbnails()
    }

    private func removeThumbnails() {
        views.values.forEach { $0.removeFromSuperview() }
        views = [:]
    }
}

private final class TrackingEffectView: NSVisualEffectView {
    var onEnter: (() -> Void)?
    var onExit: (() -> Void)?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { onEnter?() }
    override func mouseExited(with event: NSEvent) { onExit?() }
}

private final class ThumbnailView: NSView {
    var onClick: (() -> Void)?

    private let imageView = NSImageView()
    private let imageSize: CGSize

    init(item: PanelItem, imageFrame: CGRect, titleFrame: CGRect) {
        let frame = imageFrame.union(titleFrame)
        imageSize = imageFrame.size
        super.init(frame: frame)

        imageView.frame = imageFrame.offsetBy(dx: -frame.minX, dy: -frame.minY)
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = item.image.map { NSImage(cgImage: $0, size: imageFrame.size) } ?? item.icon
        addSubview(imageView)

        let label = NSTextField(labelWithString: item.title)
        label.frame = titleFrame.offsetBy(dx: -frame.minX, dy: -frame.minY)
        label.font = .systemFont(ofSize: 11)
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.textColor = .labelColor
        addSubview(label)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func setImage(_ image: CGImage) {
        imageView.image = NSImage(cgImage: image, size: imageSize)
    }

    // The panel never becomes key, so the first click must reach the view.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {}

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if bounds.contains(point) {
            onClick?()
        }
    }
}
