import AppState
import Foundation

#if canImport(SwiftData)
import SwiftData

// MARK: - SeedSize

/// Predefined seeding presets for `DataSeeder`.
public enum SeedSize: CaseIterable, Sendable {
    case sample
    case large
    case stress
    case extreme

    /// Display label with item count.
    public var title: String {
        switch self {
        case .sample:  return "Sample · 50"
        case .large:   return "Large · 1,000"
        case .stress:  return "Stress · 10,000"
        case .extreme: return "Extreme · 50,000"
        }
    }

    /// Total `TodoItem`s this preset generates.
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

/// Seeds the shared store with richly-related `TodoList`, `TodoItem`, and `Tag` records,
/// entirely off the main actor.
///
/// ```swift
/// let seeder = DataSeeder(modelContainer: Application.dependency(\.labContainer))
/// await seeder.seed(itemCount: 1_000) { inserted in
///     await MainActor.run { progress = inserted }
/// }
/// ```
@ModelActor
public actor DataSeeder {

    // MARK: - Seed

    /// Inserts `itemCount` items with varied properties and related lists/tags on the background context.
    ///
    /// Progress fires every `progressStride` items, decoupled from save batches.
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
    public func clearAll() async {
        deleteSeedModels(ofType: TodoItem.self)
        deleteSeedModels(ofType: Tag.self)
        deleteSeedModels(ofType: TodoList.self)
        saveContext()
    }

    // MARK: - Private: Tag pool

    /// Fetches existing tags or creates missing ones, respecting `@Attribute(.unique)`.
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

    /// Creates `count` new `TodoList`s, cycling through the name pool.
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

    /// Builds one `TodoItem` with randomised `isDone` (~30%), `priority` (0–5), `dueDate` (~50%), and 0–3 tags.
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

/// Static content pools for seed data generation.
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
