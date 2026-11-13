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
        let environment = AppEnvironment.testing()
        environment.store.setBox(3, for: "fixture-behavioural-1")
        environment.store.setBox(2, for: "fixture-intro-1")
        assertSnapshot(of: Snapshot.host(HomeView(environment: environment)), as: Snapshot.strategy)
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
        assertSnapshot(of: Snapshot.host(grid), as: .image(precision: 0.99, perceptualPrecision: 0.98, size: CGSize(width: 640, height: 640)))
    }

    @Test func emptyState() {
        let environment = AppEnvironment.testing(bank: QuestionBank(questions: []))
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
    }

    @Test func normalLaunchUsesBundledContentAndRealServices() throws {
        let environment = AppEnvironment.make(arguments: [])
        #expect(!environment.isUITesting)
        #expect(environment.bank.questions == (try QuestionBank.bundled()).questions)
        #expect(environment.speech is SystemSpeechService)
        #expect(environment.store is UserDefaultsProgressStore)
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
