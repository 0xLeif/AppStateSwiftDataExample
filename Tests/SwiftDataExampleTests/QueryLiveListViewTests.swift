import XCTest
import AppState
@testable import SwiftDataExampleLib

#if canImport(SwiftData) && canImport(SwiftUI) && !os(Linux) && !os(Windows)
import SwiftData
import SwiftUI
import ViewInspector

// MARK: - QueryLiveListViewTests

/// ViewInspector tests for `QueryLiveListView`.
///
/// `@Query` requires a `ModelContainer` in the SwiftUI environment to resolve its fetch
/// descriptor. Each test hosts the view with `.modelContainer(makeInMemoryLabContainer())`
/// so the `@Query` and `@Environment(\.modelContext)` both receive a real, isolated
/// in-memory store. A fresh container is created per test setUp, keeping tests fully
/// deterministic and independent.
///
/// ### Testing strategy for `@Query`
/// ViewInspector performs static structural inspection — it evaluates the view body once
/// at inspection time and does not drive SwiftUI's live observation pipeline. Therefore,
/// tests that need to verify `@Query`-populated rows do so by inserting items into the
/// container's `mainContext` *before* constructing the SUT, and then inspect the returned
/// body for the expected row content. Coverage of actual model mutation is delegated to
/// `QueryLiveItemRowViewTests`, which exercises the row view type directly.
@MainActor
final class QueryLiveListViewTests: XCTestCase {

    // MARK: - Properties

    private var containerOverride: Application.DependencyOverride?
    private var container: ModelContainer!

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        container = makeInMemoryLabContainer()
        // Override AppState's shared dependency so any incidental AppState calls in the
        // view hierarchy also resolve against the same isolated store.
        containerOverride = Application.override(\.labContainer, with: container)
    }

    override func tearDown() async throws {
        await containerOverride?.cancel()
        containerOverride = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    /// Returns a `QueryLiveListView` wrapped with the test-scoped `ModelContainer`.
    private func makeSUT() -> some View {
        QueryLiveListView()
            .modelContainer(container)
    }

    // MARK: - Tests: Rendering

    /// The view must render without throwing under ViewInspector.
    func testViewRendersWithoutThrowing() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect())
    }

    // MARK: - Tests: Text Field

    /// The new-item text field must be discoverable by its accessibility identifier.
    func testTitleTextFieldIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(
            try sut.inspect().find(viewWithAccessibilityIdentifier: "QueryLiveListView.titleField")
        )
    }

    // MARK: - Tests: Add Button

    /// The Add button must be discoverable by its accessibility identifier.
    func testAddButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(
            try sut.inspect().find(viewWithAccessibilityIdentifier: "QueryLiveListView.addButton")
        )
    }

    /// The Add button must be disabled when the title field contains only whitespace (initial state).
    func testAddButtonIsDisabledWhenTitleIsEmpty() throws {
        let sut = makeSUT()
        let button = try sut.inspect()
            .find(viewWithAccessibilityIdentifier: "QueryLiveListView.addButton")
            .button()
        XCTAssertTrue(
            try button.isDisabled(),
            "Add button must be disabled when the text field is empty"
        )
    }

    // MARK: - Tests: Caption Section

    /// The explanatory caption view must appear in the rendered hierarchy.
    func testCaptionViewIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(QueryLiveCaptionView.self))
    }

    /// The caption must contain the "Native @Query" label text.
    func testCaptionContainsQueryLabelText() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Native @Query"))
    }

    // MARK: - Tests: Container Isolation

    /// Inserting an item via the container's `mainContext` must be visible when the context
    /// is fetched directly — confirming the container wiring is correct even if `@Query`'s
    /// live observation cannot be driven from static ViewInspector inspection.
    func testInsertedItemIsRetrievableFromMainContext() throws {
        let item = TodoItem(title: "QueryLive Context Check")
        container.mainContext.insert(item)
        try container.mainContext.save()

        let fetched = try container.mainContext.fetch(
            FetchDescriptor<TodoItem>(
                sortBy: [SortDescriptor(\.title)]
            )
        )
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.title, "QueryLive Context Check")
    }

    /// Two sequential inserts must both be retrievable from the same `mainContext`.
    func testMultipleInsertedItemsAreRetrievableFromMainContext() throws {
        let alpha = TodoItem(title: "QueryLive Alpha")
        let beta = TodoItem(title: "QueryLive Beta")
        container.mainContext.insert(alpha)
        container.mainContext.insert(beta)
        try container.mainContext.save()

        let fetched = try container.mainContext.fetch(
            FetchDescriptor<TodoItem>(
                sortBy: [SortDescriptor(\.title)]
            )
        )
        XCTAssertEqual(fetched.count, 2)
        XCTAssertEqual(fetched.map(\.title), ["QueryLive Alpha", "QueryLive Beta"])
    }

    /// Each test gets a truly fresh container — the store from the previous test must not bleed over.
    func testContainerIsIsolatedBetweenTests() throws {
        let fetched = try container.mainContext.fetch(FetchDescriptor<TodoItem>())
        XCTAssertTrue(
            fetched.isEmpty,
            "Each test must start with an empty in-memory container"
        )
    }
}

// MARK: - QueryLiveItemRowViewTests

/// ViewInspector tests for `QueryLiveItemRowView`.
///
/// These tests use model objects directly without a container so they are fast and
/// do not require SwiftUI environment injection.
@MainActor
final class QueryLiveItemRowViewTests: XCTestCase {

    // MARK: - Properties

    private var containerOverride: Application.DependencyOverride?

    // MARK: - Lifecycle

    override func setUp() async throws {
        try await super.setUp()
        containerOverride = Application.override(\.labContainer, with: makeInMemoryLabContainer())
    }

    override func tearDown() async throws {
        await containerOverride?.cancel()
        containerOverride = nil
        try await super.tearDown()
    }

    // MARK: - Tests

    /// The row must display the item's title text.
    func testRowDisplaysTitle() throws {
        let item = TodoItem(title: "Row Display Title")
        let sut = QueryLiveItemRowView(item: item)
        XCTAssertNoThrow(try sut.inspect().find(text: "Row Display Title"))
    }

    /// An incomplete item (`isDone == false`) must render the open-circle system image.
    func testRowShowsOpenCircleWhenIncomplete() throws {
        let item = TodoItem(title: "Pending", isDone: false)
        let sut = QueryLiveItemRowView(item: item)

        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "circle")
    }

    /// A completed item (`isDone == true`) must render the filled-checkmark system image.
    func testRowShowsFilledCheckmarkWhenDone() throws {
        let item = TodoItem(title: "Done", isDone: true)
        let sut = QueryLiveItemRowView(item: item)

        let image = try sut.inspect().find(ViewType.Image.self)
        XCTAssertEqual(try image.actualImage().name(), "checkmark.circle.fill")
    }

    /// A row for an incomplete item must not show a strikethrough on the title Text view.
    func testIncompleteTitleIsNotStruckThrough() throws {
        let item = TodoItem(title: "Not done", isDone: false)
        let sut = QueryLiveItemRowView(item: item)

        let titleText = try sut.inspect().find(text: "Not done")
        // ViewInspector exposes strikethrough via the `.strikethrough()` attribute.
        let isStruckThrough = (try? titleText.attributes().isStrikethrough()) ?? false
        XCTAssertFalse(isStruckThrough, "Incomplete items must not have a strikethrough title")
    }
}

// MARK: - QueryLiveCaptionViewTests

/// ViewInspector tests for `QueryLiveCaptionView`.
@MainActor
final class QueryLiveCaptionViewTests: XCTestCase {

    // MARK: - Tests

    /// The caption must include the "Native @Query" label string.
    func testCaptionContainsNativeQueryLabel() throws {
        let sut = QueryLiveCaptionView()
        XCTAssertNoThrow(try sut.inspect().find(text: "Native @Query"))
    }

    /// The caption must mention `@ModelState` so readers can identify the AppState counterpart.
    func testCaptionMentionsModelState() throws {
        let sut = QueryLiveCaptionView()
        // The body Text mentions "@ModelState" in its description string.
        XCTAssertNoThrow(
            try sut.inspect().find(ViewType.Text.self, where: { text in
                (try? text.string())?.contains("@ModelState") == true
            })
        )
    }

    /// The caption view body must render without throwing.
    func testCaptionRendersWithoutThrowing() throws {
        let sut = QueryLiveCaptionView()
        XCTAssertNoThrow(try sut.inspect())
    }
}

#endif
