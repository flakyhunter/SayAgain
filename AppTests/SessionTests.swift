import SayAgainKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import SayAgain

@MainActor
@Suite("Session view model")
struct SessionViewModelTests {
    let speech = RecordingSpeechService()
    let store = InMemoryProgressStore()

    private func model(category: QuestionCategory? = .behavioural) -> SessionViewModel {
        SessionViewModel(
            session: .make(bank: .fixture, category: category, store: store, seed: LaunchArgument.uiTestingSeed),
            speech: speech,
            store: store
        )
    }

    @Test func playSpeaksTheCurrentQuestionInItsLocale() throws {
        let model = model()
        let question = try #require(model.session.current)
        model.play()
        #expect(speech.utterances == [Utterance(text: question.text, locale: "en-AU", slow: false)])
        #expect(model.playCount == 1)
    }

    @Test func slowToggleIsPassedToSpeech() {
        let model = model()
        model.slow = true
        model.play()
        #expect(speech.utterances.last?.slow == true)
    }

    @Test func autoplayHappensOnlyOncePerQuestion() {
        let model = model()
        model.playIfNotPlayedYet()
        model.playIfNotPlayedYet()
        #expect(speech.utterances.count == 1)
    }

    @Test func ratingSavesLeitnerBoxStopsSpeechAndResetsPlayCount() throws {
        let model = model()
        let question = try #require(model.session.current)
        model.play()
        model.choose(question.gist)
        model.rate(.gotIt)

        #expect(store.box(for: question.id) == 2)
        #expect(speech.stopCount == 1)
        #expect(model.playCount == 0)
        #expect(model.session.position == 2)
    }

    @Test func wrongChoiceSendsQuestionBackToFirstBox() throws {
        store.setBox(4, for: "fixture-behavioural-1")
        store.setBox(4, for: "fixture-behavioural-2")
        let model = model()
        let question = try #require(model.session.current)
        model.choose(question.distractors[0])
        #expect(model.choiceCorrect == false)
        model.rate(.missed)
        #expect(store.box(for: question.id) == 1)
    }

    @Test func leavingStopsSpeech() {
        model().leave()
        #expect(speech.stopCount == 1)
    }
}

@MainActor
@Suite("Session snapshots")
struct SessionSnapshotTests {
    private func model() -> SessionViewModel {
        let store = InMemoryProgressStore()
        return SessionViewModel(
            session: .make(bank: .fixture, category: .behavioural, store: store, seed: LaunchArgument.uiTestingSeed),
            speech: RecordingSpeechService(),
            store: store
        )
    }

    private func screen(_ model: SessionViewModel) -> some View {
        SessionView(model: model, autoplay: false)
    }

    @Test func answering() {
        assertSnapshot(of: Snapshot.host(screen(model())), as: Snapshot.strategy)
    }

    @Test func revealedWrongAnswer() throws {
        let model = model()
        model.choose(try #require(model.session.current).distractors[0])
        assertSnapshot(of: Snapshot.host(screen(model)), as: Snapshot.strategy)
    }

    @Test func revealedCorrectAnswerDark() throws {
        let model = model()
        model.choose(try #require(model.session.current).gist)
        assertSnapshot(of: Snapshot.host(screen(model), style: .dark), as: Snapshot.strategy)
    }

    @Test func summary() {
        let view = SummaryView(summary: .init(gotIt: 5, partly: 3, missed: 2), onDone: {})
        assertSnapshot(of: Snapshot.host(view), as: Snapshot.strategy)
    }
}
