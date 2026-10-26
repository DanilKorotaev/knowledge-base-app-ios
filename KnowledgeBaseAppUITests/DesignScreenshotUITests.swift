import UIKit
import XCTest

/// Captures stub UI screenshots for Figma. Host sets Simulator appearance via
/// `xcrun simctl ui <udid> appearance light|dark` before each test.
final class DesignScreenshotUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            UITestRuntime.launchArgument,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        app.launch()
    }

    func testCaptureLightScenarios() throws {
        try captureSuite(prefix: "L", folder: "light")
    }

    func testCaptureDarkScenarios() throws {
        try captureSuite(prefix: "D", folder: "dark")
    }

    private func captureSuite(prefix: String, folder: String) throws {
        let dir = URL(fileURLWithPath: "/tmp/kb-app-screenshots/\(folder)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 12))

        func save(_ name: String) throws {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            try data.write(to: dir.appendingPathComponent("\(prefix)-\(name).png"))
        }

        try save("01-chats")

        XCTAssertTrue(tabBar.buttons["Overview"].waitForExistence(timeout: 5))
        tabBar.buttons["Overview"].tap()
        XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 5))
        try save("02-overview")

        openBoard(id: "demo-kpi")
        try save("03-sui-summary")
        openRangeCalendar()
        try save("04-calendar-range")
        dismissSheetIfNeeded()
        ensureOverview()

        openBoard(id: "demo-nav")
        try save("05-sui-nav")
        ensureOverview()

        openBoard(id: "demo-form")
        try save("06-sui-form")
        ensureOverview()

        tabBar.buttons["Actions"].tap()
        _ = app.navigationBars["Actions"].waitForExistence(timeout: 5)
        try save("07-actions")

        tabBar.buttons["Settings"].tap()
        _ = app.navigationBars["Settings"].waitForExistence(timeout: 5)
        try save("08-settings")

        let offline = app.staticTexts["Manage offline cache"]
        if offline.waitForExistence(timeout: 3) {
            offline.tap()
            _ = app.navigationBars.firstMatch.waitForExistence(timeout: 5)
            try save("09-offline-cache")
            popOnce()
        }

        if tabBar.buttons["Health"].waitForExistence(timeout: 2) {
            tabBar.buttons["Health"].tap()
            try save("10-health")
        }
    }

    private func openBoard(id: String) {
        ensureOverview()
        let row = app.descendants(matching: .any)["board.row.\(id)"]
        XCTAssertTrue(row.waitForExistence(timeout: 8), "Expected board row \(id)")
        row.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["board.detail.\(id)"].waitForExistence(timeout: 8),
            "Expected board detail \(id)"
        )
    }

    private func openRangeCalendar() {
        let period = app.buttons["Period"].firstMatch
        guard period.waitForExistence(timeout: 3) else { return }
        period.tap()
        let chooseDates = app.buttons["Choose dates"].firstMatch
        if chooseDates.waitForExistence(timeout: 3) {
            chooseDates.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
    }

    private func dismissSheetIfNeeded() {
        for label in ["Done", "Close", "Cancel"] {
            let btn = app.buttons[label].firstMatch
            if btn.waitForExistence(timeout: 1) {
                btn.tap()
                break
            }
        }
        if app.buttons["Choose dates"].exists {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)).tap()
        }
        popOnce()
    }

    private func ensureOverview() {
        let tabBar = app.tabBars.firstMatch
        if app.navigationBars["Overview"].exists { return }
        var guardCount = 0
        while !app.navigationBars["Overview"].exists && guardCount < 4 {
            popOnce()
            guardCount += 1
        }
        if !app.navigationBars["Overview"].exists, tabBar.buttons["Overview"].exists {
            tabBar.buttons["Overview"].tap()
        }
        _ = app.navigationBars["Overview"].waitForExistence(timeout: 5)
    }

    private func popOnce() {
        let back = app.navigationBars.buttons.element(boundBy: 0)
        if back.exists {
            back.tap()
            Thread.sleep(forTimeInterval: 0.3)
        }
    }
}
