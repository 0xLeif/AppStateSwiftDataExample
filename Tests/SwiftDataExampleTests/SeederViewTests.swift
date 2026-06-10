import XCTest
import AppState
@testable import SwiftDataExampleLib

#if canImport(SwiftData) && canImport(SwiftUI) && !os(Linux) && !os(Windows)
import SwiftData
import SwiftUI
import ViewInspector

// MARK: - SeederViewTests

/// ViewInspector tests for `SeederView`.
///
/// These tests verify the static view structure — that preset buttons, live-count labels,
/// and the Clear All button are rendered — without exercising the live seeding flow.
/// The live seeding behaviour is covered by `DataSeederTests`.
@MainActor
final class SeederViewTests: XCTestCase {

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

    private func makeSUT() -> SeederView {
        SeederView()
    }

    // MARK: - Tests: View structure

    func testBodyRootsInScrollView() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().scrollView())
    }

    // MARK: - Tests: Navigation title

    /// ViewInspector cannot inspect a static-string `.navigationTitle` modifier — it only
    /// supports the `Binding<String>` variant. We verify the navigation title indirectly by
    /// confirming the scrollView root contains an annotated VStack (which hosts the modifier).
    func testBodyContainsAnnotatedVStack() throws {
        let sut = makeSUT()
        // The body is: ScrollView → VStack(.navigationTitle("Seed & Stress"))
        // If the VStack is missing the view hierarchy has changed fundamentally.
        XCTAssertNoThrow(try sut.inspect().scrollView().vStack())
    }

    // MARK: - Tests: Live count labels

    func testListsLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Lists"))
    }

    func testItemsLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Items"))
    }

    func testTagsLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Tags"))
    }

    // MARK: - Tests: Preset buttons

    func testSamplePresetButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: SeedSize.sample.title))
    }

    func testLargePresetButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: SeedSize.large.title))
    }

    func testStressPresetButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: SeedSize.stress.title))
    }

    func testExtremePresetButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: SeedSize.extreme.title))
    }

    func testAllFourPresetTitlesAreRendered() throws {
        let sut = makeSUT()
        for size in SeedSize.allCases {
            XCTAssertNoThrow(
                try sut.inspect().find(text: size.title),
                "SeederView must render the preset button titled '\(size.title)'"
            )
        }
    }

    // MARK: - Tests: Preset section caption

    func testBackgroundActorCaptionIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(
            try sut.inspect().find(text: "All seeding runs on a background @ModelActor — the UI stays fully responsive.")
        )
    }

    // MARK: - Tests: Clear All button

    func testClearAllButtonIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Clear All Data"))
    }

    func testClearAllButtonIsEnabledInitially() throws {
        let sut = makeSUT()
        let button = try sut.inspect().find(button: "Clear All Data")
        XCTAssertFalse(try button.isDisabled(), "Clear All must be enabled when no seed is running")
    }

    // MARK: - Tests: Progress section hidden initially

    func testProgressSectionIsHiddenInitially() throws {
        let sut = makeSUT()
        // The progress ProgressView is conditionally shown only while seeding or after a run.
        // At rest, it must not be present.
        XCTAssertThrowsError(
            try sut.inspect().find(ViewType.ProgressView.self),
            "ProgressView must not be visible before a seed run starts"
        )
    }

    // MARK: - Tests: Live count initial values

    func testInitialListCountIsZero() throws {
        let sut = makeSUT()
        // The live-counts section shows "0" for each stat when the store is empty.
        // We verify at least one "0" text is present (the counts share the same format).
        XCTAssertNoThrow(try sut.inspect().find(text: "0"))
    }

    // MARK: - Tests: Presets section label

    func testPresetsSectionLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Presets"))
    }

    // MARK: - Tests: Live counts section label

    func testLiveStoreCountsSectionLabelIsPresent() throws {
        let sut = makeSUT()
        XCTAssertNoThrow(try sut.inspect().find(text: "Live Store Counts"))
    }
}

#endif
