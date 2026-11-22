import Foundation
import Observation
import SayAgainKit

/// User preferences, stored on the device only.
@MainActor
@Observable
final class AppSettings {
    enum Key {
        static let slowByDefault = "settings.slowByDefault"
        static let categoryOrder = "settings.categoryOrder"
        static let showRussian = "settings.showRussian"
        static let aiFeedback = "settings.aiFeedback"
        static let categoriesExpanded = "settings.categoriesExpanded"
    }

    /// Whether the learner agreed to send their own words for an AI check.
    enum AIFeedbackConsent: String {
        case notAsked, allowed, declined
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Every question starts in slow mode.
    var slowByDefault: Bool {
        didSet { defaults.set(slowByDefault, forKey: Key.slowByDefault) }
    }

    /// Home screen order, changed by dragging cards.
    var categoryOrder: [QuestionCategory] {
        didSet { defaults.set(categoryOrder.map(\.rawValue), forKey: Key.categoryOrder) }
    }

    /// Russian under the English: in lessons, phrases and the kids' questions.
    /// Until the learner chooses, it follows the phone: on when the first language is Russian.
    var showRussian: Bool {
        didSet { defaults.set(showRussian, forKey: Key.showRussian) }
    }

    /// Interview categories on Home are folded under one row until the learner opens them.
    var categoriesExpanded: Bool {
        didSet { defaults.set(categoriesExpanded, forKey: Key.categoriesExpanded) }
    }

    /// Asked once, the first time the learner tries to check their own words. Changeable in Settings.
    var aiFeedback: AIFeedbackConsent {
        didSet { defaults.set(aiFeedback.rawValue, forKey: Key.aiFeedback) }
    }

    init(defaults: UserDefaults, preferredLanguages: [String] = Locale.preferredLanguages) {
        self.defaults = defaults
        aiFeedback = defaults.string(forKey: Key.aiFeedback).flatMap(AIFeedbackConsent.init) ?? .notAsked
        showRussian = defaults.object(forKey: Key.showRussian) as? Bool
            ?? (preferredLanguages.first?.hasPrefix("ru") ?? false)
        categoriesExpanded = defaults.bool(forKey: Key.categoriesExpanded)
        slowByDefault = defaults.bool(forKey: Key.slowByDefault)
        categoryOrder = CategoryOrder.resolve(saved: defaults.stringArray(forKey: Key.categoryOrder) ?? [])
    }

    func resetCategoryOrder() {
        categoryOrder = CategoryOrder.default
    }

    /// Fresh, isolated settings for tests and UI-test mode.
    static func ephemeral(_ name: String = "SayAgain.ephemeral.\(UUID().uuidString)") -> AppSettings {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppSettings(defaults: defaults, preferredLanguages: ["en"])
    }
}
