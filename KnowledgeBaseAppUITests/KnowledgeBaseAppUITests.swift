import UIKit
import XCTest

/// Smoke UI coverage against in-app stub clients (`-UITesting`). No network / staging.
final class KnowledgeBaseAppUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = [
            UITestRuntime.launchArgument,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()
    }

    func testRootTabsExist() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10), "Tab bar should appear")

        XCTAssertTrue(tabBar.buttons["Chats"].exists)
        XCTAssertTrue(tabBar.buttons["Actions"].exists)
        XCTAssertTrue(tabBar.buttons["Settings"].exists)

        if tabBar.buttons["Overview"].exists {
            tabBar.buttons["Overview"].tap()
            XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 5))
        }

        tabBar.buttons["Actions"].tap()
        let actionsNav = app.navigationBars["Actions"]
        let empty = app.staticTexts["No actions yet"]
        XCTAssertTrue(
            actionsNav.waitForExistence(timeout: 5) || empty.waitForExistence(timeout: 5),
            "Actions tab should render"
        )

        tabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))

        tabBar.buttons["Chats"].tap()
        XCTAssertTrue(app.navigationBars["Knowledge Base"].waitForExistence(timeout: 5))
    }

    func testOpenDemoSessionShowsMessages() throws {
        let demoRow = app.descendants(matching: .any)["session.row.demo-session"]
        XCTAssertTrue(demoRow.waitForExistence(timeout: 10), "Stub store should seed Demo session row")
        demoRow.tap()

        // Navigation title is the session title once pushed.
        XCTAssertTrue(
            app.navigationBars["Demo session"].waitForExistence(timeout: 8),
            "Demo session chat should open"
        )

        let summary = app.staticTexts.containing(NSPredicate(format: "label CONTAINS[c] %@", "Summary")).firstMatch
        XCTAssertTrue(summary.waitForExistence(timeout: 8), "Demo messages should stay visible in the chat list")
    }

    func testOverviewListsDemoSummaryBoard() throws {
        openOverviewTab()

        let row = app.descendants(matching: .any)["board.row.demo-kpi"]
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Stub Overview should list demo-kpi")

        XCTAssertTrue(app.staticTexts["Demo: summary"].waitForExistence(timeout: 3))
        // List cell metrics from DemoBoardsCatalog.
        XCTAssertTrue(app.staticTexts["Total"].exists || app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "12 450")).firstMatch.exists)
        // Jobs board belongs on Actions — not Overview.
        XCTAssertFalse(app.descendants(matching: .any)["board.row.demo-active-jobs"].exists)
    }

    func testOpenDemoSummaryBoardShowsStructuredUI() throws {
        openOverviewTab()

        let row = app.descendants(matching: .any)["board.row.demo-kpi"]
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        XCTAssertTrue(
            app.navigationBars["Demo: summary"].waitForExistence(timeout: 8),
            "Board detail should open"
        )
        XCTAssertTrue(
            app.descendants(matching: .any)["board.detail.demo-kpi"].waitForExistence(timeout: 5)
                || app.staticTexts["Demo summary"].waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Demo summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "12 450")).firstMatch.waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["Recent rows"].waitForExistence(timeout: 5)
            || app.staticTexts["Alpha"].waitForExistence(timeout: 5))
    }

    func testActionsTabShowsDemoJobsBoard() throws {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        tabBar.buttons["Actions"].tap()

        XCTAssertTrue(app.navigationBars["Actions"].waitForExistence(timeout: 5))

        let section = app.descendants(matching: .any)["actions.section.demo-active-jobs"]
        XCTAssertTrue(
            section.waitForExistence(timeout: 10)
                || app.staticTexts["Active jobs"].waitForExistence(timeout: 10),
            "Actions stub should render demo jobs document"
        )
        XCTAssertTrue(app.staticTexts["Active jobs"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.buttons["Cancel demo job"].waitForExistence(timeout: 5)
                || app.staticTexts["Cancel demo job"].waitForExistence(timeout: 5)
        )
    }

    func testNewSessionSendTextShowsUserAndStubReply() throws {
        let newSession = app.buttons["main.newSession"]
        XCTAssertTrue(newSession.waitForExistence(timeout: 10))
        newSession.tap()

        XCTAssertTrue(
            app.navigationBars["New session"].waitForExistence(timeout: 8),
            "Local draft chat should open"
        )

        let field = composerTextField()
        XCTAssertTrue(field.waitForExistence(timeout: 8), "Composer text field")
        enterComposerText(field, "UI test ping")

        let send = app.buttons["composer.send"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        XCTAssertTrue(
            send.wait(for: \.isEnabled, toEqual: true, timeout: 5),
            "Send should enable after text is entered"
        )
        send.tap()

        let userBubble = app.staticTexts["UI test ping"]
        XCTAssertTrue(userBubble.waitForExistence(timeout: 8), "User message should appear")

        let stubReply = app.staticTexts.containing(
            NSPredicate(format: "label CONTAINS %@", "Stub reply")
        ).firstMatch
        XCTAssertTrue(stubReply.waitForExistence(timeout: 10), "Stub assistant reply should appear")
    }

    private func openOverviewTab() {
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(tabBar.waitForExistence(timeout: 10))
        let overview = tabBar.buttons["Overview"]
        XCTAssertTrue(overview.waitForExistence(timeout: 5), "Overview tab should be enabled by default")
        overview.tap()
        XCTAssertTrue(app.navigationBars["Overview"].waitForExistence(timeout: 5))
    }

    private func composerTextField() -> XCUIElement {
        let byId = app.descendants(matching: .any)["composer.textField"]
        if byId.waitForExistence(timeout: 2) {
            return byId
        }
        return app.textViews.firstMatch
    }

    /// UITextView + SwiftUI often refuses XCTest keyboard focus; paste is more reliable.
    private func enterComposerText(_ field: XCUIElement, _ text: String) {
        UIPasteboard.general.string = text
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        field.press(forDuration: 1.0)
        let paste = app.menuItems["Paste"].firstMatch
        if paste.waitForExistence(timeout: 3) {
            paste.tap()
            return
        }
        // Last resort: type into the app (works when software keyboard is up).
        if app.keyboards.firstMatch.waitForExistence(timeout: 2) {
            app.typeText(text)
        } else {
            XCTFail("Could not paste or type into composer")
        }
    }
}

final class AuthLoginUITests: XCTestCase {
    /// Nextcloud-style onboarding: server address first; credentials only after continue.
    func testLoginScreenShowsServerAndCredentials() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            UITestRuntime.launchArgument,
            UITestRuntime.forceLoginGateArgument,
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US"
        ]
        app.launch()

        let serverNav = app.navigationBars["Server address"].waitForExistence(timeout: 10)
            || app.navigationBars["Sign in"].waitForExistence(timeout: 2)
        XCTAssertTrue(serverNav, "Expected server-first login nav title")

        XCTAssertTrue(
            app.textFields["auth.server_url"].exists
                || app.textFields["Server URL"].exists
                || app.textFields["cloud.example.com"].exists
        )
        XCTAssertTrue(
            app.buttons["auth.server_continue"].exists
                || app.buttons["Continue"].exists
        )

        // Credentials are on step 2 — not visible until the server is confirmed.
        XCTAssertFalse(app.textFields["auth.login"].exists)
        XCTAssertFalse(app.secureTextFields["auth.password"].exists)
        XCTAssertFalse(app.buttons["auth.submit"].exists)
    }
}

private extension XCUIElement {
    func wait(for keyPath: KeyPath<XCUIElement, Bool>, toEqual expected: Bool, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate { _, _ in
            self[keyPath: keyPath] == expected
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}

