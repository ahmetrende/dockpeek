import Testing
import DockPeekCore

@Test func defaultsMatchDesignDocument() {
    let settings = PreviewSettings()
    #expect(settings.openDelay == 0.150)
    #expect(settings.closeDelay == 0.200)
    #expect(settings.thumbnailWidth == 240)
    #expect(settings.thumbnailMaxHeight == 180)
    #expect(settings.panelGap == 8)
    #expect(settings.minWindowSide == 50)
    #expect(settings.cacheLimit == 20)
}
