import AppState
import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - Application + Lab dependencies & states

public extension Application {

    // MARK: ModelContainer dependency

    /// Shared in-memory `ModelContainer` for the lab. Override in tests via `Application.override`.
    var labContainer: Dependency<ModelContainer> {
        modelContainer(makeInMemoryLabContainer())
    }

    // MARK: - Unfiltered model states

    /// All `TodoList` records, newest first.
    var todoLists: ModelState<TodoList> {
        modelState(
            container: \.labContainer,
            fetchDescriptor: FetchDescriptor<TodoList>(
                sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
            )
        )
    }

    /// All `TodoItem` records, ordered by title.
    var allItems: ModelState<TodoItem> {
        modelState(
            container: \.labContainer,
            fetchDescriptor: FetchDescriptor<TodoItem>(
                sortBy: [SortDescriptor(\.title)]
            )
        )
    }

    /// All `Tag` records, ordered alphabetically by name.
    var allTags: ModelState<Tag> {
        modelState(
            container: \.labContainer,
            fetchDescriptor: FetchDescriptor<Tag>(
                sortBy: [SortDescriptor(\.name)]
            )
        )
    }

    // MARK: - Compound-query model states

    /// Incomplete items tagged `tagName`, sorted by priority desc then title asc, capped at `fetchLimit`.
    func incompleteItems(tagName: String, fetchLimit: Int = 50) -> ModelState<TodoItem> {
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
        return modelState(container: \.labContainer, fetchDescriptor: descriptor)
    }

    /// Incomplete items with `priority >= threshold`, sorted by priority desc then `createdAt` asc.
    func highPriorityIncompleteItems(threshold: Int = 1, fetchLimit: Int = 20) -> ModelState<TodoItem> {
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
        return modelState(container: \.labContainer, fetchDescriptor: descriptor)
    }

}

// MARK: - First-launch auto-seed

/// Seeds sample data on first launch; no-op if the store already has items.
///
/// All inserts run on a background `@ModelActor` — safe to call every launch.
/// ```swift
/// .task { await seedSampleDataIfEmpty() }
/// ```
@MainActor
public func seedSampleDataIfEmpty() async {
    let existingCount = Application.modelState(\.allItems).models.count
    guard existingCount == 0 else { return }

    let container = Application.dependency(\.labContainer)
    let seeder = DataSeeder(modelContainer: container)
    await seeder.seed(itemCount: 150)
}

#endif
