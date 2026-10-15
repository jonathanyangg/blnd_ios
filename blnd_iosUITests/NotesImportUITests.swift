import XCTest

final class NotesImportUITests: XCTestCase {
    private let artifacts = URL(
        fileURLWithPath: "/Users/jonathanyang/cursor-work/blnd-notes-artifacts",
        isDirectory: true
    )

    override func setUpWithError() throws {
        continueAfterFailure = false
        try FileManager.default.createDirectory(at: artifacts, withIntermediateDirectories: true)
    }

    @MainActor
    func testReviewThenFound() {
        let app = XCUIApplication()
        app.launchArguments = ["-NotesImportPreview"]
        app.launch()

        let review = app.descendants(matching: .any)["import.notes.review"]
        XCTAssertTrue(review.waitForExistence(timeout: 15))
        let included = app.descendants(matching: .any)["import.notes.include.0"]
        XCTAssertTrue(included.waitForExistence(timeout: 5))
        XCTAssertTrue(included.isSelected)
        saveShot(app, name: "notes-review")

        app.descendants(matching: .any)["import.notes.candidate.238"].tap()

        let search = app.textFields["import.notes.search.2"]
        if search.waitForExistence(timeout: 2) {
            search.tap()
            search.typeText("Spirited")
        } else {
            let box = app.descendants(matching: .any)["import.notes.search.2"]
            XCTAssertTrue(box.waitForExistence(timeout: 2))
            box.tap()
            box.typeText("Spirited")
        }
        let hit = app.descendants(matching: .any)["import.notes.hit.129"]
        XCTAssertTrue(hit.waitForExistence(timeout: 5))
        hit.tap()
        let keyboardDone = app.buttons["import.notes.keyboard.done"]
        if keyboardDone.waitForExistence(timeout: 2) {
            keyboardDone.tap()
        }
        saveShot(app, name: "notes-review-picked")

        app.descendants(matching: .any)["import.notes.bucket.watched"].tap()
        app.descendants(matching: .any)["import.notes.commit"].tap()

        let found = app.staticTexts["We found 3 movies"]
        XCTAssertTrue(found.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["import.notes.rec.680"].waitForExistence(timeout: 5))
        saveShot(app, name: "notes-found")
    }

    private func saveShot(_ app: XCUIApplication, name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        try? shot.pngRepresentation.write(to: artifacts.appendingPathComponent("\(name).png"))
    }
}
