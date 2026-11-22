import SayAgainKit
import XCTest

/// The real on-device recogniser, not the scripted one. Guards the Swift 6 isolation crash:
/// the permission and recognition callbacks arrive on background queues.
/// Opt-in, because it needs a microphone and permission dialogs:
///   TEST_RUNNER_SAYAGAIN_LIVE_DICTATION=1 xcodebuild test ... -only-testing:SayAgainUITests/LiveDictationUITests
final class LiveDictationUITests: InterviewPracticeUITestCase {
    func testMicStartsAndStopsWithoutCrashing() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SAYAGAIN_LIVE_DICTATION"] == "1",
                          "Needs a microphone; set SAYAGAIN_LIVE_DICTATION=1")
        let app = launchApp(extraArguments: [LaunchArgument.liveDictation])
        HomeScreen(app: app).waitUntilShown().categoryRow(.intro).tap()
        SessionScreen(app: app).waitUntilShown()
        let retell = RetellScreen(app: app)
        retell.openButton.tap()
        retell.allowButton.tap()

        retell.micButton.tap()
        allowSystemAlerts()

        // Either it listens, or it explains why it can't. Both mean the app survived the callbacks.
        let error = app.descendants(matching: .any)[A11yID.Retell.dictationError]
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline, !retell.listening.exists, !error.exists {
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTAssertEqual(app.state, .runningForeground, "App crashed after tapping the mic")
        XCTAssertTrue(retell.listening.exists || error.exists, "No listening state and no error")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = retell.listening.exists ? "listening" : "dictation-error"
        shot.lifetime = .keepAlways
        add(shot)
        if retell.listening.exists {
            retell.micButton.tap()
            XCTAssertTrue(retell.micButton.waitForExistence(timeout: 5))
            let stopped = NSPredicate(format: "label == %@", "Dictate your answer")
            wait(for: [expectation(for: stopped, evaluatedWith: retell.micButton)], timeout: 5)
        }
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Taps "Allow" / "OK" on the microphone and speech recognition dialogs if they show up.
    private func allowSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            guard alert.waitForExistence(timeout: 4) else { return }
            for title in ["Allow", "OK"] where alert.buttons[title].exists {
                alert.buttons[title].tap()
                break
            }
        }
    }
}
