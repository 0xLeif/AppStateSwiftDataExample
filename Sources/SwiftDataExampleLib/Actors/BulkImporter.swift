import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - BulkImporter

/// Inserts large batches of `TodoItem`s on a background `@ModelActor`, never touching `mainContext`.
///
/// ```swift
/// let importer = BulkImporter(modelContainer: Application.dependency(\.labContainer))
/// await importer.importItems(count: 10_000) { inserted in
///     await MainActor.run { progressCount = inserted }
/// }
/// ```
@ModelActor
public actor BulkImporter {

    // MARK: - Public API

    /// Inserts `count` synthetic `TodoItem`s into the background context, saving every `batchSize` inserts.
    ///
    /// Progress (`onProgress`) fires every `progressStride` items — decoupled from saves so a progress
    /// bar advances smoothly. Checks `Task.isCancelled` before every batch; cancel via the `Task` handle.
    public func importItems(
        count: Int,
        batchSize: Int = 500,
        progressStride: Int = 25,
        listTitle: String = "Bulk Import",
        onProgress: (@Sendable (Int) async -> Void)? = nil
    ) async {
        guard count > 0 else { return }

        let effectiveBatchSize = max(1, batchSize)
        let stride = max(1, progressStride)

        // Create the parent list entirely in the background context — never mainContext.
        let list = TodoList(title: listTitle)
        modelContext.insert(list)

        var inserted = 0
        var sinceLastSave = 0

        while inserted < count {
            guard !Task.isCancelled else {
                saveContext()
                await onProgress?(inserted)
                return
            }

            let item = TodoItem(
                title: "Bulk Item \(inserted + 1)",
                priority: inserted % 6
            )
            list.items.append(item)
            modelContext.insert(item)
            inserted += 1
            sinceLastSave += 1

            // Persist in batches to keep memory pressure low…
            if sinceLastSave >= effectiveBatchSize {
                saveContext()
                sinceLastSave = 0
            }

            // …but stream progress far more often so the UI updates live.
            if inserted % stride == 0 {
                await onProgress?(inserted)
                // Yield so the concurrency scheduler can service the UI between updates.
                await Task.yield()
            }
        }

        // Flush the final partial batch. Emit a terminal update only if the last in-loop report
        // didn't already land exactly on `count` (avoids a duplicate final callback).
        saveContext()
        if inserted % stride != 0 {
            await onProgress?(inserted)
        }
    }

    // MARK: - Private Implementation

    /// Saves the background context, logging failures without propagating them.
    private func saveContext() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            print("BulkImporter: background save failed — \(error)")
        }
    }
}

#endif
