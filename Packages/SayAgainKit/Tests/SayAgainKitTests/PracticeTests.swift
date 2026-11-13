import Foundation
import Testing
@testable import SayAgainKit

@Suite("Leitner scheduler")
struct LeitnerTests {
    @Test(arguments: [
        (1, Rating.gotIt, 2), (4, .gotIt, 5), (5, .gotIt, 5),
        (3, .partly, 3), (1, .partly, 1),
        (5, .missed, 1), (1, .missed, 1),
        (0, .gotIt, 2), (9, .partly, 5)
    ])
    func nextBox(current: Int, rating: Rating, expected: Int) {
        #expect(LeitnerScheduler.nextBox(current: current, rating: rating) == expected)
    }

    @Test func lowerBoxesComeFirst() {
        let questions = QuestionBank.fixture.questions
        let boxes = ["fixture-intro-1": 4, "fixture-behavioural-1": 1, "fixture-behavioural-2": 2]
        var generator = SeededGenerator(seed: 1)
        let ordered = LeitnerScheduler.order(questions, box: { boxes[$0.id]! }, using: &generator)
        #expect(ordered.map(\.id) == ["fixture-behavioural-1", "fixture-behavioural-2", "fixture-intro-1"])
    }

    @Test func sameSeedSameOrder() {
        let questions = try! QuestionBank.bundled().questions
        var first = SeededGenerator(seed: 7)
        var second = SeededGenerator(seed: 7)
        let a = LeitnerScheduler.order(questions, box: { _ in 1 }, using: &first)
        let b = LeitnerScheduler.order(questions, box: { _ in 1 }, using: &second)
        #expect(a == b)
    }
}

@Suite("Progress stores")
struct ProgressStoreTests {
    @Test func inMemoryDefaultsToFirstBox() {
        let store = InMemoryProgressStore()
        #expect(store.box(for: "unknown") == LeitnerScheduler.firstBox)
        store.setBox(3, for: "q")
        #expect(store.box(for: "q") == 3)
        store.reset()
        #expect(store.box(for: "q") == LeitnerScheduler.firstBox)
    }

    @Test func userDefaultsPersistsBetweenInstances() throws {
        let suite = "SayAgainKitTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        UserDefaultsProgressStore(defaults: defaults).setBox(4, for: "q")
        let reopened = UserDefaultsProgressStore(defaults: defaults)
        #expect(reopened.box(for: "q") == 4)
        reopened.reset()
        #expect(UserDefaultsProgressStore(defaults: defaults).box(for: "q") == LeitnerScheduler.firstBox)
    }
}

@Suite("Learned count")
struct LearnedCountTests {
    @Test func countsQuestionsAboveTheFirstBoxPerCategory() {
        let store = InMemoryProgressStore(boxes: ["fixture-behavioural-1": 2, "fixture-behavioural-2": 1, "fixture-intro-1": 5])
        #expect(QuestionBank.fixture.learnedCount(in: .behavioural, store: store) == 1)
        #expect(QuestionBank.fixture.learnedCount(in: .intro, store: store) == 1)
        #expect(QuestionBank.fixture.learnedCount(in: .school, store: store) == 0)
    }

    @Test func missingAgainUnlearnsTheQuestion() {
        let store = InMemoryProgressStore(boxes: ["fixture-intro-1": 3])
        store.setBox(LeitnerScheduler.nextBox(current: 3, rating: .missed), for: "fixture-intro-1")
        #expect(QuestionBank.fixture.learnedCount(in: .intro, store: store) == 0)
    }
}

@Suite("Practice session")
struct PracticeSessionTests {
    private func session(seed: UInt64 = 42) -> PracticeSession {
        PracticeSession(questions: QuestionBank.fixture.questions, seed: seed)
    }

    @Test func startsAnsweringWithThreeShuffledChoices() throws {
        let session = session()
        let current = try #require(session.current)
        #expect(session.phase == .answering)
        #expect(session.position == 1)
        #expect(Set(session.choices) == Set([current.gist] + current.distractors))
    }

    @Test func rightAnswerPositionVariesAcrossSeeds() {
        let positions = Set((0..<20).map { seed in
            let s = session(seed: UInt64(seed))
            return s.choices.firstIndex(of: s.current!.gist)!
        })
        #expect(positions.count > 1, "The right answer must not always be in the same place")
    }

    @Test func correctChoiceThenRatingMovesOn() throws {
        var session = session()
        let first = try #require(session.current)
        session.choose(first.gist)
        #expect(session.phase == .revealed(choiceCorrect: true))

        let outcome = session.rate(.partly)
        #expect(outcome == .init(questionID: first.id, choiceCorrect: true, rating: .partly))
        #expect(session.position == 2)
        #expect(session.phase == .answering)
        #expect(session.selectedChoice == nil)
    }

    @Test func wrongChoiceAlwaysCountsAsMissed() throws {
        var session = session()
        let first = try #require(session.current)
        session.choose(first.distractors[0])
        #expect(session.phase == .revealed(choiceCorrect: false))
        #expect(session.rate(.gotIt)?.rating == .missed)
    }

    @Test func ignoresActionsInTheWrongPhase() throws {
        var session = session()
        #expect(session.rate(.gotIt) == nil, "Cannot rate before choosing")

        let first = try #require(session.current)
        session.choose(first.gist)
        session.choose(first.distractors[0])
        #expect(session.selectedChoice == first.gist, "Second choice is ignored")

        session.choose("Not one of the choices")
        #expect(session.phase == .revealed(choiceCorrect: true))
    }

    @Test func finishesWithSummary() {
        var session = session()
        let ratings: [Rating] = [.gotIt, .partly, .missed]
        for (step, rating) in ratings.enumerated() {
            let current = session.current!
            session.choose(step == 2 ? current.distractors[1] : current.gist)
            session.rate(rating)
        }
        #expect(session.phase == .finished)
        #expect(session.current == nil)
        #expect(session.summary == .init(gotIt: 1, partly: 1, missed: 1))
        #expect(session.position == 3)
    }

    @Test func emptySessionIsFinishedRightAway() {
        let session = PracticeSession(questions: [], seed: 1)
        #expect(session.phase == .finished)
        #expect(session.choices.isEmpty)
        #expect(session.summary.total == 0)
    }

    @Test func makeFiltersByCategoryAndLimitsLength() throws {
        let bank = try QuestionBank.bundled()
        let session = PracticeSession.make(
            bank: bank, category: .behavioural, store: InMemoryProgressStore(), length: 2, seed: 3
        )
        #expect(session.questions.count == 2)
        #expect(session.questions.allSatisfy { $0.category == .behavioural })
    }

    @Test func makePutsWeakQuestionsFirst() {
        let store = InMemoryProgressStore(boxes: ["fixture-intro-1": 5, "fixture-behavioural-1": 5])
        let session = PracticeSession.make(bank: .fixture, category: nil, store: store, seed: 9)
        #expect(session.questions.first?.id == "fixture-behavioural-2")
    }
}

@MainActor
@Suite("Recording speech")
struct RecordingSpeechTests {
    @Test func recordsUtterancesAndStops() {
        let speech = RecordingSpeechService()
        speech.speak("G'day", voice: RecordingSpeechService.defaultVoices[1], locale: "en-AU", slow: true)
        speech.stop()
        #expect(speech.utterances == [Utterance(text: "G'day", voiceName: "Lee", locale: "en-AU", slow: true)])
        #expect(speech.stopCount == 1)
    }
}

@Suite("Voice roster")
struct VoiceRosterTests {
    private let karen = VoiceOption(id: "k1", name: "Karen", quality: 1)
    private let karenPremium = VoiceOption(id: "k3", name: "Karen", quality: 3)
    private let lee = VoiceOption(id: "l3", name: "Lee", quality: 3)
    private let matilda = VoiceOption(id: "m2", name: "Matilda", quality: 2)

    @Test func castKeepsBestQualityPerPersonSortedByName() {
        #expect(VoiceRoster.cast(from: [matilda, karen, lee, karenPremium]) == [karenPremium, lee, matilda])
    }

    @Test func neighbouringTurnsGetDifferentVoices() {
        let voices = [karen, lee, matilda]
        let names = (0..<6).compactMap { VoiceRoster.voice(forTurn: $0, from: voices)?.name }
        #expect(names == ["Karen", "Lee", "Matilda", "Karen", "Lee", "Matilda"])
    }

    @Test func singleVoiceIsUsedForEveryTurn() {
        #expect(VoiceRoster.voice(forTurn: 5, from: [karen]) == karen)
    }

    @Test func noVoicesMeansSystemDefault() {
        #expect(VoiceRoster.voice(forTurn: 0, from: []) == nil)
    }
}

@Suite("Slow mode phrases")
struct SpeechChunkerTests {
    @Test func splitsAtCommasQuestionMarksAndSentenceEnds() {
        let text = "Righto, last one from me. If a developer pushes back, how do you handle that?"
        #expect(SpeechChunker.chunks(text) == [
            "Righto,", "last one from me.", "If a developer pushes back,", "how do you handle that?"
        ])
    }

    @Test func keepsAbbreviationsWhole() {
        let text = "Have you had a crack at testing anything A.I. driven, like L.L.M. features?"
        #expect(SpeechChunker.chunks(text) == [
            "Have you had a crack at testing anything A.I. driven,", "like L.L.M. features?"
        ])
    }

    @Test func textWithoutPunctuationIsOneChunk() {
        #expect(SpeechChunker.chunks("G'day mate") == ["G'day mate"])
    }

    @Test func everyQuestionIsSplitIntoNonEmptyChunksThatRejoinToTheOriginal() throws {
        for question in try QuestionBank.bundled().questions {
            let chunks = SpeechChunker.chunks(question.text)
            #expect(chunks.allSatisfy { !$0.isEmpty })
            #expect(chunks.joined(separator: " ") == question.text, "\(question.id)")
        }
    }
}
