import Testing
import DockPeekCore

@Test func evictsLeastRecentlyUsed() {
    var cache = ThumbnailCache<String>(limit: 2)
    cache.store("a", window: 1, owner: 10)
    cache.store("b", window: 2, owner: 10)
    cache.store("c", window: 3, owner: 10)
    #expect(cache.count == 2)
    #expect(cache.image(for: 1) == nil)
    #expect(cache.image(for: 3) == "c")
}

@Test func readingRefreshesRecency() {
    var cache = ThumbnailCache<String>(limit: 2)
    cache.store("a", window: 1, owner: 10)
    cache.store("b", window: 2, owner: 10)
    _ = cache.image(for: 1)
    cache.store("c", window: 3, owner: 10)
    #expect(cache.image(for: 1) == "a")
    #expect(cache.image(for: 2) == nil)
}

@Test func storingSameWindowReplacesImage() {
    var cache = ThumbnailCache<String>(limit: 2)
    cache.store("a", window: 1, owner: 10)
    cache.store("b", window: 1, owner: 10)
    #expect(cache.count == 1)
    #expect(cache.image(for: 1) == "b")
}

@Test func pruneRemovesClosedWindowsOfOneOwner() {
    var cache = ThumbnailCache<String>(limit: 10)
    cache.store("a", window: 1, owner: 10)
    cache.store("b", window: 2, owner: 10)
    cache.store("c", window: 3, owner: 20)
    cache.prune(owner: 10, keeping: [1])
    #expect(cache.image(for: 1) == "a")
    #expect(cache.image(for: 2) == nil)
    #expect(cache.image(for: 3) == "c")
}

@Test func removeAllClearsOneOwner() {
    var cache = ThumbnailCache<String>(limit: 10)
    cache.store("a", window: 1, owner: 10)
    cache.store("b", window: 2, owner: 10)
    cache.store("c", window: 3, owner: 20)
    cache.removeAll(owner: 10)
    #expect(cache.count == 1)
    #expect(cache.image(for: 3) == "c")
}
