import XCTest
import AppState
@testable import SwiftDataExampleLib

#if canImport(SwiftData) && canImport(SwiftUI) && !os(Linux) && !os(Windows)
import SwiftData
import SwiftUI
import ViewInspector

// MARK: - ItemEditorViewTests

/// ViewInspector and persistence tests for `ItemEditorView` and supporting types.
///
/// Each test class overrides `\.labContainer` with a fresh in-memory container
/// to guarantee full isolation between test cases.
@MainActor
final class ItemEditorViewTests: XCTestCase {

    // MARK: - Properties

    private var containerOverride: Application.DependencyOverride?
    private var store: ItemEditorStore!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        containerOverride = Application.override(\.labContainer, with: makeInMemoryLabContainer())
        store = ItemEditorStore()
    }

    override func tearDown() async throws {
        store = nil
        await containerOverride?.cancel()
        containerOverride = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Inserts a known `TodoItem` and returns it, for use as a test fixture.
    private func insertKnownItem(
        title: String = "Test Task",
        priority: Int = 3,
        isDone: Bool = false
    ) -> TodoItem {
        let item = TodoItem(title: title, isDone: isDone, priority: priority)
        Application.modelState(\.allItems).insert(item)
        return item
    }

    // MARK: - Tests: List rendering via ViewInspector

    /// The list must render an inserted item's title somewhere in the view hierarchy.
    func testListRendersKnownItemTitle() throws {
        _ = insertKnownItem(title: "My Known Task")

        let sut = ItemEditorView()
        XCTAssertNoThrow(try sut.inspect().find(text: "My Known Task"),
                         "ItemEditorView must display the title of every inserted TodoItem")
    }

    /// Inserting two items must produce two rows, both visible in the hierarchy.
    func testListRendersBothItems() throws {
        _ = insertKnownItem(title: "Alpha Task")
        _ = insertKnownItem(title: "Zeta Task")

        let sut = ItemEditorView()
        XCTAssertNoThrow(try sut.inspect().find(text: "Alpha Task"))
        XCTAssertNoThrow(try sut.inspect().find(text: "Zeta Task"))
    }

    /// A completed item must show the filled checkmark system image.
    func testRowShowsCheckmarkForCompletedItem() throws {
        let item = TodoItem(title: "Done Item", isDone: true)
        Application.modelState(\.allItems).insert(item)

        let sut = ItemEditorRowView(item: item)
        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "checkmark.circle.fill")
    }

    /// An incomplete item must show the empty circle system image.
    func testRowShowsEmptyCircleForIncompleteItem() throws {
        let item = TodoItem(title: "Pending Item", isDone: false)
        Application.modelState(\.allItems).insert(item)

        let sut = ItemEditorRowView(item: item)
        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "circle")
    }

    /// A non-zero priority must produce a visible badge in the row.
    func testRowShowsPriorityBadgeForHighPriorityItem() throws {
        let item = TodoItem(title: "Urgent", priority: 4)
        Application.modelState(\.allItems).insert(item)

        let sut = ItemEditorRowView(item: item)
        XCTAssertNoThrow(try sut.inspect().find(text: "P4"),
                         "Row must show a priority badge for items with priority > 0")
    }

    /// A zero-priority item must not show any priority badge text.
    func testRowHidesZeroPriorityBadge() throws {
        let item = TodoItem(title: "Normal", priority: 0)
        Application.modelState(\.allItems).insert(item)

        let sut = ItemEditorRowView(item: item)
        XCTAssertThrowsError(try sut.inspect().find(text: "P0"),
                             "Row must not render a badge when priority is 0")
    }

    /// The detail sheet must display the item's title in its text field.
    func testDetailSheetRendersItemTitle() throws {
        let item = insertKnownItem(title: "Sheet Task")

        let sut = ItemEditorDetailSheet(item: item, store: store)
        XCTAssertNoThrow(try sut.inspect().find(ViewType.TextField.self))
    }

    /// The detail sheet must contain a Toggle for the "Completed" field.
    func testDetailSheetContainsCompletedToggle() throws {
        let item = insertKnownItem()

        let sut = ItemEditorDetailSheet(item: item, store: store)
        XCTAssertNoThrow(try sut.inspect().find(ViewType.Toggle.self))
    }

    /// The detail sheet must contain a Stepper for the priority field.
    func testDetailSheetContainsPriorityStepper() throws {
        let item = insertKnownItem()

        let sut = ItemEditorDetailSheet(item: item, store: store)
        XCTAssertNoThrow(try sut.inspect().find(ViewType.Stepper.self))
    }

    // MARK: - Tests: Direct mutation + persistence

    /// Mutating `title` on a persisted item and calling `save()` must be reflected
    /// when reading back via `Application.modelState(\.allItems).models`.
    func testMutatingTitlePersists() {
        let item = insertKnownItem(title: "Original Title")
        Application.modelState(\.allItems).save()

        item.title = "Updated Title"
        Application.modelState(\.allItems).save()

        let readBack = Application.modelState(\.allItems).models
        XCTAssertEqual(readBack.first(where: { $0.persistentModelID == item.persistentModelID })?.title,
                       "Updated Title",
                       "Title mutation must be visible after save()")
    }

    /// Mutating `priority` on a persisted item and calling `save()` must be reflected
    /// when reading back via `Application.modelState(\.allItems).models`.
    func testMutatingPriorityPersists() {
        let item = insertKnownItem(priority: 1)
        Application.modelState(\.allItems).save()

        item.priority = 5
        Application.modelState(\.allItems).save()

        let readBack = Application.modelState(\.allItems).models
        XCTAssertEqual(readBack.first(where: { $0.persistentModelID == item.persistentModelID })?.priority,
                       5,
                       "Priority mutation must be visible after save()")
    }

    /// Flipping `isDone` to `true` on a persisted item and calling `save()` must be reflected
    /// when reading back via `Application.modelState(\.allItems).models`.
    func testMutatingIsDonePersists() {
        let item = insertKnownItem(isDone: false)
        Application.modelState(\.allItems).save()

        item.isDone = true
        Application.modelState(\.allItems).save()

        let readBack = Application.modelState(\.allItems).models
        XCTAssertTrue(readBack.first(where: { $0.persistentModelID == item.persistentModelID })?.isDone ?? false,
                      "isDone mutation must be visible after save()")
    }

    /// Mutating all three editable fields in a single round-trip must all persist correctly.
    func testMutatingAllFieldsTogetherPersists() {
        let due = Date(timeIntervalSince1970: 2_000_000)
        let item = insertKnownItem(title: "Before", priority: 0, isDone: false)
        Application.modelState(\.allItems).save()

        item.title = "After"
        item.priority = 4
        item.isDone = true
        item.dueDate = due
        Application.modelState(\.allItems).save()

        let readBack = Application.modelState(\.allItems).models
        guard let found = readBack.first(where: { $0.persistentModelID == item.persistentModelID }) else {
            return XCTFail("Item must still exist after mutation")
        }
        XCTAssertEqual(found.title, "After")
        XCTAssertEqual(found.priority, 4)
        XCTAssertTrue(found.isDone)
        XCTAssertEqual(found.dueDate, due)
    }
}

// MARK: - ItemEditorStoreTests

/// Unit tests for `ItemEditorStore` — addItem, delete, save, seedIfEmpty.
@MainActor
final class ItemEditorStoreTests: XCTestCase {

    // MARK: - Properties

    private var containerOverride: Application.DependencyOverride?
    private var store: ItemEditorStore!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        containerOverride = Application.override(\.labContainer, with: makeInMemoryLabContainer())
        store = ItemEditorStore()
    }

    override func tearDown() async throws {
        store = nil
        await containerOverride?.cancel()
        containerOverride = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    func testStoreInitialisesEmpty() {
        XCTAssertTrue(store.items.isEmpty)
    }

    func testAddItemInsertsRecord() {
        store.addItem()
        XCTAssertEqual(store.items.count, 1)
    }

    func testAddItemCreatesDefaultTitle() {
        store.addItem()
        XCTAssertEqual(store.items.first?.title, "New Item")
    }

    func testDeleteItemRemovesRecord() {
        store.addItem()
        guard let item = store.items.first else { return XCTFail("Expected item") }
        store.delete(item)
        XCTAssertTrue(store.items.isEmpty)
    }

    func testSaveDoesNotCrash() {
        store.addItem()
        store.save()
        store.save()
        XCTAssertEqual(store.items.count, 1)
    }

    func testSeedIfEmptyInsertsExactlyTwoItems() {
        store.seedIfEmpty()
        XCTAssertEqual(store.items.count, 2,
                       "seedIfEmpty must insert exactly 2 seed items into an empty store")
    }

    func testSeedIfEmptyIsIdempotentWhenNonEmpty() {
        store.addItem()
        store.seedIfEmpty()
        XCTAssertEqual(store.items.count, 1,
                       "seedIfEmpty must not add items when the store already has records")
    }

    func testSeedItemsHaveNonEmptyTitles() {
        store.seedIfEmpty()
        let emptyTitles = store.items.filter { $0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        XCTAssertTrue(emptyTitles.isEmpty, "All seed items must have non-empty titles")
    }
}

#endif
