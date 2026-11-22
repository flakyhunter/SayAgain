import Foundation
import Testing
@testable import SayAgainKit

// MARK: - Helpers

private func exercise(
    id: String = "e1",
    kind: Exercise.Kind = .listen,
    say: String? = "Pardon, love?",
    answer: String = "Right",
    distractors: [String] = ["Wrong 1", "Wrong 2"]
) -> Exercise {
    Exercise(
        id: id, kind: kind, say: say, situation: "A resident speaks.", situationRu: "Житель говорит.",
        answer: answer, answerRu: "Ответ", distractors: distractors,
        distractorsRu: distractors.map { "Перевод \($0)" },
        explanation: "Why.", explanationRu: "Почему."
    )
}

private func lesson(
    number: Int,
    practice: [Exercise]? = nil,
    check: [Exercise]? = nil,
    passPercent: Int = 80,
    words: [VocabItem] = [VocabItem(text: "G'day", translationRu: "Привет")]
) -> Lesson {
    Lesson(
        id: "l\(number)", number: number, title: "Lesson \(number)", titleRu: "Урок \(number)",
        goal: "Goal", goalRu: "Цель", words: words,
        dialogue: [DialogueLine(role: .resident, speaker: "Mrs Brown", text: "Hello, dear.", translationRu: "Здравствуй, дорогая.")],
        tip: nil,
        practice: practice ?? [exercise(id: "l\(number)-p1")],
        check: check ?? [exercise(id: "l\(number)-c1")],
        passPercent: passPercent
    )
}

private func course(_ lessons: [Lesson]) -> Course {
    Course(id: "c", title: "Course", subtitle: "Sub", titleRu: "Курс", locale: "en-AU", lessons: lessons)
}

// MARK: - Shipped content

@Suite("Shipped courses")
struct ShippedCourseTests {
    @Test("Bundled courses decode and pass every content rule")
    func bundledCoursesAreValid() throws {
        let library = try CourseLibrary.bundled()
        #expect(!library.courses.isEmpty)
        #expect(library.validate() == [])
    }

    @Test("The aged care volunteer course starts with lesson 1")
    func agedCareCourseExists() throws {
        let course = try #require(try CourseLibrary.bundled().course(id: Course.agedCareVolunteerID))
        #expect(course.lessons.first?.number == 1)
    }

    @Test("Block 1 has nine lessons and the safety lesson needs every answer right")
    func blockOneShape() throws {
        let course = try #require(try CourseLibrary.bundled().course(id: Course.agedCareVolunteerID))
        #expect(course.lessons.map(\.number) == Array(1...9))
        #expect(course.lessons.first { $0.title == "Safety first" }?.passPercent == 100)
        #expect(course.lessons.last?.check.count ?? 0 >= 10, "The block test is longer than a lesson check")
    }

    @Test("Every lesson has words, a dialogue, practice and a check")
    func everyLessonIsComplete() throws {
        for course in try CourseLibrary.bundled().courses {
            for lesson in course.lessons {
                #expect(lesson.words.count >= 8, "\(lesson.id) has \(lesson.words.count) words")
                #expect(lesson.dialogue.count >= 4, "\(lesson.id) dialogue is too short")
                #expect(lesson.practice.count >= 4, "\(lesson.id) practice is too short")
                #expect(lesson.check.count >= 4, "\(lesson.id) check is too short")
            }
        }
    }

    @Test("Every lesson practises the volunteer rule at least once")
    func volunteerRuleInEveryLesson() throws {
        for course in try CourseLibrary.bundled().courses {
            for lesson in course.lessons {
                let answers = (lesson.practice + lesson.check).map(\.answer)
                #expect(answers.contains { $0.contains("not allowed") }, "\(lesson.id) skips the volunteer rule")
            }
        }
    }

    @Test("The courses read as one series")
    func courseTitles() throws {
        let library = try CourseLibrary.bundled()
        #expect(library.courses.map(\.id) == [Course.agedCareVolunteerID, Course.careSkillsID, Course.dementiaID])
        #expect(library.courses.map(\.title) == [
            "Aged care volunteer: English", "Aged care volunteer: Care skills", "Aged care volunteer: Dementia"
        ])
    }

    @Test("Dementia: five lessons with key points and scenarios, a long final test")
    func dementiaShape() throws {
        let course = try #require(try CourseLibrary.bundled().course(id: Course.dementiaID))
        #expect(course.lessons.map(\.number) == Array(1...5))
        #expect(course.tipLabel == "Key points")
        for lesson in course.lessons {
            #expect((lesson.practice + lesson.check).count { $0.kind == .scenario } >= 2, "\(lesson.id)")
            #expect(lesson.tip != nil, "\(lesson.id) has no key points")
        }
        #expect(course.lessons.last?.check.count ?? 0 >= 10)
    }

    @Test("Care skills: six lessons, a scenario in each, a long final test, strict boundaries lesson")
    func careSkillsShape() throws {
        let course = try #require(try CourseLibrary.bundled().course(id: Course.careSkillsID))
        #expect(course.lessons.map(\.number) == Array(1...6))
        #expect(course.tipLabel == "Key points")
        for lesson in course.lessons {
            let scenarios = (lesson.practice + lesson.check).filter { $0.kind == .scenario }
            #expect(scenarios.count >= 2, "\(lesson.id) needs \"what do you do\" tasks")
            #expect(lesson.tip != nil, "\(lesson.id) has no key points")
        }
        #expect(course.lessons.first { $0.title.hasPrefix("Boundaries") }?.passPercent == 100)
        #expect(course.lessons.last?.check.count ?? 0 >= 10)
    }

    @Test("Material under CC BY is credited as the licence asks")
    func careSkillsCredits() throws {
        let course = try #require(try CourseLibrary.bundled().course(id: Course.careSkillsID))
        let credits = try #require(course.credits)
        #expect(credits.contains("Aged Care Quality and Safety Commission"))
        #expect(credits.contains("CC BY 4.0"))
    }

    @Test("Aussie slang appears from the first lesson")
    func slangFromLessonOne() throws {
        let course = try #require(try CourseLibrary.bundled().course(id: Course.agedCareVolunteerID))
        #expect(course.lessons[0].words.contains { $0.aussie })
    }

    @Test("Fixture course used by UI tests is valid")
    func fixtureIsValid() {
        #expect(CourseLibrary.fixture.validate() == [])
    }
}

// MARK: - Validation

@Suite("Course validation rules")
struct CourseValidationTests {
    @Test func validCourseHasNoIssues() {
        #expect(CourseLibrary(courses: [course([lesson(number: 1), lesson(number: 2)])]).validate() == [])
    }

    @Test func duplicateExerciseIDsAcrossLessons() {
        let first = lesson(number: 1, check: [exercise(id: "same")])
        let second = lesson(number: 2, check: [exercise(id: "same")])
        #expect(CourseLibrary(courses: [course([first, second])]).validate() == [.duplicateID("same")])
    }

    @Test func lessonsMustBeNumberedInOrder() {
        let issues = CourseLibrary(courses: [course([lesson(number: 1), lesson(number: 3)])]).validate()
        #expect(issues == [.lessonNumberGap(courseID: "c", expected: 2, found: 3)])
    }

    @Test(arguments: [0, 1, 3])
    func wrongDistractorCount(count: Int) {
        let bad = exercise(id: "x", distractors: (0..<count).map { "D\($0)" })
        let issues = CourseLibrary(courses: [course([lesson(number: 1, check: [bad])])]).validate()
        #expect(issues == [.wrongDistractorCount(id: "x", count: count)])
    }

    @Test func distractorEqualToAnswerIgnoringCase() {
        let bad = exercise(id: "x", answer: "Same", distractors: ["same", "Other"])
        let issues = CourseLibrary(courses: [course([lesson(number: 1, check: [bad])])]).validate()
        #expect(issues == [.distractorMatchesAnswer(id: "x")])
    }

    @Test func listenExerciseNeedsSomethingToSay() {
        let bad = exercise(id: "x", kind: .listen, say: nil)
        let issues = CourseLibrary(courses: [course([lesson(number: 1, check: [bad])])]).validate()
        #expect(issues == [.emptyField(id: "x", field: "say")])
    }

    @Test("A scenario reads the situation; a line to hear is optional")
    func scenarioNeedsNoVoice() {
        let silent = exercise(id: "x", kind: .scenario, say: nil)
        let heard = exercise(id: "y", kind: .scenario, say: "I keep having bad dreams.")
        #expect(CourseLibrary(courses: [course([lesson(number: 1, check: [silent, heard])])]).validate() == [])
    }

    @Test("Only spoken English answers can be played back")
    func whichKindsNeedVoiceAndHaveEnglishAnswers() {
        #expect(Exercise.Kind.allCases.filter(\.needsVoice) == [.listen, .slang])
        #expect(Exercise.Kind.allCases.filter(\.answerIsEnglish) == [.reply, .slang])
    }

    @Test("Tip label defaults to Grammar and can be set per course")
    func tipLabelDecoding() throws {
        let plain = #"[{"id":"a","title":"A","subtitle":"S","titleRu":"А","locale":"en-AU","lessons":[]}]"#
        let custom = #"[{"id":"b","title":"B","subtitle":"S","titleRu":"Б","locale":"en-AU","lessons":[],"tipLabel":"Key points","credits":"Source"}]"#
        let a = try CourseLibrary.decode(Data(plain.utf8)).courses[0]
        let b = try CourseLibrary.decode(Data(custom.utf8)).courses[0]
        #expect(a.tipLabel == "Grammar")
        #expect(a.credits == nil)
        #expect(b.tipLabel == "Key points")
        #expect(b.credits == "Source")
    }

    @Test("Choices are English; Russian lives only in the translation fields")
    func russianInAnEnglishChoice() {
        let bad = exercise(id: "x", answer: "Она просит повторить")
        let issues = CourseLibrary(courses: [course([lesson(number: 1, check: [bad])])]).validate()
        #expect(issues == [.russianInEnglishField(id: "x", field: "answer")])
    }

    @Test func everyDistractorHasATranslation() {
        let good = exercise(id: "x")
        let bad = Exercise(
            id: "x", kind: good.kind, say: good.say, situation: good.situation, situationRu: good.situationRu,
            answer: good.answer, answerRu: good.answerRu, distractors: good.distractors, distractorsRu: ["Один"],
            explanation: good.explanation, explanationRu: good.explanationRu
        )
        let issues = CourseLibrary(courses: [course([lesson(number: 1, check: [bad])])]).validate()
        #expect(issues == [.missingTranslation(id: "x", field: "distractorsRu")])
    }

    @Test func eachChoiceKnowsItsRussian() {
        let e = exercise(answer: "Right", distractors: ["Wrong 1", "Wrong 2"])
        #expect(e.translationRu(of: "Right") == "Ответ")
        #expect(e.translationRu(of: "Wrong 2") == "Перевод Wrong 2")
        #expect(e.translationRu(of: "Something else") == nil)
    }

    @Test func lessonWithoutCheck() {
        let issues = CourseLibrary(courses: [course([lesson(number: 1, check: [])])]).validate()
        #expect(issues == [.emptyField(id: "l1", field: "check")])
    }

    @Test(arguments: ["\u{2014}", "\u{0451}"])
    func forbiddenCharacters(character: String) {
        let words = [VocabItem(text: "G'day", translationRu: "Привет \(character)")]
        let issues = CourseLibrary(courses: [course([lesson(number: 1, words: words)])]).validate()
        #expect(issues == [.forbiddenCharacter(id: "l1", character: character)])
    }

    @Test("Real organisations and people never appear", arguments: ["MercyCare", "Julia", "Caitlin"])
    func bannedNames(name: String) {
        let words = [VocabItem(text: "Hi, I'm \(name).", translationRu: "Привет")]
        let issues = CourseLibrary(courses: [course([lesson(number: 1, words: words)])]).validate()
        #expect(issues == [.bannedName(id: "l1", name: name)])
    }

    @Test("Content is not tied to one city or its football teams", arguments: ["Perth", "Eagles", "Dockers"])
    func cityNames(name: String) {
        let words = [VocabItem(text: "Go \(name)!", translationRu: "Вперед")]
        let issues = CourseLibrary(courses: [course([lesson(number: 1, words: words)])]).validate()
        #expect(issues == [.bannedName(id: "l1", name: name)])
    }

    @Test func passPercentOutOfRange() {
        let issues = CourseLibrary(courses: [course([lesson(number: 1, passPercent: 120)])]).validate()
        #expect(issues == [.invalidPassPercent(id: "l1", value: 120)])
    }
}

// MARK: - Steps

@Suite("Lesson steps")
struct LessonStepTests {
    @Test func fullLessonGoesWordsDialogueTipPracticeCheck() {
        var full = lesson(number: 1)
        full = Lesson(
            id: full.id, number: 1, title: full.title, titleRu: full.titleRu, goal: full.goal, goalRu: full.goalRu,
            words: full.words, dialogue: full.dialogue,
            tip: GrammarTip(title: "to be", rule: "Rule", ruleRu: "Правило", examples: ["I am a volunteer."]),
            practice: full.practice, check: full.check, passPercent: 80
        )
        #expect(full.steps == [.words, .dialogue, .tip, .practice, .check])
    }

    @Test func emptyPartsAreSkipped() {
        #expect(lesson(number: 1).steps == [.words, .dialogue, .practice, .check])
        #expect(lesson(number: 1, practice: [], words: []).steps == [.dialogue, .check])
    }
}

// MARK: - Exercise run

@Suite("Exercise run")
struct ExerciseRunTests {
    private let exercises = [
        exercise(id: "a", answer: "A", distractors: ["a1", "a2"]),
        exercise(id: "b", answer: "B", distractors: ["b1", "b2"])
    ]

    @Test func choicesAreAnswerPlusDistractorsInSeededOrder() {
        let first = ExerciseRun(exercises: exercises, seed: 7)
        let again = ExerciseRun(exercises: exercises, seed: 7)
        #expect(Set(first.choices) == ["A", "a1", "a2"])
        #expect(first.choices == again.choices)
    }

    @Test func rightAndWrongAnswersAreCounted() {
        var run = ExerciseRun(exercises: exercises, seed: 1)
        run.choose("A")
        #expect(run.phase == .revealed(correct: true))
        run.next()
        run.choose("b1")
        #expect(run.phase == .revealed(correct: false))
        run.next()
        #expect(run.phase == .finished)
        #expect(run.correctCount == 1)
        #expect(run.scorePercent == 50)
    }

    @Test func secondChoiceAfterRevealIsIgnored() {
        var run = ExerciseRun(exercises: exercises, seed: 1)
        run.choose("a1")
        run.choose("A")
        #expect(run.selected == "a1")
        #expect(run.phase == .revealed(correct: false))
    }

    @Test func unknownChoiceIsIgnored() {
        var run = ExerciseRun(exercises: exercises, seed: 1)
        run.choose("Not a choice")
        #expect(run.phase == .answering)
    }

    @Test func nextBeforeAnsweringDoesNothing() {
        var run = ExerciseRun(exercises: exercises, seed: 1)
        run.next()
        #expect(run.index == 0)
    }

    @Test func emptyRunIsFinishedWithZeroScore() {
        let run = ExerciseRun(exercises: [], seed: 1)
        #expect(run.phase == .finished)
        #expect(run.scorePercent == 0)
    }

    @Test func scoreRoundsDown() {
        var run = ExerciseRun(exercises: exercises + [exercise(id: "c", answer: "C", distractors: ["c1", "c2"])], seed: 3)
        for answer in ["A", "B", "c1"] {
            run.choose(answer)
            run.next()
        }
        #expect(run.scorePercent == 66)
    }
}

// MARK: - Progress and unlocking

@Suite("Course progress")
struct CourseProgressTests {
    private let threeLessons = course([lesson(number: 1), lesson(number: 2), lesson(number: 3, passPercent: 100)])

    @Test func onlyFirstLessonIsOpenAtStart() {
        let store = InMemoryCourseProgressStore()
        #expect(threeLessons.lessons.map { threeLessons.isUnlocked($0, store: store) } == [true, false, false])
    }

    @Test func passingALessonOpensTheNextOne() {
        let store = InMemoryCourseProgressStore()
        threeLessons.record(score: 80, for: threeLessons.lessons[0], store: store)
        #expect(threeLessons.isUnlocked(threeLessons.lessons[1], store: store))
        #expect(!threeLessons.isUnlocked(threeLessons.lessons[2], store: store))
        #expect(threeLessons.passedCount(store: store) == 1)
    }

    @Test func scoreBelowThresholdDoesNotPass() {
        let store = InMemoryCourseProgressStore()
        threeLessons.record(score: 79, for: threeLessons.lessons[0], store: store)
        #expect(!threeLessons.isPassed(threeLessons.lessons[0], store: store))
        #expect(!threeLessons.isUnlocked(threeLessons.lessons[1], store: store))
    }

    @Test("A safety lesson needs every answer right")
    func strictLessonNeedsFullScore() {
        let store = InMemoryCourseProgressStore()
        threeLessons.record(score: 95, for: threeLessons.lessons[2], store: store)
        #expect(!threeLessons.isPassed(threeLessons.lessons[2], store: store))
        threeLessons.record(score: 100, for: threeLessons.lessons[2], store: store)
        #expect(threeLessons.isPassed(threeLessons.lessons[2], store: store))
    }

    @Test func aWorseRetryKeepsTheBestScore() {
        let store = InMemoryCourseProgressStore()
        threeLessons.record(score: 90, for: threeLessons.lessons[0], store: store)
        threeLessons.record(score: 40, for: threeLessons.lessons[0], store: store)
        #expect(store.bestScore(for: "l1") == 90)
    }

    @Test func nextLessonAfterTheLastIsNil() {
        #expect(threeLessons.lesson(after: threeLessons.lessons[0])?.number == 2)
        #expect(threeLessons.lesson(after: threeLessons.lessons[2]) == nil)
    }

    @Test func resetClosesEverythingAgain() {
        let store = InMemoryCourseProgressStore()
        threeLessons.record(score: 100, for: threeLessons.lessons[0], store: store)
        threeLessons.resetProgress(store: store)
        #expect(threeLessons.passedCount(store: store) == 0)
        #expect(!threeLessons.isUnlocked(threeLessons.lessons[1], store: store))
    }

    @Test func userDefaultsStoreSurvivesANewInstance() throws {
        let name = "CourseProgressTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        UserDefaultsCourseProgressStore(defaults: defaults).setBestScore(70, for: "l1")
        #expect(UserDefaultsCourseProgressStore(defaults: defaults).bestScore(for: "l1") == 70)
    }
}
