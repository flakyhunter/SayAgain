import Foundation
import SayAgainKit
import SwiftUI
import UIKit

@main
struct SayAgainApp: App {
    private let environment: AppEnvironment

    init() {
        environment = AppEnvironment.make()
        if environment.isUITesting {
            UIView.setAnimationsEnabled(false)
        }
    }

    var body: some Scene {
        WindowGroup {
            HomeView(environment: environment)
        }
    }
}

/// Dependencies chosen once at launch. UI tests switch them with launch arguments.
@MainActor
struct AppEnvironment {
    let bank: QuestionBank
    let isUITesting: Bool
    let speech: SpeechService
    let store: ProgressStore
    let settings: AppSettings
    /// Checks the learner's own words. Nil when no Worker is configured for this build.
    let feedback: FeedbackService?
    /// Speech to text for the retelling. On the device only.
    let dictation: DictationService
    /// Fixed in UI-test mode, random otherwise.
    let makeSeed: () -> UInt64

    var animated: Bool { !isUITesting }

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        if arguments.contains(LaunchArgument.uiTesting) {
            let bank = arguments.contains(LaunchArgument.bundledContent)
                ? (try? QuestionBank.bundled()) ?? .fixture
                : .fixture
            let feedback: FeedbackService? = arguments.contains(LaunchArgument.liveFeedback)
                ? configuredFeedbackService()
                : ScriptedFeedbackService()
            let dictation: DictationService = arguments.contains(LaunchArgument.liveDictation)
                ? SystemDictationService()
                : ScriptedDictationService()
            return .testing(bank: bank, feedback: feedback, dictation: dictation)
        }
        return AppEnvironment(
            bank: (try? QuestionBank.bundled()) ?? QuestionBank(questions: []),
            isUITesting: false,
            speech: SystemSpeechService(),
            store: UserDefaultsProgressStore(),
            settings: AppSettings(defaults: .standard),
            feedback: configuredFeedbackService(),
            dictation: SystemDictationService(),
            makeSeed: { UInt64.random(in: .min ... .max) }
        )
    }

    /// Deterministic environment: fixture content, silent speech, fresh progress, fixed seed.
    static func testing(
        bank: QuestionBank = .fixture,
        speech: SpeechService = RecordingSpeechService(),
        feedback: FeedbackService? = ScriptedFeedbackService(),
        dictation: DictationService = ScriptedDictationService()
    ) -> AppEnvironment {
        AppEnvironment(
            bank: bank,
            isUITesting: true,
            speech: speech,
            store: InMemoryProgressStore(),
            settings: .ephemeral(),
            feedback: feedback,
            dictation: dictation,
            makeSeed: { LaunchArgument.uiTestingSeed }
        )
    }

    /// The Worker URL comes from the `FEEDBACK_ENDPOINT` build setting (see project.yml).
    static func configuredFeedbackService(info: [String: Any]? = Bundle.main.infoDictionary) -> FeedbackService? {
        guard let value = info?["SAFeedbackEndpoint"] as? String, !value.isEmpty,
              let url = URL(string: value), url.scheme != nil else { return nil }
        return RemoteFeedbackService(endpoint: url)
    }

    func makeSession(category: QuestionCategory?) -> SessionViewModel {
        SessionViewModel(
            session: .make(bank: bank, category: category, store: store, seed: makeSeed()),
            speech: speech,
            store: store,
            slow: settings.slowByDefault,
            category: category,
            bank: bank,
            animated: animated,
            feedback: feedback,
            settings: settings,
            dictation: dictation
        )
    }
}
