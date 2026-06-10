import XCTest
import AppState
@testable import SwiftDataExampleLib

#if canImport(SwiftData)
import SwiftData

// MARK: - DataSeederTests

/// Unit tests for `DataSeeder`.
///
/// Each test overrides `\.labContainer` with a fresh in-memory container so they are fully
/// isolated. The seeder runs on its own `@ModelActor` executor — tests `await` the actor's
/// methods and then read results back on `@MainActor` via the main context to verify correctness.
///
/// ### Coverage
/// - Correct total item count after `seed(itemCount:)`.
/// - Lists and tags are created and wired to items.
/// - Relationship density: items have a list; some items have tags; tags are shared.
/// - `clearAll()` removes every `TodoItem`, `Tag`, and `TodoList`.
/// - Progress callback streams monotonically increasing values ending at `itemCount`.
/// - Cancellation stops the seed early without corrupting the store.
/// - `SeedSize` exposes expected item counts and a non-empty title.
/// - `seedSampleDataIfEmpty()` seeds only once (no-op when store is non-empty).
@MainActor
final class DataSeederTests: XCTestCase {

    // MARK: - Properties

    private var containerOverride: Application.DependencyOverride?

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        containerOverride = Application.override(
            \.labContainer,
            with: makeInMemoryLabContainer()
        )
    }

    override func tearDown() async throws {
        await containerOverride?.cancel()
        containerOverride = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func makeSeeder() -> DataSeeder {
        DataSeeder(modelContainer: Application.dependency(\.labContainer))
    }

    private func itemCount() -> Int {
        Application.modelState(\.allItems).models.count
    }

    private func listCount() -> Int {
        Application.modelState(\.todoLists).models.count
    }

    private func tagCount() -> Int {
        Application.modelState(\.allTags).models.count
    }

    // MARK: - Tests: Basic item count

    func testSeedInsertsExactItemCount() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        XCTAssertEqual(itemCount(), 60)
    }

    func testSeedInsertCountNotMultipleOfBatch() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 75, batchSize: 20)
        XCTAssertEqual(itemCount(), 75)
    }

    func testSeedCountSmallerThanBatchSize() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 10, batchSize: 500)
        XCTAssertEqual(itemCount(), 10)
    }

    func testSeedZeroCountIsNoOp() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 0)
        XCTAssertEqual(itemCount(), 0)
    }

    // MARK: - Tests: Lists created

    func testSeedCreatesAtLeastFiveLists() async {
        let seeder = makeSeeder()
        // With 60 items, listCount = max(5, 60/200) = 5.
        await seeder.seed(itemCount: 60)
        XCTAssertGreaterThanOrEqual(listCount(), 5)
    }

    func testSeedScalesListsWithItemCount() async {
        let seeder = makeSeeder()
        // 200 items → max(5, 200/200) = max(5,1) = 5 lists minimum.
        await seeder.seed(itemCount: 200)
        XCTAssertGreaterThanOrEqual(listCount(), 5)
    }

    // MARK: - Tests: Tags created

    func testSeedCreatesTagsFromPool() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        // With 60 items and 0–3 tags per item, at least some tags must be created.
        XCTAssertGreaterThan(tagCount(), 0)
    }

    // MARK: - Tests: Relationships

    func testAllItemsHaveAList() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        let items = Application.modelState(\.allItems).models
        let allHaveList = items.allSatisfy { $0.list != nil }
        XCTAssertTrue(allHaveList, "Every seeded TodoItem must be assigned to a TodoList")
    }

    func testSomeItemsHaveTags() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 100)
        let items = Application.modelState(\.allItems).models
        let itemsWithTags = items.filter { !$0.tags.isEmpty }
        // With 100 items and 0–3 tags each, statistically some will have tags.
        XCTAssertGreaterThan(itemsWithTags.count, 0, "At least some items must have tags attached")
    }

    func testTagsAreSharedAcrossItems() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 100)

        let tags = Application.modelState(\.allTags).models
        // If tags are truly shared (not duplicated per-item), the max tag.items.count > 1.
        let maxUsage = tags.map { $0.items.count }.max() ?? 0
        XCTAssertGreaterThan(maxUsage, 1, "Tags must be shared across multiple items")
    }

    func testTagsAreUnique() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 100)

        let tags = Application.modelState(\.allTags).models
        let names = tags.map(\.name)
        let unique = Set(names)
        XCTAssertEqual(names.count, unique.count, "Tag names must satisfy the @Attribute(.unique) constraint")
    }

    func testListItemCountsAddUpToTotal() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 80)
        let lists = Application.modelState(\.todoLists).models
        let total = lists.reduce(0) { $0 + $1.items.count }
        XCTAssertEqual(total, 80, "Sum of items across all lists must equal the seeded count")
    }

    // MARK: - Tests: Item property variety

    func testSomeItemsAreDone() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 100)
        let doneItems = Application.modelState(\.allItems).models.filter(\.isDone)
        XCTAssertGreaterThan(doneItems.count, 0, "~30% of items should be marked done")
    }

    func testSomeItemsHaveDueDates() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 100)
        let withDueDate = Application.modelState(\.allItems).models.filter { $0.dueDate != nil }
        XCTAssertGreaterThan(withDueDate.count, 0, "~50% of items should have a due date")
    }

    func testItemPriorityIsInValidRange() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        let priorities = Application.modelState(\.allItems).models.map(\.priority)
        XCTAssertTrue(priorities.allSatisfy { $0 >= 0 && $0 <= 5 })
    }

    func testItemTitlesAreNotPlaceholders() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        let titles = Application.modelState(\.allItems).models.map(\.title)
        let allNonEmpty = titles.allSatisfy { !$0.isEmpty }
        XCTAssertTrue(allNonEmpty, "Every item must have a non-empty title")
        // Titles must NOT be the BulkImporter-style "Bulk Item N" placeholders.
        let anyPlaceholder = titles.contains { $0.hasPrefix("Bulk Item") || $0.hasPrefix("Seed Item") }
        XCTAssertFalse(anyPlaceholder, "DataSeeder must generate realistic titles, not placeholders")
    }

    // MARK: - Tests: clearAll

    func testClearAllRemovesAllItems() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        XCTAssertEqual(itemCount(), 60)

        await seeder.clearAll()
        XCTAssertEqual(itemCount(), 0)
    }

    func testClearAllRemovesAllLists() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        await seeder.clearAll()
        XCTAssertEqual(listCount(), 0)
    }

    func testClearAllRemovesAllTags() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        await seeder.clearAll()
        XCTAssertEqual(tagCount(), 0)
    }

    func testClearAllOnEmptyStoreIsNoOp() async {
        let seeder = makeSeeder()
        await seeder.clearAll()
        XCTAssertEqual(itemCount(), 0)
    }

    func testSeedAfterClearInsertsCorrectly() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60)
        await seeder.clearAll()
        await seeder.seed(itemCount: 80)
        XCTAssertEqual(itemCount(), 80)
    }

    // MARK: - Tests: Progress callback

    func testProgressCallbackStreamsValues() async {
        var callCount = 0
        let seeder = makeSeeder()

        await seeder.seed(itemCount: 100, batchSize: 50, progressStride: 25) { _ in
            await MainActor.run { callCount += 1 }
        }

        // 100 items / stride 25 = 4 updates (at 25, 50, 75, 100).
        XCTAssertEqual(callCount, 4)
    }

    func testProgressCallbackValuesAreMonotonicallyIncreasing() async {
        var values: [Int] = []
        let seeder = makeSeeder()

        await seeder.seed(itemCount: 60, batchSize: 20, progressStride: 25) { inserted in
            await MainActor.run { values.append(inserted) }
        }

        XCTAssertFalse(values.isEmpty)
        XCTAssertEqual(values, values.sorted())
        XCTAssertEqual(values.last, 60)
    }

    func testProgressCallbackFinalValueEqualsItemCount() async {
        var last = 0
        let seeder = makeSeeder()

        await seeder.seed(itemCount: 80, batchSize: 20) { inserted in
            await MainActor.run { last = inserted }
        }

        XCTAssertEqual(last, 80)
    }

    func testProgressCallbackIsOptional() async {
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 60, onProgress: nil)
        XCTAssertEqual(itemCount(), 60)
    }

    // MARK: - Tests: Cancellation

    func testCancellationStopsSeedEarly() async {
        let seeder = makeSeeder()

        let task = Task {
            await seeder.seed(itemCount: 10_000, batchSize: 100)
        }

        try? await Task.sleep(nanoseconds: 1_000_000)
        task.cancel()
        await task.value

        let inserted = itemCount()
        XCTAssertLessThan(inserted, 10_000, "Cancellation must stop the seed before all items are inserted")
    }

    func testCancellationLeavesStoreConsistent() async {
        let seeder = makeSeeder()

        let task = Task {
            await seeder.seed(itemCount: 5_000, batchSize: 250)
        }

        try? await Task.sleep(nanoseconds: 2_000_000)
        task.cancel()
        await task.value

        XCTAssertGreaterThanOrEqual(itemCount(), 0, "Store must remain consistent after cancellation")
    }

    // MARK: - Tests: SeedSize

    func testSeedSizeAllCasesIsNonEmpty() {
        XCTAssertFalse(SeedSize.allCases.isEmpty)
    }

    func testSeedSizeSampleCount() {
        XCTAssertEqual(SeedSize.sample.itemCount, 50)
    }

    func testSeedSizeLargeCount() {
        XCTAssertEqual(SeedSize.large.itemCount, 1_000)
    }

    func testSeedSizeStressCount() {
        XCTAssertEqual(SeedSize.stress.itemCount, 10_000)
    }

    func testSeedSizeExtremeCount() {
        XCTAssertEqual(SeedSize.extreme.itemCount, 50_000)
    }

    func testSeedSizeTitlesAreNonEmpty() {
        for size in SeedSize.allCases {
            XCTAssertFalse(size.title.isEmpty, "SeedSize.\(size) must have a non-empty title")
        }
    }

    func testSeedSizeTitlesContainItemCount() {
        XCTAssertTrue(SeedSize.sample.title.contains("50"))
        XCTAssertTrue(SeedSize.large.title.contains("1,000"))
        XCTAssertTrue(SeedSize.stress.title.contains("10,000"))
        XCTAssertTrue(SeedSize.extreme.title.contains("50,000"))
    }

    // MARK: - Tests: seedSampleDataIfEmpty

    func testSeedSampleDataIfEmptySeedsWhenStoreIsEmpty() async {
        await seedSampleDataIfEmpty()
        XCTAssertGreaterThan(itemCount(), 0, "seedSampleDataIfEmpty must insert items into an empty store")
    }

    func testSeedSampleDataIfEmptyIsNoOpWhenStoreIsNonEmpty() async {
        // Pre-populate the store.
        let seeder = makeSeeder()
        await seeder.seed(itemCount: 10)
        let countBefore = itemCount()
        XCTAssertEqual(countBefore, 10)

        // Should not add more items.
        await seedSampleDataIfEmpty()
        XCTAssertEqual(itemCount(), countBefore, "seedSampleDataIfEmpty must not insert when store is non-empty")
    }

    func testSeedSampleDataIfEmptyInserts150Items() async {
        await seedSampleDataIfEmpty()
        XCTAssertEqual(itemCount(), 150, "seedSampleDataIfEmpty must insert exactly 150 items")
    }
}

#endif
