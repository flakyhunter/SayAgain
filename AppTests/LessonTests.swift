import SayAgainKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import SayAgain

@MainActor
@Suite("Lesson view model")
struct LessonViewModelTests {
    let speech = RecordingSpeechService()
    let store = InMemoryCourseProgressStore()
    let course = CourseLibrary.fixture.courses[0]

    private func model(lesson: Int = 0) -> LessonViewModel {
        LessonViewModel(
            course: course, lesson: course.lessons[lesson], speech: speech, store: store,
            seed: LaunchArgument.uiTestingSeed, animated: false
        )
    }

    /// Answers every exercise of the current step (and only that step), right or wrong.
    private func answerAll(_ model: LessonViewModel, right: Bool) {
        let step = model.step
        while model.step == step, let run = model.run, let exercise = run.current {
            let pick = right ? exercise.answer : exercise.distractors[0]
            model.choose(pick)
            model.next()
        }
    }

    @Test func goesThroughStepsInOrder() {
        let model = model()
        #expect(model.step == .words)
        model.advance()
        #expect(model.step == .dialogue)
        model.advance()
        #expect(model.step == .tip)
        model.advance()
        #expect(model.step == .practice)
        answerAll(model, right: false)
        #expect(model.step == .check, "Practice mistakes never block the check")
    }

    @Test func passingTheCheckSavesTheScoreAndOpensTheNextLesson() {
        let model = model()
        for _ in 0..<3 { model.advance() }
        answerAll(model, right: true)
        answerAll(model, right: true)
        #expect(model.result?.passed == true)
        #expect(model.result?.score == 100)
        #expect(model.result?.unlockedNext?.number == 2)
        #expect(course.isUnlocked(course.lessons[1], store: store))
    }

    @Test func failingTheCheckKeepsTheNextLessonLockedAndAllowsARetry() {
        let model = model()
        for _ in 0..<3 { model.advance() }
        answerAll(model, right: true)
        answerAll(model, right: false)
        #expect(model.result?.passed == false)
        #expect(!course.isUnlocked(course.lessons[1], store: store))

        model.retryCheck()
        #expect(model.result == nil)
        #expect(model.step == .check)
        #expect(model.run?.index == 0)
    }

    @Test func passingAgainDoesNotAnnounceAnUnlockTwice() {
        store.setBestScore(100, for: course.lessons[0].id)
        let model = model()
        for _ in 0..<3 { model.advance() }
        answerAll(model, right: true)
        answerAll(model, right: true)
        #expect(model.result?.passed == true)
        #expect(model.result?.unlockedNext == nil)
    }

    @Test func dialogueRolesGetDifferentVoicesAndResidentsAreSlower() {
        let model = model()
        model.playDialogue()
        #expect(speech.utterances.map(\.voiceName) == ["Lee", "Karen"])
        #expect(speech.utterances.map(\.slow) == [false, true])
    }

    @Test func exerciseLineIsAutoplayedOnlyOnce() {
        let model = model()
        for _ in 0..<3 { model.advance() }
        model.autoplayExerciseIfNew()
        model.autoplayExerciseIfNew()
        #expect(speech.utterances.map(\.text) == ["Pardon, love?"])
    }

    @Test func russianMeaningIsNeverReadAloud() {
        let model = model()
        for _ in 0..<3 { model.advance() }
        model.choose(course.lessons[0].practice[0].answer)
        model.playAnswer()
        #expect(speech.utterances.isEmpty, "A listen answer is Russian; the English voice must not read it")
    }

    @Test func scenarioAnswerIsNeverReadAloud() {
        let care = CourseLibrary.fixture.courses[1]
        let model = LessonViewModel(
            course: care, lesson: care.lessons[0], speech: speech, store: store,
            seed: LaunchArgument.uiTestingSeed, animated: false
        )
        for _ in 0..<3 { model.advance() }
        #expect(model.run?.current?.kind == .scenario)
        model.choose(care.lessons[0].practice[0].answer)
        model.playAnswer()
        #expect(speech.utterances.isEmpty, "A scenario answer is an action in Russian")
    }

    @Test func tipStepIsNamedByTheCourse() {
        #expect(LessonView.stepText(.tip, index: 2, count: 5, run: nil) == "Step 3 of 5: Grammar")
        #expect(LessonView.stepText(.tip, index: 2, count: 5, run: nil, tipLabel: "Key points") == "Step 3 of 5: Key points")
    }

    @Test func stepTextShowsTheExercisePosition() {
        let model = model()
        for _ in 0..<3 { model.advance() }
        #expect(LessonView.stepText(model.step, index: model.stepIndex, count: model.steps.count, run: model.run)
            == "Step 4 of 5: Practice, 1 of 1")
    }
}

@MainActor
@Suite("Course snapshots")
struct CourseSnapshotTests {
    @Test func lessonList() {
        let environment = AppEnvironment.testing()
        let course = environment.courses.courses[0]
        course.record(score: 50, for: course.lessons[0], store: environment.courseStore)
        let view = NavigationStack { CourseView(environment: environment, course: course) }
        assertSnapshot(of: Snapshot.host(view), as: Snapshot.strategy)
    }

    @Test func careSkillsListShowsCredits() {
        let environment = AppEnvironment.testing()
        let view = NavigationStack { CourseView(environment: environment, course: environment.courses.courses[1]) }
        assertSnapshot(of: Snapshot.host(view), as: Snapshot.strategy)
    }

    @Test func scenarioExerciseRevealedInDarkMode() {
        let environment = AppEnvironment.testing()
        let care = environment.courses.courses[1]
        let model = environment.makeLesson(care.lessons[0], in: care)
        for _ in 0..<3 { model.advance() }
        model.choose(care.lessons[0].practice[0].distractors[0])
        let view = NavigationStack { LessonView(model: model) }
        assertSnapshot(of: Snapshot.host(view, style: .dark), as: Snapshot.strategy)
    }

    @Test("Russian help under the task, every choice and the explanation")
    func scenarioExerciseWithRussian() {
        let environment = AppEnvironment.testing()
        environment.settings.showRussian = true
        let care = environment.courses.courses[1]
        let model = environment.makeLesson(care.lessons[0], in: care)
        for _ in 0..<3 { model.advance() }
        model.choose(care.lessons[0].practice[0].answer)
        let view = NavigationStack { LessonView(model: model) }
            .environment(\.showRussian, environment.settings.showRussian)
        assertSnapshot(of: Snapshot.host(view), as: Snapshot.strategy)
    }

    @Test func wordsStep() throws {
        let environment = AppEnvironment.testing(courses: try CourseLibrary.bundled())
        let course = environment.courses.courses[0]
        let view = NavigationStack { LessonView(model: environment.makeLesson(course.lessons[0], in: course)) }
        assertSnapshot(of: Snapshot.host(view), as: Snapshot.strategy)
    }
}
