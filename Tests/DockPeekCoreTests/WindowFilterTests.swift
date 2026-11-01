import CoreGraphics
import Testing
import DockPeekCore

private func window(
    subrole: String? = "AXStandardWindow",
    width: CGFloat = 800,
    height: CGFloat = 600,
    minimized: Bool = false,
    appHidden: Bool = false
) -> WindowCandidate {
    WindowCandidate(
        id: 1, title: "T", size: CGSize(width: width, height: height), subrole: subrole,
        isMinimized: minimized, appIsHidden: appHidden
    )
}

@Test func keepsStandardWindow() {
    #expect(WindowFilter.keep(window(), minSide: 50))
}

@Test func keepsMinimizedStandardWindow() {
    #expect(WindowFilter.keep(window(minimized: true), minSide: 50))
}

@Test func dropsNonStandardSubrole() {
    #expect(!WindowFilter.keep(window(subrole: "AXFloatingWindow"), minSide: 50))
    #expect(!WindowFilter.keep(window(subrole: nil), minSide: 50))
}

@Test func dropsSmallWindows() {
    #expect(!WindowFilter.keep(window(width: 49), minSide: 50))
    #expect(!WindowFilter.keep(window(height: 49), minSide: 50))
    #expect(WindowFilter.keep(window(width: 50, height: 50), minSide: 50))
}

@Test func onlyApplicationDockItemsCount() {
    #expect(DockItem.isApplication(subrole: "AXApplicationDockItem"))
    #expect(!DockItem.isApplication(subrole: "AXTrashDockItem"))
    #expect(!DockItem.isApplication(subrole: "AXFolderDockItem"))
    #expect(!DockItem.isApplication(subrole: nil))
}

@Test func normalizesBundlePaths() {
    #expect(DockItem.normalizedPath("/Applications/Safari.app/") == "/Applications/Safari.app")
    #expect(DockItem.normalizedPath("/Applications/Safari.app") == "/Applications/Safari.app")
    #expect(DockItem.normalizedPath("/") == "/")
}

@Test func emptyTitleFallsBackToAppName() {
    #expect(WindowTitle.display("", appName: "Safari") == "Safari")
    #expect(WindowTitle.display(nil, appName: "Safari") == "Safari")
    #expect(WindowTitle.display("   ", appName: "Safari") == "Safari")
}

@Test func titleIsTrimmed() {
    #expect(WindowTitle.display("  Belge  ", appName: "Safari") == "Belge")
}

// macOS 27 reports a minimized window with the AXDialog subrole.
@Test func keepsMinimizedWindowWithDialogSubrole() {
    #expect(WindowFilter.keep(window(subrole: "AXDialog", minimized: true), minSide: 50))
}

// macOS 27 also reports every window of a hidden (Cmd+H) app with the AXDialog subrole.
@Test func keepsHiddenAppWindowWithDialogSubrole() {
    #expect(WindowFilter.keep(window(subrole: "AXDialog", appHidden: true), minSide: 50))
}

@Test func hiddenAppStillDropsSmallWindows() {
    #expect(!WindowFilter.keep(window(subrole: "AXDialog", width: 49, appHidden: true), minSide: 50))
}
