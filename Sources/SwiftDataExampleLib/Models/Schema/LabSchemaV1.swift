import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - LabSchemaV1

/// V1 schema: `TodoList → cascade → TodoItem ↔ nullify ↔ Tag`. `Tag.name` is unique (upsert).
public enum LabSchemaV1: VersionedSchema {
    // `Schema.Version` is not `Sendable` on older SDKs; this is an immutable constant, so opt out
    // of the global-actor isolation check explicitly.
    nonisolated(unsafe) public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [TodoList.self, TodoItem.self, Tag.self]
    }

    // MARK: - TodoList

    @Model
    public final class TodoList {
        public var title: String
        public var createdAt: Date

        @Relationship(deleteRule: .cascade, inverse: \TodoItem.list)
        public var items: [TodoItem]

        public init(title: String, createdAt: Date = .now) {
            self.title = title
            self.createdAt = createdAt
            self.items = []
        }
    }

    // MARK: - TodoItem

    @Model
    public final class TodoItem {
        public var title: String
        public var isDone: Bool
        public var createdAt: Date

        public var list: TodoList?

        @Relationship(deleteRule: .nullify, inverse: \Tag.items)
        public var tags: [Tag]

        public init(title: String, isDone: Bool = false, createdAt: Date = .now) {
            self.title = title
            self.isDone = isDone
            self.createdAt = createdAt
            self.tags = []
        }
    }

    // MARK: - Tag

    /// `@Attribute(.unique)` on `name` means duplicate inserts perform an upsert.
    @Model
    public final class Tag {
        @Attribute(.unique)
        public var name: String

        public var items: [TodoItem]

        public init(name: String) {
            self.name = name
            self.items = []
        }
    }
}

#endif
