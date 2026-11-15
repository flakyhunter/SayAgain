import SayAgainKit
import XCTest

/// The whole chain: app, real HTTP, the Worker's routing and validation, and back.
/// Needs the Worker running locally with the offline checker (no API key, no cost):
///   cd server && npm run dev
///   TEST_RUNNER_SAYAGAIN_E2E=1 xcodebuild test ... -only-testing:SayAgainUITests/FeedbackEndToEndUITests
/// Skipped in normal runs and in CI.
final class FeedbackEndToEndUITests: SayAgainUITestCase {
    func testRetellingRoundTripThroughTheLocalWorker() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SAYAGAIN_E2E"] == "1",
                          "Start the Worker with `npm run dev` in server/ and set SAYAGAIN_E2E=1")
        let app = launchApp(extraArguments: [LaunchArgument.bundledContent, LaunchArgument.liveFeedback])
        HomeScreen(app: app).waitUntilShown().categoryRow(.intro).tap()
        let session = SessionScreen(app: app).waitUntilShown()
        let retell = RetellScreen(app: app)

        retell.openButton.tap()
        retell.allowButton.tap()
        retell.check("They asked about my background and why I came to Australia")

        XCTAssertTrue(retell.verdict.waitForExistence(timeout: 15), "No answer from the Worker")
        XCTAssertFalse(retell.error.exists)
        XCTAssertTrue(retell.feedback.label.hasSuffix("(Offline test feedback.)"),
                      "Feedback must come from the Worker's offline checker, got: \(retell.feedback.label)")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "feedback-from-local-worker"
        attachment.lifetime = .keepAlways
        add(attachment)
        retell.continueButton.tap()
        XCTAssertTrue(session.reveal.waitForExistence(timeout: 5))
    }
}
