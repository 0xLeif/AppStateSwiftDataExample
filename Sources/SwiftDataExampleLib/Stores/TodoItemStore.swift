import AppState
import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - TodoItemStore

/// View-model for the items within a single `TodoList`.
@MainActor
public final class TodoItemStore: ObservableObject {

    // MARK: Properties

    /// The list whose items this store manages.
    public private(set) var list: TodoList

    /// All items (unfiltered), sourced from `Application.allItems`.
    @ModelState(\.allItems) public var allItems: [TodoItem]

    public init(list: TodoList) {
        self.list = list
    }

    // MARK: Public Interface

    /// Items belonging to this list, sorted by title. Uses `list.items` as the authoritative source.
    public var items: [TodoItem] {
        list.items.sorted { $0.title < $1.title }
    }

    public func addItem(titled title: String, priority: Int = 0, dueDate: Date? = nil) {
        let item = TodoItem(title: title, priority: priority, dueDate: dueDate)
        list.items.append(item)
        $allItems.insert(item)
    }

    public func delete(_ item: TodoItem) {
        $allItems.delete(item)
    }

    public func toggleDone(_ item: TodoItem) {
        item.isDone.toggle()
        $allItems.save()
    }

    /// Attaches (or reuses) a tag by name. Exercises the `@Attribute(.unique)` upsert path.
    public func attachTag(named tagName: String, to item: TodoItem) {
        let context = $allItems.context
        let existingTag = resolveTag(named: tagName, in: context)
        guard !item.tags.contains(where: { $0.name == tagName }) else { return }
        item.tags.append(existingTag)
        $allItems.save()
    }

    /// Removes a tag from an item without deleting the tag (nullify).
    public func detachTag(_ tag: Tag, from item: TodoItem) {
        item.tags.removeAll { $0.name == tag.name }
        $allItems.save()
    }

    /// Incomplete items tagged `tagName`, sorted by priority desc then title.
    public func incompleteItems(taggedWith tagName: String) -> [TodoItem] {
        Application.modelState(\.allItems)
            .models
            .filter { !$0.isDone && $0.tags.contains { $0.name == tagName } }
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.title < $1.title
            }
    }

    // MARK: Private Helpers

    private func resolveTag(named name: String, in context: ModelContext) -> Tag {
        let predicate = #Predicate<Tag> { $0.name == name }
        let descriptor = FetchDescriptor<Tag>(predicate: predicate)

        if let existing = (try? context.fetch(descriptor))?.first {
            return existing
        }
        let newTag = Tag(name: name)
        context.insert(newTag)
        return newTag
    }
}

#endif
