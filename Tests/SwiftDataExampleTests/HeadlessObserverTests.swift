import XCTest
import AppState
@testable import SwiftDataExampleLib

#if !os(Linux) && !os(Windows)

// MARK: - HeadlessObserverTests

/// Proves that AppState 3.0's `@Observable Application` can be observed by a plain Swift object
/// — with **no SwiftUI view, no `ObservableObject`, and no `DynamicProperty`** in the loop.
///
/// Each test:
/// 1. Resets `observedCounter` and `observerReactionLog` to a clean baseline.
/// 2. Creates a `HeadlessObserver` and optionally calls `start()`.
/// 3. Mutates `Application.state(\.observedCounter).value` imperatively.
/// 4. Awaits delivery of the `onChange` notification (which AppState dispatches via `Task`
///    onto the main actor — typically one run-loop cycle).
/// 5. Asserts that `HeadlessObserver.reactionCount` and `lastObservedValue` updated correctly.
///
/// The `await waitForReactions(count:timeout:)` helper polls `reactionCount` with a short
/// deadline so tests remain deterministic without sleeping for a fixed duration.
@MainActor
final class HeadlessObserverTests: XCTestCase {

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        Application.reset(\.observedCounter)
        var log = Application.state(\.observerReactionLog)
        log.value = []
    }

    override func tearDown() async throws {
        Application.reset(\.observedCounter)
        var log = Application.state(\.observerReactionLog)
        log.value = []
        try await super.tearDown()
    }

    // MARK: - Helper

    /// Polls `observer.reactionCount` until it reaches `count` or `timeout` seconds elapse.
    ///
    /// Using a busy-poll with `Task.yield()` avoids a hard `sleep` while remaining on the main
    /// actor so that the `Task { @MainActor in … }` dispatched by `HeadlessObserver.handleChange`
    /// can execute between poll iterations.
    private func waitForReactions(
        in observer: HeadlessObserver,
        count expectedCount: Int,
        timeout: TimeInterval = 2.0
    ) async {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while observer.reactionCount < expectedCount, Date() < deadline {
            await Task.yield()
        }
    }

    // MARK: - Tests: started observer reacts

    /// Mutating `observedCounter` after `start()` must increment `reactionCount` and update
    /// `lastObservedValue`. This is the core proof that a plain object can observe `Application`.
    func testStartedObserverReactsToMutation() async {
        let observer = HeadlessObserver()
        observer.start()

        var counter = Application.state(\.observedCounter)
        counter.value = 42

        await waitForReactions(in: observer, count: 1)

        XCTAssertEqual(observer.reactionCount, 1,
            "HeadlessObserver must react once after a single mutation")
        XCTAssertEqual(observer.lastObservedValue, 42,
            "HeadlessObserver must capture the new counter value")
    }

    // MARK: - Tests: unstarted observer does NOT react

    /// An observer on which `start()` was never called must not react to mutations, proving
    /// that the observation loop is opt-in and not a side-effect of construction.
    func testUnstartedObserverDoesNotReact() async {
        let observer = HeadlessObserver()
        // Deliberately NOT calling observer.start()

        var counter = Application.state(\.observedCounter)
        counter.value = 99

        // Give the run-loop a few iterations to confirm nothing fires.
        for _ in 0 ..< 10 {
            await Task.yield()
        }

        XCTAssertEqual(observer.reactionCount, 0,
            "An unstarted HeadlessObserver must never receive change notifications")
        XCTAssertNil(observer.lastObservedValue,
            "lastObservedValue must remain nil when the observer has not been started")
    }

    // MARK: - Tests: multiple mutations accumulate

    /// Three sequential mutations must produce exactly three reactions, each capturing the
    /// latest value, proving that the continuous re-arm loop works correctly.
    func testMultipleMutationsAccumulateReactions() async {
        let observer = HeadlessObserver()
        observer.start()

        var counter = Application.state(\.observedCounter)
        counter.value = 1
        await waitForReactions(in: observer, count: 1)

        counter = Application.state(\.observedCounter)
        counter.value = 2
        await waitForReactions(in: observer, count: 2)

        counter = Application.state(\.observedCounter)
        counter.value = 3
        await waitForReactions(in: observer, count: 3)

        XCTAssertEqual(observer.reactionCount, 3,
            "Three mutations must produce exactly three reactions")
        XCTAssertEqual(observer.lastObservedValue, 3,
            "lastObservedValue must reflect the final mutation (3)")
    }

    // MARK: - Tests: reaction log is written to shared Application state

    /// The log entries written by `HeadlessObserver.handleChange` into `observerReactionLog`
    /// must be readable via the imperative `Application.state` accessor — confirming that the
    /// observer writes back into Application state that any subscriber (UI or otherwise) can read.
    func testReactionLogIsAppendedToApplicationState() async {
        let observer = HeadlessObserver()
        observer.start()

        var counter = Application.state(\.observedCounter)
        counter.value = 7

        await waitForReactions(in: observer, count: 1)

        let log = Application.state(\.observerReactionLog).value
        XCTAssertEqual(log.count, 1,
            "Exactly one log entry must appear after one mutation")
        XCTAssertTrue(log.first?.contains("counter=7") == true,
            "Log entry must contain the mutated counter value")
    }

    // MARK: - Tests: observer tracks incremental changes

    /// Verifies that `lastObservedValue` always reflects the *most recent* mutation, not a
    /// stale snapshot, even when mutations arrive in quick succession.
    func testLastObservedValueReflectsMostRecentMutation() async {
        let observer = HeadlessObserver()
        observer.start()

        for value in [10, 20, 30, 40, 50] {
            var counter = Application.state(\.observedCounter)
            counter.value = value
            await waitForReactions(in: observer, count: value / 10)
        }

        XCTAssertEqual(observer.lastObservedValue, 50,
            "lastObservedValue must equal the final mutation after sequential mutations")
        XCTAssertEqual(observer.reactionCount, 5,
            "Five sequential mutations must produce five reactions")
    }
}

#endif
