import XCTest

// MARK: - AppStateSwiftDataDemoPerformanceTests

/// Instrumented performance tests for the SwiftData + AppState demo.
///
/// Uses XCTest's metric harness for high-precision wall-clock timing (`XCTClockMetric`), app launch
/// duration (`XCTApplicationLaunchMetric`), and memory footprint (`XCTMemoryMetric`). Each `measure`
/// block runs multiple iterations and reports the average + standard deviation; the raw numbers are
/// emitted to the test log (grep `measured`).
final class AppStateSwiftDataDemoPerformanceTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    // MARK: - Helpers

    private func openRow(_ app: XCUIApplication, _ titlePrefix: String) {
        let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", titlePrefix)).firstMatch
        var swipes = 0
        while !row.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        while row.exists && !row.isHittable && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
        row.tap()
    }

    private func goToCatalog(_ app: XCUIApplication) {
        let back = app.navigationBars.buttons.firstMatch
        if back.exists { back.tap() }
        _ = app.staticTexts["AppState · SwiftData"].waitForExistence(timeout: 5)
    }

    /// Scrolls a row into view (untimed) so subsequent taps measure pure tap→render, not scrolling.
    private func ensureVisible(_ app: XCUIApplication, _ row: XCUIElement) {
        var swipes = 0
        while !row.exists && swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
        while row.exists && !row.isHittable && swipes < 12 {
            app.swipeUp()
            swipes += 1
        }
    }

    /// Measures the pure wall-clock time from tapping an *already-visible* row to its screen
    /// rendering (ms). Scrolling is done untimed, so this isolates the navigation + render cost.
    private func measureOpen(_ titlePrefix: String, navBar: String) {
        let app = XCUIApplication()
        app.launch()
        // Let the launch auto-seed settle so timings reflect a populated store.
        _ = app.staticTexts["AppState · SwiftData"].waitForExistence(timeout: 10)

        let row = app.buttons.containing(NSPredicate(format: "label BEGINSWITH %@", titlePrefix)).firstMatch
        ensureVisible(app, row)

        // Auto-start at block entry; manually stop the clock the instant the screen renders. The tap
        // target is already on-screen, and the back-navigation + re-scroll happen after stopMeasuring.
        let options = XCTMeasureOptions()
        options.invocationOptions = [.manuallyStop]
        measure(metrics: [XCTClockMetric()], options: options) {
            row.tap()
            XCTAssertTrue(app.navigationBars[navBar].waitForExistence(timeout: 15), "\(navBar) did not render")
            stopMeasuring()
            goToCatalog(app)
            ensureVisible(app, row)
        }
    }

    // MARK: - Launch

    func testLaunchPerformance() {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // MARK: - Screen load times (wall-clock, ms)

    func testOpenStatsScreenTime() {
        measureOpen("Stats", navBar: "Stats")
    }

    func testOpenSearchScreenTime() {
        measureOpen("Search", navBar: "Search")
    }

    func testOpenSortFilterScreenTime() {
        measureOpen("Sort & Filter", navBar: "Sort & Filter")
    }

    func testOpenLiveQueryScreenTime() {
        measureOpen("Live @Query", navBar: "Live @Query")
    }

    func testOpenLabScreenTime() {
        measureOpen("SwiftData Lab", navBar: "SwiftData Lab")
    }

    // MARK: - Memory footprint navigating the data-heavy screens

    func testMemoryFootprintNavigatingHeavyScreens() {
        let app = XCUIApplication()
        app.launch()
        _ = app.staticTexts["AppState · SwiftData"].waitForExistence(timeout: 10)

        measure(metrics: [XCTMemoryMetric(application: app)]) {
            for (title, navBar) in [("Stats", "Stats"), ("Search", "Search"), ("Sort & Filter", "Sort & Filter")] {
                openRow(app, title)
                _ = app.navigationBars[navBar].waitForExistence(timeout: 15)
                goToCatalog(app)
            }
        }
    }

    // MARK: - Stress: time to seed 10,000 items off-main, while staying responsive

    func testSeedStressDurationAndResponsiveness() {
        let app = XCUIApplication()
        app.launch()
        _ = app.staticTexts["AppState · SwiftData"].waitForExistence(timeout: 10)
        openRow(app, "Seed & Stress")
        XCTAssertTrue(app.navigationBars["Seed & Stress"].waitForExistence(timeout: 10))

        let stress = app.buttons.containing(NSPredicate(format: "label BEGINSWITH 'Stress'")).firstMatch
        XCTAssertTrue(stress.waitForExistence(timeout: 5))

        let cancel = app.buttons["Cancel"]
        let start = Date()
        stress.tap()

        // Non-blocking proof: while 10,000 items seed off-main, Cancel is present and hittable.
        if cancel.waitForExistence(timeout: 5) {
            XCTAssertTrue(cancel.isHittable, "Cancel not hittable — the UI is blocked")
        }
        XCTAssertTrue(cancel.waitForNonExistence(timeout: 180), "Seed did not finish in time")
        let elapsed = Date().timeIntervalSince(start)
        // Emitted to the test log for the perf report (grep PERF:).
        print(String(format: "PERF: seed 10000 items end-to-end = %.3f s (%.3f ms/item)", elapsed, elapsed * 1000 / 10000))
        XCTAssertTrue(stress.isEnabled, "Controls did not re-enable after seeding")
    }
}
