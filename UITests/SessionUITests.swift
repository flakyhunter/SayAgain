import SayAgainKit
import XCTest

final class SessionUITests: SayAgainUITestCase {
    private let behavioural = QuestionBank.fixture.questions(in: .behavioural)

    /// Full run through a category: one right answer, one wrong, summary, back home.
    func testCategorySessionFromStartToSummary() {
        let app = launchApp()
        let home = HomeScreen(app: app).waitUntilShown()
        home.categoryRow(.behavioural).tap()

        let session = SessionScreen(app: app).waitUntilShown()
        XCTAssertEqual(session.progress.label, "Question 1 of 2")
        XCTAssertEqual(session.playButton.value as? String, "Played once", "Question autoplays once")
        XCTAssertFalse(session.reveal.exists, "Text stays hidden until the user answers")
        XCTAssertEqual(session.speaker.label, "Karen is asking")

        let first = question(shownIn: session)
        session.choose(first.gist)
        XCTAssertTrue(session.reveal.waitForExistence(timeout: 5))
        XCTAssertEqual(session.originalText.label, "\u{201C}\(first.text)\u{201D}")
        session.gotItButton.tap()

        XCTAssertEqual(session.progress.label, "Question 2 of 2")
        XCTAssertEqual(session.speaker.label, "Lee is asking", "Each question gets another interviewer")
        let second = question(shownIn: session)
        session.chooseWrong(insteadOf: second.gist)
        XCTAssertFalse(session.gotItButton.exists, "Wrong answer cannot be rated as understood")
        session.nextButton.tap()

        XCTAssertTrue(session.summary.waitForExistence(timeout: 5))
        XCTAssertEqual(session.summaryGotIt.value as? String, "1")
        XCTAssertEqual(session.summaryPartly.value as? String, "0")
        XCTAssertEqual(session.summaryMissed.value as? String, "1")

        session.doneButton.tap()
        XCTAssertTrue(home.startButton.waitForExistence(timeout: 5))
    }

    func testReplayCountsPlays() {
        let app = launchApp()
        HomeScreen(app: app).waitUntilShown().startButton.tap()

        let session = SessionScreen(app: app).waitUntilShown()
        session.playButton.tap()
        XCTAssertEqual(session.playButton.value as? String, "Played 2 times")
    }

    /// The fixture question currently on screen, found by its choices.
    private func question(shownIn session: SessionScreen) -> Question {
        let labels = Set(session.choices.map { $0.label })
        guard let match = behavioural.first(where: { labels.contains($0.gist) }) else {
            XCTFail("Choices \(labels) do not match any fixture question")
            return behavioural[0]
        }
        return match
    }
}
