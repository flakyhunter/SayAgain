import SayAgainKit
import XCTest

final class ReorderUITests: SayAgainUITestCase {
    private func isAbove(_ first: XCUIElement, _ second: XCUIElement) -> Bool {
        first.frame.midY < second.frame.midY
    }

    func testDraggingACardChangesTheOrderAndSettingsCanResetIt() {
        let app = launchApp()
        let home = HomeScreen(app: app).waitUntilShown()
        let intro = home.categoryRow(.intro)
        let behavioural = home.categoryRow(.behavioural)
        XCTAssertTrue(isAbove(intro, behavioural), "Default order: intro before behavioural")

        // Hold the card, then drag it onto the one above.
        behavioural.press(forDuration: 1.0, thenDragTo: intro)
        let moved = NSPredicate { _, _ in behavioural.frame.midY < intro.frame.midY }
        wait(for: [expectation(for: moved, evaluatedWith: nil)], timeout: 5)

        home.settingsButton.tap()
        let settings = SettingsScreen(app: app).waitUntilShown()
        settings.resetOrderButton.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(home.startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(isAbove(intro, behavioural), "Reset brings back the default order")
    }
}
