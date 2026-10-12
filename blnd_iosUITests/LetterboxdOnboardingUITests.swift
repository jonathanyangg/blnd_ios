import XCTest

final class LetterboxdOnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAtLetterboxdQuestion() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UI_TEST_LETTERBOXD_IMPORT")
        app.launch()
        XCTAssertTrue(app.staticTexts["Do you use Letterboxd?"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testYesShowsImportInstructions() {
        let app = launchAtLetterboxdQuestion()
        app.buttons["import.question.yes"].tap()
        XCTAssertTrue(app.buttons["import.continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Import from Letterboxd"].exists)
    }

    @MainActor
    func testNoGoesToFindFriends() {
        let app = launchAtLetterboxdQuestion()
        app.buttons["import.question.no"].tap()
        XCTAssertTrue(app.staticTexts["Find Your Friends"].waitForExistence(timeout: 5))
    }
}
