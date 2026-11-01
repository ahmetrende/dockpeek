import CoreGraphics

public enum ScreenGeometry {
    /// AX uses a top-left origin on the primary screen. AppKit uses a bottom-left origin.
    public static func appKitRect(fromAX rect: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
