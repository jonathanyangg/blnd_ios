import XCTest

final class LetterboxdEarlyOnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testImportStepFollowsLovedAndIsSkippable() {
        let app = XCUIApplication()
        app.launchArguments += ["-UITestScreen", "onboardTaste"]
        app.launch()
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        XCTAssertTrue(app.staticTexts["Import from Letterboxd"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["tutorial.letterboxd"].exists)
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(app.staticTexts["Swipe it"].waitForExistence(timeout: 5))
    }
}
