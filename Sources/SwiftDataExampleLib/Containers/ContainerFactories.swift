import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - Container Factories

/// In-memory `ModelContainer` using the current (V2) schema.
///
/// The `fatalError` path is structurally uncoverable — an in-memory container for a static
/// schema cannot fail on supported platforms. It is the single intentionally-uncovered region.
public func makeInMemoryLabContainer() -> ModelContainer {
    do {
        return try ModelContainer(
            for: TodoList.self, TodoItem.self, Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Failed to create the in-memory lab ModelContainer: \(error)")
    }
}

/// In-memory `ModelContainer` for the V1 schema — used by migration tests.
public func makeInMemoryV1Container() -> ModelContainer {
    do {
        return try ModelContainer(
            for: LabSchemaV1.TodoList.self,
                LabSchemaV1.TodoItem.self,
                LabSchemaV1.Tag.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Failed to create the in-memory V1 ModelContainer: \(error)")
    }
}

/// In-memory `ModelContainer` backed by `LabMigrationPlan` (V1 → V2 lightweight migration).
public func makeInMemoryMigratedContainer() -> ModelContainer {
    do {
        return try ModelContainer(
            for: TodoList.self, TodoItem.self, Tag.self,
            migrationPlan: LabMigrationPlan.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    } catch {
        fatalError("Failed to create the in-memory migrated ModelContainer: \(error)")
    }
}

#endif
