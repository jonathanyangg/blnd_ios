import XCTest

final class LetterboxdOnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAtMovieHub() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("UI_TEST_LETTERBOXD_IMPORT")
        app.launch()
        XCTAssertTrue(app.staticTexts["Bring your movies"].waitForExistence(timeout: 10))
        return app
    }

    @MainActor
    func testHubShowsThreeWaysIn() {
        let app = launchAtMovieHub()
        XCTAssertTrue(app.buttons["import.hub.letterboxd"].exists)
        XCTAssertTrue(app.buttons["import.hub.photos"].exists)
        XCTAssertTrue(app.buttons["import.hub.notes"].exists)
        XCTAssertTrue(app.buttons["Skip for now"].exists)
    }

    @MainActor
    func testLetterboxdCardShowsExportSteps() {
        let app = launchAtMovieHub()
        app.buttons["import.hub.letterboxd"].tap()
        XCTAssertTrue(app.staticTexts["Export from Letterboxd"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Upload to blnd"].exists)
    }

    @MainActor
    func testSkipGoesToFindFriends() {
        let app = launchAtMovieHub()
        app.buttons["import.skip"].tap()
        XCTAssertTrue(app.staticTexts["Find Your Friends"].waitForExistence(timeout: 5))
    }
}
