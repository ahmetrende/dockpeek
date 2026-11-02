import Testing
import DockPeekCore

@Test func turkishFirstLanguagePicksTurkish() {
    #expect(AppLanguage.pick(preferredLanguages: ["tr-TR", "en-US"]) == .turkish)
    #expect(AppLanguage.pick(preferredLanguages: ["tr"]) == .turkish)
}

@Test func otherFirstLanguagePicksEnglish() {
    #expect(AppLanguage.pick(preferredLanguages: ["en-GB", "tr-TR"]) == .english)
    #expect(AppLanguage.pick(preferredLanguages: ["de-DE"]) == .english)
    #expect(AppLanguage.pick(preferredLanguages: []) == .english)
}

@Test func onlyTheLanguagePartCounts() {
    // "trv" is another language whose code starts with "tr".
    #expect(AppLanguage.pick(preferredLanguages: ["trv"]) == .english)
    #expect(AppLanguage.pick(preferredLanguages: ["TR-tr"]) == .turkish)
}

@Test func stringsFollowLanguage() {
    #expect(UIStrings(.english).quit == "Quit DockPeek")
    #expect(UIStrings(.turkish).quit == "DockPeek'ten çık")
    #expect(UIStrings(.turkish).hideWindow == "Pencereyi gizle")
}

@Test func versionAndCommitLines() {
    let english = UIStrings(.english)
    #expect(english.version("0.1.0") == "Version 0.1.0")
    // The user asked for the date alone, with no label.
    #expect(english.lastCommit("2026-10-31 12:23") == "2026-10-31 12:23 UTC")
    let turkish = UIStrings(.turkish)
    #expect(turkish.version("0.1.0") == "Sürüm 0.1.0")
    #expect(turkish.lastCommit("2026-10-31 12:23") == "2026-10-31 12:23 UTC")
}

@Test func updatesRowTexts() {
    let english = UIStrings(.english)
    #expect(english.updates == "Updates")
    #expect(english.checkNow == "Check Now")
    #expect(english.updateStatus(.idle) == "")
    #expect(english.updateStatus(.checking) == "Checking…")
    #expect(english.updateStatus(.upToDate) == "Up to date")
    #expect(english.updateStatus(.available(AppVersion("0.2.2")!)) == "0.2.2 available")
    #expect(english.updateStatus(.failed) == "Could not check")
    let turkish = UIStrings(.turkish)
    #expect(turkish.updates == "Güncellemeler")
    #expect(turkish.checkNow == "Şimdi denetle")
    #expect(turkish.updateStatus(.idle) == "")
    #expect(turkish.updateStatus(.checking) == "Denetleniyor…")
    #expect(turkish.updateStatus(.upToDate) == "Güncel")
    #expect(turkish.updateStatus(.available(AppVersion("0.2.2")!)) == "0.2.2 hazır")
    #expect(turkish.updateStatus(.failed) == "Denetlenemedi")
}

@Test func updateProgressTexts() {
    let english = UIStrings(.english)
    #expect(english.updatingTo("0.2.3") == "Updating DockPeek to 0.2.3")
    #expect(english.updateStepText(.downloading(fraction: nil)) == "Downloading…")
    #expect(english.updateStepText(.downloading(fraction: 0.456)) == "Downloading… 45%")
    #expect(english.updateStepText(.verifying) == "Verifying…")
    #expect(english.updateStepText(.installing) == "Installing…")
    let turkish = UIStrings(.turkish)
    #expect(turkish.updatingTo("0.2.3") == "DockPeek 0.2.3 sürümüne güncelleniyor")
    #expect(turkish.updateStepText(.downloading(fraction: nil)) == "İndiriliyor…")
    // Turkish puts the percent sign before the number.
    #expect(turkish.updateStepText(.downloading(fraction: 0.456)) == "İndiriliyor… %45")
    #expect(turkish.updateStepText(.verifying) == "Doğrulanıyor…")
    #expect(turkish.updateStepText(.installing) == "Kuruluyor…")
}

@Test func downloadPercentStaysInRange() {
    let english = UIStrings(.english)
    #expect(english.updateStepText(.downloading(fraction: 1)) == "Downloading… 100%")
    #expect(english.updateStepText(.downloading(fraction: 1.2)) == "Downloading… 100%")
    #expect(english.updateStepText(.downloading(fraction: -0.1)) == "Downloading… 0%")
}

@Test func gitHubLinkText() {
    #expect(UIStrings(.english).viewOnGitHub == "View on GitHub")
    #expect(UIStrings(.turkish).viewOnGitHub == "GitHub'da gör")
}

@Test func automaticChoiceFollowsTheMac() {
    #expect(LanguageChoice.automatic.resolve(preferredLanguages: ["tr-TR"]) == .turkish)
    #expect(LanguageChoice.automatic.resolve(preferredLanguages: ["en-TR"]) == .english)
}

@Test func explicitChoiceWins() {
    #expect(LanguageChoice.english.resolve(preferredLanguages: ["tr-TR"]) == .english)
    #expect(LanguageChoice.turkish.resolve(preferredLanguages: ["en-US"]) == .turkish)
}

@Test func storedChoiceDefaultsToAutomatic() {
    #expect(LanguageChoice.stored("turkish") == .turkish)
    #expect(LanguageChoice.stored("english") == .english)
    #expect(LanguageChoice.stored(nil) == .automatic)
    #expect(LanguageChoice.stored("klingon") == .automatic)
}

@Test func languageRowStrings() {
    #expect(UIStrings(.english).language == "Language")
    #expect(UIStrings(.turkish).language == "Dil")
    #expect(UIStrings(.turkish).automatic == "Otomatik")
}

@Test func updateQuestionFollowsLanguage() {
    let english = UIStrings(.english)
    let turkish = UIStrings(.turkish)
    #expect(english.updateAvailable("0.2.1") == "DockPeek 0.2.1 is available")
    #expect(turkish.updateAvailable("0.2.1") == "DockPeek 0.2.1 hazır")
    #expect(english.youHave("0.2.0") == "You have 0.2.0.")
    #expect(turkish.youHave("0.2.0") == "Sende 0.2.0 var.")
    #expect(english.updateNow == "Update Now")
    #expect(turkish.updateNow == "Şimdi güncelle")
    #expect(english.later == "Later")
    #expect(turkish.later == "Sonra")
}

@Test func updateFailureNamesReasonAndKeptVersion() {
    #expect(UIStrings(.english).updateFailed(.signature, keeping: "0.2.0")
        == "The new version is not signed with the DockPeek certificate. DockPeek keeps version 0.2.0.")
    #expect(UIStrings(.turkish).updateFailed(.download, keeping: "0.2.0")
        == "İndirme başarısız oldu. DockPeek 0.2.0 sürümünde kalıyor.")
    #expect(UIStrings(.turkish).updateFailedTitle == "Güncelleme yapılamadı")
}

@Test func everyUpdateFailureHasTextInBothLanguages() {
    for failure in UpdateFailure.allCases {
        let english = UIStrings(.english).updateFailed(failure, keeping: "1.0.0")
        let turkish = UIStrings(.turkish).updateFailed(failure, keeping: "1.0.0")
        #expect(english != turkish, "\(failure)")
        #expect(english.hasSuffix("DockPeek keeps version 1.0.0."), "\(failure)")
        #expect(turkish.hasSuffix("DockPeek 1.0.0 sürümünde kalıyor."), "\(failure)")
        #expect(!english.hasPrefix(" "), "\(failure)")
        #expect(!turkish.hasPrefix(" "), "\(failure)")
    }
}
