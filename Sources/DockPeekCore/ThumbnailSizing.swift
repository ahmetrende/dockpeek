import CoreGraphics

public enum ThumbnailSizing {
    /// Fits the window's aspect ratio into the box. Small windows are scaled up.
    public static func fit(_ window: CGSize, maxWidth: CGFloat, maxHeight: CGFloat) -> CGSize {
        guard window.width > 0, window.height > 0 else {
            return CGSize(width: maxWidth, height: maxHeight)
        }
        let scale = min(maxWidth / window.width, maxHeight / window.height)
        return CGSize(width: (window.width * scale).rounded(), height: (window.height * scale).rounded())
    }
}
