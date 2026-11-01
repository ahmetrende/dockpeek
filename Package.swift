// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DockPeek",
    platforms: [.macOS("27.0")],
    targets: [
        .target(name: "DockPeekCore"),
        .executableTarget(name: "DockPeek", dependencies: ["DockPeekCore"]),
        .testTarget(
            name: "DockPeekCoreTests",
            dependencies: ["DockPeekCore"],
            // Swift Build sometimes leaves out the Swift Testing macro plugin when only Command Line Tools is installed.
            swiftSettings: [.unsafeFlags([
                "-external-plugin-path",
                "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing#/Library/Developer/CommandLineTools/usr/bin/swift-plugin-server",
            ])]
        ),
    ],
    // AX C callbacks and ScreenCaptureKit types do not fit strict Swift 6 checking without much ceremony.
    swiftLanguageModes: [.v5]
)
