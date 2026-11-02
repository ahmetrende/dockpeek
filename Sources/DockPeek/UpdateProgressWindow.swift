import AppKit
import DockPeekCore

/// The small window that shows an update while it runs. DockPeek quits for the restart right after
/// the last step, which closes it. On a failure it closes before the failure alert opens.
@MainActor
final class UpdateProgressWindow {
    private static let width: CGFloat = 340
    private let window: NSWindow
    private let bar = NSProgressIndicator()
    private let stepLabel = NSTextField(labelWithString: "")
    private let strings: UIStrings
    private var downloadDone = false

    init(version: String, strings: UIStrings) {
        self.strings = strings
        window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.title = "DockPeek"
        window.isReleasedWhenClosed = false

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 52).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let title = NSTextField(labelWithString: strings.updatingTo(version))
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        bar.style = .bar
        bar.minValue = 0
        bar.maxValue = 1
        // Keeps the bar moving while the main thread is busy.
        bar.usesThreadedAnimation = true
        stepLabel.font = .systemFont(ofSize: 11)
        stepLabel.textColor = .secondaryLabelColor

        let text = NSStackView(views: [title, bar, stepLabel])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 8
        bar.widthAnchor.constraint(equalTo: text.widthAnchor).isActive = true

        let content = NSStackView(views: [icon, text])
        content.orientation = .horizontal
        content.alignment = .top
        content.spacing = 14
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        content.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: Self.width, height: content.fittingSize.height))
        update(.downloading(fraction: nil))
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func update(_ step: UpdateStep) {
        // Download progress can arrive after the next step has started. It must not move the window back.
        if case .downloading = step {
            guard !downloadDone else { return }
        } else {
            downloadDone = true
        }
        stepLabel.stringValue = strings.updateStepText(step)
        if case .downloading(let fraction?) = step {
            bar.stopAnimation(nil)
            bar.isIndeterminate = false
            bar.doubleValue = fraction
        } else {
            bar.isIndeterminate = true
            bar.startAnimation(nil)
        }
    }

    func close() {
        window.close()
    }
}
