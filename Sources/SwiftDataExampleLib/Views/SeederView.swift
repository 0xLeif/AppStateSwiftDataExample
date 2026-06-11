import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - SeederView

/// A SwiftUI screen that drives `DataSeeder` to fill the shared store with varied, related data
/// entirely off the main thread.
///
/// The view shows live store counts (lists / items / tags), one button per `SeedSize` preset,
/// a live `ProgressView` during seeding, and a destructive "Clear All" control. All heavy work
/// runs inside the `@ModelActor` `DataSeeder` — only tiny `@State` integers are updated on the
/// main actor.
///
/// ### Integration
/// ```swift
/// NavigationStack {
///     SeederView()
/// }
/// ```
///
/// The view is self-contained: it attaches its own `.navigationTitle` but does not wrap itself
/// in a `NavigationStack` or `NavigationSplitView`.
public struct SeederView: View {

    // MARK: - Properties

    /// Running inserted-item count streamed from the background actor.
    @State private var progressCount: Int = 0

    /// Total items the active preset will generate (used to compute the progress fraction).
    @State private var targetCount: Int = 0

    /// Whether a seed operation is currently in flight.
    @State private var isRunning: Bool = false

    /// The `Task` wrapping the active seed run — retained so Cancel can cancel it.
    @State private var seedTask: Task<Void, Never>?

    /// Whether a clear operation is currently running.
    @State private var isClearing: Bool = false

    // MARK: - Init

    /// Creates a `SeederView`.
    public init() {}

    // MARK: - Body

    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                liveCountsSection
                progressSection
                presetsSection
                clearSection
                Spacer(minLength: 0)
            }
            .padding()
        }
        .navigationTitle("Seed & Stress")
        .disabled(isClearing)
    }

    // MARK: - Sub-views

    private var liveCountsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Live Store Counts")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            HStack(spacing: 0) {
                SeedCountChip(label: "Lists", count: storeCount(TodoList.self), color: .blue)
                SeedCountChip(label: "Items", count: storeCount(TodoItem.self), color: .purple)
                SeedCountChip(label: "Tags", count: storeCount(Tag.self), color: .teal)
            }
            .padding(.vertical, 2)
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var progressSection: some View {
        if isRunning || progressCount > 0 {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(isRunning ? "Seeding in background…" : "Seed complete")
                        .font(.subheadline.bold())
                        .foregroundStyle(isRunning ? .orange : .green)
                    Spacer()
                    if isRunning {
                        Button(role: .destructive) {
                            cancelSeed()
                        } label: {
                            Label("Cancel", systemImage: "xmark.circle")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                ProgressView(value: progressFraction)
                    .progressViewStyle(.linear)
                    .animation(.linear(duration: 0.1), value: progressCount)

                HStack {
                    Text("\(progressCount) / \(targetCount) items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                    Spacer()
                    Text("\(Int(progressFraction * 100))%")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(SeedSize.allCases, id: \.itemCount) { size in
                SeedPresetButton(size: size, isRunning: isRunning) {
                    startSeed(size: size)
                }
            }

            Text("All seeding runs on a background @ModelActor — the UI stays fully responsive.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var clearSection: some View {
        Button(role: .destructive) {
            startClear()
        } label: {
            Label("Clear All Data", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(.red)
        .disabled(isRunning)
    }

    // MARK: - Computed

    private var progressFraction: Double {
        guard targetCount > 0 else { return 0 }
        return min(1, Double(progressCount) / Double(targetCount))
    }

    // MARK: - Actions

    private func startSeed(size: SeedSize) {
        guard !isRunning else { return }

        progressCount = 0
        targetCount = size.itemCount
        isRunning = true

        let container = Application.dependency(\.labContainer)
        let count = size.itemCount

        seedTask = Task {
            let seeder = DataSeeder(modelContainer: container)

            await seeder.seed(itemCount: count) { inserted in
                let clamped = min(inserted, count)
                await MainActor.run {
                    progressCount = clamped
                }
            }

            await MainActor.run {
                isRunning = false
                seedTask = nil
            }
        }
    }

    private func cancelSeed() {
        seedTask?.cancel()
        seedTask = nil
        isRunning = false
    }

    private func startClear() {
        guard !isRunning else { return }

        isClearing = true

        let container = Application.dependency(\.labContainer)

        Task {
            let seeder = DataSeeder(modelContainer: container)
            await seeder.clearAll()

            await MainActor.run {
                progressCount = 0
                targetCount = 0
                isClearing = false
            }
        }
    }

    /// A cheap live store count via `fetchCount` (a SQL `COUNT(*)`).
    ///
    /// `ModelState.models.count` materializes *every* record before counting, which — because this
    /// view re-renders on each streamed progress tick — made the counts O(n) per frame and dominated
    /// large-seed time. `fetchCount` counts in the store without loading any objects.
    private func storeCount<Model: PersistentModel>(_ type: Model.Type) -> Int {
        let context = Application.dependency(\.labContainer).mainContext
        return (try? context.fetchCount(FetchDescriptor<Model>())) ?? 0
    }
}

// MARK: - SeedCountChip

/// A compact stat chip displaying a store-count with a label.
private struct SeedCountChip: View {

    let label: String
    let count: Int
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(count)")
                .font(.title2.bold())
                .monospacedDigit()
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.2), value: count)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - SeedPresetButton

/// A single preset row button for `SeederView`.
private struct SeedPresetButton: View {

    let size: SeedSize
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(size.title)
                        .font(.body.bold())
                    Text("\(formattedCount(size.itemCount)) TodoItems + related lists & tags")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "bolt.fill")
                    .foregroundStyle(buttonTint)
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .disabled(isRunning)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(buttonTint.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 2)
    }

    private var buttonTint: Color {
        switch size {
        case .sample:  return .blue
        case .large:   return .green
        case .stress:  return .orange
        case .extreme: return .red
        }
    }

    private func formattedCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}

#endif
