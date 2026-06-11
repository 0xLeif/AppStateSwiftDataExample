import AppState
import Foundation
import Observation

// MARK: - Application + Headless Observation States

public extension Application {

    // MARK: Observed counter

    /// An in-memory integer counter that `HeadlessObserver` tracks.
    ///
    /// Mutating `observedCounter.value` via `Application.state(\.observedCounter).value = N`
    /// calls `Application.notifyChange()` internally, which bumps `changeAnchor` and fires any
    /// active `withObservationTracking` closure — including the one armed by `HeadlessObserver`.
    var observedCounter: Application.State<Int> {
        state(initial: 0, feature: "HeadlessObservability", id: "observedCounter")
    }

    // MARK: Observer reaction log

    /// A log of timestamped reaction strings written by `HeadlessObserver` each time it detects
    /// a change to `observedCounter`.
    ///
    /// A plain SwiftUI view can read this state (via `@AppState(\.observerReactionLog)`) to
    /// display what the headless observer recorded — without the view itself being the observer.
    var observerReactionLog: Application.State<[String]> {
        state(initial: [], feature: "HeadlessObservability", id: "observerReactionLog")
    }
}

// MARK: - HeadlessObserver

/// A plain Swift object that observes `Application.state(\.observedCounter)` without being a
/// SwiftUI `View`, an `ObservableObject`, or a `DynamicProperty`.
///
/// ## How it works
///
/// `HeadlessObserver` arms a `withObservationTracking { … } onChange: { … }` loop in `start()`.
/// The *tracking* closure reads `Application.state(\.observedCounter).value`, which internally
/// calls `Application.shared.registerObservation()`. That call reads `changeAnchor` — the
/// single `@Observable`-tracked property on `Application` — registering the current tracking
/// scope as a dependent. When `Application.notifyChange()` is next called (which AppState's
/// setters invoke automatically), the `onChange` handler fires **synchronously**, outside of
/// any SwiftUI machinery.
///
/// The `onChange` handler records the new value, appends to the shared `observerReactionLog`,
/// and immediately re-arms another tracking scope so that subsequent mutations are also caught.
/// This produces a continuous, self-renewing observation loop.
///
/// ## AppState 3.0 vs. 2.x
///
/// In AppState **2.x**, `Application` was an `ObservableObject`. Its `objectWillChange`
/// publisher could only drive UI through `@ObservedObject` / `@StateObject` property wrappers,
/// which are SwiftUI-only constructs. Observing from a plain object required manual `Combine`
/// subscriptions wired to a `PassthroughSubject`.
///
/// In AppState **3.0**, `Application` is annotated `@Observable` (Swift's
/// `Observation` framework). The `withObservationTracking` function is a **pure Swift** API
/// with no dependency on SwiftUI — SwiftUI happens to use it internally to update views, but
/// nothing prevents a non-view object from using it too. This object is the proof.
@MainActor
public final class HeadlessObserver {

    // MARK: - Public API

    /// The number of times the observer has reacted to a change in `observedCounter` since
    /// `start()` was called.
    public private(set) var reactionCount: Int = 0

    /// The most recently observed value of `observedCounter`, or `nil` if `start()` has not
    /// been called or no changes have occurred yet.
    public private(set) var lastObservedValue: Int?

    /// `true` if `start()` has been called and the observation loop is active.
    public private(set) var isRunning: Bool = false

    // MARK: - Initialiser

    /// Creates a new, unstarted `HeadlessObserver`.
    ///
    /// Call `start()` to arm the observation loop.
    public init() {}

    // MARK: - Public Methods

    /// Arms the continuous `withObservationTracking` loop.
    ///
    /// Each call to `start()` installs a fresh tracking scope. The scope reads
    /// `Application.state(\.observedCounter).value`, subscribing itself to
    /// `Application.changeAnchor`. When `changeAnchor` is bumped (by any AppState write),
    /// the `onChange` handler fires, records the change, and re-arms a new scope.
    ///
    /// Calling `start()` multiple times is safe: each invocation is idempotent after the first
    /// because the continuous re-arm means only one active scope exists at any time.
    public func start() {
        isRunning = true
        armObservationTracking()
    }

    // MARK: - Private Methods

    /// Installs a single `withObservationTracking` scope and schedules a re-arm on change.
    ///
    /// The tracking closure reads the counter value so the scope is registered as dependent
    /// on `Application.changeAnchor`. The `onChange` handler captures `self` weakly to avoid
    /// a retain cycle; if the observer has been deallocated the cycle silently stops.
    private func armObservationTracking() {
        withObservationTracking {
            // Reading through the imperative accessor registers the current tracking scope
            // as dependent on Application.changeAnchor — the same mechanism SwiftUI uses.
            _ = Application.state(\.observedCounter).value
        } onChange: { [weak self] in
            // `onChange` fires on the same thread that committed the change (main actor for
            // AppState writes). Dispatch to the main actor to safely mutate our state and
            // access Application.state, then re-arm for the next change.
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.handleChange()
            }
        }
    }

    /// Records the new counter value, appends to the shared log, and re-arms tracking.
    private func handleChange() {
        let newValue = Application.state(\.observedCounter).value
        lastObservedValue = newValue
        reactionCount += 1

        let entry = "[\(reactionCount)] counter=\(newValue) at \(ISO8601DateFormatter().string(from: Date()))"
        var log = Application.state(\.observerReactionLog)
        log.value.append(entry)

        // Re-arm so we continue to observe future mutations.
        armObservationTracking()
    }
}
