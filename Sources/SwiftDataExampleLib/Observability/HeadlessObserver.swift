import AppState
import Foundation
import Observation

// MARK: - Application + Headless Observation States

public extension Application {

    // MARK: Observed counter

    /// In-memory counter observed by `HeadlessObserver`.
    var observedCounter: Application.State<Int> {
        state(initial: 0, feature: "HeadlessObservability", id: "observedCounter")
    }

    // MARK: Observer reaction log

    /// Timestamped reactions written by `HeadlessObserver`; read via `@AppState(\.observerReactionLog)`.
    var observerReactionLog: Application.State<[String]> {
        state(initial: [], feature: "HeadlessObservability", id: "observerReactionLog")
    }
}

// MARK: - HeadlessObserver

/// Observes `Application.state(\.observedCounter)` from a plain Swift object — no SwiftUI required.
///
/// Arms a `withObservationTracking { … } onChange: { … }` loop in `start()`. The tracking closure
/// reads `observedCounter.value`, registering the scope against `Application`'s `@Observable`
/// `changeAnchor`. When AppState writes bump `changeAnchor`, `onChange` fires, records the new value,
/// and immediately re-arms — producing a continuous self-renewing loop.
///
/// This proves that AppState 3.0's `@Observable` backend is accessible to any Swift code, not just
/// SwiftUI views (which use the same `withObservationTracking` internally).
@MainActor
public final class HeadlessObserver {

    // MARK: - Public API

    public private(set) var reactionCount: Int = 0
    public private(set) var lastObservedValue: Int?
    /// `true` once `start()` has been called.
    public private(set) var isRunning: Bool = false

    // MARK: - Initialiser

    public init() {}

    // MARK: - Public Methods

    /// Arms the continuous observation loop. Safe to call multiple times.
    public func start() {
        isRunning = true
        armObservationTracking()
    }

    // MARK: - Private Methods

    private func armObservationTracking() {
        withObservationTracking {
            // Reading the value registers this scope against Application.changeAnchor.
            _ = Application.state(\.observedCounter).value
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning else { return }
                self.handleChange()
            }
        }
    }

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
