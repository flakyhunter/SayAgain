/// A system voice the device can speak with.
public struct VoiceOption: Equatable, Hashable, Sendable {
    /// Platform identifier, used to load the voice.
    public let id: String
    /// Display name, for example "Karen".
    public let name: String
    /// 1 = default, 2 = enhanced, 3 = premium.
    public let quality: Int

    public init(id: String, name: String, quality: Int) {
        self.id = id
        self.name = name
        self.quality = quality
    }
}

/// Picks who "asks" each question, so a session sounds like several interviewers.
public enum VoiceRoster {
    /// One voice per person (the best quality of each name), in a stable order.
    public static func cast(from voices: [VoiceOption]) -> [VoiceOption] {
        Dictionary(grouping: voices, by: \.name)
            .compactMap { $0.value.max { $0.quality < $1.quality } }
            .sorted { $0.name < $1.name }
    }

    /// Neighbouring questions get different voices whenever there is more than one.
    public static func voice(forTurn turn: Int, from voices: [VoiceOption]) -> VoiceOption? {
        let cast = cast(from: voices)
        guard !cast.isEmpty else { return nil }
        return cast[((turn % cast.count) + cast.count) % cast.count]
    }
}

/// Reads questions aloud. The app uses the system voices; tests use `RecordingSpeechService`.
@MainActor
public protocol SpeechService: AnyObject {
    /// Voices installed on the device for the locale. May be empty.
    func voices(for locale: String) -> [VoiceOption]
    func speak(_ text: String, voice: VoiceOption?, locale: String, slow: Bool)
    func stop()
}

public struct Utterance: Equatable, Sendable {
    public let text: String
    public let voiceName: String?
    public let locale: String
    public let slow: Bool

    public init(text: String, voiceName: String?, locale: String, slow: Bool) {
        self.text = text
        self.voiceName = voiceName
        self.locale = locale
        self.slow = slow
    }
}

/// Silent speech for tests and UI-test mode: remembers what would have been said.
@MainActor
public final class RecordingSpeechService: SpeechService {
    public static let defaultVoices = [
        VoiceOption(id: "test.karen", name: "Karen", quality: 3),
        VoiceOption(id: "test.lee", name: "Lee", quality: 3)
    ]

    public private(set) var utterances: [Utterance] = []
    public private(set) var stopCount = 0
    public var installedVoices: [VoiceOption]

    public init(voices: [VoiceOption] = RecordingSpeechService.defaultVoices) {
        installedVoices = voices
    }

    public func voices(for locale: String) -> [VoiceOption] {
        installedVoices
    }

    public func speak(_ text: String, voice: VoiceOption?, locale: String, slow: Bool) {
        utterances.append(Utterance(text: text, voiceName: voice?.name, locale: locale, slow: slow))
    }

    public func stop() {
        stopCount += 1
    }
}
