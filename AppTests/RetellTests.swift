import SayAgainKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import SayAgain

@MainActor
@Suite("Retelling with AI feedback")
struct RetellViewModelTests {
    let store = InMemoryProgressStore()
    let service = ScriptedFeedbackService()

    private func model(
        category: QuestionCategory = .behavioural,
        consent: AppSettings.AIFeedbackConsent = .allowed,
        feedback: FeedbackService?? = nil,
        bank: QuestionBank = .fixture
    ) -> SessionViewModel {
        let settings = AppSettings.ephemeral()
        settings.aiFeedback = consent
        return SessionViewModel(
            session: .make(bank: bank, category: category, store: store, seed: LaunchArgument.uiTestingSeed),
            speech: RecordingSpeechService(),
            store: store,
            category: category,
            bank: bank,
            feedback: feedback ?? service,
            settings: settings
        )
    }

    @Test func offeredOnlyBeforeAnswering() throws {
        let model = model()
        #expect(model.canRetell)
        model.choose(try #require(model.session.current).gist)
        #expect(!model.canRetell)
    }

    @Test func hiddenWithoutAConfiguredWorker() {
        #expect(!model(feedback: .some(nil)).canRetell)
    }

    @Test func hiddenAfterTheLearnerSaidNo() {
        #expect(!model(consent: .declined).canRetell)
    }

    @Test func kidsQuestionsNeverOfferIt() {
        let kids = QuestionBank(questions: [
            Question(id: "school-x", category: .school, text: "What's your name?", rephrase: "Your name?",
                     gist: "What is your name?", distractors: ["How old are you?", "Where do you live?"],
                     phrases: [], sampleAnswer: "My name is [name].")
        ])
        #expect(!model(category: .school, bank: kids).canRetell)
    }

    @Test func asksForConsentFirstAndRemembersTheAnswer() {
        let model = model(consent: .notAsked)
        #expect(model.needsConsent)
        #expect(model.canRetell, "The button is shown; the sheet asks before anything is sent")
        model.setConsent(true)
        #expect(!model.needsConsent)
    }

    @Test func nothingIsSentWithoutConsent() async {
        let model = model(consent: .declined)
        model.retellText = "my background"
        await model.submitRetelling()
        #expect(service.calls.isEmpty)
        #expect(model.retellState == .editing)
    }

    @Test(arguments: ["", "   ", String(repeating: "a", count: Retelling.maxLength + 1)])
    func blankOrTooLongCannotBeSent(text: String) async {
        let model = model()
        model.retellText = text
        #expect(!model.canSubmitRetelling)
        await model.submitRetelling()
        #expect(service.calls.isEmpty)
    }

    @Test func sendsTheTrimmedTextForTheCurrentQuestion() async throws {
        let model = model()
        let question = try #require(model.session.current)
        model.retellText = "  a hard bug I found \n"
        await model.submitRetelling()
        #expect(service.calls.map(\.questionID) == [question.id])
        #expect(service.calls.map(\.retelling) == ["a hard bug I found"])
        #expect(model.retellState == .result(RetellingFeedback(verdict: .understood, feedback: "Yes, that's what they asked.")))
    }

    @Test(arguments: [
        ("a hard bug", FeedbackVerdict.understood, 2),
        ("partly a bug", .partly, 1),
        ("missed it", .missed, 1)
    ])
    func acceptedVerdictDrivesRevealAndProgress(text: String, verdict: FeedbackVerdict, box: Int) async throws {
        let model = model()
        let question = try #require(model.session.current)
        model.retellText = text
        await model.submitRetelling()
        model.acceptFeedback()

        #expect(model.isRevealed)
        #expect(model.acceptedFeedback?.verdict == verdict)
        #expect(model.choiceCorrect == (verdict != .missed))
        model.next()
        #expect(store.box(for: question.id) == box)
        #expect(model.retellText.isEmpty && model.retellState == .editing && model.acceptedFeedback == nil,
                "The next question starts clean")
    }

    @Test func errorKeepsTheTextAndPracticeGoesOn() async throws {
        let model = model()
        model.retellText = "offline now"
        await model.submitRetelling()
        #expect(model.retellState == .failed(.offline))
        model.editRetellingAgain()
        #expect(model.retellText == "offline now")
        #expect(model.retellState == .editing)
        #expect(!model.isRevealed, "The learner can still pick a choice")
        model.choose(try #require(model.session.current).gist)
        #expect(model.isRevealed)
    }

    @Test func acceptWithoutAResultDoesNothing() {
        let model = model()
        model.acceptFeedback()
        #expect(!model.isRevealed)
    }
}

@MainActor
@Suite("Dictating the retelling")
struct DictationViewModelTests {
    let speech = RecordingSpeechService()
    let dictation = ScriptedDictationService(script: "and why I came here")

    private func model(dictation: DictationService? = nil) -> SessionViewModel {
        let store = InMemoryProgressStore()
        let settings = AppSettings.ephemeral()
        settings.aiFeedback = .allowed
        return SessionViewModel(
            session: .make(bank: .fixture, category: .behavioural, store: store, seed: LaunchArgument.uiTestingSeed),
            speech: speech, store: store, category: .behavioural, bank: .fixture,
            feedback: ScriptedFeedbackService(), settings: settings, dictation: dictation ?? self.dictation
        )
    }

    @Test func dictatedWordsGoAfterWhatWasTyped() async {
        let model = model()
        model.retellText = "My background"
        await model.toggleDictation()
        #expect(model.isDictating)
        #expect(model.retellText == "My background and why I came here")
    }

    @Test func micStopsTheInterviewerFirst() async {
        let model = model()
        model.play()
        await model.toggleDictation()
        #expect(speech.stopCount == 1, "The question voice must not be recorded")
    }

    @Test func secondTapStops() async {
        let model = model()
        await model.toggleDictation()
        await model.toggleDictation()
        #expect(!model.isDictating)
        #expect(!dictation.isListening)
        #expect(model.retellText == "and why I came here", "Text stays after stopping")
    }

    @Test func cannotSendWhileListening() async {
        let model = model()
        await model.toggleDictation()
        #expect(!model.canSubmitRetelling)
        await model.toggleDictation()
        #expect(model.canSubmitRetelling)
    }

    @Test func checkingStopsTheMicrophone() async {
        let model = model()
        await model.toggleDictation()
        await model.submitRetelling()
        #expect(!dictation.isListening)
    }

    @Test func leavingStopsTheMicrophone() async {
        let model = model()
        await model.toggleDictation()
        model.leave()
        #expect(!dictation.isListening)
        #expect(!model.isDictating)
    }

    @Test(arguments: [DictationError.denied, .unsupported, .failed])
    func failureShowsAMessageAndKeepsTyping(error: DictationError) async {
        let model = model(dictation: ScriptedDictationService(prepareError: error))
        model.retellText = "typed"
        await model.toggleDictation()
        #expect(!model.isDictating)
        #expect(model.dictationError == error)
        #expect(model.retellText == "typed")
        #expect(model.canSubmitRetelling)
    }

    @Test func noDictationServiceNoMicButton() {
        let store = InMemoryProgressStore()
        let model = SessionViewModel(session: .make(bank: .fixture, category: .behavioural, store: store, seed: 1),
                                     speech: speech, store: store)
        #expect(!model.canDictate)
    }
}

@MainActor
@Suite("Feedback configuration")
struct FeedbackConfigurationTests {
    @Test func usesTheEndpointFromInfoPlist() throws {
        let service = try #require(AppEnvironment.configuredFeedbackService(info: ["SAFeedbackEndpoint": "https://w.example.dev"]))
        #expect((service as? RemoteFeedbackService)?.endpoint.absoluteString == "https://w.example.dev")
    }

    @Test(arguments: [nil, "", "not a url", "$(FEEDBACK_ENDPOINT)"])
    func missingOrBrokenEndpointHidesTheFeature(value: String?) {
        let info: [String: Any] = value.map { ["SAFeedbackEndpoint": $0] } ?? [:]
        #expect(AppEnvironment.configuredFeedbackService(info: info) == nil)
    }

    @Test func consentIsNotAskedByDefaultAndPersists() throws {
        let name = "SayAgain.test.consent.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        #expect(AppSettings(defaults: defaults).aiFeedback == .notAsked)
        AppSettings(defaults: defaults).aiFeedback = .allowed
        #expect(AppSettings(defaults: defaults).aiFeedback == .allowed)
        defaults.removePersistentDomain(forName: name)
    }
}

@MainActor
@Suite("Retelling snapshots")
struct RetellSnapshotTests {
    private func model(consent: AppSettings.AIFeedbackConsent = .allowed) -> SessionViewModel {
        let store = InMemoryProgressStore()
        let settings = AppSettings.ephemeral()
        settings.aiFeedback = consent
        return SessionViewModel(
            session: .make(bank: .fixture, category: .behavioural, store: store, seed: LaunchArgument.uiTestingSeed),
            speech: RecordingSpeechService(), store: store, category: .behavioural, bank: .fixture,
            feedback: ScriptedFeedbackService(), settings: settings
        )
    }

    @Test func listening() async {
        let model = SessionViewModel(
            session: .make(bank: .fixture, category: .behavioural, store: InMemoryProgressStore(), seed: LaunchArgument.uiTestingSeed),
            speech: RecordingSpeechService(), store: InMemoryProgressStore(), category: .behavioural, bank: .fixture,
            feedback: ScriptedFeedbackService(), settings: {
                let settings = AppSettings.ephemeral()
                settings.aiFeedback = .allowed
                return settings
            }(), dictation: ScriptedDictationService(script: "They want to know about a tricky bug I found")
        )
        await model.toggleDictation()
        assertSnapshot(of: Snapshot.host(RetellView(model: model) {}), as: Snapshot.strategy)
    }

    @Test func consent() {
        assertSnapshot(of: Snapshot.host(RetellView(model: model(consent: .notAsked)) {}), as: Snapshot.strategy)
    }

    @Test func partlyResult() async {
        let model = model()
        model.retellText = "partly: a bug I found"
        await model.submitRetelling()
        assertSnapshot(of: Snapshot.host(RetellView(model: model) {}), as: Snapshot.strategy)
    }

    @Test func missedResultDark() async {
        let model = model()
        model.retellText = "missed something about bugs"
        await model.submitRetelling()
        assertSnapshot(of: Snapshot.host(RetellView(model: model) {}, style: .dark), as: Snapshot.strategy)
    }

    @Test func answeringWithRetellButton() {
        assertSnapshot(of: Snapshot.host(SessionView(model: model(), autoplay: false)), as: Snapshot.strategy)
    }

    @Test func revealedWithAIFeedback() async {
        let model = model()
        model.retellText = "partly a bug"
        await model.submitRetelling()
        model.acceptFeedback()
        assertSnapshot(of: Snapshot.host(SessionView(model: model, autoplay: false)), as: Snapshot.strategy)
    }
}
