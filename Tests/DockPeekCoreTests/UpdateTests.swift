import Foundation
import Testing
import DockPeekCore

@Test func readsPlainAndTaggedVersions() {
    #expect(AppVersion("0.2.0")?.description == "0.2.0")
    #expect(AppVersion("v1.10.3")?.description == "1.10.3")
}

@Test func rejectsOtherVersionForms() {
    for text in ["", "v", "1.2", "1.2.3.4", "1.2.x", "1..3", "+1.2.3", "1.2.3-beta", " 1.2.3"] {
        #expect(AppVersion(text) == nil, "\(text)")
    }
}

@Test func comparesVersionsNumberByNumber() {
    let versions = ["0.2.0", "0.2.1", "0.10.0", "1.0.0"].compactMap { AppVersion($0) }
    #expect(versions.count == 4)
    #expect(versions == versions.sorted())
    #expect(AppVersion("v0.2.0") == AppVersion("0.2.0"))
}

private let currentVersion = AppVersion("0.2.0")!
private let zipLink = "https://github.com/ahmetrende/dockpeek/releases/download/v0.2.1/DockPeek.zip"

private func releaseResponse(tag: String, assets: [(name: String, url: String)]) -> Data {
    let list = assets.map { #"{"name":"\#($0.name)","browser_download_url":"\#($0.url)"}"# }
    return Data(#"{"tag_name":"\#(tag)","draft":false,"assets":[\#(list.joined(separator: ","))]}"#.utf8)
}

private func isUnusable(_ decision: UpdateDecision) -> Bool {
    if case .unusable = decision { true } else { false }
}

@Test func newerReleaseWithZipIsAvailable() {
    let response = releaseResponse(tag: "v0.2.1", assets: [("DockPeek.dmg", "https://example.com/a.dmg"), ("DockPeek.zip", zipLink)])
    #expect(UpdateCheck.decide(current: currentVersion, response: response)
        == .available(version: AppVersion("0.2.1")!, zipURL: URL(string: zipLink)!))
}

@Test func sameOrOlderReleaseIsUpToDate() {
    for tag in ["v0.2.0", "v0.1.9"] {
        let response = releaseResponse(tag: tag, assets: [("DockPeek.zip", zipLink)])
        #expect(UpdateCheck.decide(current: currentVersion, response: response) == .upToDate, "\(tag)")
    }
}

@Test func newerReleaseWithoutZipIsUnusable() {
    let response = releaseResponse(tag: "v0.2.1", assets: [("DockPeek.dmg", "https://example.com/a.dmg")])
    #expect(isUnusable(UpdateCheck.decide(current: currentVersion, response: response)))
}

@Test func brokenResponsesAreUnusable() {
    let responses = [
        Data("not json".utf8),
        Data(#"{"message":"Not Found"}"#.utf8),
        releaseResponse(tag: "latest", assets: [("DockPeek.zip", zipLink)]),
    ]
    for response in responses {
        #expect(isUnusable(UpdateCheck.decide(current: currentVersion, response: response)))
    }
}

@Test func downloadMustUseHTTPSExceptOnLocalhost() {
    let response = releaseResponse(tag: "v0.2.1", assets: [("DockPeek.zip", "http://example.com/DockPeek.zip")])
    #expect(isUnusable(UpdateCheck.decide(current: currentVersion, response: response)))
    #expect(UpdateCheck.isAllowedDownload(URL(string: "http://localhost:8765/DockPeek.zip")!))
    #expect(UpdateCheck.isAllowedDownload(URL(string: "http://127.0.0.1:8765/DockPeek.zip")!))
    #expect(!UpdateCheck.isAllowedDownload(URL(string: "ftp://example.com/DockPeek.zip")!))
}

private let declinedAt = Date(timeIntervalSince1970: 1_000_000)

@Test func asksWhenNothingWasPutOff() {
    #expect(UpdatePolicy.shouldAsk(about: AppVersion("0.2.1")!, declined: nil, now: declinedAt))
}

@Test func laterSilencesTheSameVersionForADay() {
    let declined = DeclinedUpdate(version: AppVersion("0.2.1")!, at: declinedAt)
    #expect(!UpdatePolicy.shouldAsk(about: AppVersion("0.2.1")!, declined: declined, now: declinedAt + 3600))
    #expect(UpdatePolicy.shouldAsk(about: AppVersion("0.2.1")!, declined: declined, now: declinedAt + 86400))
}

@Test func aNewerVersionAsksRightAway() {
    let declined = DeclinedUpdate(version: AppVersion("0.2.1")!, at: declinedAt)
    #expect(UpdatePolicy.shouldAsk(about: AppVersion("0.2.2")!, declined: declined, now: declinedAt + 60))
}

@Test func checkNowAsksEvenAfterLater() {
    let declined = DeclinedUpdate(version: AppVersion("0.2.1")!, at: declinedAt)
    #expect(UpdatePolicy.shouldAsk(about: AppVersion("0.2.1")!, declined: declined, now: declinedAt + 60, manual: true))
}

private let lastCheck = Date(timeIntervalSince1970: 2_000_000)

@Test func wakeChecksAtOnceWhenADayHasPassed() {
    #expect(UpdatePolicy.nextCheckDelay(lastCheck: lastCheck, now: lastCheck + 86400) == 0)
    #expect(UpdatePolicy.nextCheckDelay(lastCheck: lastCheck, now: lastCheck + 100_000) == 0)
}

@Test func wakeWaitsForTheRestOfTheDay() {
    #expect(UpdatePolicy.nextCheckDelay(lastCheck: lastCheck, now: lastCheck + 3600) == 86400 - 3600)
    #expect(UpdatePolicy.nextCheckDelay(lastCheck: lastCheck, now: lastCheck - 60) == 86400)
}
