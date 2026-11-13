import SayAgainKit
import XCTest

@MainActor
struct SettingsScreen {
    let app: XCUIApplication

    var slowByDefaultToggle: XCUIElement { app.switches[A11yID.Settings.slowByDefaultToggle] }
    var resetButton: XCUIElement { app.buttons[A11yID.Settings.resetButton] }
    var resetOrderButton: XCUIElement { app.buttons[A11yID.Settings.resetOrderButton] }
    var russianToggle: XCUIElement { app.switches[A11yID.Settings.russianToggle] }
    /// The dialog exposes its action twice on iOS 26 (sheet and its container), so take the first.
    var resetConfirmButton: XCUIElement { app.buttons.matching(identifier: A11yID.Settings.resetConfirmButton).firstMatch }
    var resetDoneLabel: XCUIElement { app.staticTexts[A11yID.Settings.resetDoneLabel] }

    func voiceRow(_ name: String) -> XCUIElement {
        app.descendants(matching: .any)[A11yID.Settings.voiceRow(name)]
    }

    @discardableResult
    func waitUntilShown(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(resetButton.waitForExistence(timeout: timeout), "Settings did not appear", file: file, line: line)
        return self
    }
}
