import Foundation
import Testing
import DockPeekCore

@Test func retryWaitsTheIntervalUntilAttemptsRunOut() {
    let policy = RetryPolicy(interval: 2, maxAttempts: 3)
    #expect(policy.delay(afterFailedAttempt: 1) == 2)
    #expect(policy.delay(afterFailedAttempt: 2) == 2)
    #expect(policy.delay(afterFailedAttempt: 3) == nil)
}

/// A clock that moves forward by `step` each time an item is transformed.
private final class FakeClock {
    var time: TimeInterval = 100
    let step: TimeInterval
    init(step: TimeInterval) { self.step = step }
}

@Test func budgetKeepsEverythingWhenFast() {
    let clock = FakeClock(step: 0)
    let result = Budgeted.map([1, 2, 3], budget: 0.5, now: { clock.time }) { $0 * 10 }
    #expect(result == [10, 20, 30])
}

@Test func budgetStopsOnceSpent() {
    let clock = FakeClock(step: 0.2)
    let result = Budgeted.map([1, 2, 3, 4, 5], budget: 0.5, now: { clock.time }) { value -> Int? in
        clock.time += clock.step
        return value
    }
    // Starts at 0, 0.2 and 0.4 seconds are inside the budget; the fourth would start at 0.6.
    #expect(result == [1, 2, 3])
}

@Test func budgetDropsNilResults() {
    let clock = FakeClock(step: 0)
    let result = Budgeted.map([1, 2, 3, 4], budget: 0.5, now: { clock.time }) { value -> Int? in
        value.isMultiple(of: 2) ? value : nil
    }
    #expect(result == [2, 4])
}
