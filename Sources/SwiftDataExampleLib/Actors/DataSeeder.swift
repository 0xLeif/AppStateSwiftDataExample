import AppState
import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - SeedSize

/// Predefined seeding presets for `DataSeeder`.
///
/// Each case exposes a human-readable `title` and the `itemCount` it will generate.
/// The enum conforms to `CaseIterable` so `SeederView` can iterate all presets.
public enum SeedSize: CaseIterable, Sendable {

    // MARK: Cases

    /// A quick sample run — useful for smoke-testing relationships.
    case sample

    /// A moderate data set — exercises queries and sort descriptors at meaningful scale.
    case large

    /// A stress-level data set — tests memory pressure and batch-save throughput.
    case stress

    /// An extreme data set — pushes the store and UI to their limits.
    case extreme

    // MARK: Properties

    /// A human-readable display label including the formatted item count.
    public var title: String {
        switch self {
        case .sample:  return "Sample · 50"
        case .large:   return "Large · 1,000"
        case .stress:  return "Stress · 10,000"
        case .extreme: return "Extreme · 50,000"
        }
    }

    /// The number of `TodoItem`s this preset will insert.
    public var itemCount: Int {
        switch self {
        case .sample:  return 50
        case .large:   return 1_000
        case .stress:  return 10_000
        case .extreme: return 50_000
        }
    }
}

// MARK: - DataSeeder

/// A `@ModelActor` that seeds the shared SwiftData store with a rich, related data graph,
/// running entirely off the main actor to keep the UI responsive.
///
/// `DataSeeder` creates realistic `TodoList`, `TodoItem`, and `Tag` records with varied
/// properties and dense many-to-many relationships. It never touches the main-actor
/// `mainContext` — all work happens inside the actor's own background `ModelContext`.
///
/// ### Usage
/// ```swift
/// let seeder = DataSeeder(modelContainer: Application.dependency(\.labContainer))
/// await seeder.seed(itemCount: 1_000) { inserted in
///     await MainActor.run { progress = inserted }
/// }
/// ```
///
/// ### Design notes
/// - Fetch-or-create keeps `Tag` names unique (respects `@Attribute(.unique)`).
/// - Lists scale with `itemCount` (~1 per 200 items, minimum 5) so relationships are dense.
/// - Items receive varied titles drawn from verb + noun pools (not "Seed Item N").
/// - ~30 % of items are marked done, ~50 % have a due date spread across past and future.
/// - Saves are batched (default 500) to keep memory pressure low; progress streams every
///   `progressStride` items so a `ProgressView` updates smoothly.
@ModelActor
public actor DataSeeder {

    // MARK: - Seed

    /// Inserts `itemCount` richly-related `TodoItem`s, distributed across `TodoList`s and `Tag`s,
    /// entirely on the background context.
    ///
    /// Progress is streamed via `onProgress` every `progressStride` items, decoupled from the
    /// save batch, so a progress bar advances smoothly. Pass `nil` if no tracking is needed.
    ///
    /// - Parameters:
    ///   - itemCount: Total `TodoItem`s to generate. No-op if ≤ 0.
    ///   - batchSize: Items persisted per save round-trip. Defaults to `500`.
    ///   - progressStride: Callback frequency in items. Defaults to `25`.
    ///   - onProgress: Optional `@Sendable` async closure called with the running inserted count.
    public func seed(
        itemCount: Int,
        batchSize: Int = 500,
        progressStride: Int = 25,
        onProgress: (@Sendable (Int) async -> Void)? = nil
    ) async {
        guard itemCount > 0 else { return }

        let effectiveBatch = max(1, batchSize)
        let stride = max(1, progressStride)

        // ── 1. Create or fetch the tag pool ──────────────────────────────────────────────────
        let tags = await fetchOrCreateTags()

        guard !Task.isCancelled else { return }

        // ── 2. Create the list pool (scales with itemCount) ───────────────────────────────────
        let listCount = max(5, itemCount / 200)
        let lists = createLists(count: listCount)

        guard !Task.isCancelled else {
            saveContext()
            return
        }

        saveContext()

        // ── 3. Insert items with varied properties ─────────────────────────────────────────
        var inserted = 0
        var sinceLastSave = 0

        while inserted < itemCount {
            guard !Task.isCancelled else {
                saveContext()
                await onProgress?(inserted)
                return
            }

            let item = makeSeedItem(index: inserted, lists: lists, tags: tags)
            modelContext.insert(item)
            inserted += 1
            sinceLastSave += 1

            if sinceLastSave >= effectiveBatch {
                saveContext()
                sinceLastSave = 0
            }

            if inserted % stride == 0 {
                await onProgress?(inserted)
                await Task.yield()
            }
        }

        saveContext()

        // Emit a terminal progress update if the last in-loop report didn't land on `itemCount`.
        if inserted % stride != 0 {
            await onProgress?(inserted)
        }
    }

    // MARK: - Clear All

    /// Deletes every `TodoItem`, `Tag`, and `TodoList` from the background context and saves.
    ///
    /// Safe to call while the store is being used from other contexts — the background context
    /// owns the delete and the shared `ModelContainer` propagates the changes.
    public func clearAll() async {
        deleteSeedModels(ofType: TodoItem.self)
        deleteSeedModels(ofType: Tag.self)
        deleteSeedModels(ofType: TodoList.self)
        saveContext()
    }

    // MARK: - Private: Tag pool

    /// Fetches existing `Tag` records or creates them if absent.
    ///
    /// Respects the `@Attribute(.unique)` constraint — inserting a Tag whose name already
    /// exists triggers SwiftData's upsert behaviour, which is why we fetch-first.
    private func fetchOrCreateTags() async -> [Tag] {
        let descriptor = FetchDescriptor<Tag>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let existingNames = Set(existing.map(\.name))

        var result = existing

        for name in SeedContent.tagNames where !existingNames.contains(name) {
            let tag = Tag(name: name)
            modelContext.insert(tag)
            result.append(tag)
        }

        return result
    }

    // MARK: - Private: List pool

    /// Creates `count` new `TodoList`s with realistic titles, cycling through the name pool.
    private func createLists(count: Int) -> [TodoList] {
        (0 ..< count).map { index in
            let name = SeedContent.listNames[index % SeedContent.listNames.count]
            let suffix = index < SeedContent.listNames.count ? "" : " \(index / SeedContent.listNames.count + 1)"
            let list = TodoList(title: "\(name)\(suffix)")
            modelContext.insert(list)
            return list
        }
    }

    // MARK: - Private: Item factory

    /// Builds a single `TodoItem` with realistic, varied properties.
    ///
    /// - `isDone`: ~30 % probability.
    /// - `dueDate`: ~50 % probability, spread ±365 days from now.
    /// - `priority`: random 0…5.
    /// - Tags: 0–3 random tags from the pool.
    /// - List: assigned to a list via round-robin distribution.
    private func makeSeedItem(index: Int, lists: [TodoList], tags: [Tag]) -> TodoItem {
        let title = SeedContent.makeTitle(index: index)
        let isDone = Int.random(in: 0 ..< 10) < 3   // ~30 %
        let priority = Int.random(in: 0 ... 5)

        let dueDate: Date? = Int.random(in: 0 ..< 2) == 0
            ? Date(timeIntervalSinceNow: Double.random(in: -365 ... 365) * 86_400)
            : nil

        let item = TodoItem(
            title: title,
            isDone: isDone,
            priority: priority,
            dueDate: dueDate
        )

        // Assign to a list (round-robin). Setting the to-one side is enough — SwiftData maintains the
        // inverse `list.items` automatically. Appending to the to-many side as well is redundant and
        // gets quadratic as the list grows, which is what made large seeds slow.
        item.list = lists[index % lists.count]

        // Attach 0–3 random tags in a single assignment (the inverse `Tag.items` is auto-maintained).
        if !tags.isEmpty {
            let tagCount = Int.random(in: 0 ... min(3, tags.count))
            item.tags = Array(tags.shuffled().prefix(tagCount))
        }

        return item
    }

    // MARK: - Private: Batch delete helper

    /// Deletes all instances of a `PersistentModel` type from the background context.
    private func deleteSeedModels<Model: PersistentModel>(ofType type: Model.Type) {
        let all = (try? modelContext.fetch(FetchDescriptor<Model>())) ?? []
        for model in all {
            modelContext.delete(model)
        }
    }

    // MARK: - Private: Save helper

    /// Saves the background `ModelContext`, logging failures without propagating them.
    private func saveContext() {
        guard modelContext.hasChanges else { return }
        do {
            try modelContext.save()
        } catch {
            print("DataSeeder: background save failed — \(error)")
        }
    }
}

// MARK: - SeedContent

/// Static content pools used to generate realistic, varied seed data.
///
/// Keeping these in a separate namespace prevents them from polluting `DataSeeder`'s interface.
private enum SeedContent {

    // MARK: Tag names

    static let tagNames: [String] = [
        "urgent", "home", "work", "errand", "shopping",
        "health", "finance", "travel", "reading", "ideas",
        "bills", "calls", "family", "personal", "project",
        "low-priority", "blocked", "in-progress", "review", "done",
    ]

    // MARK: List names

    static let listNames: [String] = [
        "Groceries", "Work Tasks", "Personal", "Reading List", "Home Projects",
        "Trip Planning", "Bills & Finance", "Fitness", "Garden", "Errands",
        "Shopping", "Side Projects", "Learning", "Calls to Make", "Wishlist",
    ]

    // MARK: Title components

    private static let verbs: [String] = [
        "Buy", "Call", "Review", "Schedule", "Fix",
        "Read", "Write", "Plan", "Order", "Clean",
        "Update", "Check", "Prepare", "Send", "Book",
        "Research", "Pay", "Organise", "Download", "Track",
        "Draft", "File", "Return", "Cancel", "Follow up on",
    ]

    private static let nouns: [String] = [
        "groceries", "dentist appointment", "quarterly report", "kitchen sink",
        "flight tickets", "electric bill", "gym session", "library books",
        "budget spreadsheet", "birthday gift", "car service", "tax return",
        "team meeting", "software update", "passport renewal", "new notebook",
        "prescription", "parking permit", "insurance claim", "dinner reservation",
        "podcast episode", "code review", "product roadmap", "bike tyres",
        "hotel booking", "vet appointment", "phone contract", "travel insurance",
        "mortgage statement", "Wi-Fi router", "garden tools", "window cleaning",
    ]

    // MARK: Title generation

    /// Produces a varied title by combining a verb and noun, cycling through the pools.
    static func makeTitle(index: Int) -> String {
        let verb = verbs[index % verbs.count]
        let noun = nouns[(index / verbs.count) % nouns.count]
        return "\(verb) \(noun)"
    }
}

#endif
