import SayAgainKit
import XCTest

/// Page object for the course list and a lesson.
@MainActor
struct CourseScreen {
    let app: XCUIApplication

    private func element(_ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    var card: XCUIElement { element(A11yID.Course.card) }
    var list: XCUIElement { element(A11yID.Course.list) }
    var step: XCUIElement { element(A11yID.Lesson.step) }
    var continueButton: XCUIElement { app.buttons[A11yID.Lesson.continueButton] }
    var nextButton: XCUIElement { app.buttons[A11yID.Lesson.nextButton] }
    var explanation: XCUIElement { element(A11yID.Lesson.explanation) }
    var result: XCUIElement { element(A11yID.Lesson.result) }
    var retryButton: XCUIElement { app.buttons[A11yID.Lesson.retryButton] }
    var nextLessonButton: XCUIElement { app.buttons[A11yID.Lesson.nextLessonButton] }
    var doneButton: XCUIElement { app.buttons[A11yID.Lesson.doneButton] }

    func lessonRow(_ number: Int) -> XCUIElement { element(A11yID.Course.lessonRow(number)) }
    func choice(_ index: Int) -> XCUIElement { app.buttons[A11yID.Lesson.choice(index)] }

    /// Answers a run of exercises. The order of choices comes from the same seed the app uses.
    func answer(_ exercises: [Exercise], seed: UInt64, right: Bool) {
        var run = ExerciseRun(exercises: exercises, seed: seed)
        while let exercise = run.current {
            let pick = right ? exercise.answer : exercise.distractors[0]
            let index = run.choices.firstIndex(of: pick)!
            XCTAssertTrue(choice(index).waitForExistence(timeout: 5))
            choice(index).tap()
            XCTAssertTrue(explanation.waitForExistence(timeout: 5))
            run.choose(pick)
            run.next()
            nextButton.tap()
        }
    }
}

final class CourseUITests: SayAgainUITestCase {
    private let course = CourseLibrary.fixture.courses[0]
    private let seed = LaunchArgument.uiTestingSeed

    func testOnlyTheFirstLessonIsOpenAtStart() {
        let app = launchApp()
        let screen = CourseScreen(app: app)
        HomeScreen(app: app).waitUntilShown()

        screen.card.tap()
        XCTAssertTrue(screen.list.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.lessonRow(1).value as? String, "Not started")
        XCTAssertEqual(screen.lessonRow(2).value as? String, "Locked")
    }

    func testPassingLessonOneOpensLessonTwo() {
        let app = launchApp()
        let screen = CourseScreen(app: app)
        HomeScreen(app: app).waitUntilShown()
        screen.card.tap()
        screen.lessonRow(1).tap()

        // Words, dialogue, grammar tip.
        for _ in 0..<3 {
            XCTAssertTrue(screen.continueButton.waitForExistence(timeout: 5))
            screen.continueButton.tap()
        }
        let lesson = course.lessons[0]
        screen.answer(lesson.practice, seed: seed, right: false)
        screen.answer(lesson.check, seed: seed &+ 1, right: true)

        XCTAssertTrue(screen.result.waitForExistence(timeout: 5))
        XCTAssertTrue(screen.result.label.contains("Lesson 1 passed"))
        screen.doneButton.tap()

        XCTAssertTrue(screen.list.waitForExistence(timeout: 5))
        XCTAssertEqual(screen.lessonRow(1).value as? String, "Passed")
        XCTAssertEqual(screen.lessonRow(2).value as? String, "Not started")
    }

    func testFailedCheckOffersARetryAndKeepsLessonTwoLocked() {
        let app = launchApp()
        let screen = CourseScreen(app: app)
        HomeScreen(app: app).waitUntilShown()
        screen.card.tap()
        screen.lessonRow(1).tap()
        for _ in 0..<3 {
            XCTAssertTrue(screen.continueButton.waitForExistence(timeout: 5))
            screen.continueButton.tap()
        }
        let lesson = course.lessons[0]
        screen.answer(lesson.practice, seed: seed, right: true)
        screen.answer(lesson.check, seed: seed &+ 1, right: false)

        XCTAssertTrue(screen.retryButton.waitForExistence(timeout: 5))
        XCTAssertFalse(screen.nextLessonButton.exists)
        screen.retryButton.tap()
        // The retry uses the next seed, so the answers come in a new order.
        screen.answer(lesson.check, seed: seed &+ 2, right: true)
        XCTAssertTrue(screen.nextLessonButton.waitForExistence(timeout: 5))
        screen.nextLessonButton.tap()
        XCTAssertTrue(screen.step.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Lesson 2"].waitForExistence(timeout: 5))
    }
}
