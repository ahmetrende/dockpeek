import DockPeekCore
import Foundation

/// The language picked in settings, shared by every window and alert.
enum CurrentLanguage {
    static let key = "language"

    static var choice: LanguageChoice {
        LanguageChoice.stored(UserDefaults.standard.string(forKey: key))
    }

    static var strings: UIStrings {
        UIStrings(choice.resolve(preferredLanguages: Locale.preferredLanguages))
    }
}
