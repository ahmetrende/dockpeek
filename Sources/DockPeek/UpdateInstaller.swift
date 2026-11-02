import AppKit
import DockPeekCore
import Security

/// Downloads a release zip, checks it, swaps it in for the running app and restarts DockPeek.
@MainActor
final class UpdateInstaller {
    private static let justUpdatedKey = "ShowSettingsAfterUpdate"
    private let current: AppVersion

    init(current: AppVersion) {
        self.current = current
    }

    /// True once, on the first launch after an update. The settings window then shows the new version.
    static func takeJustUpdated() -> Bool {
        let value = UserDefaults.standard.bool(forKey: justUpdatedKey)
        UserDefaults.standard.removeObject(forKey: justUpdatedKey)
        return value
    }

    /// Throws only `UpdateFailure`. On success DockPeek quits and the new version opens.
    /// Every failure logs its cause first, because `UpdateFailure` keeps only the step name.
    /// `progress` gets each step on the main thread, for the update window.
    func install(from zipURL: URL, progress: @escaping @MainActor (UpdateStep) -> Void) async throws {
        let files = FileManager.default
        let work = files.temporaryDirectory.appendingPathComponent("DockPeek-update-\(UUID().uuidString)")
        defer { try? files.removeItem(at: work) }

        // 1. Download.
        progress(.downloading(fraction: nil))
        let zip = work.appendingPathComponent(UpdateCheck.assetName)
        do {
            try files.createDirectory(at: work, withIntermediateDirectories: true)
            let reporter = DownloadProgress { fraction in
                Task { @MainActor in progress(.downloading(fraction: fraction)) }
            }
            let (downloaded, response) = try await URLSession.shared.download(from: zipURL, delegate: reporter)
            // 0 when the response is not HTTP.
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                Log.update.error("download failed: HTTP status \(status, privacy: .public)")
                throw UpdateFailure.download
            }
            try files.moveItem(at: downloaded, to: zip)
        } catch is UpdateFailure {
            throw UpdateFailure.download
        } catch {
            Log.update.error("download failed: \(Self.describe(error), privacy: .public)")
            throw UpdateFailure.download
        }

        // 2. Unpack. Steps 2 and 3 run off the main thread, so the update window keeps moving.
        progress(.verifying)
        let newApp = work.appendingPathComponent("DockPeek.app")
        let unpackStatus = await Task.detached { Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, work.path]) }.value
        guard unpackStatus == 0 else {
            Log.update.error("unpack failed: ditto exit status \(unpackStatus, privacy: .public)")
            throw UpdateFailure.unpack
        }
        guard files.fileExists(atPath: newApp.path) else {
            Log.update.error("unpack failed: DockPeek.app is missing in the zip")
            throw UpdateFailure.unpack
        }

        // 3. Check: same signer as this app, and a newer version.
        guard await Task.detached(operation: { Self.isSignedLikeRunningApp(newApp) }).value else {
            throw UpdateFailure.signature
        }
        let text = Bundle(url: newApp)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let text, let newVersion = AppVersion(text), newVersion > current else {
            Log.update.error("""
                version check failed: the new app has version \(text ?? "none", privacy: .public), \
                this app has \(self.current.description, privacy: .public)
                """)
            throw UpdateFailure.notNewer
        }

        // 4. Write access. A copy that runs from a disk image or a quarantine location cannot update itself.
        progress(.installing)
        let target = Bundle.main.bundleURL
        let folder = target.deletingLastPathComponent().path
        guard files.isWritableFile(atPath: folder),
              files.isWritableFile(atPath: target.path) else {
            Log.update.error("write check failed: no write access to the app or its folder \(folder, privacy: .public)")
            throw UpdateFailure.cannotWrite
        }

        // 5. Restart helper: waits until this process ends, then opens the new version.
        let helper = Process()
        helper.executableURL = URL(fileURLWithPath: "/bin/sh")
        helper.arguments = [
            "-c", "while /bin/kill -0 \"$1\" 2>/dev/null; do /bin/sleep 0.2; done; /usr/bin/open \"$2\"",
            "sh", String(ProcessInfo.processInfo.processIdentifier), target.path,
        ]
        do {
            try helper.run()
        } catch {
            Log.update.error("restart helper failed: \(Self.describe(error), privacy: .public)")
            throw UpdateFailure.relaunch
        }

        // 6. Swap. If it fails, the helper must not reopen the old version later.
        // The new bundle keeps no metadata from the old one.
        do {
            _ = try files.replaceItemAt(target, withItemAt: newApp, backupItemName: nil, options: .usingNewMetadataOnly)
        } catch {
            Log.update.error("swap failed: \(Self.describe(error), privacy: .public)")
            helper.terminate()
            throw UpdateFailure.cannotWrite
        }
        UserDefaults.standard.set(true, forKey: Self.justUpdatedKey)
        Log.update.notice("installed \(newVersion.description, privacy: .public), restarting")
        NSApp.terminate(nil)
    }

    /// The new app must carry a valid signature that meets this app's designated requirement:
    /// the same bundle identifier and the same certificate.
    /// Logs the failing call and its OSStatus.
    nonisolated private static func isSignedLikeRunningApp(_ url: URL) -> Bool {
        var running: SecCode?
        var runningStatic: SecStaticCode?
        var requirement: SecRequirement?
        var candidate: SecStaticCode?
        guard succeeded(SecCodeCopySelf([], &running), "SecCodeCopySelf"), let running,
              succeeded(SecCodeCopyStaticCode(running, [], &runningStatic), "SecCodeCopyStaticCode"), let runningStatic,
              succeeded(SecCodeCopyDesignatedRequirement(runningStatic, [], &requirement),
                        "SecCodeCopyDesignatedRequirement"), let requirement,
              succeeded(SecStaticCodeCreateWithPath(url as CFURL, [], &candidate),
                        "SecStaticCodeCreateWithPath"), let candidate else {
            return false
        }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures | kSecCSCheckNestedCode)
        return succeeded(SecStaticCodeCheckValidity(candidate, flags, requirement), "SecStaticCodeCheckValidity")
    }

    /// True when the call succeeded. Otherwise logs the call name and its OSStatus.
    nonisolated private static func succeeded(_ status: OSStatus, _ call: String) -> Bool {
        if status != errSecSuccess {
            Log.update.error("signature check failed: \(call, privacy: .public) returned OSStatus \(status, privacy: .public)")
        }
        return status == errSecSuccess
    }

    /// Runs the tool and returns its exit status. Returns -1 when the tool could not start.
    nonisolated private static func run(_ tool: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        do {
            try process.run()
        } catch {
            Log.update.error("could not start \(tool, privacy: .public): \(describe(error), privacy: .public)")
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }

    /// Error domain, code and text, for example "NSURLErrorDomain -1009: The Internet connection appears to be offline."
    nonisolated private static func describe(_ error: Error) -> String {
        let nsError = error as NSError
        return "\(nsError.domain) \(nsError.code): \(error.localizedDescription)"
    }
}

/// Reports how much of the download has arrived. URLSession calls it on its own queue.
private final class DownloadProgress: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let report: @Sendable (Double?) -> Void
    /// Set once, when the task is created, before any progress arrives.
    private var observation: NSKeyValueObservation?

    init(report: @escaping @Sendable (Double?) -> Void) {
        self.report = report
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        observation = task.progress.observe(\.fractionCompleted) { [report] progress, _ in
            // The total is unknown (-1) until the server sends the size.
            report(progress.totalUnitCount > 0 ? progress.fractionCompleted : nil)
        }
    }
}
