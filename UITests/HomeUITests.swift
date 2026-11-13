import SayAgainKit
import XCTest

@MainActor
final class HomeUITests: XCTestCase {
    /// Launches the app in deterministic UI-test mode: fixture content, no animations.
    private func launchApp() -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.uiTesting]
        app.launch()
        return app
    }

    func testHomeShowsFixtureCategoriesWithCounts() {
        let home = HomeScreen(app: launchApp()).waitUntilShown()

        XCTAssertTrue(home.header.exists)
        XCTAssertEqual(home.categoryRow(.intro).label, "Intro and background, 1 question")
        XCTAssertEqual(home.categoryRow(.behavioural).label, "Behavioural, 2 questions")
        XCTAssertFalse(home.categoryRow(.logistics).exists, "Fixture has no logistics questions")
    }
}
