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
            HomeView(bank: environment.bank, animated: !environment.isUITesting)
        }
    }
}

/// Dependencies chosen once at launch. UI tests switch them with launch arguments.
struct AppEnvironment {
    let bank: QuestionBank
    let isUITesting: Bool

    static func make(arguments: [String] = ProcessInfo.processInfo.arguments) -> AppEnvironment {
        if arguments.contains(LaunchArgument.uiTesting) {
            return AppEnvironment(bank: .fixture, isUITesting: true)
        }
        let bank = (try? QuestionBank.bundled()) ?? QuestionBank(questions: [])
        return AppEnvironment(bank: bank, isUITesting: false)
    }
}
