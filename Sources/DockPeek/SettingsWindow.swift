import AppKit
import DockPeekCore
import ServiceManagement

/// The window that opens when DockPeek is opened again (design document, section 6.6).
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    var onAccessibilityChanged: (() -> Void)?

    private static let width: CGFloat = 460
    private static let repository = "github.com/ahmetrende/dockpeek"
    private var strings: UIStrings
    private let window: NSWindow
    /// Nil for builds made from source. They do not check for updates, so the Updates row is left out.
    private let updateChecker: UpdateChecker?
    private let loginSwitch = NSSwitch()
    private let languagePopup = NSPopUpButton()
    private var accessibilityRow: PermissionRow?
    private var screenRow: PermissionRow?
    private var updatesRow: UpdatesRow?
    private let helpLabel = NSTextField(wrappingLabelWithString: "")
    private var pollTimer: Timer?
    private var lastAccessibility = Permissions.accessibility

    var isVisible: Bool { window.isVisible }

    init(updateChecker: UpdateChecker?) {
        strings = CurrentLanguage.strings
        self.updateChecker = updateChecker
        window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: true)
        super.init()
        window.title = "DockPeek"
        window.isReleasedWhenClosed = false
        window.delegate = self
        loginSwitch.target = self
        loginSwitch.action = #selector(loginChanged)
        languagePopup.target = self
        languagePopup.action = #selector(languageChanged)
        buildContent()
    }

    func show() {
        refresh()
        startPolling()
        // The Dock icon is visible only while this window is open (design document, section 6.6).
        NSApp.setActivationPolicy(.regular)
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        pollTimer?.invalidate()
        pollTimer = nil
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Layout

    /// Builds the window's views in the current language. A language change builds them again.
    private func buildContent() {
        let accessibilityRow = PermissionRow(title: strings.accessibility, strings: strings)
        accessibilityRow.button.target = self
        accessibilityRow.button.action = #selector(openAccessibility)
        let screenRow = PermissionRow(title: strings.screenRecording, strings: strings)
        screenRow.button.target = self
        screenRow.button.action = #selector(openScreenRecording)
        self.accessibilityRow = accessibilityRow
        self.screenRow = screenRow
        var generalRows = [
            row(strings.openAtLogin, accessory: loginSwitch),
            row(strings.language, accessory: languagePopup),
        ]
        updatesRow = nil
        if updateChecker != nil {
            let updatesRow = UpdatesRow(strings: strings)
            updatesRow.button.target = self
            updatesRow.button.action = #selector(checkForUpdates)
            self.updatesRow = updatesRow
            generalRows.append(updatesRow.view)
        }

        // Language names stay in their own language.
        languagePopup.removeAllItems()
        languagePopup.addItems(withTitles: [strings.automatic, "English", "Türkçe"])
        languagePopup.selectItem(at: LanguageChoice.allCases.firstIndex(of: CurrentLanguage.choice) ?? 0)

        helpLabel.font = .systemFont(ofSize: 11)
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.preferredMaxLayoutWidth = Self.width - 48

        let content = NSStackView(views: [
            header(),
            section(strings.general, rows: generalRows),
            section(strings.permissions, rows: [accessibilityRow.view, screenRow.view], note: helpLabel),
            about(),
            footer(),
        ])
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 16
        content.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 16, right: 20)
        content.widthAnchor.constraint(equalToConstant: Self.width).isActive = true
        for view in content.arrangedSubviews {
            view.widthAnchor.constraint(equalTo: content.widthAnchor, constant: -40).isActive = true
        }
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        window.setContentSize(NSSize(width: Self.width, height: content.fittingSize.height))
    }

    private func header() -> NSView {
        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.widthAnchor.constraint(equalToConstant: 52).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 52).isActive = true

        let name = NSTextField(labelWithString: "DockPeek")
        name.font = .systemFont(ofSize: 17, weight: .semibold)
        let info = Bundle.main.infoDictionary ?? [:]
        var lines: [NSView] = [name, secondaryLabel(strings.version(info["CFBundleShortVersionString"] as? String ?? "?"), size: 13)]
        // build-app.sh writes this key from the last commit, in UTC.
        if let date = info["DockPeekCommitDate"] as? String {
            lines.append(secondaryLabel(strings.lastCommit(date), size: 11))
        }
        let text = NSStackView(views: lines)
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 2

        let stack = NSStackView(views: [icon, text])
        stack.orientation = .horizontal
        stack.alignment = .centerY
        stack.spacing = 14
        return stack
    }

    private func sectionHeading(_ title: String) -> NSTextField {
        let heading = secondaryLabel(title, size: 11)
        heading.font = .systemFont(ofSize: 11, weight: .semibold)
        return heading
    }

    private func section(_ title: String, rows: [NSView], note: NSView? = nil) -> NSView {
        let heading = sectionHeading(title)

        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 0
        for (index, row) in rows.enumerated() {
            if index > 0 {
                let line = separator()
                list.addArrangedSubview(line)
                line.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
            }
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        let box = GroupBox(content: list)

        let stack = NSStackView(views: [heading, box] + (note.map { [$0] } ?? []))
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        box.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func row(_ title: String, accessory: NSView) -> NSView {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
        stack.setViews([NSTextField(labelWithString: title)], in: .leading)
        stack.setViews([accessory], in: .trailing)
        stack.heightAnchor.constraint(equalToConstant: 44).isActive = true
        return stack
    }

    /// Plain text under its heading, without a group box: it is information, not a setting.
    private func about() -> NSView {
        let text = NSTextField(wrappingLabelWithString: strings.aboutText)
        text.preferredMaxLayoutWidth = Self.width - 40
        // A link label, not a borderless button: a button's inset moves it off the text's left edge.
        let link = NSTextField(labelWithAttributedString: NSAttributedString(
            string: Self.repository,
            attributes: [.link: URL(string: "https://\(Self.repository)") as Any, .font: NSFont.systemFont(ofSize: 11)]
        ))
        link.isSelectable = true
        let stack = NSStackView(views: [sectionHeading(strings.about), text, link])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.setCustomSpacing(8, after: text)
        return stack
    }

    private func footer() -> NSView {
        // Standard push buttons side by side at the right edge, default button last, like a macOS dialog.
        let quit = NSButton(title: strings.quit, target: self, action: #selector(quit))
        quit.hasDestructiveAction = true
        let hide = NSButton(title: strings.hideWindow, target: self, action: #selector(hideWindow))
        // Return presses the default button, which macOS draws in the accent color.
        hide.keyEquivalent = "\r"

        let bar = NSStackView()
        bar.orientation = .horizontal
        bar.spacing = 12
        bar.setViews([quit, hide], in: .trailing)

        let line = separator()
        let stack = NSStackView(views: [line, bar])
        stack.orientation = .vertical
        stack.spacing = 12
        line.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        bar.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
        return stack
    }

    private func secondaryLabel(_ text: String, size: CGFloat) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: size)
        label.textColor = .secondaryLabelColor
        return label
    }

    private func separator() -> NSBox {
        let line = NSBox()
        line.boxType = .separator
        return line
    }

    // MARK: - State

    private func refresh() {
        loginSwitch.state = SMAppService.mainApp.status == .enabled ? .on : .off
        let accessibility = Permissions.accessibility
        let screen = Permissions.screenRecording
        accessibilityRow?.update(granted: accessibility)
        screenRow?.update(granted: screen)
        helpLabel.stringValue = !accessibility ? strings.accessibilityMissingHelp
            : !screen ? strings.screenRecordingMissingHelp
            : strings.permissionsHelp
        // The once-per-second poll also shows the result of a running check.
        if let updateChecker {
            updatesRow?.update(updateChecker.status)
        }
    }

    /// Polls once per second, only while the window is open (design document, section 8).
    private func startPolling() {
        pollTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func poll() {
        let granted = Permissions.accessibility
        if granted != lastAccessibility {
            lastAccessibility = granted
            onAccessibilityChanged?()
        }
        refresh()
    }

    // MARK: - Actions

    @objc private func loginChanged() {
        do {
            if loginSwitch.state == .on {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Log.app.error("login item change failed: \(error.localizedDescription, privacy: .public)")
        }
        refresh()
    }

    @objc private func languageChanged() {
        let index = languagePopup.indexOfSelectedItem
        guard LanguageChoice.allCases.indices.contains(index) else { return }
        let choice = LanguageChoice.allCases[index]
        UserDefaults.standard.set(choice.rawValue, forKey: CurrentLanguage.key)
        strings = UIStrings(choice.resolve(preferredLanguages: Locale.preferredLanguages))
        buildContent()
        refresh()
    }

    @objc private func openAccessibility() {
        Permissions.requestAccessibility()
        Permissions.openSystemSettings(.accessibility)
    }

    @objc private func openScreenRecording() {
        Permissions.requestScreenRecording()
        Permissions.openSystemSettings(.screenRecording)
    }

    @objc private func checkForUpdates() {
        updateChecker?.checkNow()
        refresh()
    }

    /// Closes the window. DockPeek keeps running without a Dock icon.
    @objc private func hideWindow() {
        window.close()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

/// A 44 pt line: the title on the left, then an icon, a status text and a small button on the right.
@MainActor
private func statusLine(title: String, icon: NSImageView, status: NSTextField, button: NSButton) -> NSStackView {
    button.controlSize = .small
    let state = NSStackView(views: [icon, status, button])
    state.orientation = .horizontal
    state.spacing = 6
    // Without this the status group stretches and sits next to the title instead of at the right edge.
    state.setHuggingPriority(.required, for: .horizontal)
    let view = NSStackView()
    view.orientation = .horizontal
    view.edgeInsets = NSEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)
    view.setViews([NSTextField(labelWithString: title)], in: .leading)
    view.setViews([state], in: .trailing)
    view.heightAnchor.constraint(equalToConstant: 44).isActive = true
    return view
}

/// One permission line: name, status and a button that shows only while the permission is missing.
@MainActor
private final class PermissionRow {
    let view: NSStackView
    let button: NSButton
    private let icon = NSImageView()
    private let status = NSTextField(labelWithString: "")
    private let strings: UIStrings

    init(title: String, strings: UIStrings) {
        self.strings = strings
        button = NSButton(title: strings.openSettings, target: nil, action: nil)
        view = statusLine(title: title, icon: icon, status: status, button: button)
    }

    func update(granted: Bool) {
        let color: NSColor = granted ? .statusGood : .statusBad
        icon.image = NSImage(
            systemSymbolName: granted ? "checkmark.circle" : "exclamationmark.circle",
            accessibilityDescription: nil
        )
        icon.contentTintColor = color
        status.stringValue = granted ? strings.allowed : strings.notAllowed
        status.textColor = color
        button.isHidden = granted
    }
}

/// The Updates line: the result of the last check and the Check Now button.
@MainActor
private final class UpdatesRow {
    let view: NSStackView
    let button: NSButton
    private let icon = NSImageView()
    private let status = NSTextField(labelWithString: "")
    private let strings: UIStrings

    init(strings: UIStrings) {
        self.strings = strings
        button = NSButton(title: strings.checkNow, target: nil, action: nil)
        view = statusLine(title: strings.updates, icon: icon, status: status, button: button)
    }

    func update(_ check: UpdateCheckStatus) {
        status.stringValue = strings.updateStatus(check)
        switch check {
        case .upToDate:
            icon.image = NSImage(systemSymbolName: "checkmark.circle", accessibilityDescription: nil)
            icon.contentTintColor = .statusGood
            status.textColor = .statusGood
        case .failed:
            icon.image = NSImage(systemSymbolName: "exclamationmark.circle", accessibilityDescription: nil)
            icon.contentTintColor = .statusBad
            status.textColor = .statusBad
        case .idle, .checking, .available:
            icon.image = nil
            status.textColor = .secondaryLabelColor
        }
        icon.isHidden = icon.image == nil
        button.isEnabled = check != .checking
    }
}

/// A rounded group like the ones in System Settings. Colors follow light and dark mode.
private final class GroupBox: NSView {
    init(content: NSView) {
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var wantsUpdateLayer: Bool { true }

    // Dynamic colors resolve for the current appearance here.
    override func updateLayer() {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
    }
}

private extension NSColor {
    /// Status text colors with at least 4.5:1 contrast in light and dark mode.
    static let statusGood = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 0.19, green: 0.82, blue: 0.35, alpha: 1)
            : NSColor(srgbRed: 0.10, green: 0.50, blue: 0.22, alpha: 1)
    }

    static let statusBad = NSColor(name: nil) { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            ? NSColor(srgbRed: 1.00, green: 0.41, blue: 0.38, alpha: 1)
            : NSColor(srgbRed: 0.70, green: 0.15, blue: 0.12, alpha: 1)
    }
}
