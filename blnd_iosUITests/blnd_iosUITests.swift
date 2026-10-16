import XCTest

final class BlndIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {}

    @MainActor
    func testExample() {
        let app = XCUIApplication()
        app.launch()
    }

    /// Drives Sign in with Apple on the simulator. Error 1000 is what a signed-out sim returns.
    /// Skipped unless APPLE_AUTH_SHOT is set, so a normal test run does not depend on that sheet.
    @MainActor
    func testAppleSignInFailureShowsFriendlyCopy() throws {
        let shotPath = ProcessInfo.processInfo.environment["APPLE_AUTH_SHOT"]
            ?? ProcessInfo.processInfo.environment["TEST_RUNNER_APPLE_AUTH_SHOT"]
        try XCTSkipIf(shotPath == nil, "Set APPLE_AUTH_SHOT to capture the Apple error state")

        let app = XCUIApplication()
        app.launch()

        let signIn = app.buttons["Sign In"]
        XCTAssertTrue(signIn.waitForExistence(timeout: 20))
        signIn.tap()

        let apple = app.buttons["Sign in with Apple"]
        XCTAssertTrue(apple.waitForExistence(timeout: 10))
        apple.tap()

        let message = app.staticTexts["Couldn't sign in with Apple. Try again or use email."]
        let deadline = Date().addingTimeInterval(20)
        while !message.exists, Date() < deadline {
            let alert = app.alerts.firstMatch
            if alert.exists {
                let button = alert.buttons["OK"].exists ? alert.buttons["OK"] : alert.buttons.firstMatch
                if button.exists { button.tap() }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.4))
        }

        if message.exists, !message.isHittable {
            app.swipeUp()
        }

        let url = URL(fileURLWithPath: shotPath!)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try app.screenshot().pngRepresentation.write(to: url)
        XCTAssertTrue(
            message.exists,
            "Apple failure did not show friendly copy. Hierarchy:\n\(app.debugDescription)"
        )
    }

    @MainActor
    func testLaunchPerformance() {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
