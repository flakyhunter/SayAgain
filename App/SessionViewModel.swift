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

    @ObservationIgnored private let speech: SpeechService
    @ObservationIgnored private let store: ProgressStore

    init(session: PracticeSession, speech: SpeechService, store: ProgressStore) {
        self.session = session
        self.speech = speech
        self.store = store
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

    func play() {
        guard let question = session.current else { return }
        speech.speak(question.text, locale: question.locale, slow: slow)
        playCount += 1
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
