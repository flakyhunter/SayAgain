import SayAgainKit
import XCTest

/// "Say it in your own words" against the scripted feedback service (no network in UI tests).
final class RetellUITests: SayAgainUITestCase {
    /// First use: consent, retell, partly verdict, reveal shows the AI feedback, summary counts it.
    func testRetellPartlyRevealsWithAIFeedbackAndCountsAsUnderstood() {
        let app = launchApp()
        HomeScreen(app: app).waitUntilShown().categoryRow(.intro).tap()
        let session = SessionScreen(app: app).waitUntilShown()
        let retell = RetellScreen(app: app)

        retell.openButton.tap()
        XCTAssertTrue(retell.consent.waitForExistence(timeout: 5), "Consent comes before anything is sent")
        XCTAssertFalse(retell.textField.exists)
        retell.allowButton.tap()

        retell.check("partly my background")
        XCTAssertTrue(retell.verdict.waitForExistence(timeout: 5))
        XCTAssertEqual(retell.verdict.label, "Partly there")
        XCTAssertEqual(retell.feedback.label, "Close. You missed the second part of the question.")

        retell.continueButton.tap()
        XCTAssertTrue(session.reveal.waitForExistence(timeout: 5))
        XCTAssertEqual(retell.sessionFeedback.label, "Close. You missed the second part of the question.")
        XCTAssertFalse(retell.openButton.exists, "No second retelling once the answer is shown")

        session.nextButton.tap()
        XCTAssertTrue(session.summary.waitForExistence(timeout: 5))
        XCTAssertEqual(session.summaryUnderstood.value as? String, "1", "Partly counts as understood")
    }

    /// No internet: the error is shown, the text is kept, and the learner can still pick a choice.
    func testOfflineShowsErrorAndPracticeGoesOn() {
        let app = launchApp()
        HomeScreen(app: app).waitUntilShown().categoryRow(.intro).tap()
        let session = SessionScreen(app: app).waitUntilShown()
        let retell = RetellScreen(app: app)

        retell.openButton.tap()
        retell.allowButton.tap()
        retell.check("offline please")
        XCTAssertTrue(retell.error.waitForExistence(timeout: 5))
        XCTAssertEqual(retell.error.label, FeedbackServiceError.offline.message)

        retell.retryButton.tap()
        XCTAssertEqual(retell.textField.value as? String, "offline please", "Typed text survives the error")
        retell.cancelButton.tap()

        XCTAssertTrue(session.choices[0].waitForExistence(timeout: 5))
        XCTAssertTrue(retell.openButton.exists, "Can try again later")
        session.choose(QuestionBank.fixture.questions(in: .intro)[0].gist)
        XCTAssertTrue(session.reveal.waitForExistence(timeout: 5))
    }

    /// "Not now" hides the button for good; Settings can turn it back on.
    func testDeclineHidesTheFeatureUntilSettingsTurnItOn() {
        let app = launchApp()
        let home = HomeScreen(app: app).waitUntilShown()
        home.categoryRow(.intro).tap()
        let session = SessionScreen(app: app).waitUntilShown()
        let retell = RetellScreen(app: app)

        retell.openButton.tap()
        retell.declineButton.tap()
        XCTAssertTrue(session.playButton.waitForExistence(timeout: 5))
        XCTAssertFalse(retell.openButton.exists)

        app.navigationBars.buttons.element(boundBy: 0).tap()
        home.settingsButton.tap()
        let toggle = app.switches[A11yID.Settings.aiFeedbackToggle]
        var swipes = 0
        while !toggle.isHittable && swipes < 4 { app.swipeUp(); swipes += 1 }
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.switches.firstMatch.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        home.categoryRow(.intro).tap()
        XCTAssertTrue(retell.openButton.waitForExistence(timeout: 5))
        retell.openButton.tap()
        XCTAssertTrue(retell.textField.waitForExistence(timeout: 5), "Already allowed, no consent screen")
    }
}
