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
    var speaker: XCUIElement { element(A11yID.Session.speaker) }
    var slowToggle: XCUIElement { element(A11yID.Session.slowToggle) }

    /// Button-style toggles report "1" when on.
    var isSlowOn: Bool { slowToggle.isSelected || (slowToggle.value as? String) == "1" }
    var reveal: XCUIElement { element(A11yID.Session.reveal) }
    var originalText: XCUIElement { element(A11yID.Session.originalText) }
    var sampleAnswerButton: XCUIElement { app.buttons[A11yID.Session.sampleAnswerButton] }
    var nextButton: XCUIElement { app.buttons[A11yID.Session.nextButton] }

    var summary: XCUIElement { element(A11yID.Summary.root) }
    var summaryUnderstood: XCUIElement { element(A11yID.Summary.understood) }
    var masteredBanner: XCUIElement { element(A11yID.Summary.masteredBanner) }
    var summaryStartOverButton: XCUIElement { app.buttons[A11yID.Summary.startOverButton] }

    var sampleAnswerText: XCUIElement { element(A11yID.SampleAnswer.text) }
    var sampleAnswerListenButton: XCUIElement { app.buttons[A11yID.SampleAnswer.listenButton] }
    var sampleAnswerCloseButton: XCUIElement { app.buttons[A11yID.SampleAnswer.closeButton] }
    var summaryMissed: XCUIElement { element(A11yID.Summary.missed) }
    var doneButton: XCUIElement { app.buttons[A11yID.Summary.doneButton] }

    var choices: [XCUIElement] { (0..<3).map { app.buttons[A11yID.Session.choice($0)] } }

    @discardableResult
    func waitUntilShown(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(playButton.waitForExistence(timeout: timeout), "Session screen did not appear", file: file, line: line)
        return self
    }

    /// The revealed text must be visible without scrolling: inside the window and above the rating bar.
    func assertOriginalTextIsOnScreen(timeout: TimeInterval = 3, file: StaticString = #filePath, line: UInt = #line) {
        let deadline = Date().addingTimeInterval(timeout)
        var frame = originalText.frame
        let bar = nextButton.frame
        while Date() < deadline, !(frame.minY >= 0 && frame.maxY <= bar.minY) {
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            frame = originalText.frame
        }
        XCTAssertGreaterThanOrEqual(frame.minY, 0, "Original text is above the screen", file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxY, bar.minY, "Original text is hidden under the rating bar", file: file, line: line)
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
