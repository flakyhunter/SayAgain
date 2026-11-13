import AVFoundation
import SayAgainKit

/// Reads questions with the best installed system voice for the locale (en-AU by default).
/// Runs fully on the device; nothing is sent anywhere.
@MainActor
final class SystemSpeechService: SpeechService {
    static let normalRate = AVSpeechUtteranceDefaultSpeechRate
    static let slowRate = AVSpeechUtteranceDefaultSpeechRate * 0.75

    private let synthesizer = AVSpeechSynthesizer()

    init() {
        // Play even when the ring switch is on silent: the user explicitly tapped Play.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }

    func speak(_ text: String, locale: String, slow: Bool) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.bestVoice(for: locale)
        utterance.rate = slow ? Self.slowRate : Self.normalRate
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// Premium or enhanced voices sound much more natural; use them when the user has them.
    static func bestVoice(for locale: String) -> AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == locale }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: locale)
    }
}
