import XCTest
import AppState
@testable import SwiftDataExampleLib

#if canImport(SwiftData) && canImport(SwiftUI) && !os(Linux) && !os(Windows)
import SwiftData
import SwiftUI
import ViewInspector

// MARK: - ItemSearchViewTests

/// ViewInspector tests for `ItemSearchView`.
///
/// Each test installs a fresh in-memory `labContainer` override and inserts a known set
/// of `TodoItem`s directly into `mainContext`. The deterministic seed guarantees that
/// search assertions are not flaky across runs.
@MainActor
final class ItemSearchViewTests: XCTestCase {

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

    /// Returns the `mainContext` of the currently-overridden lab container.
    private var context: ModelContext {
        Application.dependency(\.labContainer).mainContext
    }

    /// Inserts a fixed set of `TodoItem`s with distinct, predictable titles and priorities.
    ///
    /// - Returns: The inserted items so callers can reference them directly.
    @discardableResult
    private func insertKnownItems() -> [TodoItem] {
        let items: [TodoItem] = [
            TodoItem(title: "Buy groceries",         priority: 1),
            TodoItem(title: "Write unit tests",       priority: 3),
            TodoItem(title: "Review pull request",    priority: 2),
            TodoItem(title: "Fix the login bug",      priority: 5),
            TodoItem(title: "Plan retrospective",     priority: 0),
        ]
        for item in items {
            context.insert(item)
        }
        try? context.save()
        return items
    }

    /// Performs a `#Predicate`-based fetch against `context` for the given query,
    /// matching `ItemSearchView`'s own fetch logic exactly.
    private func fetchItems(query: String) -> [TodoItem] {
        let descriptor: FetchDescriptor<TodoItem>

        if query.isEmpty {
            descriptor = FetchDescriptor<TodoItem>(
                sortBy: [SortDescriptor(\.title)]
            )
        } else {
            let predicate = #Predicate<TodoItem> { item in
                item.title.localizedStandardContains(query)
            }
            descriptor = FetchDescriptor<TodoItem>(
                predicate: predicate,
                sortBy: [SortDescriptor(\.title)]
            )
        }

        return (try? context.fetch(descriptor)) ?? []
    }

    // MARK: - Tests: View Structure

    /// `ItemSearchView` must be constructible with its public `init()`.
    func testItemSearchViewInitialises() {
        XCTAssertNoThrow(ItemSearchView())
    }

    /// The root body of `ItemSearchView` renders without throwing (ViewInspector entry point).
    func testItemSearchViewBodyDoesNotThrow() throws {
        let sut = ItemSearchView()
        XCTAssertNoThrow(try sut.inspect())
    }

    /// `ItemSearchView` renders a body without throwing — a necessary proxy for structural
    /// integrity including the `.navigationTitle("Search")` modifier that ViewInspector cannot
    /// reflect for static-string titles (it only supports `Binding<String>` titles).
    func testItemSearchViewBodyIsInspectable() throws {
        let sut = ItemSearchView()
        // inspect() succeeds only if the view tree is well-formed.
        XCTAssertNoThrow(try sut.inspect())
    }

    // MARK: - Tests: Row Structure

    /// `ItemSearchResultRow` renders the item title text.
    func testItemSearchResultRowDisplaysTitle() throws {
        let item = TodoItem(title: "Visible title", priority: 0)
        context.insert(item)
        try? context.save()

        let sut = ItemSearchResultRow(item: item)
        XCTAssertNoThrow(try sut.inspect().find(text: "Visible title"))
    }

    /// `ItemSearchResultRow` shows a filled circle for a completed item.
    func testItemSearchResultRowShowsFilledCircleWhenDone() throws {
        let item = TodoItem(title: "Done item", isDone: true)
        context.insert(item)
        try? context.save()

        let sut = ItemSearchResultRow(item: item)
        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "checkmark.circle.fill")
    }

    /// `ItemSearchResultRow` shows an empty circle for an incomplete item.
    func testItemSearchResultRowShowsEmptyCircleWhenIncomplete() throws {
        let item = TodoItem(title: "Pending", isDone: false)
        context.insert(item)
        try? context.save()

        let sut = ItemSearchResultRow(item: item)
        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "circle")
    }

    /// `ItemSearchResultRow` renders a priority badge when `item.priority > 0`.
    func testItemSearchResultRowShowsPriorityBadgeWhenPriorityIsPositive() throws {
        let item = TodoItem(title: "Urgent", priority: 4)
        context.insert(item)
        try? context.save()

        let sut = ItemSearchResultRow(item: item)
        XCTAssertNoThrow(try sut.inspect().find(text: "P4"))
    }

    /// `ItemSearchResultRow` omits the priority badge when `item.priority == 0`.
    func testItemSearchResultRowOmitsPriorityBadgeWhenPriorityIsZero() throws {
        let item = TodoItem(title: "Normal", priority: 0)
        context.insert(item)
        try? context.save()

        let sut = ItemSearchResultRow(item: item)
        XCTAssertThrowsError(try sut.inspect().find(text: "P0"))
    }

    // MARK: - Tests: Search Logic (predicate)

    /// An empty query must return all inserted items.
    func testEmptyQueryReturnsAllItems() {
        insertKnownItems()

        let results = fetchItems(query: "")
        XCTAssertEqual(results.count, 5, "Empty query must return every item")
    }

    /// A query matching a unique substring narrows results to exactly one item.
    func testQueryFiltersByTitleSubstring() {
        insertKnownItems()

        let results = fetchItems(query: "login")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Fix the login bug")
    }

    /// The predicate is case-insensitive ("BUY" must match "Buy groceries").
    func testQueryIsCaseInsensitive() {
        insertKnownItems()

        let results = fetchItems(query: "BUY")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.title, "Buy groceries")
    }

    /// Results must be sorted alphabetically by title so display order is deterministic.
    func testResultsAreSortedAlphabeticallyByTitle() {
        insertKnownItems()

        let results = fetchItems(query: "")
        let titles = results.map(\.title)
        XCTAssertEqual(titles, titles.sorted(), "Fetch must return items sorted by title ascending")
    }

    /// A query that matches no items must return an empty array.
    func testQueryWithNoMatchReturnsEmpty() {
        insertKnownItems()

        let results = fetchItems(query: "xyzzy_no_match")
        XCTAssertTrue(results.isEmpty, "Non-matching query must return no results")
    }

    /// A query matching multiple items returns all of them.
    func testQueryMatchingMultipleItemsReturnsAll() {
        insertKnownItems()

        // "review" matches "Review pull request"; "unit" matches "Write unit tests";
        // "r" matches "Buy groceries", "Review pull request", "Write unit tests", "Plan retrospective"
        let results = fetchItems(query: "r")
        XCTAssertGreaterThan(results.count, 1,
                             "Query 'r' must match more than one item in the seed set")
    }

    // MARK: - Tests: Seeding

    /// After inserting items manually, the context must not be empty.
    func testContextHoldsItemsAfterInsert() {
        insertKnownItems()

        let descriptor = FetchDescriptor<TodoItem>()
        let count = (try? context.fetchCount(descriptor)) ?? 0
        XCTAssertEqual(count, 5)
    }

    /// Two in-memory containers are fully independent — overrides do not bleed across tests.
    func testContainersAreIsolatedBetweenTests() {
        let count = (try? context.fetchCount(FetchDescriptor<TodoItem>())) ?? 0
        XCTAssertEqual(count, 0, "Each test must start with a fresh, empty container")
    }
}

#endif
