import SayAgainKit
import XCTest

final class MasteryUITests: SayAgainUITestCase {
    private let intro = QuestionBank.fixture.questions(in: .intro)[0]

    private func masterIntro(_ app: XCUIApplication, home: HomeScreen) -> SessionScreen {
        home.categoryRow(.intro).tap()
        let session = SessionScreen(app: app).waitUntilShown()
        session.choose(intro.gist)
        XCTAssertTrue(session.nextButton.waitForExistence(timeout: 5))
        session.nextButton.tap()
        XCTAssertTrue(session.masteredBanner.waitForExistence(timeout: 5), "Celebration after the last question")
        return session
    }

    func testStartOverFromTheCelebration() {
        let app = launchApp()
        let home = HomeScreen(app: app).waitUntilShown()
        XCTAssertEqual(home.progress(of: .intro), "1 question")

        masterIntro(app, home: home).summaryStartOverButton.tap()

        XCTAssertTrue(home.startButton.waitForExistence(timeout: 5))
        XCTAssertEqual(home.progress(of: .intro), "1 question", "Category starts from zero again")
        XCTAssertFalse(home.startOverButton(.intro).exists)
    }

    func testMasteredCardOffersStartOverWithConfirmation() {
        let app = launchApp()
        let home = HomeScreen(app: app).waitUntilShown()

        masterIntro(app, home: home).doneButton.tap()
        XCTAssertTrue(home.startOverButton(.intro).waitForExistence(timeout: 5))
        XCTAssertEqual(home.progress(of: .intro), "Understood, mastered")

        home.startOverButton(.intro).tap()
        XCTAssertTrue(home.startOverConfirmButton.waitForExistence(timeout: 5))
        home.startOverConfirmButton.tap()

        XCTAssertFalse(home.startOverButton(.intro).waitForExistence(timeout: 2))
        XCTAssertEqual(home.progress(of: .intro), "1 question")
    }
}
