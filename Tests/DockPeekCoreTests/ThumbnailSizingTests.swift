import CoreGraphics
import Testing
import DockPeekCore

@Test func landscapeIsLimitedByWidth() {
    #expect(ThumbnailSizing.fit(CGSize(width: 1600, height: 1000), maxWidth: 240, maxHeight: 180) == CGSize(width: 240, height: 150))
}

@Test func portraitIsLimitedByHeight() {
    #expect(ThumbnailSizing.fit(CGSize(width: 1000, height: 1600), maxWidth: 240, maxHeight: 180) == CGSize(width: 113, height: 180))
}

@Test func smallWindowIsScaledUp() {
    #expect(ThumbnailSizing.fit(CGSize(width: 100, height: 80), maxWidth: 240, maxHeight: 180) == CGSize(width: 225, height: 180))
}

@Test func emptySizeUsesFullBox() {
    #expect(ThumbnailSizing.fit(.zero, maxWidth: 240, maxHeight: 180) == CGSize(width: 240, height: 180))
}
