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

    /// Russian translation under phrases and for the kids' questions.
    var showRussian: Bool {
        didSet { defaults.set(showRussian, forKey: Key.showRussian) }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        showRussian = defaults.bool(forKey: Key.showRussian)
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
        return AppSettings(defaults: defaults)
    }
}
