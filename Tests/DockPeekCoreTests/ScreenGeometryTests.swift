import CoreGraphics
import Testing
import DockPeekCore

@Test func convertsBottomOfScreen() {
    let ax = CGRect(x: 100, y: 950, width: 50, height: 50)
    #expect(ScreenGeometry.appKitRect(fromAX: ax, primaryScreenHeight: 1000) == CGRect(x: 100, y: 0, width: 50, height: 50))
}

@Test func convertsTopOfScreen() {
    let ax = CGRect(x: 0, y: 0, width: 10, height: 10)
    #expect(ScreenGeometry.appKitRect(fromAX: ax, primaryScreenHeight: 1000) == CGRect(x: 0, y: 990, width: 10, height: 10))
}
