/// Going through a list of exercises: choose, see why, next. Used for practice and for the check.
/// A pure value type, so every rule is covered by fast unit tests.
public struct ExerciseRun: Sendable {
    public enum Phase: Equatable, Sendable {
        case answering
        case revealed(correct: Bool)
        case finished
    }

    public let exercises: [Exercise]
    public private(set) var index = 0
    public private(set) var choices: [String] = []
    public private(set) var selected: String?
    public private(set) var phase: Phase
    public private(set) var correctCount = 0
    private var generator: SeededGenerator

    public init(exercises: [Exercise], seed: UInt64) {
        self.exercises = exercises
        generator = SeededGenerator(seed: seed)
        phase = exercises.isEmpty ? .finished : .answering
        prepareChoices()
    }

    public var current: Exercise? {
        phase == .finished ? nil : exercises[index]
    }

    /// 1-based position for "2 of 5".
    public var position: Int { min(index + 1, exercises.count) }

    /// Share of right answers, rounded down. 0 for an empty run.
    public var scorePercent: Int {
        exercises.isEmpty ? 0 : correctCount * 100 / exercises.count
    }

    public mutating func choose(_ choice: String) {
        guard phase == .answering, let current, choices.contains(choice) else { return }
        selected = choice
        let correct = choice == current.answer
        if correct { correctCount += 1 }
        phase = .revealed(correct: correct)
    }

    public mutating func next() {
        guard case .revealed = phase else { return }
        index += 1
        selected = nil
        phase = index < exercises.count ? .answering : .finished
        prepareChoices()
    }

    private mutating func prepareChoices() {
        guard let current else {
            choices = []
            return
        }
        choices = ([current.answer] + current.distractors).shuffled(using: &generator)
    }
}
