import Foundation
import Observation

/// User preferences, stored on the device only.
@MainActor
@Observable
final class AppSettings {
    enum Key {
        static let slowByDefault = "settings.slowByDefault"
    }

    @ObservationIgnored private let defaults: UserDefaults

    /// Every question starts in slow mode.
    var slowByDefault: Bool {
        didSet { defaults.set(slowByDefault, forKey: Key.slowByDefault) }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        slowByDefault = defaults.bool(forKey: Key.slowByDefault)
    }

    /// Fresh, isolated settings for tests and UI-test mode.
    static func ephemeral(_ name: String = "SayAgain.ephemeral.\(UUID().uuidString)") -> AppSettings {
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return AppSettings(defaults: defaults)
    }
}
