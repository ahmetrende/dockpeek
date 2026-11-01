import Foundation

/// How often to try again after a failure, and when to give up.
public struct RetryPolicy: Equatable, Sendable {
    public let interval: TimeInterval
    public let maxAttempts: Int

    public init(interval: TimeInterval, maxAttempts: Int) {
        self.interval = interval
        self.maxAttempts = maxAttempts
    }

    /// The wait before the next attempt, or nil when no attempt is left.
    public func delay(afterFailedAttempt attempt: Int) -> TimeInterval? {
        attempt < maxAttempts ? interval : nil
    }
}

public enum Budgeted {
    /// Transforms items in order until `budget` seconds have passed, then keeps what it has.
    /// An item starts only while time is left; nil results are dropped.
    public static func map<Item, Result>(
        _ items: [Item],
        budget: TimeInterval,
        now: () -> TimeInterval,
        _ transform: (Item) -> Result?
    ) -> [Result] {
        let start = now()
        var results: [Result] = []
        for item in items {
            guard now() - start < budget else { break }
            if let result = transform(item) {
                results.append(result)
            }
        }
        return results
    }
}
