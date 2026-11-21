import Foundation
import Observation
import SayAgainKit

/// One lesson, step by step: words, dialogue, tip, practice, check, result.
@MainActor
@Observable
final class LessonViewModel {
    let course: Course
    let lesson: Lesson
    let animated: Bool
    private let speech: SpeechService
    private let store: CourseProgressStore
    private let seed: UInt64

    private(set) var stepIndex = 0
    private(set) var practice: ExerciseRun
    private(set) var check: ExerciseRun
    /// Set once the check is finished and saved.
    private(set) var result: LessonResult?
    /// Exercise ids already read aloud, so going back to the screen does not replay them.
    @ObservationIgnored private var autoplayed = Set<String>()
    @ObservationIgnored private var attempts: UInt64 = 1

    init(course: Course, lesson: Lesson, speech: SpeechService, store: CourseProgressStore, seed: UInt64, animated: Bool) {
        self.course = course
        self.lesson = lesson
        self.speech = speech
        self.store = store
        self.seed = seed
        self.animated = animated
        practice = ExerciseRun(exercises: lesson.practice, seed: seed)
        check = ExerciseRun(exercises: lesson.check, seed: seed &+ 1)
    }

    var steps: [Lesson.Step] { lesson.steps }
    var step: Lesson.Step? { steps.indices.contains(stepIndex) ? steps[stepIndex] : nil }
    var nextLesson: Lesson? { course.lesson(after: lesson) }

    /// The exercise run of the current step, if the step has exercises.
    var run: ExerciseRun? {
        switch step {
        case .practice: practice
        case .check: check
        default: nil
        }
    }

    var isRevealed: Bool {
        if case .revealed = run?.phase { return true }
        return false
    }

    // MARK: Moving through the lesson

    /// "Continue" on words, dialogue and tip; also after the last practice exercise.
    func advance() {
        speech.stop()
        guard stepIndex < steps.count - 1 else { return }
        stepIndex += 1
    }

    func choose(_ choice: String) {
        switch step {
        case .practice: practice.choose(choice)
        case .check: check.choose(choice)
        default: return
        }
    }

    /// "Next" after an answer. The last practice exercise moves to the check; the last check shows the result.
    func next() {
        speech.stop()
        switch step {
        case .practice:
            practice.next()
            if practice.phase == .finished { advance() }
        case .check:
            check.next()
            if check.phase == .finished { finish() }
        default:
            return
        }
    }

    func retryCheck() {
        attempts += 1
        // A new order of answers each try, still deterministic for tests.
        check = ExerciseRun(exercises: lesson.check, seed: seed &+ attempts)
        autoplayed.subtract(lesson.check.map(\.id))
        result = nil
    }

    func leave() {
        speech.stop()
    }

    private func finish() {
        let score = check.scorePercent
        let wasPassed = course.isPassed(lesson, store: store)
        course.record(score: score, for: lesson, store: store)
        result = LessonResult(
            score: score,
            correct: check.correctCount,
            total: check.exercises.count,
            passed: score >= lesson.passPercent,
            passPercent: lesson.passPercent,
            unlockedNext: !wasPassed && course.isPassed(lesson, store: store) ? nextLesson : nil
        )
    }

    // MARK: Speech

    private var cast: [VoiceOption] { VoiceRoster.cast(from: speech.voices(for: course.locale)) }

    /// Residents, the volunteer and staff sound like different people whenever the device has the voices.
    func voice(for role: DialogueLine.Role) -> VoiceOption? {
        let turn = switch role {
        case .resident: 0
        case .volunteer: 1
        case .staff: 2
        }
        return VoiceRoster.voice(forTurn: turn, from: cast)
    }

    /// Older residents are read slower: it is easier to follow, and it is how many of them talk.
    private func isSlow(_ role: DialogueLine.Role) -> Bool { role == .resident }

    func play(word: VocabItem) {
        speech.speak(word.text, voice: voice(for: .resident), locale: course.locale, slow: false)
    }

    func play(line: DialogueLine) {
        speech.speak(line.text, voice: voice(for: line.role), locale: course.locale, slow: isSlow(line.role))
    }

    func playDialogue() {
        let lines = lesson.dialogue.map { SpokenLine(text: $0.text, voice: voice(for: $0.role), slow: isSlow($0.role)) }
        speech.speak(lines: lines, locale: course.locale)
    }

    func playExercise() {
        guard let say = run?.current?.say else { return }
        speech.speak(say, voice: voice(for: .resident), locale: course.locale, slow: false)
    }

    /// Plays the line of a new exercise once, when it appears.
    func autoplayExerciseIfNew() {
        guard let exercise = run?.current, exercise.say != nil, autoplayed.insert(exercise.id).inserted else { return }
        playExercise()
    }

    /// What the volunteer should say, read in the volunteer's voice. Only for English answers.
    func playAnswer() {
        guard let exercise = run?.current, exercise.kind != .listen else { return }
        speech.speak(exercise.answer, voice: voice(for: .volunteer), locale: course.locale, slow: false)
    }
}

struct LessonResult: Equatable {
    let score: Int
    let correct: Int
    let total: Int
    let passed: Bool
    let passPercent: Int
    /// The lesson this result opened for the first time, if any.
    let unlockedNext: Lesson?
}
