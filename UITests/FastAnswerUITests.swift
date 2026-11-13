import SayAgainKit
import XCTest

/// Regression for a user report: 10 right answers, summary showed 3 missed.
/// A fast user answers each question right away, while the screen may still be moving.
final class FastAnswerUITests: SayAgainUITestCase {
    func testTenFastRightAnswersAreAllCountedAsGotIt() throws {
        let bank = try QuestionBank.bundled()
        let app = launchApp(extraArguments: [LaunchArgument.bundledContent])
        HomeScreen(app: app).waitUntilShown().startButton.tap()
        let session = SessionScreen(app: app).waitUntilShown()

        for step in 1...10 {
            XCTAssertTrue(session.choices[0].waitForExistence(timeout: 5), "Question \(step) has choices")
            let labels = Set(session.choices.map { $0.label })
            let question = try XCTUnwrap(bank.questions.first { labels.contains($0.gist) }, "Question \(step)")
            session.choose(question.gist)
            XCTAssertTrue(session.gotItButton.waitForExistence(timeout: 3),
                          "Question \(step): right answer \"\(question.gist)\" was not accepted")
            session.gotItButton.tap()
        }

        XCTAssertTrue(session.summary.waitForExistence(timeout: 5))
        XCTAssertEqual(session.summaryGotIt.value as? String, "10")
        XCTAssertEqual(session.summaryMissed.value as? String, "0")
    }
}
