import SayAgainKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import SayAgain

@MainActor
enum Snapshot {
    static let strategy: Snapshotting<UIViewController, UIImage> =
        .image(on: .iPhone13, precision: 0.99, perceptualPrecision: 0.98)

    static func host(_ view: some View, style: UIUserInterfaceStyle = .light) -> UIViewController {
        let controller = UIHostingController(rootView: view)
        controller.overrideUserInterfaceStyle = style
        return controller
    }
}

@MainActor
@Suite("Home screen snapshots")
struct HomeSnapshotTests {
    @Test func lightMode() {
        assertSnapshot(of: Snapshot.host(HomeView(environment: .testing())), as: Snapshot.strategy)
    }

    @Test func darkMode() {
        assertSnapshot(of: Snapshot.host(HomeView(environment: .testing()), style: .dark), as: Snapshot.strategy)
    }

    @Test func withProgress() {
        let environment = AppEnvironment.testing(interviewPractice: true)
        environment.settings.categoriesExpanded = true
        environment.store.setBox(3, for: "fixture-behavioural-1")
        environment.store.setBox(2, for: "fixture-intro-1")
        assertSnapshot(of: Snapshot.host(HomeView(environment: environment)), as: Snapshot.strategy)
    }

    @Test func categoriesExpandedInDarkMode() {
        let environment = AppEnvironment.testing(interviewPractice: true)
        environment.settings.categoriesExpanded = true
        assertSnapshot(of: Snapshot.host(HomeView(environment: environment), style: .dark), as: Snapshot.strategy)
    }

    @Test func interviewHomeKeepsTheOldHero() {
        let environment = AppEnvironment.testing(interviewPractice: true)
        assertSnapshot(of: Snapshot.host(HomeView(environment: environment)), as: Snapshot.strategy)
    }

    @Test("Start opens the first course with a lesson still to pass")
    func startPicksTheFirstUnfinishedCourse() {
        let environment = AppEnvironment.testing()
        let courses = environment.courses.courses
        #expect(HomeView.courseToStart(courses, store: environment.courseStore)?.id == courses[0].id)
        for lesson in courses[0].lessons { courses[0].record(score: 100, for: lesson, store: environment.courseStore) }
        #expect(HomeView.courseToStart(courses, store: environment.courseStore)?.id == courses[1].id)
        for lesson in courses[1].lessons { courses[1].record(score: 100, for: lesson, store: environment.courseStore) }
        #expect(HomeView.courseToStart(courses, store: environment.courseStore)?.id == courses[0].id, "All done: back to the first")
    }

    @Test func heroPhrasesComeFromTheLessons() {
        let environment = AppEnvironment.testing()
        let phrases = HomeView.volunteerPhrases(environment.courses)
        #expect(!phrases.isEmpty)
        let words = Set(environment.courses.courses.flatMap { $0.lessons.flatMap { $0.words.map(\.text) } })
        #expect(phrases.allSatisfy(words.contains))
    }

    @Test func allCategoryIcons() {
        let grid = HStack(spacing: 0) {
            ForEach([ColorScheme.light, .dark], id: \.self) { scheme in
                VStack(spacing: 18) {
                    ForEach(QuestionCategory.allCases, id: \.self) { category in
                        HStack(spacing: 14) {
                            CategoryIcon(category: category)
                            Text(category.title).font(.headline)
                            Spacer()
                        }
                    }
                }
                .padding(24)
                .background(Color(.systemGroupedBackground))
                .environment(\.colorScheme, scheme)
            }
        }
        .frame(width: 640)
        // Photo icons are downscaled by the system, and iOS versions resample them a little
        // differently (local 26.1 vs CI 26.5: 0.17% of pixels differ by more than deltaE 20).
        // perceptualPrecision 0.8 absorbs that noise; precision 0.995 still fails if a single
        // icon (0.77% of the image) is missing or wrong.
        assertSnapshot(of: Snapshot.host(grid), as: .image(precision: 0.995, perceptualPrecision: 0.8, size: CGSize(width: 640, height: 640)))
    }

    @Test func emptyState() {
        let environment = AppEnvironment.testing(bank: QuestionBank(questions: []), interviewPractice: true)
        assertSnapshot(of: Snapshot.host(HomeView(environment: environment)), as: Snapshot.strategy)
    }
}

@MainActor
@Suite("App environment")
struct AppEnvironmentTests {
    @Test func uiTestingArgumentSwitchesToDeterministicMode() {
        let environment = AppEnvironment.make(arguments: [LaunchArgument.uiTesting])
        #expect(environment.isUITesting)
        #expect(!environment.animated)
        #expect(environment.bank.questions == QuestionBank.fixture.questions)
        #expect(environment.speech is RecordingSpeechService)
        #expect(environment.store is InMemoryProgressStore)
        #expect(environment.makeSeed() == LaunchArgument.uiTestingSeed)
        #expect(!environment.interviewPractice, "Tests see the volunteer app unless they ask for interviews")
        #expect(AppEnvironment.make(arguments: [LaunchArgument.uiTesting, LaunchArgument.interviewPractice]).interviewPractice)
    }

    @Test func normalLaunchUsesBundledContentAndRealServices() throws {
        let environment = AppEnvironment.make(arguments: [])
        #expect(!environment.isUITesting)
        #expect(environment.bank.questions == (try QuestionBank.bundled()).questions)
        #expect(environment.speech is SystemSpeechService)
        #expect(environment.store is UserDefaultsProgressStore)
        #expect(!environment.interviewPractice, "The app ships as a volunteer trainer")
    }
}

@Suite("App bundle")
struct AppBundleTests {
    /// Regression: the icon set once lost its Contents.json and the app shipped without an icon.
    @Test func appIconIsCompiledIntoTheBundle() throws {
        let icons = try #require(Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any])
        let primary = try #require(icons["CFBundlePrimaryIcon"] as? [String: Any])
        #expect(primary["CFBundleIconName"] as? String == "AppIcon")
        #expect(Bundle.main.url(forResource: "Assets", withExtension: "car") != nil)
    }

    @Test func displayNameAndVersionComeFromBuildSettings() {
        let info = Bundle.main.infoDictionary ?? [:]
        #expect(info["CFBundleDisplayName"] as? String == "Say Again")
        #expect((info["CFBundleShortVersionString"] as? String)?.isEmpty == false)
    }
}
