import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - LabSchemaV2

/// V2 schema: adds `priority` (Int, default 0) and `dueDate` (Date?) to `TodoItem`.
public enum LabSchemaV2: VersionedSchema {
    // `Schema.Version` is not `Sendable` on older SDKs; this is an immutable constant, so opt out
    // of the global-actor isolation check explicitly.
    nonisolated(unsafe) public static let versionIdentifier = Schema.Version(2, 0, 0)

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

    // MARK: - TodoItem (V2)

    @Model
    public final class TodoItem {
        public var title: String
        public var isDone: Bool
        public var createdAt: Date
        public var priority: Int
        public var dueDate: Date?

        public var list: TodoList?

        @Relationship(deleteRule: .nullify, inverse: \Tag.items)
        public var tags: [Tag]

        public init(
            title: String,
            isDone: Bool = false,
            priority: Int = 0,
            dueDate: Date? = nil,
            createdAt: Date = .now
        ) {
            self.title = title
            self.isDone = isDone
            self.priority = priority
            self.dueDate = dueDate
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

// MARK: - LabMigrationPlan

/// V1 → V2 lightweight migration (additive columns with defaults — no custom code needed).
public enum LabMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] {
        [LabSchemaV1.self, LabSchemaV2.self]
    }

    public static var stages: [MigrationStage] {
        [migrateV1toV2]
    }

    // `MigrationStage` is not `Sendable` on older SDKs; this is an immutable constant.
    nonisolated(unsafe) private static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: LabSchemaV1.self,
        toVersion: LabSchemaV2.self
    )
}

#endif
