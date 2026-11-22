import SayAgainKit
import XCTest

/// Produces the App Store screenshots of the volunteer trainer. Skipped in normal runs;
/// see scripts/screenshots.sh.
final class AppStoreScreenshots: SayAgainUITestCase {
    private func snap(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testCaptureScreenshots() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SAYAGAIN_SCREENSHOTS"] == "1",
                          "Run scripts/screenshots.sh to capture App Store screenshots")
        let course = try XCTUnwrap(try CourseLibrary.bundled().course(id: Course.careSkillsID))
        let lesson = course.lessons[0]
        let seed = LaunchArgument.uiTestingSeed

        let app = launchApp(extraArguments: [LaunchArgument.bundledContent])
        let screen = CourseScreen(app: app)
        HomeScreen(app: app).waitUntilShown()
        snap(app, "01-home")

        screen.careSkillsCard.tap()
        XCTAssertTrue(screen.list.waitForExistence(timeout: 5))
        snap(app, "02-lessons")

        screen.lessonRow(1).tap()
        XCTAssertTrue(screen.step.waitForExistence(timeout: 5))
        snap(app, "03-words")

        // Words, dialogue, then the key points.
        for _ in 0..<2 {
            XCTAssertTrue(screen.continueButton.waitForExistence(timeout: 5))
            screen.continueButton.tap()
        }
        XCTAssertTrue(screen.step.label.contains("Key points"))
        snap(app, "04-key-points")
        screen.continueButton.tap()

        // Practice: right answers, a picture of the first "What do you do?" task.
        var run = ExerciseRun(exercises: lesson.practice, seed: seed)
        var snappedScenario = false
        while let exercise = run.current {
            let index = try XCTUnwrap(run.choices.firstIndex(of: exercise.answer))
            XCTAssertTrue(screen.choice(index).waitForExistence(timeout: 5))
            screen.choice(index).tap()
            XCTAssertTrue(screen.explanation.waitForExistence(timeout: 5))
            if exercise.kind == .scenario, !snappedScenario {
                snap(app, "05-what-do-you-do")
                snappedScenario = true
            }
            run.choose(exercise.answer)
            run.next()
            screen.nextButton.tap()
        }
        XCTAssertTrue(snappedScenario, "The lesson has no scenario task in practice")

        screen.answer(lesson.check, seed: seed &+ 1, right: true)
        XCTAssertTrue(screen.result.waitForExistence(timeout: 5))
        snap(app, "06-lesson-passed")
    }
}
