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

    func testInterviewCategoriesUnfoldOnTapAndFoldBack() {
        let home = HomeScreen(app: launchApp()).waitUntilShown()
        let introID = A11yID.Home.categoryRow(.intro)

        XCTAssertEqual(home.categoriesToggle.value as? String, "Collapsed")
        XCTAssertFalse(app(home).descendants(matching: .any)[introID].exists, "Folded at start")

        home.categoriesToggle.tap()
        XCTAssertEqual(home.categoriesToggle.value as? String, "Expanded")
        XCTAssertTrue(app(home).descendants(matching: .any)[introID].waitForExistence(timeout: 5))

        home.categoriesToggle.tap()
        XCTAssertEqual(home.categoriesToggle.value as? String, "Collapsed")
        XCTAssertFalse(app(home).descendants(matching: .any)[introID].exists)
    }

    private func app(_ home: HomeScreen) -> XCUIApplication { home.app }
}
