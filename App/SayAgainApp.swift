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
    /// Step-by-step courses shown above the categories.
    let courses: CourseLibrary
    let courseStore: CourseProgressStore
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
    /// Interview categories, mixed practice and the phrasebook. Hidden while the app is a volunteer trainer.
    var interviewPractice = false

    /// Release builds ship as a volunteer trainer. Flip to bring the interview practice back.
    static let interviewPracticeInRelease = false

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
            let courses = arguments.contains(LaunchArgument.bundledContent)
                ? (try? CourseLibrary.bundled()) ?? .fixture
                : .fixture
            return .testing(
                bank: bank, courses: courses, feedback: feedback, dictation: dictation,
                interviewPractice: arguments.contains(LaunchArgument.interviewPractice)
            )
        }
        return AppEnvironment(
            bank: (try? QuestionBank.bundled()) ?? QuestionBank(questions: []),
            courses: (try? CourseLibrary.bundled()) ?? CourseLibrary(courses: []),
            courseStore: UserDefaultsCourseProgressStore(),
            isUITesting: false,
            speech: SystemSpeechService(),
            store: UserDefaultsProgressStore(),
            settings: AppSettings(defaults: .standard),
            feedback: configuredFeedbackService(),
            dictation: SystemDictationService(),
            makeSeed: { UInt64.random(in: .min ... .max) },
            interviewPractice: interviewPracticeInRelease
        )
    }

    /// Deterministic environment: fixture content, silent speech, fresh progress, fixed seed.
    static func testing(
        bank: QuestionBank = .fixture,
        courses: CourseLibrary = .fixture,
        speech: SpeechService = RecordingSpeechService(),
        feedback: FeedbackService? = ScriptedFeedbackService(),
        dictation: DictationService = ScriptedDictationService(),
        interviewPractice: Bool = false
    ) -> AppEnvironment {
        AppEnvironment(
            bank: bank,
            courses: courses,
            courseStore: InMemoryCourseProgressStore(),
            isUITesting: true,
            speech: speech,
            store: InMemoryProgressStore(),
            settings: .ephemeral(),
            feedback: feedback,
            dictation: dictation,
            makeSeed: { LaunchArgument.uiTestingSeed },
            interviewPractice: interviewPractice
        )
    }

    /// The Worker URL comes from the `FEEDBACK_ENDPOINT` build setting (see project.yml).
    static func configuredFeedbackService(info: [String: Any]? = Bundle.main.infoDictionary) -> FeedbackService? {
        guard let value = info?["SAFeedbackEndpoint"] as? String, !value.isEmpty,
              let url = URL(string: value), url.scheme != nil else { return nil }
        return RemoteFeedbackService(endpoint: url)
    }

    func makeLesson(_ lesson: Lesson, in course: Course) -> LessonViewModel {
        LessonViewModel(
            course: course, lesson: lesson, speech: speech, store: courseStore,
            seed: makeSeed(), animated: animated
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
            animated: animated,
            feedback: feedback,
            settings: settings,
            dictation: dictation
        )
    }
}
