import SayAgainKit
import XCTest

final class SettingsUITests: SayAgainUITestCase {
    func testResetProgressAsksForConfirmation() {
        let app = launchApp()
        HomeScreen(app: app).waitUntilShown().settingsButton.tap()

        let settings = SettingsScreen(app: app).waitUntilShown()
        XCTAssertTrue(settings.voiceRow("Karen").exists)
        XCTAssertTrue(settings.voiceRow("Lee").exists)

        settings.resetButton.tap()
        XCTAssertTrue(settings.resetConfirmButton.waitForExistence(timeout: 5))
        settings.resetConfirmButton.tap()
        app.swipeUp()   // the confirmation note is in the footer, lower down the longer form
        XCTAssertTrue(settings.resetDoneLabel.waitForExistence(timeout: 5))
    }

    func testSlowByDefaultTurnsOnSlowerInPractice() {
        let app = launchApp()
        let home = HomeScreen(app: app).waitUntilShown()
        home.settingsButton.tap()

        let settings = SettingsScreen(app: app).waitUntilShown()
        settings.slowByDefaultToggle.switches.firstMatch.tap()
        XCTAssertEqual(settings.slowByDefaultToggle.value as? String, "1")

        app.navigationBars.buttons.element(boundBy: 0).tap()
        home.startButton.tap()
        let session = SessionScreen(app: app).waitUntilShown()
        XCTAssertTrue(session.slowToggle.waitForExistence(timeout: 5))
        XCTAssertTrue(session.isSlowOn, "Slower is on for the new session: \(session.slowToggle.debugDescription)")
    }
}
