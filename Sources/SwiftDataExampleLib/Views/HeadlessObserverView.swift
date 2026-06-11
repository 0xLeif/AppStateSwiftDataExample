import AppState
import Foundation

#if canImport(SwiftUI)
import SwiftUI

// MARK: - HeadlessObserverView

/// Demonstrates AppState 3.0's `@Observable` observability working **without** SwiftUI being
/// the observer.
///
/// The button increments `Application.state(\.observedCounter)`. A separate plain Swift object
/// — `HeadlessObserver` — is what tracks that state via `withObservationTracking`. This view
/// merely presents what the headless observer recorded; it is not the entity doing the observing.
///
/// ### What this proves
/// SwiftUI views reactively re-render because they call `withObservationTracking` internally
/// during their `body` evaluation. In AppState 3.0, `Application` is `@Observable`, so the
/// same `withObservationTracking` API available to SwiftUI is available to **any** Swift code.
/// `HeadlessObserver` exercises this path with no SwiftUI machinery in the loop.
///
/// ### Integration
/// Place this inside an existing `NavigationStack` — it deliberately omits its own stack so
/// it composes cleanly as a pushed destination.
///
/// ```swift
/// NavigationStack {
///     HeadlessObserverView()
/// }
/// ```
public struct HeadlessObserverView: View {

    // MARK: - Properties

    /// The log entries written by `HeadlessObserver`; observed so the view re-renders when the
    /// headless object appends a new entry.
    @AppState(\.observerReactionLog) private var reactionLog: [String]

    /// The current counter value; observed so the "Current counter" row stays live.
    @AppState(\.observedCounter) private var counter: Int

    /// The headless observer whose reaction count and last value are displayed.
    @State private var observer: HeadlessObserver = HeadlessObserver()

    // MARK: - Initialiser

    public init() {}

    // MARK: - Body

    public var body: some View {
        List {
            counterSection
            observerSection
            logSection
        }
        .navigationTitle("Headless Observer")
        .task {
            observer.start()
        }
    }

    // MARK: - Sections

    /// Shows the live counter value and the "Mutate" button.
    private var counterSection: some View {
        Section("Observed State") {
            HStack {
                Text("Current counter")
                Spacer()
                Text("\(counter)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Current counter: \(counter)")

            Button("Mutate observed value") {
                var counter = Application.state(\.observedCounter)
                counter.value += 1
            }
            .accessibilityIdentifier("headlessObserverMutateButton")
        }
    }

    /// Reports what the *headless* object (not the view) observed.
    private var observerSection: some View {
        Section("HeadlessObserver (non-UI object)") {
            HStack {
                Text("Reactions fired")
                Spacer()
                Text("\(observer.reactionCount)")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Reactions fired: \(observer.reactionCount)")

            HStack {
                Text("Last seen value")
                Spacer()
                Text(observer.lastObservedValue.map { "\($0)" } ?? "—")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Last seen value: \(observer.lastObservedValue.map { "\($0)" } ?? "none")")
        }
    }

    /// Displays the timestamped reaction log entries written by `HeadlessObserver`.
    private var logSection: some View {
        Section("Reaction Log (written by HeadlessObserver)") {
            if reactionLog.isEmpty {
                Text("No reactions yet — tap the button above.")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            } else {
                ForEach(reactionLog.reversed(), id: \.self) { entry in
                    Text(entry)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#endif
