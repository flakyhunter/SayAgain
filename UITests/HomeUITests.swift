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

/// Tests of the interview practice, which the app hides by default. They launch with it switched on.
@MainActor
class InterviewPracticeUITestCase: SayAgainUITestCase {
    override func launchApp(extraArguments: [String] = []) -> XCUIApplication {
        super.launchApp(extraArguments: [LaunchArgument.interviewPractice] + extraArguments)
    }
}

final class HomeUITests: InterviewPracticeUITestCase {
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

        home.scroll(until: home.categoriesToggle)
        XCTAssertEqual(home.categoriesToggle.value as? String, "Collapsed")
        XCTAssertFalse(app(home).descendants(matching: .any)[introID].exists, "Folded at start")

        home.categoriesToggle.tap()
        waitForValue("Expanded", of: home.categoriesToggle)
        home.scroll(until: app(home).descendants(matching: .any)[introID])
        XCTAssertTrue(app(home).descendants(matching: .any)[introID].exists)
        home.scroll(until: home.categoriesToggle)

        home.categoriesToggle.tap()
        waitForValue("Collapsed", of: home.categoriesToggle)
        XCTAssertFalse(app(home).descendants(matching: .any)[introID].exists)
    }

    private func app(_ home: HomeScreen) -> XCUIApplication { home.app }

    private func waitForValue(_ value: String, of element: XCUIElement) {
        let changed = expectation(for: NSPredicate(format: "value == %@", value), evaluatedWith: element)
        wait(for: [changed], timeout: 5)
    }
}
