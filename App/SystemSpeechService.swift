import AVFoundation
import SayAgainKit

/// Reads questions with the system voices installed on the device. Nothing is sent anywhere.
@MainActor
final class SystemSpeechService: SpeechService {
    static let normalRate = AVSpeechUtteranceDefaultSpeechRate
    static let slowRate = AVSpeechUtteranceDefaultSpeechRate * 0.75

    private let synthesizer = AVSpeechSynthesizer()

    init() {
        // Play even when the ring switch is on silent: the user explicitly tapped Play.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    func voices(for locale: String) -> [VoiceOption] {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == locale && !$0.voiceTraits.contains(.isNoveltyVoice) }
            .map { VoiceOption(id: $0.identifier, name: Self.displayName($0.name), quality: $0.quality.rawValue) }
    }

    func speak(_ text: String, voice: VoiceOption?, locale: String, slow: Bool) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice.flatMap { AVSpeechSynthesisVoice(identifier: $0.id) }
            ?? AVSpeechSynthesisVoice(language: locale)
        utterance.rate = slow ? Self.slowRate : Self.normalRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// "Karen (Premium)" and "Karen (Enhanced)" are the same person.
    static func displayName(_ name: String) -> String {
        name.components(separatedBy: " (").first ?? name
    }
}
