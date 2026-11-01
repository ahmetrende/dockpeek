import Foundation

public enum AppLanguage: Equatable, Sendable {
    case english
    case turkish

    /// Turkish when the Mac's first preferred language is Turkish, else English.
    public static func pick(preferredLanguages: [String]) -> AppLanguage {
        guard let first = preferredLanguages.first else { return .english }
        let code = first.split(separator: "-").first.map { $0.lowercased() }
        return code == "tr" ? .turkish : .english
    }
}

/// The language the person picked in the settings window. `automatic` follows the Mac.
public enum LanguageChoice: String, CaseIterable, Sendable {
    case automatic
    case english
    case turkish

    /// Reads a stored value. A missing or unknown value means `automatic`.
    public static func stored(_ value: String?) -> LanguageChoice {
        value.flatMap(LanguageChoice.init(rawValue:)) ?? .automatic
    }

    public func resolve(preferredLanguages: [String]) -> AppLanguage {
        switch self {
        case .automatic: AppLanguage.pick(preferredLanguages: preferredLanguages)
        case .english: .english
        case .turkish: .turkish
        }
    }
}

/// Every text the settings window shows, in one language.
public struct UIStrings: Sendable {
    public let general: String
    public let openAtLogin: String
    public let language: String
    public let automatic: String
    public let permissions: String
    public let accessibility: String
    public let screenRecording: String
    public let allowed: String
    public let notAllowed: String
    public let openSettings: String
    public let permissionsHelp: String
    public let accessibilityMissingHelp: String
    public let screenRecordingMissingHelp: String
    public let about: String
    public let aboutText: String
    public let hideWindow: String
    public let quit: String
    public let updateNow: String
    public let later: String
    public let updateFailedTitle: String
    private let availableFormat: String
    private let youHaveFormat: String
    private let keepsFormat: String
    private let failureReasons: [UpdateFailure: String]
    private let versionLabel: String

    public init(_ language: AppLanguage) {
        switch language {
        case .english:
            general = "General"
            openAtLogin = "Open at login"
            self.language = "Language"
            automatic = "Automatic"
            permissions = "Permissions"
            accessibility = "Accessibility"
            screenRecording = "Screen Recording"
            allowed = "Allowed"
            notAllowed = "Not allowed"
            openSettings = "Open Settings"
            permissionsHelp = "Needed to read the Dock and to capture window thumbnails."
            accessibilityMissingHelp = "Without Accessibility, DockPeek cannot see the Dock."
            screenRecordingMissingHelp = "Without Screen Recording, previews show app icons instead of thumbnails."
            about = "About"
            aboutText = "Hover an app in the Dock to see its windows. Click a preview to bring that window to the front."
            hideWindow = "Hide window"
            quit = "Quit DockPeek"
            versionLabel = "Version"
            updateNow = "Update Now"
            later = "Later"
            updateFailedTitle = "Update failed"
            availableFormat = "DockPeek %@ is available"
            youHaveFormat = "You have %@."
            keepsFormat = "DockPeek keeps version %@."
            failureReasons = [
                .download: "The download failed.",
                .unpack: "The downloaded file could not be opened.",
                .signature: "The new version is not signed with the DockPeek certificate.",
                .notNewer: "The downloaded version is not newer.",
                .cannotWrite: "DockPeek cannot write to its folder.",
                .relaunch: "DockPeek could not prepare the restart.",
            ]
        case .turkish:
            general = "Genel"
            openAtLogin = "Girişte başlat"
            self.language = "Dil"
            automatic = "Otomatik"
            permissions = "İzinler"
            accessibility = "Erişilebilirlik"
            screenRecording = "Ekran Kaydı"
            allowed = "Verildi"
            notAllowed = "Verilmedi"
            openSettings = "Ayarları aç"
            permissionsHelp = "Dock'u okumak ve pencere görüntüsü almak için gerekli."
            accessibilityMissingHelp = "Erişilebilirlik izni olmadan DockPeek Dock'u göremez."
            screenRecordingMissingHelp = "Ekran Kaydı izni olmadan önizlemede küçük resim yerine uygulama simgesi görünür."
            about = "Hakkında"
            aboutText = "Dock'taki bir uygulamanın üstüne gel, pencerelerini gör. Bir önizlemeye tıkla, o pencere öne gelsin."
            hideWindow = "Pencereyi gizle"
            quit = "DockPeek'ten çık"
            versionLabel = "Sürüm"
            updateNow = "Şimdi güncelle"
            later = "Sonra"
            updateFailedTitle = "Güncelleme yapılamadı"
            availableFormat = "DockPeek %@ hazır"
            youHaveFormat = "Sende %@ var."
            keepsFormat = "DockPeek %@ sürümünde kalıyor."
            failureReasons = [
                .download: "İndirme başarısız oldu.",
                .unpack: "İnen dosya açılamadı.",
                .signature: "Yeni sürüm DockPeek sertifikasıyla imzalı değil.",
                .notNewer: "İnen sürüm daha yeni değil.",
                .cannotWrite: "DockPeek kendi klasörüne yazamıyor.",
                .relaunch: "DockPeek yeniden açılmayı hazırlayamadı.",
            ]
        }
    }

    public func version(_ number: String) -> String {
        "\(versionLabel) \(number)"
    }

    /// `date` is the last commit time in UTC, formatted yyyy-MM-dd HH:mm. It shows with no label.
    public func lastCommit(_ date: String) -> String {
        "\(date) UTC"
    }

    public func updateAvailable(_ version: String) -> String {
        availableFormat.replacingOccurrences(of: "%@", with: version)
    }

    public func youHave(_ version: String) -> String {
        youHaveFormat.replacingOccurrences(of: "%@", with: version)
    }

    /// The reason first, then the version that stays installed.
    public func updateFailed(_ reason: UpdateFailure, keeping version: String) -> String {
        "\(failureReasons[reason] ?? "") \(keepsFormat.replacingOccurrences(of: "%@", with: version))"
    }
}
