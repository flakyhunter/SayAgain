import SayAgainKit
import XCTest

final class PhrasebookUITests: SayAgainUITestCase {
    private func row(_ app: XCUIApplication, _ phrase: String) -> XCUIElement {
        app.buttons[A11yID.Phrasebook.row(phrase)]
    }

    func testSearchFindsAPhraseAndRussianAppearsWhenTurnedOn() {
        let app = launchApp(extraArguments: [LaunchArgument.bundledContent])
        let home = HomeScreen(app: app).waitUntilShown()

        home.phrasebookButton.tap()
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("arvo")
        let arvo = row(app, "arvo")
        XCTAssertTrue(arvo.waitForExistence(timeout: 5))
        XCTAssertTrue(arvo.label.contains("afternoon"))
        XCTAssertFalse(arvo.label.contains("после обеда"), "Russian is off by default")
        XCTAssertFalse(row(app, "reckon").exists, "Search hides other phrases")

        // Turn Russian on in Settings and come back. An active search hides the bar: close it first.
        // iOS 26 shows a round "close" button instead of "Cancel".
        let close = app.buttons["close"].exists ? app.buttons["close"] : app.buttons["Cancel"]
        close.firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        home.settingsButton.tap()
        let settings = SettingsScreen(app: app).waitUntilShown()
        settings.russianToggle.switches.firstMatch.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        home.phrasebookButton.tap()
        let search2 = app.searchFields.firstMatch
        XCTAssertTrue(search2.waitForExistence(timeout: 5))
        search2.tap()
        search2.typeText("после обеда")
        XCTAssertTrue(row(app, "arvo").waitForExistence(timeout: 5), "Search works in Russian too")
        XCTAssertTrue(row(app, "arvo").label.contains("после обеда"))
    }
}
