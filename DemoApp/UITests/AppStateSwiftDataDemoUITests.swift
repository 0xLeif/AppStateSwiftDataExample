import XCTest

// MARK: - AppStateSwiftDataDemoUITests

/// End-to-end UI tests that drive the SwiftData + AppState demo through the real SwiftUI UI on a
/// simulator: launch, open each example, interact, and assert the on-screen result.
final class AppStateSwiftDataDemoUITests: XCTestCase {

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
    }

    // MARK: - Helpers

    /// Scrolls a catalog row (matched by its title prefix) into view and taps it.
    private func openExample(_ titlePrefix: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", titlePrefix)).firstMatch
        var swipes = 0
        while !row.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(row.exists, "Catalog row '\(titlePrefix)' not found", file: file, line: line)
        while !row.isHittable && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        row.tap()
    }

    private func goBack() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists { back.tap() }
    }

    // MARK: - Catalog

    func testCatalogListsExamples() {
        XCTAssertTrue(app.staticTexts["AppState · SwiftData"].waitForExistence(timeout: 5))
        for title in ["SwiftData Lab", "Bulk Import", "Live @Query", "Search", "Stats", "Edit"] {
            let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", title)).firstMatch
            if !row.exists { app.swipeUp() }
            XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing catalog row: \(title)")
        }
    }

    /// Every example screen is reachable and shows its nav bar, then returns cleanly.
    func testEveryScreenIsReachable() {
        let screens = ["Bulk Import", "Live @Query", "Search", "Sort & Filter", "Stats", "Edit", "Undo / Redo"]
        for title in screens {
            openExample(title)
            XCTAssertTrue(
                app.navigationBars[title].waitForExistence(timeout: 8),
                "Screen '\(title)' did not show its nav bar"
            )
            goBack()
            XCTAssertTrue(app.staticTexts["AppState · SwiftData"].waitForExistence(timeout: 5))
        }
    }

    // MARK: - SwiftData Lab: create a list AND navigate into its detail (regression for nested-nav bug)

    func testSwiftDataLabCreateAndNavigateToDetail() {
        openExample("SwiftData Lab")

        let field = app.textFields["New list…"]
        XCTAssertTrue(field.waitForExistence(timeout: 8))
        field.tap()
        let listName = "UITest \(Int.random(in: 1000...9999))"
        field.typeText(listName)
        app.buttons["Add"].firstMatch.tap()

        let listRow = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", listName)).firstMatch
        XCTAssertTrue(listRow.waitForExistence(timeout: 5), "Created list '\(listName)' did not appear")

        // Tapping the list must push the detail — this is the bug that was broken by the nested
        // NavigationSplitView and is now fixed by pushing onto the catalog's NavigationStack.
        listRow.tap()
        XCTAssertTrue(
            app.textFields["Title…"].waitForExistence(timeout: 5),
            "List detail did not open — navigation into the item list is broken"
        )
    }

    // MARK: - Bulk Import: non-blocking, streaming progress

    func testBulkImportRunsOffMainAndCompletes() {
        openExample("Bulk Import")
        XCTAssertTrue(app.navigationBars["Bulk Import"].waitForExistence(timeout: 8))

        let generate = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Generate'")).firstMatch
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()

        // Cancel is hittable while the import runs off-main — proof the UI is not blocked.
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Import did not start / UI was blocked")
        XCTAssertTrue(cancel.isHittable, "Cancel not hittable — the UI is blocked")
        cancel.tap()

        XCTAssertTrue(
            generate.waitForExistence(timeout: 20) && generate.isEnabled,
            "UI did not return to an interactive state"
        )
    }

    // MARK: - Seed & Stress: large background seed, non-blocking

    func testSeedLargeIsNonBlockingAndCompletes() {
        openExample("Seed & Stress")
        XCTAssertTrue(app.navigationBars["Seed & Stress"].waitForExistence(timeout: 8))

        let large = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Large'")).firstMatch
        XCTAssertTrue(large.waitForExistence(timeout: 5))
        large.tap()

        // While the 1,000 items seed on the background @ModelActor, Cancel is present and hittable —
        // the main thread is not blocked. The seed is fast, so if we catch it mid-flight we assert
        // responsiveness; either way the controls return to an interactive state on completion.
        // (The 10k seed in the performance suite asserts the non-blocking window robustly.)
        let cancel = app.buttons["Cancel"]
        if cancel.waitForExistence(timeout: 3) {
            XCTAssertTrue(cancel.isHittable, "Cancel not hittable — the UI is blocked")
            _ = cancel.waitForNonExistence(timeout: 60)
        }

        XCTAssertTrue(
            large.waitForExistence(timeout: 30) && large.isEnabled,
            "Controls did not re-enable after seeding"
        )
    }
}
