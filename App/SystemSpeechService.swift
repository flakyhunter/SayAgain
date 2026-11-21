import AVFoundation
import SayAgainKit

/// Reads questions with the system voices installed on the device. Nothing is sent anywhere.
@MainActor
final class SystemSpeechService: SpeechService {
    static let normalRate = AVSpeechUtteranceDefaultSpeechRate
    /// The rate scale is not linear: 0.3 is only about 20% slower than the default 0.5.
    /// Pauses between phrases do most of the slowing down.
    static let slowRate: Float = 0.3
    static let slowPause: TimeInterval = 0.7

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

    /// Pause between dialogue lines, so two voices do not run into each other.
    static let linePause: TimeInterval = 0.6

    func speak(_ text: String, voice: VoiceOption?, locale: String, slow: Bool) {
        synthesizer.stopSpeaking(at: .immediate)
        enqueue(text, voice: voice, locale: locale, slow: slow, pauseAfter: 0)
    }

    func speak(lines: [SpokenLine], locale: String) {
        synthesizer.stopSpeaking(at: .immediate)
        for line in lines {
            enqueue(line.text, voice: line.voice, locale: locale, slow: line.slow, pauseAfter: Self.linePause)
        }
    }

    private func enqueue(_ text: String, voice: VoiceOption?, locale: String, slow: Bool, pauseAfter: TimeInterval) {
        let systemVoice = voice.flatMap { AVSpeechSynthesisVoice(identifier: $0.id) }
            ?? AVSpeechSynthesisVoice(language: locale)
        let phrases = slow ? SpeechChunker.chunks(text) : [text]
        for (offset, phrase) in phrases.enumerated() {
            let utterance = AVSpeechUtterance(string: phrase)
            utterance.voice = systemVoice
            utterance.rate = slow ? Self.slowRate : Self.normalRate
            let last = offset == phrases.count - 1
            utterance.postUtteranceDelay = max(slow ? Self.slowPause : 0, last ? pauseAfter : 0)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// "Karen (Premium)" and "Karen (Enhanced)" are the same person.
    static func displayName(_ name: String) -> String {
        name.components(separatedBy: " (").first ?? name
    }
}
