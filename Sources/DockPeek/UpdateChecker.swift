import AppKit
import DockPeekCore

/// Checks GitHub for a newer release and asks before installing it.
@MainActor
final class UpdateChecker {
    private static let latestReleaseURL = URL(string: "https://api.github.com/repos/ahmetrende/dockpeek/releases/latest")!
    /// For local tests only: points the check at another address.
    private static let feedOverrideKey = "UpdateFeedURL"
    private static let declinedVersionKey = "UpdateDeclinedVersion"
    private static let declinedAtKey = "UpdateDeclinedAt"

    /// Runs right before the question opens, so the preview panel can close first.
    var onWillPrompt: (() -> Void)?

    private let current: AppVersion
    private let installer: UpdateInstaller
    private var timer: Timer?
    private var busy = false
    private var lastCheck: Date?
    private var wakeObserver: NSObjectProtocol?

    /// Nil for builds made from source: only release builds check for updates.
    init?(bundle: Bundle = .main) {
        guard bundle.object(forInfoDictionaryKey: "DockPeekReleaseBuild") as? Bool == true,
              let text = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let current = AppVersion(text) else { return nil }
        self.current = current
        installer = UpdateInstaller(current: current)
    }

    func start() {
        schedule(after: UpdatePolicy.firstCheckDelay)
        // A run-loop timer does not count sleep time. After wake, the clock times the next check.
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.didWake() }
        }
    }

    private func schedule(after delay: TimeInterval) {
        timer?.invalidate()
        let next = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(next, forMode: .common)
        timer = next
    }

    private func didWake() {
        guard let lastCheck else { return }
        // The network is often not back right after wake.
        schedule(after: max(UpdatePolicy.firstCheckDelay, UpdatePolicy.nextCheckDelay(lastCheck: lastCheck, now: Date())))
    }

    private func check() {
        lastCheck = Date()
        schedule(after: UpdatePolicy.checkInterval)
        guard !busy else { return }
        busy = true
        Task { @MainActor in
            let decision = await fetchDecision()
            switch decision {
            case .upToDate:
                Log.update.notice("up to date at \(self.current.description, privacy: .public)")
            case .unusable(let reason):
                Log.update.error("update check unusable: \(reason, privacy: .public)")
            case .available(let version, let zipURL):
                Log.update.notice("version \(version.description, privacy: .public) is available")
                await askAndInstall(version, zipURL)
            }
            busy = false
        }
    }

    private func fetchDecision() async -> UpdateDecision {
        var request = URLRequest(url: feedURL(), timeoutInterval: 15)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("DockPeek/\(current)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { return .unusable("HTTP \(status)") }
            return UpdateCheck.decide(current: current, response: data)
        } catch {
            return .unusable(error.localizedDescription)
        }
    }

    private func feedURL() -> URL {
        UserDefaults.standard.string(forKey: Self.feedOverrideKey).flatMap(URL.init(string:)) ?? Self.latestReleaseURL
    }

    private func askAndInstall(_ version: AppVersion, _ zipURL: URL) async {
        guard UpdatePolicy.shouldAsk(about: version, declined: storedDeclined(), now: Date()) else {
            Log.update.notice("version \(version.description, privacy: .public) was put off")
            return
        }
        onWillPrompt?()
        let strings = CurrentLanguage.strings
        let alert = NSAlert()
        alert.messageText = strings.updateAvailable(version.description)
        alert.informativeText = strings.youHave(current.description)
        alert.addButton(withTitle: strings.updateNow)
        alert.addButton(withTitle: strings.later)
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else {
            // The time of the check that found this version, so the next daily check asks again.
            storeDeclined(DeclinedUpdate(version: version, at: lastCheck ?? Date()))
            return
        }
        do {
            try await installer.install(from: zipURL)
        } catch {
            showFailure(error as? UpdateFailure ?? .download)
        }
    }

    private func showFailure(_ failure: UpdateFailure) {
        Log.update.error("update failed: \(String(describing: failure), privacy: .public)")
        let strings = CurrentLanguage.strings
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = strings.updateFailedTitle
        alert.informativeText = strings.updateFailed(failure, keeping: current.description)
        NSApp.activate()
        alert.runModal()
    }

    private func storedDeclined() -> DeclinedUpdate? {
        let defaults = UserDefaults.standard
        guard let text = defaults.string(forKey: Self.declinedVersionKey),
              let version = AppVersion(text),
              let at = defaults.object(forKey: Self.declinedAtKey) as? Date else { return nil }
        return DeclinedUpdate(version: version, at: at)
    }

    private func storeDeclined(_ declined: DeclinedUpdate) {
        UserDefaults.standard.set(declined.version.description, forKey: Self.declinedVersionKey)
        UserDefaults.standard.set(declined.at, forKey: Self.declinedAtKey)
    }
}
