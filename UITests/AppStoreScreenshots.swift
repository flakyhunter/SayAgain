import SayAgainKit
import XCTest

/// Produces the App Store screenshots. Skipped in normal runs; see scripts/screenshots.sh.
final class AppStoreScreenshots: SayAgainUITestCase {
    private func snap(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SAYAGAIN_SCREENSHOTS"] == "1",
                          "Run scripts/screenshots.sh to capture App Store screenshots")
        let bank = try QuestionBank.bundled()
        let app = launchApp(extraArguments: [LaunchArgument.bundledContent])
        let home = HomeScreen(app: app).waitUntilShown()
        snap(app, "01-home")

        home.startButton.tap()
        let session = SessionScreen(app: app).waitUntilShown()
        snap(app, "02-listen")

        for step in 1...10 {
            XCTAssertTrue(session.choices[0].waitForExistence(timeout: 5))
            let labels = Set(session.choices.map { $0.label })
            let question = try XCTUnwrap(bank.questions.first { labels.contains($0.gist) })
            session.choose(question.gist)
            XCTAssertTrue(session.nextButton.waitForExistence(timeout: 5))
            if step == 1 {
                sleep(1)
                snap(app, "03-explanation")
                session.sampleAnswerButton.tap()
                XCTAssertTrue(session.sampleAnswerText.waitForExistence(timeout: 5))
                sleep(1)
                snap(app, "04-sample-answer")
                session.sampleAnswerCloseButton.tap()
            }
            session.nextButton.tap()
        }
        XCTAssertTrue(session.summary.waitForExistence(timeout: 5))
        snap(app, "05-summary")

        session.doneButton.tap()
        home.phrasebookButton.tap()
        XCTAssertTrue(app.buttons[A11yID.Phrasebook.row("arvo")].waitForExistence(timeout: 2)
                      || app.descendants(matching: .any)[A11yID.Phrasebook.list].waitForExistence(timeout: 5))
        sleep(1)
        snap(app, "06-phrasebook")
    }
}
