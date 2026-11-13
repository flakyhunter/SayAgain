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
    /// Fixed in UI-test mode, random otherwise.
    let makeSeed: () -> UInt64

    var animated: Bool { !isUITesting }

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        if arguments.contains(LaunchArgument.uiTesting) {
            let bank = arguments.contains(LaunchArgument.bundledContent)
                ? (try? QuestionBank.bundled()) ?? .fixture
                : .fixture
            return .testing(bank: bank)
        }
        return AppEnvironment(
            bank: (try? QuestionBank.bundled()) ?? QuestionBank(questions: []),
            isUITesting: false,
            speech: SystemSpeechService(),
            store: UserDefaultsProgressStore(),
            settings: AppSettings(defaults: .standard),
            makeSeed: { UInt64.random(in: .min ... .max) }
        )
    }

    /// Deterministic environment: fixture content, silent speech, fresh progress, fixed seed.
    static func testing(
        bank: QuestionBank = .fixture,
        speech: SpeechService = RecordingSpeechService()
    ) -> AppEnvironment {
        AppEnvironment(
            bank: bank,
            isUITesting: true,
            speech: speech,
            store: InMemoryProgressStore(),
            settings: .ephemeral(),
            makeSeed: { LaunchArgument.uiTestingSeed }
        )
    }

    func makeSession(category: QuestionCategory?) -> SessionViewModel {
        SessionViewModel(
            session: .make(bank: bank, category: category, store: store, seed: makeSeed()),
            speech: speech,
            store: store,
            slow: settings.slowByDefault,
            category: category,
            bank: bank,
            animated: animated
        )
    }
}
