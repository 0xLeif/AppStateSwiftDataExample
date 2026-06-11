import AppState
import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - Public query helper functions

/// Incomplete items tagged `tagName`, sorted by priority desc then title asc, capped at `fetchLimit`.
///
/// Free function so tests and non-`Application` call sites can execute the compound query directly.
@MainActor
public func fetchIncompleteItems(tagName: String, fetchLimit: Int = 50) -> [TodoItem] {
    let context = Application.modelContext(\.labContainer)
    let predicate = #Predicate<TodoItem> { item in
        item.isDone == false && item.tags.contains { $0.name == tagName }
    }
    var descriptor = FetchDescriptor<TodoItem>(
        predicate: predicate,
        sortBy: [
            SortDescriptor(\.priority, order: .reverse),
            SortDescriptor(\.title),
        ]
    )
    descriptor.fetchLimit = fetchLimit
    return (try? context.fetch(descriptor)) ?? []
}

/// Incomplete items with `priority >= threshold`, sorted by priority desc then `createdAt` asc.
@MainActor
public func fetchHighPriorityIncompleteItems(threshold: Int = 1, fetchLimit: Int = 20) -> [TodoItem] {
    let context = Application.modelContext(\.labContainer)
    let predicate = #Predicate<TodoItem> { item in
        item.isDone == false && item.priority >= threshold
    }
    var descriptor = FetchDescriptor<TodoItem>(
        predicate: predicate,
        sortBy: [
            SortDescriptor(\.priority, order: .reverse),
            SortDescriptor(\.createdAt),
        ]
    )
    descriptor.fetchLimit = fetchLimit
    return (try? context.fetch(descriptor)) ?? []
}

#endif
