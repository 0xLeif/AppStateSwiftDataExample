import XCTest

// MARK: - AppStateSwiftDataDemoUITests

/// End-to-end UI tests that drive the SwiftData + AppState demo through the real SwiftUI UI on a
/// simulator: launch, open each SwiftData screen, interact, and assert the on-screen result.
final class AppStateSwiftDataDemoUITests: XCTestCase {

    private enum Row {
        static let swiftDataLab = "SwiftData Lab — relationships, queries, migration"
        static let bulkImport = "Bulk Import — 10k items off-main, responsive"
    }

    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    override func tearDown() {
        app = nil
    }

    private func openExample(_ label: String, file: StaticString = #filePath, line: UInt = #line) {
        let row = app.buttons[label]
        var swipes = 0
        while !row.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        XCTAssertTrue(row.exists, "Catalog row '\(label)' not found", file: file, line: line)
        while !row.isHittable && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        row.tap()
    }

    // MARK: - Catalog

    func testCatalogListsBothSwiftDataExamples() {
        XCTAssertTrue(app.staticTexts["AppState · SwiftData"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[Row.swiftDataLab].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons[Row.bulkImport].waitForExistence(timeout: 5))
    }

    // MARK: - SwiftData Lab (relationships, queries, migration)

    func testSwiftDataLabCreatesList() {
        openExample(Row.swiftDataLab)

        let field = app.textFields["New list…"]
        XCTAssertTrue(field.waitForExistence(timeout: 8), "SwiftData Lab list field not found")
        field.tap()
        let listName = "UITest list \(Int.random(in: 1000...9999))"
        field.typeText(listName)

        app.buttons["Add"].firstMatch.tap()

        XCTAssertTrue(
            app.staticTexts[listName].waitForExistence(timeout: 5),
            "Created list '\(listName)' did not appear"
        )
    }

    // MARK: - Bulk Import (background @ModelActor, non-blocking)

    func testBulkImportRunsOffMainAndCompletes() {
        openExample(Row.bulkImport)
        XCTAssertTrue(app.navigationBars["Bulk Import"].waitForExistence(timeout: 8))

        let generate = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Generate'")).firstMatch
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()

        // The Cancel control appears AND is hittable *while the import runs off-main* — proof the UI
        // is not blocked. A frozen main thread could neither present nor accept this control.
        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "Import did not start / UI was blocked")
        XCTAssertTrue(cancel.isHittable, "Cancel not hittable — the UI is blocked")
        cancel.tap()

        XCTAssertTrue(
            generate.waitForExistence(timeout: 20) && generate.isEnabled,
            "UI did not return to an interactive state"
        )
    }
}
