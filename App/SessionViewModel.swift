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
    @ObservationIgnored private let feedbackService: FeedbackService?
    @ObservationIgnored private let settings: AppSettings?
    @ObservationIgnored private let dictation: DictationService?
    /// What was typed before the microphone started; dictated words go after it.
    @ObservationIgnored private var textBeforeDictation = ""

    /// The microphone is on.
    private(set) var isDictating = false
    /// Shown under the text field when dictation could not start.
    private(set) var dictationError: DictationError?

    /// The retelling flow for the current question.
    enum RetellState: Equatable {
        case editing
        case checking
        case result(RetellingFeedback)
        case failed(FeedbackServiceError)
    }

    var retellText = ""
    private(set) var retellState = RetellState.editing
    /// Feedback the learner accepted for the current question, shown with the revealed text.
    private(set) var acceptedFeedback: RetellingFeedback?

    init(
        session: PracticeSession,
        speech: SpeechService,
        store: ProgressStore,
        slow: Bool = false,
        category: QuestionCategory? = nil,
        bank: QuestionBank = QuestionBank(questions: []),
        animated: Bool = false,
        feedback: FeedbackService? = nil,
        settings: AppSettings? = nil,
        dictation: DictationService? = nil
    ) {
        self.dictation = dictation
        self.feedbackService = feedback
        self.settings = settings
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

    /// Moves on. A right choice or retelling counts as understood, a wrong one comes back sooner.
    func next() {
        rate(session.suggestedRating ?? .missed)
    }

    // MARK: - Retelling with AI feedback

    /// "Say it in your own words" is offered: a Worker is configured, the category may use it,
    /// the learner did not turn it off, and the question is not answered yet.
    var canRetell: Bool {
        guard feedbackService != nil, settings?.aiFeedback != .declined,
              let question = session.current, Retelling.isAvailable(for: question.category) else { return false }
        return session.phase == .answering
    }

    /// The learner has not said yet whether their words may be sent.
    var needsConsent: Bool { settings?.aiFeedback == .notAsked }

    func setConsent(_ allowed: Bool) {
        settings?.aiFeedback = allowed ? .allowed : .declined
    }

    var canSubmitRetelling: Bool {
        Retelling.prepared(retellText) != nil && retellState != .checking && !isDictating
    }

    var canDictate: Bool { dictation != nil }

    /// Mic button: starts listening, or stops if already listening.
    func toggleDictation() async {
        guard let dictation else { return }
        if isDictating {
            dictation.stop()
            return
        }
        dictationError = nil
        speech.stop()   // don't record the interviewer's voice
        let locale = session.current?.locale ?? "en-AU"
        do {
            try await dictation.prepare(locale: locale)
            textBeforeDictation = retellText
            try dictation.start(locale: locale, onText: { [weak self] text in
                guard let self else { return }
                self.retellText = DictationText.combine(typed: self.textBeforeDictation, dictated: text)
            }, onEnd: { [weak self] in
                self?.isDictating = false
            })
            isDictating = true
        } catch {
            dictationError = error
        }
    }

    /// Turns the microphone off, for example when the sheet closes.
    func stopDictation() {
        if isDictating { dictation?.stop() }
    }

    func submitRetelling() async {
        stopDictation()
        guard let service = feedbackService, let question = session.current,
              let text = Retelling.prepared(retellText), settings?.aiFeedback != .declined else { return }
        retellState = .checking
        do {
            retellState = .result(try await service.check(questionID: question.id, retelling: text))
        } catch {
            retellState = .failed(error)
        }
    }

    /// Back to the text field after an error, keeping what the learner typed.
    func editRetellingAgain() {
        retellState = .editing
    }

    /// Reveals the question with the AI verdict counting as the answer.
    func acceptFeedback() {
        guard case let .result(feedback) = retellState else { return }
        acceptedFeedback = feedback
        session.retell(verdict: feedback.verdict)
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
        retellText = ""
        retellState = .editing
        acceptedFeedback = nil
        dictationError = nil
    }

    func leave() {
        stopDictation()
        speech.stop()
    }
}
