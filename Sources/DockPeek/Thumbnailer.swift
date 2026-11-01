import AppKit
import DockPeekCore
import ScreenCaptureKit

struct CaptureRequest {
    let id: CGWindowID
    let pointSize: CGSize
    let scale: CGFloat

    var pixelWidth: Int { Int((pointSize.width * scale).rounded()) }
    var pixelHeight: Int { Int((pointSize.height * scale).rounded()) }
}

@MainActor
final class Thumbnailer {
    private var cache: ThumbnailCache<CGImage>

    init(limit: Int) {
        cache = ThumbnailCache(limit: limit)
    }

    func cachedImage(for id: CGWindowID) -> CGImage? {
        cache.image(for: id)
    }

    func prune(owner: pid_t, keeping ids: Set<CGWindowID>) {
        cache.prune(owner: owner, keeping: ids)
    }

    func removeAll(owner: pid_t) {
        cache.removeAll(owner: owner)
    }

    /// Captures each window once, in parallel. `deliver` runs on the main actor as each image arrives.
    func capture(_ requests: [CaptureRequest], owner: pid_t, deliver: (CGWindowID, CGImage) -> Void) async {
        guard !requests.isEmpty else { return }
        let started = ProcessInfo.processInfo.systemUptime
        guard let windowsByID = await shareableWindows() else { return }
        let listed = ProcessInfo.processInfo.systemUptime
        let sizes = Dictionary(requests.map { ($0.id, $0.pointSize) }, uniquingKeysWith: { first, _ in first })

        await withTaskGroup(of: (CGWindowID, CGImage?).self) { group in
            for request in requests {
                guard let window = windowsByID[request.id] else { continue }
                group.addTask {
                    let image = await Self.captureImage(of: window, request: request)
                    return (request.id, image)
                }
            }
            for await (id, image) in group {
                guard let image else {
                    Log.capture.error("capture failed for window \(id)")
                    continue
                }
                deliver(id, image)
                if let size = sizes[id], let small = Self.downscale(image, to: size) {
                    cache.store(small, window: id, owner: owner)
                }
            }
        }

        let finished = ProcessInfo.processInfo.systemUptime
        Log.capture.notice("captured \(requests.count) windows: list \((listed - started) * 1000, format: .fixed(precision: 1)) ms, total \((finished - started) * 1000, format: .fixed(precision: 1)) ms")
    }

    private func shareableWindows() async -> [CGWindowID: SCWindow]? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            return Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
        } catch {
            Log.capture.error("shareable content failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private nonisolated static func captureImage(of window: SCWindow, request: CaptureRequest) async -> CGImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = request.pixelWidth
        config.height = request.pixelHeight
        config.showsCursor = false
        config.ignoreShadowsSingleWindow = true
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    }

    /// Stores cache images at 1x to keep memory low (design document, section 6.3).
    private static func downscale(_ image: CGImage, to size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        guard width > 0, height > 0,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
              ) else { return nil }
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return context.makeImage()
    }
}
