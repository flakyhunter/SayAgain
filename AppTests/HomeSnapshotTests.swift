import SayAgainKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import SayAgain

@MainActor
@Suite("Home screen snapshots")
struct HomeSnapshotTests {
    private func controller(
        bank: QuestionBank,
        style: UIUserInterfaceStyle = .light
    ) -> UIViewController {
        let controller = UIHostingController(rootView: HomeView(bank: bank))
        controller.overrideUserInterfaceStyle = style
        return controller
    }

    private var strategy: Snapshotting<UIViewController, UIImage> {
        .image(on: .iPhone13, precision: 0.99, perceptualPrecision: 0.98)
    }

    @Test func lightMode() {
        assertSnapshot(of: controller(bank: .fixture), as: strategy)
    }

    @Test func darkMode() {
        assertSnapshot(of: controller(bank: .fixture, style: .dark), as: strategy)
    }

    @Test func emptyState() {
        assertSnapshot(of: controller(bank: QuestionBank(questions: [])), as: strategy)
    }
}

@Suite("App environment")
struct AppEnvironmentTests {
    @Test func uiTestingArgumentSwitchesToFixture() {
        let environment = AppEnvironment.make(arguments: [LaunchArgument.uiTesting])
        #expect(environment.isUITesting)
        #expect(environment.bank.questions == QuestionBank.fixture.questions)
    }

    @Test func normalLaunchUsesBundledContent() throws {
        let environment = AppEnvironment.make(arguments: [])
        #expect(!environment.isUITesting)
        #expect(environment.bank.questions == (try QuestionBank.bundled()).questions)
    }
}
