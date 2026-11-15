import AVFoundation
import SayAgainKit
import Speech

/// Dictation with Apple's speech recognition, forced to run on the device:
/// the audio never leaves the iPhone and is not stored.
@MainActor
final class SystemDictationService: DictationService {
    /// Long enough for any retelling; stops a forgotten microphone.
    static let maxDuration: Duration = .seconds(60)

    private let engine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var onText: (@MainActor (String) -> Void)?
    private var onEnd: (@MainActor () -> Void)?
    private var timeout: Task<Void, Never>?
    /// Bumped on every start, so a late callback from an old run can't end a new one.
    private var run = 0

    /// en-AU when the device has it on board, otherwise another English model that runs locally.
    static func recognizer(preferred: String) -> SFSpeechRecognizer? {
        DictationLocale.pick(preferred: preferred) {
            SFSpeechRecognizer(locale: Locale(identifier: $0))?.supportsOnDeviceRecognition == true
        }
        .flatMap { SFSpeechRecognizer(locale: Locale(identifier: $0)) }
    }

    func prepare(locale: String) async throws(DictationError) {
        guard Self.recognizer(preferred: locale) != nil else { throw .unsupported }
        let speech = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0) }
        }
        guard speech == .authorized, await AVAudioApplication.requestRecordPermission() else { throw .denied }
    }

    func start(locale: String, onText: @escaping @MainActor (String) -> Void,
               onEnd: @escaping @MainActor () -> Void) throws(DictationError) {
        stop()
        guard let recognizer = Self.recognizer(preferred: locale), recognizer.isAvailable else { throw .unsupported }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = true
        request.addsPunctuation = true

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            let input = engine.inputNode
            let format = input.outputFormat(forBus: 0)
            input.removeTap(onBus: 0)
            nonisolated(unsafe) let target = request
            input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
                target.append(buffer)
            }
            engine.prepare()
            try engine.start()
        } catch {
            restorePlayback()
            throw .failed
        }

        run += 1
        let current = run
        self.request = request
        self.onText = onText
        self.onEnd = onEnd
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            let text = result?.bestTranscription.formattedString
            let done = error != nil || (result?.isFinal ?? false)
            Task { @MainActor in
                guard let self, self.run == current else { return }
                if let text { self.onText?(text) }
                if done { self.finish() }
            }
        }
        timeout = Task { [weak self] in
            try? await Task.sleep(for: Self.maxDuration)
            self?.stop()
        }
    }

    /// Stops the microphone; the recogniser then delivers its final text and `finish` runs.
    func stop() {
        guard request != nil else { return }
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        request = nil
        timeout?.cancel()
        // If the recogniser never reports back, end anyway.
        let current = run
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.5))
            guard let self, self.run == current else { return }
            self.finish()
        }
    }

    private func finish() {
        if request != nil { stop() }
        task?.cancel()
        task = nil
        restorePlayback()
        let end = onEnd
        onText = nil
        onEnd = nil
        end?()
    }

    /// Back to the session the question voices use.
    private func restorePlayback() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
    }
}
