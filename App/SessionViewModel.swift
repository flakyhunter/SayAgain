import Observation
import SayAgainKit

/// Glue between the pure `PracticeSession`, speech and saved progress.
@MainActor
@Observable
final class SessionViewModel {
    private(set) var session: PracticeSession
    /// How many times the current question has been played.
    private(set) var playCount = 0
    var slow = false

    /// The category being practised; nil for mixed practice.
    let category: QuestionCategory?
    /// Celebrations and confetti are off in tests and with Reduce Motion.
    let animated: Bool

    @ObservationIgnored private let speech: SpeechService
    @ObservationIgnored private let store: ProgressStore
    @ObservationIgnored private let bank: QuestionBank
    @ObservationIgnored private let masteredBefore: Bool

    init(
        session: PracticeSession,
        speech: SpeechService,
        store: ProgressStore,
        slow: Bool = false,
        category: QuestionCategory? = nil,
        bank: QuestionBank = QuestionBank(questions: []),
        animated: Bool = false
    ) {
        self.session = session
        self.slow = slow
        self.speech = speech
        self.store = store
        self.category = category
        self.bank = bank
        self.animated = animated
        masteredBefore = category.map { bank.isMastered($0, store: store) } ?? false
    }

    /// This session finished the category: every question in it is now understood.
    var justMastered: Bool {
        guard isFinished, let category, !masteredBefore else { return false }
        return bank.isMastered(category, store: store)
    }

    var categoryQuestionCount: Int {
        category.map { bank.questions(in: $0).count } ?? 0
    }

    /// Sends every question of this category back to the start.
    func startCategoryOver() {
        guard let category else { return }
        bank.resetProgress(in: category, store: store)
    }

    var isFinished: Bool { session.phase == .finished }

    var isRevealed: Bool {
        if case .revealed = session.phase { return true }
        return false
    }

    var choiceCorrect: Bool? {
        if case let .revealed(correct) = session.phase { return correct }
        return nil
    }

    /// Who asks the current question. Changes from question to question.
    var speaker: VoiceOption? {
        guard let question = session.current else { return nil }
        return VoiceRoster.voice(forTurn: session.index, from: speech.voices(for: question.locale))
    }

    /// True when the device has fewer than two voices, so every question sounds the same.
    var canGetMoreVoices: Bool {
        guard let question = session.current else { return false }
        return VoiceRoster.cast(from: speech.voices(for: question.locale)).count < 2
    }

    func play() {
        guard let question = session.current else { return }
        speech.speak(question.text, voice: speaker, locale: question.locale, slow: slow)
        playCount += 1
    }

    /// Switching speed replays the question right away, so the user hears the difference.
    func setSlow(_ isOn: Bool) {
        slow = isOn
        play()
    }

    /// Reads the sample answer for the current question with the same interviewer voice.
    func playSampleAnswer() {
        guard let question = session.current else { return }
        speech.speak(AnswerTemplate.spoken(question.sampleAnswer), voice: speaker, locale: question.locale, slow: slow)
    }

    /// Moves on. A right choice counts as understood, a wrong one comes back sooner.
    func next() {
        rate(choiceCorrect == true ? .gotIt : .missed)
    }

    /// Plays the question once when it first appears.
    func playIfNotPlayedYet() {
        if playCount == 0 { play() }
    }

    func choose(_ choice: String) {
        session.choose(choice)
    }

    func rate(_ rating: Rating) {
        guard let outcome = session.rate(rating) else { return }
        let current = store.box(for: outcome.questionID)
        store.setBox(LeitnerScheduler.nextBox(current: current, rating: outcome.rating), for: outcome.questionID)
        speech.stop()
        playCount = 0
    }

    func leave() {
        speech.stop()
    }
}
