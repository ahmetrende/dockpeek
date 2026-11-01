/// Keeps the last image of each window, up to `limit` images.
/// When the limit is exceeded, the least recently used image is removed.
public struct ThumbnailCache<Image> {
    private struct Entry {
        let owner: Int32
        let image: Image
    }

    public let limit: Int
    private var entries: [UInt32: Entry] = [:]
    /// Window IDs, least recently used first.
    private var recency: [UInt32] = []

    public init(limit: Int) {
        self.limit = limit
    }

    public var count: Int { entries.count }

    public mutating func store(_ image: Image, window: UInt32, owner: Int32) {
        entries[window] = Entry(owner: owner, image: image)
        touch(window)
        while entries.count > limit, let oldest = recency.first {
            remove(oldest)
        }
    }

    public mutating func image(for window: UInt32) -> Image? {
        guard let entry = entries[window] else { return nil }
        touch(window)
        return entry.image
    }

    public mutating func prune(owner: Int32, keeping windows: Set<UInt32>) {
        let stale = entries.filter { $0.value.owner == owner && !windows.contains($0.key) }.map(\.key)
        stale.forEach { remove($0) }
    }

    public mutating func removeAll(owner: Int32) {
        let ids = entries.filter { $0.value.owner == owner }.map(\.key)
        ids.forEach { remove($0) }
    }

    private mutating func touch(_ window: UInt32) {
        recency.removeAll { $0 == window }
        recency.append(window)
    }

    private mutating func remove(_ window: UInt32) {
        entries[window] = nil
        recency.removeAll { $0 == window }
    }
}
