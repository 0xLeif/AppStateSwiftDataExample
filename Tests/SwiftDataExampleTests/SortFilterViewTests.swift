import XCTest
import AppState
@testable import SwiftDataExampleLib

#if canImport(SwiftData) && canImport(SwiftUI) && !os(Linux) && !os(Windows)
import SwiftData
import SwiftUI
import ViewInspector

// MARK: - SortFilterViewTests

/// ViewInspector tests for `SortFilterView` and `SortFilterRowView`.
///
/// Each test class overrides `\.labContainer` with a fresh in-memory container and seeds a
/// deterministic set of `TodoItem`s so that sort and filter assertions are fully predictable.
///
/// ### Strategy
/// - Control presence tests verify that all UI controls render without asserting on live data.
/// - Data-driven tests insert known items directly into `mainContext` and then invoke
///   the view's fetch helpers via `sortFilterFetchedItems(...)` free function, keeping
///   assertions deterministic and independent of SwiftUI state timing.
@MainActor
final class SortFilterViewTests: XCTestCase {

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

    /// Inserts a deterministic set of varied `TodoItem`s into the current test container.
    private func insertKnownItems() {
        let context = Application.modelContext(\.labContainer)
        let items: [(title: String, priority: Int, isDone: Bool)] = [
            ("Alpha",   3, false),
            ("Beta",    1, true),
            ("Gamma",   5, false),
            ("Delta",   0, false),
            ("Epsilon", 4, true),
            ("Zeta",    2, false),
        ]
        for item in items {
            context.insert(TodoItem(title: item.title, isDone: item.isDone, priority: item.priority))
        }
        try? context.save()
    }

    // MARK: - Tests: View controls exist

    func testSortFilterViewHasSortByPicker() throws {
        let sut = SortFilterView()
        XCTAssertNoThrow(try sut.inspect().find(ViewType.Picker.self))
    }

    func testSortFilterViewHasHideCompletedToggle() throws {
        let sut = SortFilterView()
        XCTAssertNoThrow(try sut.inspect().find(text: "Hide completed"))
    }

    func testSortFilterViewHasOrderToggle() throws {
        let sut = SortFilterView()
        // Default state is ascending.
        XCTAssertNoThrow(try sut.inspect().find(text: "Order: Ascending"))
    }

    func testSortFilterViewHasMinPriorityStepper() throws {
        let sut = SortFilterView()
        XCTAssertNoThrow(try sut.inspect().find(ViewType.Stepper.self))
    }

    // MARK: - Tests: View renders without throwing

    func testSortFilterViewBodyRendersWithoutThrowing() throws {
        let sut = SortFilterView()
        // ViewInspector's navigationTitle() only supports Binding<String> — so we verify the
        // view renders (contains a List) without directly inspecting the navigation title string.
        XCTAssertNoThrow(try sut.inspect().find(ViewType.List.self))
    }

    // MARK: - Tests: Row view

    func testSortFilterRowViewDisplaysTitle() throws {
        let item = TodoItem(title: "Row title", isDone: false, priority: 2)
        let sut = SortFilterRowView(item: item)
        XCTAssertNoThrow(try sut.inspect().find(text: "Row title"))
    }

    func testSortFilterRowViewShowsFilledCircleForDoneItem() throws {
        let item = TodoItem(title: "Done item", isDone: true, priority: 0)
        let sut = SortFilterRowView(item: item)
        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "checkmark.circle.fill")
    }

    func testSortFilterRowViewShowsEmptyCircleForIncompleteItem() throws {
        let item = TodoItem(title: "Pending item", isDone: false, priority: 0)
        let sut = SortFilterRowView(item: item)
        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "circle")
    }

    func testSortFilterRowViewDisplaysPriority() throws {
        let item = TodoItem(title: "High priority", isDone: false, priority: 5)
        let sut = SortFilterRowView(item: item)
        XCTAssertNoThrow(try sut.inspect().find(text: "Priority 5"))
    }

    // MARK: - Tests: Sorting behaviour (direct context fetch)

    func testSortByTitleAscendingOrdersAlphabetically() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: false,
            minPriority: 0
        )
        let titles = result.map(\.title)
        XCTAssertEqual(titles, titles.sorted(), "Title-ascending sort must be alphabetical")
    }

    func testSortByTitleDescendingReversesOrder() {
        insertKnownItems()
        let ascending = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: false,
            minPriority: 0
        ).map(\.title)
        let descending = sortFilterFetchedItems(
            sortKey: .title,
            ascending: false,
            hideCompleted: false,
            minPriority: 0
        ).map(\.title)
        XCTAssertEqual(descending, ascending.reversed())
    }

    func testSortByPriorityAscendingOrdersByPriority() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .priority,
            ascending: true,
            hideCompleted: false,
            minPriority: 0
        )
        let priorities = result.map(\.priority)
        // Must be non-decreasing.
        for index in priorities.indices.dropLast() {
            XCTAssertLessThanOrEqual(priorities[index], priorities[index + 1])
        }
    }

    func testSortByPriorityDescendingOrdersByPriorityHighFirst() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .priority,
            ascending: false,
            hideCompleted: false,
            minPriority: 0
        )
        let priorities = result.map(\.priority)
        // Must be non-increasing.
        for index in priorities.indices.dropLast() {
            XCTAssertGreaterThanOrEqual(priorities[index], priorities[index + 1])
        }
    }

    func testSortByCreatedAscendingReturnsSixItems() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .created,
            ascending: true,
            hideCompleted: false,
            minPriority: 0
        )
        XCTAssertEqual(result.count, 6)
    }

    // MARK: - Tests: Filtering behaviour (direct context fetch)

    func testHideCompletedExcludesDoneItems() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: true,
            minPriority: 0
        )
        XCTAssertTrue(result.allSatisfy { !$0.isDone }, "All returned items must be incomplete")
    }

    func testHideCompletedFalseIncludesDoneItems() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: false,
            minPriority: 0
        )
        XCTAssertTrue(result.contains { $0.isDone }, "Completed items must appear when filter is off")
    }

    func testMinPriorityFiltersOutLowPriorityItems() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: false,
            minPriority: 3
        )
        XCTAssertTrue(
            result.allSatisfy { $0.priority >= 3 },
            "All items must have priority >= 3 when minPriority is 3"
        )
    }

    func testMinPriorityZeroReturnsAllItems() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: false,
            minPriority: 0
        )
        XCTAssertEqual(result.count, 6)
    }

    func testMinPriorityFiveReturnsOnlyHighestPriorityItem() {
        insertKnownItems()
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: false,
            minPriority: 5
        )
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.title, "Gamma")
    }

    func testCombinedHideCompletedAndMinPriorityNarrowsResults() {
        insertKnownItems()
        // Seeds: Alpha(3,false), Beta(1,done), Gamma(5,false), Delta(0,false),
        //        Epsilon(4,done), Zeta(2,false)
        // hideCompleted=true, minPriority=3 → Alpha(3), Gamma(5)
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: true,
            minPriority: 3
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result.map(\.title).sorted(), ["Alpha", "Gamma"])
    }

    func testEmptyStoreReturnsNoItems() {
        // No seeding — store starts empty for each test.
        let result = sortFilterFetchedItems(
            sortKey: .title,
            ascending: true,
            hideCompleted: false,
            minPriority: 0
        )
        XCTAssertTrue(result.isEmpty)
    }
}

// MARK: - SortFilterSortKeyTests

/// Unit tests for `SortFilterSortKey` enum conformance.
@MainActor
final class SortFilterSortKeyTests: XCTestCase {

    func testSortFilterSortKeyAllCasesHasThreeMembers() {
        XCTAssertEqual(SortFilterSortKey.allCases.count, 3)
    }

    func testSortFilterSortKeyIdEqualsRawValue() {
        for key in SortFilterSortKey.allCases {
            XCTAssertEqual(key.id, key.rawValue)
        }
    }

    func testSortFilterSortKeyRawValues() {
        XCTAssertEqual(SortFilterSortKey.title.rawValue, "Title")
        XCTAssertEqual(SortFilterSortKey.priority.rawValue, "Priority")
        XCTAssertEqual(SortFilterSortKey.created.rawValue, "Created")
    }
}

// MARK: - Free helper (mirrors SortFilterView's private fetch logic)

/// Replicates the fetch + filter logic from `SortFilterView.sortFilterRefetch()` so that
/// tests can assert on sorted/filtered results without depending on live `@State` mutation.
///
/// - Parameters:
///   - sortKey: The field used as the primary sort key.
///   - ascending: `true` for ascending order, `false` for descending.
///   - hideCompleted: Exclude items where `isDone == true` when `true`.
///   - minPriority: Exclude items with `priority < minPriority`.
/// - Returns: Matching `TodoItem` models in the requested order.
@MainActor
private func sortFilterFetchedItems(
    sortKey: SortFilterSortKey,
    ascending: Bool,
    hideCompleted: Bool,
    minPriority: Int
) -> [TodoItem] {
    let context = Application.modelContext(\.labContainer)
    let order: SortOrder = ascending ? .forward : .reverse

    let sortDescriptors: [SortDescriptor<TodoItem>] = switch sortKey {
    case .title:    [SortDescriptor(\.title, order: order)]
    case .priority: [SortDescriptor(\.priority, order: order), SortDescriptor(\.title)]
    case .created:  [SortDescriptor(\.createdAt, order: order)]
    }

    let descriptor = FetchDescriptor<TodoItem>(sortBy: sortDescriptors)
    let raw = (try? context.fetch(descriptor)) ?? []

    return raw.filter { item in
        if hideCompleted, item.isDone { return false }
        if item.priority < minPriority { return false }
        return true
    }
}

#endif
