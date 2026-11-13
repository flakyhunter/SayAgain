/// One practice run: listen, choose the meaning, see the answer, rate yourself, next.
/// A pure value type, so every rule is covered by fast unit tests.
public struct PracticeSession: Sendable {
    public enum Phase: Equatable, Sendable {
        case answering
        case revealed(choiceCorrect: Bool)
        case finished
    }

    public struct Outcome: Equatable, Sendable {
        public let questionID: String
        public let choiceCorrect: Bool
        public let rating: Rating
    }

    public struct Summary: Equatable, Sendable {
        public let gotIt: Int
        public let partly: Int
        public let missed: Int
        public var total: Int { gotIt + partly + missed }

        public init(gotIt: Int, partly: Int, missed: Int) {
            self.gotIt = gotIt
            self.partly = partly
            self.missed = missed
        }
    }

    public static let defaultLength = 10

    public let questions: [Question]
    public private(set) var index = 0
    public private(set) var choices: [String] = []
    public private(set) var selectedChoice: String?
    public private(set) var phase: Phase
    public private(set) var outcomes: [Outcome] = []
    private var generator: SeededGenerator

    public init(questions: [Question], seed: UInt64) {
        self.questions = questions
        generator = SeededGenerator(seed: seed)
        phase = questions.isEmpty ? .finished : .answering
        prepareChoices()
    }

    /// Builds a session: questions that need practice first, then a fixed length.
    public static func make(
        bank: QuestionBank,
        category: QuestionCategory?,
        store: ProgressStore,
        length: Int = defaultLength,
        seed: UInt64
    ) -> PracticeSession {
        let pool = category.map(bank.questions(in:)) ?? bank.questions
        var generator = SeededGenerator(seed: seed)
        let ordered = LeitnerScheduler.order(pool, box: { store.box(for: $0.id) }, using: &generator)
        return PracticeSession(questions: Array(ordered.prefix(length)), seed: generator.next())
    }

    public var current: Question? {
        phase == .finished ? nil : questions[index]
    }

    /// 1-based position for "Question 2 of 5".
    public var position: Int { min(index + 1, questions.count) }

    public var summary: Summary {
        Summary(
            gotIt: outcomes.count { $0.rating == .gotIt },
            partly: outcomes.count { $0.rating == .partly },
            missed: outcomes.count { $0.rating == .missed }
        )
    }

    /// Picks a meaning. Ignored unless the session waits for an answer.
    public mutating func choose(_ choice: String) {
        guard phase == .answering, let current, choices.contains(choice) else { return }
        selectedChoice = choice
        phase = .revealed(choiceCorrect: choice == current.gist)
    }

    /// Rates the revealed question and moves on. A wrong choice always counts as missed.
    @discardableResult
    public mutating func rate(_ rating: Rating) -> Outcome? {
        guard case let .revealed(choiceCorrect) = phase, let current else { return nil }
        let outcome = Outcome(
            questionID: current.id,
            choiceCorrect: choiceCorrect,
            rating: choiceCorrect ? rating : .missed
        )
        outcomes.append(outcome)
        index += 1
        selectedChoice = nil
        phase = index < questions.count ? .answering : .finished
        prepareChoices()
        return outcome
    }

    private mutating func prepareChoices() {
        guard let current else {
            choices = []
            return
        }
        choices = ([current.gist] + current.distractors).shuffled(using: &generator)
    }
}
