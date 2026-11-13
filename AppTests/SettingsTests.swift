import SayAgainKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import SayAgain

@MainActor
@Suite("Settings")
struct SettingsTests {
    @Test func slowByDefaultPersistsBetweenLaunches() throws {
        let name = "SettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        AppSettings(defaults: defaults).slowByDefault = true
        #expect(AppSettings(defaults: defaults).slowByDefault)
    }

    @Test func categoryOrderPersistsAndResets() throws {
        let name = "SettingsTests.order.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }

        #expect(AppSettings(defaults: defaults).categoryOrder == CategoryOrder.default)
        let settings = AppSettings(defaults: defaults)
        settings.categoryOrder = CategoryOrder.move(.intro, to: .school, in: settings.categoryOrder)
        #expect(AppSettings(defaults: defaults).categoryOrder.first == .intro, "Order survives a restart")

        let model = SettingsViewModel(environment: .testing())
        model.settings.categoryOrder = [.intro]
        model.resetCategoryOrder()
        #expect(model.settings.categoryOrder == CategoryOrder.default)
        #expect(model.orderWasReset)
    }

    @Test func newSessionStartsSlowWhenSettingIsOn() {
        let environment = AppEnvironment.testing()
        #expect(environment.makeSession(category: nil).slow == false)
        environment.settings.slowByDefault = true
        #expect(environment.makeSession(category: nil).slow == true)
    }

    @Test func previewSpeaksWithTheChosenVoice() {
        let speech = RecordingSpeechService()
        let model = SettingsViewModel(environment: .testing(speech: speech))
        let lee = model.voices[1]
        model.preview(lee)
        #expect(speech.utterances.last == Utterance(
            text: SettingsViewModel.previewLine, voiceName: "Lee", locale: "en-AU", slow: false
        ))
    }

    @Test func resetClearsProgress() {
        let environment = AppEnvironment.testing()
        environment.store.setBox(5, for: "fixture-intro-1")
        let model = SettingsViewModel(environment: environment)
        model.resetProgress()
        #expect(environment.store.box(for: "fixture-intro-1") == LeitnerScheduler.firstBox)
        #expect(model.progressWasReset)
    }

    @Test(arguments: [(1, "Default"), (2, "Enhanced"), (3, "Premium")])
    func qualityNames(quality: Int, name: String) {
        #expect(SettingsViewModel.qualityName(quality) == name)
    }

    @Test func snapshot() {
        let view = SettingsView(model: SettingsViewModel(environment: .testing(), version: "1.0.0 (1)"))
        assertSnapshot(of: Snapshot.host(view), as: Snapshot.strategy)
    }
}
