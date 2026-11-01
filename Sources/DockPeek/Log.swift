import os

enum Log {
    private static let subsystem = "io.github.ahmetrende.dockpeek"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let dock = Logger(subsystem: subsystem, category: "dock")
    static let windows = Logger(subsystem: subsystem, category: "windows")
    static let capture = Logger(subsystem: subsystem, category: "capture")
    static let panel = Logger(subsystem: subsystem, category: "panel")
    static let update = Logger(subsystem: subsystem, category: "update")
}
