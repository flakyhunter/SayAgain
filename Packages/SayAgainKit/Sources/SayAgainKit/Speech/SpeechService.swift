/// Reads questions aloud. The app uses the system voices; tests use `RecordingSpeechService`.
@MainActor
public protocol SpeechService: AnyObject {
    func speak(_ text: String, locale: String, slow: Bool)
    func stop()
}

public struct Utterance: Equatable, Sendable {
    public let text: String
    public let locale: String
    public let slow: Bool

    public init(text: String, locale: String, slow: Bool) {
        self.text = text
        self.locale = locale
        self.slow = slow
    }
}

/// Silent speech for tests and UI-test mode: remembers what would have been said.
@MainActor
public final class RecordingSpeechService: SpeechService {
    public private(set) var utterances: [Utterance] = []
    public private(set) var stopCount = 0

    public init() {}

    public func speak(_ text: String, locale: String, slow: Bool) {
        utterances.append(Utterance(text: text, locale: locale, slow: slow))
    }

    public func stop() {
        stopCount += 1
    }
}
