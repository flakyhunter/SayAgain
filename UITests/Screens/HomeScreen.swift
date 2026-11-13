import SayAgainKit
import XCTest

/// Page object for the home screen. Tests talk to screens, never to raw queries.
struct HomeScreen {
    let app: XCUIApplication

    var list: XCUIElement { app.descendants(matching: .any)[A11yID.Home.list] }
    var header: XCUIElement { app.descendants(matching: .any)[A11yID.Home.header] }

    func categoryRow(_ category: QuestionCategory) -> XCUIElement {
        app.descendants(matching: .any)[A11yID.Home.categoryRow(category)]
    }

    @discardableResult
    func waitUntilShown(timeout: TimeInterval = 10, file: StaticString = #filePath, line: UInt = #line) -> Self {
        XCTAssertTrue(list.waitForExistence(timeout: timeout), "Home screen did not appear", file: file, line: line)
        return self
    }
}
