import SayAgainKit
import XCTest

@MainActor
class SayAgainUITestCase: XCTestCase {
    /// Launches the app in deterministic UI-test mode: fixture content, silent speech,
    /// fresh progress, fixed seed, no animations.
    func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = [LaunchArgument.uiTesting] + extraArguments
        app.launch()
        return app
    }
}

final class HomeUITests: SayAgainUITestCase {
    func testHomeShowsFixtureCategoriesWithCounts() {
        let home = HomeScreen(app: launchApp()).waitUntilShown()

        XCTAssertTrue(home.header.exists)
        XCTAssertTrue(home.startButton.exists)
        XCTAssertEqual(home.categoryRow(.intro).label, "Intro and background, 1 question")
        XCTAssertEqual(home.categoryRow(.behavioural).label, "Behavioural, 2 questions")
        XCTAssertFalse(home.categoryRow(.logistics).exists, "Fixture has no logistics questions")
    }
}
