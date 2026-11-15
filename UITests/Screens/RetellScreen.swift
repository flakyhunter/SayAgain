import SayAgainKit
import XCTest

/// Page object for the "Say it in your own words" sheet.
@MainActor
struct RetellScreen {
    let app: XCUIApplication

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    var openButton: XCUIElement { app.buttons[A11yID.Session.retellButton] }
    var consent: XCUIElement { element(A11yID.Retell.consent) }
    var allowButton: XCUIElement { app.buttons[A11yID.Retell.allowButton] }
    var declineButton: XCUIElement { app.buttons[A11yID.Retell.declineButton] }
    var textField: XCUIElement { app.textViews[A11yID.Retell.textField].exists
        ? app.textViews[A11yID.Retell.textField] : app.textFields[A11yID.Retell.textField] }
    var checkButton: XCUIElement { app.buttons[A11yID.Retell.checkButton] }
    var verdict: XCUIElement { element(A11yID.Retell.verdict) }
    var feedback: XCUIElement { element(A11yID.Retell.feedback) }
    var error: XCUIElement { element(A11yID.Retell.error) }
    var retryButton: XCUIElement { app.buttons[A11yID.Retell.retryButton] }
    var continueButton: XCUIElement { app.buttons[A11yID.Retell.continueButton] }
    var cancelButton: XCUIElement { app.buttons[A11yID.Retell.cancelButton] }
    var sessionFeedback: XCUIElement { element(A11yID.Session.aiFeedback) }

    /// Types the retelling and taps Check.
    func check(_ text: String, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(textField.waitForExistence(timeout: 5), "Text field missing", file: file, line: line)
        textField.tap()
        textField.typeText(text)
        checkButton.tap()
    }
}
