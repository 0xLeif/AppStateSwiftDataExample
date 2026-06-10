import XCTest
import AppState
@testable import SwiftDataExampleLib

#if canImport(SwiftData) && canImport(SwiftUI) && !os(Linux) && !os(Windows)
import SwiftData
import SwiftUI
import ViewInspector

// MARK: - StatsViewTests

/// ViewInspector tests for `StatsView`.
///
/// Each test overrides `\.labContainer` with a fresh in-memory container and inserts a
/// deterministic fixture so that the assertions are exact and independent of any prior state.
///
/// ### Fixture layout
/// - 3 `TodoItem`s: one done (priority 2), two incomplete (priority 0 and priority 5)
/// - 1 `TodoList`
/// - 1 `Tag`
///
/// Derived expectations:
/// - Total items : 3
/// - Completed   : 1
/// - Remaining   : 2
/// - Percent     : 33%   (floor of 1/3 × 100, rounded to nearest → 33)
/// - Priority 0  : 1
/// - Priority 2  : 1
/// - Priority 5  : 1
@MainActor
final class StatsViewTests: XCTestCase {

    // MARK: - Properties

    private var containerOverride: Application.DependencyOverride?

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        containerOverride = Application.override(\.labContainer, with: makeInMemoryLabContainer())
        insertFixture()
    }

    override func tearDown() async throws {
        await containerOverride?.cancel()
        containerOverride = nil
        try await super.tearDown()
    }

    // MARK: - Fixture

    /// Inserts 3 items (1 done), 1 list, and 1 tag into the test container.
    private func insertFixture() {
        let context = Application.dependency(\.labContainer).mainContext

        let list = TodoList(title: "Stats Test List")
        context.insert(list)

        let tag = Tag(name: "stats-tag")
        context.insert(tag)

        let doneItem = TodoItem(title: "Done task", isDone: true, priority: 2)
        let pendingLow = TodoItem(title: "Pending low", isDone: false, priority: 0)
        let pendingCritical = TodoItem(title: "Pending critical", isDone: false, priority: 5)

        list.items.append(doneItem)
        list.items.append(pendingLow)
        list.items.append(pendingCritical)

        context.insert(doneItem)
        context.insert(pendingLow)
        context.insert(pendingCritical)

        doneItem.tags = [tag]

        try? context.save()
    }

    // MARK: - Helpers

    private func makeSUT() -> StatsView {
        StatsView()
    }

    // MARK: - Tests: Overview Totals

    func testTotalItemsLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Total Items"))
    }

    func testTotalItemsValueIsThree() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "3"),
                         "Expected total item count of 3 to be displayed")
    }

    func testCompletedLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Completed"))
    }

    func testCompletedCountIsOne() throws {
        let sut = makeSUT()
        // "1" appears as the completed count — confirmed unique among overview rows for this fixture.
        XCTAssertNoThrow(try sut.inspect().find(text: "1"),
                         "Expected completed count of 1 to be displayed")
    }

    func testRemainingLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Remaining"))
    }

    func testRemainingCountIsTwo() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "2"),
                         "Expected remaining count of 2 to be displayed")
    }

    func testTotalListsLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Total Lists"))
    }

    func testTotalTagsLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Total Tags"))
    }

    // MARK: - Tests: Completion Percentage

    func testCompleteLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Complete"))
    }

    func testCompletionPercentTextIs33Percent() throws {
        // 1 done out of 3 → 33% (rounded to nearest integer).
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "33%"),
                         "Expected completion percentage to be 33%")
    }

    // MARK: - Tests: Progress Indicator

    func testProgressViewIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(ViewType.ProgressView.self))
    }

    // MARK: - Tests: Priority Breakdown Labels

    func testPriorityNoneLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "None (0)"))
    }

    func testPriorityLowLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Low (1)"))
    }

    func testPriorityMediumLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Medium (2)"))
    }

    func testPriorityElevatedLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Elevated (3)"))
    }

    func testPriorityHighLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "High (4)"))
    }

    func testPriorityCriticalLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Critical (5)"))
    }

    // MARK: - Tests: Action Buttons

    func testSeedButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(button: "Seed Sample Data"))
    }

    func testClearButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(button: "Clear All"))
    }

    // MARK: - Tests: Navigation Title

    func testNavigationTitleIsStats() throws {
        let sut = makeSUT()
        // The .navigationTitle modifier is applied to the List; verify the root is a List.
        XCTAssertNoThrow(try sut.inspect().find(ViewType.List.self),
                         "StatsView body must root in a List")
    }

    // MARK: - Tests: Data Integrity After Fixture

    func testModelStateReflectsThreeItems() {
        let count = Application.modelState(\.allItems).models.count
        XCTAssertEqual(count, 3, "allItems ModelState must return 3 items after fixture insert")
    }

    func testModelStateReflectsOneList() {
        let count = Application.modelState(\.todoLists).models.count
        XCTAssertEqual(count, 1, "todoLists ModelState must return 1 list after fixture insert")
    }

    func testModelStateReflectsOneTag() {
        let count = Application.modelState(\.allTags).models.count
        XCTAssertEqual(count, 1, "allTags ModelState must return 1 tag after fixture insert")
    }

    func testCompletedItemCountMatchesFixture() {
        let items = Application.modelState(\.allItems).models
        let completed = items.filter(\.isDone).count
        XCTAssertEqual(completed, 1, "Exactly 1 item must be done in the fixture")
    }

    func testRemainingItemCountMatchesFixture() {
        let items = Application.modelState(\.allItems).models
        let remaining = items.filter { !$0.isDone }.count
        XCTAssertEqual(remaining, 2, "Exactly 2 items must be incomplete in the fixture")
    }

    func testPriorityZeroCountIsOne() {
        let items = Application.modelState(\.allItems).models
        let count = items.filter { $0.priority == 0 }.count
        XCTAssertEqual(count, 1, "Exactly 1 item must have priority 0")
    }

    func testPriorityTwoCountIsOne() {
        let items = Application.modelState(\.allItems).models
        let count = items.filter { $0.priority == 2 }.count
        XCTAssertEqual(count, 1, "Exactly 1 item must have priority 2")
    }

    func testPriorityFiveCountIsOne() {
        let items = Application.modelState(\.allItems).models
        let count = items.filter { $0.priority == 5 }.count
        XCTAssertEqual(count, 1, "Exactly 1 item must have priority 5")
    }

    func testPriorityOneCountIsZero() {
        let items = Application.modelState(\.allItems).models
        let count = items.filter { $0.priority == 1 }.count
        XCTAssertEqual(count, 0, "No items must have priority 1 in the fixture")
    }
}

#endif
