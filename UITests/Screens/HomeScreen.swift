import SayAgainKit
import XCTest

/// Page object for the home screen. Tests talk to screens, never to raw queries.
@MainActor
struct HomeScreen {
    let app: XCUIApplication

    var list: XCUIElement { app.descendants(matching: .any)[A11yID.Home.list] }
    var header: XCUIElement { app.descendants(matching: .any)[A11yID.Home.header] }
    var startButton: XCUIElement { app.buttons[A11yID.Home.startButton] }
    var settingsButton: XCUIElement { app.buttons[A11yID.Home.settingsButton] }
    var phrasebookButton: XCUIElement { app.buttons[A11yID.Home.phrasebookButton] }
    var startOverConfirmButton: XCUIElement {
        app.buttons.matching(identifier: A11yID.Home.startOverConfirmButton).firstMatch
    }

    func startOverButton(_ category: QuestionCategory) -> XCUIElement {
        app.buttons[A11yID.Home.startOverButton(category)]
    }

    func progress(of category: QuestionCategory) -> String {
        categoryRow(category).value as? String ?? ""
    }

    var categoriesToggle: XCUIElement { app.descendants(matching: .any)[A11yID.Home.categoriesToggle] }

    var categoriesExpanded: Bool { categoriesToggle.value as? String == "Expanded" }

    /// Interview categories start folded below the courses. Every test that goes to a category
    /// scrolls to the toggle, unfolds the list and scrolls until the row is built (the list is lazy).
    func categoryRow(_ category: QuestionCategory) -> XCUIElement {
        let row = app.descendants(matching: .any)[A11yID.Home.categoryRow(category)]
        scroll(until: categoriesToggle)
        if categoriesToggle.exists, !categoriesExpanded { categoriesToggle.tap() }
        scroll(until: row)
        return row
    }

    /// Swipes the home list up until the element is on screen, a few times at most.
    func scroll(until element: XCUIElement, attempts: Int = 4) {
        for _ in 0..<attempts where !(element.exists && element.isHittable) {
            list.swipeUp()
        }
    }

    @discardableResult
    func waitUntilShown(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(list.waitForExistence(timeout: timeout), "Home screen did not appear", file: file, line: line)
        return self
    }
}
