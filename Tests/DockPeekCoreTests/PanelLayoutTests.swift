import CoreGraphics
import Testing
import DockPeekCore

private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
private let landscape = CGSize(width: 240, height: 150)

private func layout(_ thumbnails: [CGSize], iconX: CGFloat) -> PanelLayoutResult {
    PanelLayout.compute(
        thumbnails: thumbnails,
        iconFrame: CGRect(x: iconX, y: 0, width: 60, height: 60),
        visibleFrame: screen,
        gap: 8,
        metrics: PanelMetrics()
    )
}

@Test func singleThumbnailIsCenteredAboveIcon() {
    let result = layout([landscape], iconX: 500)
    #expect(result.panelFrame == CGRect(x: 398, y: 68, width: 264, height: 192))
    #expect(result.imageFrames == [CGRect(x: 12, y: 30, width: 240, height: 150)])
    #expect(result.titleFrames == [CGRect(x: 12, y: 12, width: 240, height: 18)])
}

@Test func clampsToLeftEdge() {
    #expect(layout([landscape], iconX: 0).panelFrame.minX == 8)
}

@Test func clampsToRightEdge() {
    #expect(layout([landscape], iconX: 1400).panelFrame.minX == 1168)
}

@Test func shrinksThumbnailsToFitScreen() {
    let result = layout(Array(repeating: landscape, count: 10), iconX: 690)
    #expect(result.panelFrame.minX >= 8)
    #expect(result.panelFrame.maxX <= 1432)
    #expect(result.imageFrames.allSatisfy { $0.width == 129 && $0.height == 80 })
}

@Test func thirtyWindowsStayOnScreen() {
    let result = layout(Array(repeating: landscape, count: 30), iconX: 690)
    #expect(result.panelFrame.minX >= 8)
    #expect(result.panelFrame.maxX <= 1432)
    #expect(result.imageFrames.count == 30)
    #expect(result.imageFrames.allSatisfy { $0.width > 0 && $0.height > 0 })
}

@Test func mixedHeightsAreCenteredVertically() {
    let result = layout([landscape, CGSize(width: 113, height: 180)], iconX: 500)
    #expect(result.panelFrame.height == 222)
    #expect(result.imageFrames[0].minY == 45)
    #expect(result.imageFrames[1].minY == 30)
    #expect(result.imageFrames[1].minX == 264)
}
