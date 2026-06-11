import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - SeederView

/// Drives `DataSeeder` off the main thread; shows live counts, progress, and preset buttons.
///
/// ```swift
/// NavigationStack { SeederView() }
/// ```
public struct SeederView: View {

    // MARK: - Properties

    @State private var progressCount: Int = 0
    @State private var targetCount: Int = 0
    @State private var isRunning: Bool = false
    /// Retained so Cancel can call `task.cancel()`.
    @State private var seedTask: Task<Void, Never>?
    @State private var isClearing: Bool = false

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

        // Scale the cadence with the dataset: ~100 progress updates total (smooth bar, far fewer
        // re-renders/main-actor hops) and larger save batches for big seeds.
        let stride = max(25, count / 100)
        let batchSize = count >= 10_000 ? 2_000 : 500

        seedTask = Task {
            let seeder = DataSeeder(modelContainer: container)

            await seeder.seed(itemCount: count, batchSize: batchSize, progressStride: stride) { inserted in
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

/// Store-count chip with animated number transition.
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
