import AppState
import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - TodoListStore

/// `ObservableObject` view-model for the top-level list of `TodoList` records.
@MainActor
public final class TodoListStore: ObservableObject {

    // MARK: Properties

    /// All `TodoList` records, ordered by creation date (newest first).
    @ModelState(\.todoLists) public var lists: [TodoList]

    public init() {}

    // MARK: Public Interface

    public func createList(titled title: String) {
        $lists.insert(TodoList(title: title))
    }

    /// Cascade-deletes the list and all its child items.
    public func delete(_ list: TodoList) {
        $lists.delete(list)
    }

    public func save() {
        $lists.save()
    }
}

#endif
