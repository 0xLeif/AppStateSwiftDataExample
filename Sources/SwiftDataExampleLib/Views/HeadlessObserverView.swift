import AppState
import Foundation

#if canImport(SwiftUI)
import SwiftUI

// MARK: - HeadlessObserverView

/// Shows what `HeadlessObserver` recorded — the view is not the observer; it just reads the log.
///
/// ```swift
/// HeadlessObserverView()
/// ```
public struct HeadlessObserverView: View {

    // MARK: - Properties

    @AppState(\.observerReactionLog) private var reactionLog: [String]
    @AppState(\.observedCounter) private var counter: Int
    @State private var observer: HeadlessObserver = HeadlessObserver()

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
