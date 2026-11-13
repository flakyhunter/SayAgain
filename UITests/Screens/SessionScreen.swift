import SayAgainKit
import XCTest

/// Page object for the practice screen and the summary that follows it.
@MainActor
struct SessionScreen {
    let app: XCUIApplication

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    var progress: XCUIElement { element(A11yID.Session.progress) }
    var playButton: XCUIElement { app.buttons[A11yID.Session.playButton] }
    var reveal: XCUIElement { element(A11yID.Session.reveal) }
    var originalText: XCUIElement { element(A11yID.Session.originalText) }
    var gotItButton: XCUIElement { app.buttons[A11yID.Session.gotItButton] }
    var partlyButton: XCUIElement { app.buttons[A11yID.Session.partlyButton] }
    var nextButton: XCUIElement { app.buttons[A11yID.Session.nextButton] }

    var summary: XCUIElement { element(A11yID.Summary.root) }
    var summaryGotIt: XCUIElement { element(A11yID.Summary.gotIt) }
    var summaryPartly: XCUIElement { element(A11yID.Summary.partly) }
    var summaryMissed: XCUIElement { element(A11yID.Summary.missed) }
    var doneButton: XCUIElement { app.buttons[A11yID.Summary.doneButton] }

    var choices: [XCUIElement] { (0..<3).map { app.buttons[A11yID.Session.choice($0)] } }

    @discardableResult
    func waitUntilShown(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(playButton.waitForExistence(timeout: timeout), "Session screen did not appear", file: file, line: line)
        return self
    }

    /// Taps the choice whose text equals `meaning`.
    func choose(_ meaning: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let button = choices.first(where: { $0.label == meaning }) else {
            XCTFail("No choice \"\(meaning)\" among \(choices.map { $0.label })", file: file, line: line)
            return
        }
        button.tap()
    }

    /// Taps any choice that is not `meaning`.
    func chooseWrong(insteadOf meaning: String, file: StaticString = #filePath, line: UInt = #line) {
        guard let button = choices.first(where: { $0.label != meaning }) else {
            XCTFail("No wrong choice found", file: file, line: line)
            return
        }
        button.tap()
    }
}
