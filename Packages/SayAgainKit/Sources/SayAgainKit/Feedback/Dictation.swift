import Foundation

/// Why dictation could not start.
public enum DictationError: Error, Equatable, Sendable {
    /// Microphone or speech recognition permission was refused.
    case denied
    /// This device cannot recognise speech on the device for the language.
    case unsupported
    /// The microphone could not be started.
    case failed

    public var message: String {
        switch self {
        case .denied: "Allow Microphone and Speech Recognition for Say Again in Settings to dictate."
        case .unsupported: "Dictation on this iPhone isn't available for English. You can type, or use the mic on the keyboard."
        case .failed: "Couldn't start the microphone. Try again, or type instead."
        }
    }
}

/// Turns the learner's speech into text, on the device. Audio is never stored or sent anywhere.
@MainActor
public protocol DictationService: AnyObject {
    /// Asks for microphone and speech permission the first time; afterwards answers at once.
    func prepare(locale: String) async throws(DictationError)
    /// Starts listening. `onText` gets the whole transcript so far, again and again as it grows.
    /// `onEnd` is called once, when listening stops for any reason.
    func start(locale: String, onText: @escaping @MainActor (String) -> Void,
               onEnd: @escaping @MainActor () -> Void) throws(DictationError)
    /// Stops listening; the last transcript arrives through `onText` before `onEnd`.
    func stop()
}

/// Which recogniser language to use. The learner, not the interviewer, is speaking, so any English
/// model that runs on the device will do; the question's own accent is only the first choice.
public enum DictationLocale {
    public static func candidates(preferred: String) -> [String] {
        var seen = Set<String>()
        return ([preferred, "en-AU", "en-GB", "en-US"]).filter { seen.insert($0).inserted }
    }

    /// The first candidate that can run on the device, or nil.
    public static func pick(preferred: String, runsOnDevice: (String) -> Bool) -> String? {
        candidates(preferred: preferred).first(where: runsOnDevice)
    }
}

/// How dictated words join text the learner already typed.
public enum DictationText {
    /// Typed text first, then the dictated words, with one space between, cut to `limit`.
    public static func combine(typed: String, dictated: String, limit: Int = Retelling.maxLength) -> String {
        let head = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let tail = dictated.trimmingCharacters(in: .whitespacesAndNewlines)
        let joined = [head, tail].filter { !$0.isEmpty }.joined(separator: " ")
        return String(joined.prefix(limit))
    }
}

/// Deterministic dictation for UI tests and previews: "hears" a fixed script word by word.
/// Stays listening until `stop()`, like the real service.
@MainActor
public final class ScriptedDictationService: DictationService {
    public var script: String
    public var prepareError: DictationError?
    public private(set) var startCount = 0
    public private(set) var isListening = false
    private var onEnd: (@MainActor () -> Void)?

    public init(script: String = "partly they want my background", prepareError: DictationError? = nil) {
        self.script = script
        self.prepareError = prepareError
    }

    public func prepare(locale: String) async throws(DictationError) {
        if let prepareError { throw prepareError }
    }

    public func start(locale: String, onText: @escaping @MainActor (String) -> Void,
                      onEnd: @escaping @MainActor () -> Void) throws(DictationError) {
        if let prepareError { throw prepareError }
        startCount += 1
        isListening = true
        self.onEnd = onEnd
        onText(script)
    }

    public func stop() {
        guard isListening else { return }
        isListening = false
        let end = onEnd
        onEnd = nil
        end?()
    }
}
