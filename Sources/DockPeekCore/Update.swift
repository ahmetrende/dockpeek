import Foundation

/// A version in X.Y.Z form. A leading "v", as in git tags, is allowed.
public struct AppVersion: Comparable, CustomStringConvertible, Sendable {
    public let major: Int
    public let minor: Int
    public let patch: Int

    public init?(_ text: String) {
        let body = text.hasPrefix("v") ? text.dropFirst() : Substring(text)
        let parts = body.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        var numbers: [Int] = []
        for part in parts {
            guard !part.isEmpty, part.allSatisfy({ ("0"..."9").contains($0) }), let number = Int(part) else {
                return nil
            }
            numbers.append(number)
        }
        major = numbers[0]
        minor = numbers[1]
        patch = numbers[2]
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

public enum UpdateDecision: Equatable, Sendable {
    case upToDate
    case available(version: AppVersion, zipURL: URL)
    /// The response could not be used. The reason goes to the log only.
    case unusable(String)
}

public enum UpdateCheck {
    /// Every release carries this file. The app updates from it.
    public static let assetName = "DockPeek.zip"

    private struct Release: Decodable {
        let tagName: String
        let assets: [Asset]
    }

    private struct Asset: Decodable {
        let name: String
        let browserDownloadUrl: String
    }

    /// Reads GitHub's "latest release" response and compares it with the running version.
    public static func decide(current: AppVersion, response: Data) -> UpdateDecision {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard let release = try? decoder.decode(Release.self, from: response) else {
            return .unusable("response is not a release")
        }
        guard let latest = AppVersion(release.tagName) else {
            return .unusable("tag \(release.tagName) is not a version")
        }
        guard latest > current else { return .upToDate }
        guard let asset = release.assets.first(where: { $0.name == assetName }),
              let url = URL(string: asset.browserDownloadUrl),
              isAllowedDownload(url) else {
            return .unusable("release \(latest) has no usable \(assetName)")
        }
        return .available(version: latest, zipURL: url)
    }

    /// HTTPS only. Plain HTTP is allowed on this Mac only, for local update tests.
    public static func isAllowedDownload(_ url: URL) -> Bool {
        switch url.scheme {
        case "https": true
        case "http": url.host == "localhost" || url.host == "127.0.0.1"
        default: false
        }
    }
}

/// What the Updates row in the settings window shows about the last check.
public enum UpdateCheckStatus: Equatable, Sendable {
    case idle
    case checking
    case upToDate
    case available(AppVersion)
    /// The check got no usable answer. The reason goes to the log only.
    case failed
}

/// The person chose "Later" for this version at this time.
public struct DeclinedUpdate: Equatable, Sendable {
    public let version: AppVersion
    public let at: Date

    public init(version: AppVersion, at: Date) {
        self.version = version
        self.at = at
    }
}

public enum UpdatePolicy {
    /// The first check waits a little, so launch stays quick.
    public static let firstCheckDelay: TimeInterval = 10
    public static let checkInterval: TimeInterval = 24 * 60 * 60
    public static let laterQuietPeriod: TimeInterval = 24 * 60 * 60

    /// "Later" silences one version for a day. A newer version asks at once.
    /// A check from the Check Now button always asks: the person asked for it.
    public static func shouldAsk(about version: AppVersion, declined: DeclinedUpdate?, now: Date, manual: Bool = false) -> Bool {
        guard !manual, let declined, declined.version == version else { return true }
        return now.timeIntervalSince(declined.at) >= laterQuietPeriod
    }

    /// Clock time left until the next check. A run-loop timer does not count sleep, so this times the check after wake.
    public static func nextCheckDelay(lastCheck: Date, now: Date) -> TimeInterval {
        min(checkInterval, max(0, checkInterval - now.timeIntervalSince(lastCheck)))
    }
}

/// Why an update stopped. The installed version stays in every case.
public enum UpdateFailure: Error, CaseIterable, Equatable, Sendable {
    case download
    case unpack
    case signature
    case notNewer
    case cannotWrite
    case relaunch
}
