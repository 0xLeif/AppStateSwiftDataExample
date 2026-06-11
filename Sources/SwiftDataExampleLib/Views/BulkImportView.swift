import AppState
import Foundation

#if canImport(SwiftData) && canImport(SwiftUI)
import SwiftData
import SwiftUI

// MARK: - BulkImportView

/// Non-blocking bulk SwiftData inserts via `BulkImporter`. The UI stays responsive throughout.
///
/// ```swift
/// BulkImportView()
/// ```
public struct BulkImportView: View {

    // MARK: - Properties

    @State private var progressCount: Int = 0
    @State private var isRunning: Bool = false
    @State private var wasCancelled: Bool = false
    @State private var finalCount: Int = 0
    /// Retained so Cancel can call `task.cancel()`.
    @State private var importTask: Task<Void, Never>?
    private let targetCount: Int

    // MARK: - Initialiser

    public init(targetCount: Int = 10_000) {
        self.targetCount = targetCount
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 24) {
            statusHeader
            progressSection
            controlButtons
            finalCountSection
            Spacer()
            interactivityDemoSection
        }
        .padding()
        .navigationTitle("Bulk Import")
    }

    // MARK: - Sub-views

    private var statusHeader: some View {
        VStack(spacing: 6) {
            Text(statusText)
                .font(.headline)
                .foregroundStyle(statusColor)
                .animation(.easeInOut, value: isRunning)
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(value: progressFraction)
                .progressViewStyle(.linear)
                .animation(.linear(duration: 0.1), value: progressCount)

            HStack {
                Text("\(progressCount) / \(targetCount) inserted")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                Spacer()
                Text(percentageText)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var controlButtons: some View {
        HStack(spacing: 16) {
            generateButton
            cancelButton
        }
    }

    private var generateButton: some View {
        Button {
            startImport()
        } label: {
            Label("Generate \(formattedCount(targetCount))", systemImage: "bolt.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .disabled(isRunning)
    }

    private var cancelButton: some View {
        Button(role: .destructive) {
            cancelImport()
        } label: {
            Label("Cancel", systemImage: "xmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(!isRunning)
    }

    @ViewBuilder
    private var finalCountSection: some View {
        if !isRunning && finalCount > 0 {
            VStack(spacing: 6) {
                Divider()
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("Main context now holds \(finalCount) item(s)")
                        .font(.subheadline)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var interactivityDemoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("UI Responsiveness Demo")
                .font(.caption.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(0 ..< 20, id: \.self) { index in
                        ResponsivenessChip(index: index, isRunning: isRunning)
                    }
                }
                .padding(.horizontal, 4)
            }
        }
    }

    // MARK: - Computed Helpers

    private var progressFraction: Double {
        guard targetCount > 0 else { return 0 }
        return Double(progressCount) / Double(targetCount)
    }

    private var percentageText: String {
        let pct = Int(progressFraction * 100)
        return "\(pct)%"
    }

    private var statusText: String {
        if isRunning { return "Importing in background…" }
        if wasCancelled { return "Import cancelled" }
        if progressCount == targetCount { return "Import complete" }
        return "Ready"
    }

    private var statusColor: Color {
        if isRunning { return .orange }
        if wasCancelled { return .red }
        if progressCount == targetCount { return .green }
        return .secondary
    }

    // MARK: - Actions

    private func startImport() {
        guard !isRunning else { return }

        progressCount = 0
        finalCount = 0
        wasCancelled = false
        isRunning = true

        let container = Application.dependency(\.labContainer)
        let count = targetCount

        importTask = Task {
            let importer = BulkImporter(modelContainer: container)

            await importer.importItems(count: count) { [count] inserted in
                let clamped = min(inserted, count)
                await MainActor.run {
                    progressCount = clamped
                }
            }

            // The actor's task has finished (completed or cancelled).
            // Hop back to the main actor to read the final persisted count.
            await MainActor.run {
                isRunning = false
                finalCount = Application.modelState(\.allItems).models.count
            }
        }
    }

    private func cancelImport() {
        importTask?.cancel()
        importTask = nil
        wasCancelled = true
        isRunning = false
    }

    // MARK: - Private Helpers

    private func formattedCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }
}

// MARK: - ResponsivenessChip

/// Animated chip that pulses during import, proving the main thread stays free.
private struct ResponsivenessChip: View {

    // MARK: Properties

    let index: Int
    let isRunning: Bool

    @State private var animating: Bool = false

    // MARK: Body

    var body: some View {
        Text("Live \(index + 1)")
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(chipColor.opacity(animating ? 0.9 : 0.3), in: Capsule())
            .foregroundStyle(animating ? .white : chipColor)
            .scaleEffect(animating ? 1.06 : 1.0)
            .animation(
                isRunning
                    ? .easeInOut(duration: 0.5).repeatForever().delay(Double(index) * 0.08)
                    : .default,
                value: animating
            )
            .onChange(of: isRunning) { _, running in
                animating = running
            }
    }

    private var chipColor: Color {
        let colors: [Color] = [.blue, .purple, .pink, .orange, .teal, .green, .indigo]
        return colors[index % colors.count]
    }
}

#endif
