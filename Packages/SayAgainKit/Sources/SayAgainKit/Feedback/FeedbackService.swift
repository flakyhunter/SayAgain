import Foundation

/// Why a retelling could not be checked. Maps the Worker's error codes (`contract/feedback`).
public enum FeedbackServiceError: Error, Equatable, Sendable {
    case offline
    case rateLimited
    case busy
    case notAvailable
    case cannotCheck
    case unexpected(status: Int)

    /// Short text for the learner. Practice always goes on without AI feedback.
    public var message: String {
        switch self {
        case .offline: "No internet connection. You can still pick the meaning below."
        case .rateLimited: "That's a lot of checks in a row. Wait a minute and try again."
        case .busy: "AI feedback is busy right now. Try again in a moment."
        case .notAvailable: "AI feedback isn't available for this question."
        case .cannotCheck, .unexpected: "Couldn't check this one. Try different words, or pick the meaning below."
        }
    }

    /// Worth offering "Try again" for.
    public var isRetryable: Bool {
        switch self {
        case .offline, .rateLimited, .busy, .cannotCheck, .unexpected: true
        case .notAvailable: false
        }
    }
}

/// Checks a learner's retelling of a question.
public protocol FeedbackService: Sendable {
    func check(questionID: String, retelling: String) async throws(FeedbackServiceError) -> RetellingFeedback
}

/// Talks to the SayAgain Worker (`server/`). The Anthropic key lives in the Worker, never in the app.
public struct RemoteFeedbackService: FeedbackService {
    public let endpoint: URL
    private let session: URLSession

    public init(endpoint: URL, session: URLSession = .shared) {
        self.endpoint = endpoint
        self.session = session
    }

    struct Body: Encodable {
        let questionId: String
        let retelling: String
    }

    struct ErrorBody: Decodable {
        let error: String
    }

    public func check(questionID: String, retelling: String) async throws(FeedbackServiceError) -> RetellingFeedback {
        var request = URLRequest(url: endpoint.appending(path: "v1/feedback"))
        request.httpMethod = "POST"
        request.timeoutInterval = 25
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Body(questionId: questionID, retelling: retelling))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw .offline
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        if status == 200 {
            guard let feedback = try? JSONDecoder().decode(RetellingFeedback.self, from: data) else {
                throw .cannotCheck
            }
            return feedback
        }
        let code = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
        throw Self.error(status: status, code: code)
    }

    static func error(status: Int, code: String?) -> FeedbackServiceError {
        switch (status, code) {
        case (429, _): .rateLimited
        case (503, _): .busy
        case (403, "not_available"): .notAvailable
        case (502, _): .cannotCheck
        default: .unexpected(status: status)
        }
    }
}

/// Deterministic stand-in for UI tests and previews. No network.
/// The first word of the retelling picks the answer: "missed ..." gives missed, "partly ..." gives
/// partly, "offline ..." and "busy ..." throw those errors, anything else is understood.
/// Records every call, so tests can check what would have been sent.
public final class ScriptedFeedbackService: FeedbackService, @unchecked Sendable {
    private let lock = NSLock()
    private var _calls: [(questionID: String, retelling: String)] = []

    public init() {}

    public var calls: [(questionID: String, retelling: String)] {
        lock.withLock { _calls }
    }

    public func check(questionID: String, retelling: String) async throws(FeedbackServiceError) -> RetellingFeedback {
        lock.withLock { _calls.append((questionID, retelling)) }
        let first = String(retelling.lowercased().prefix(while: \.isLetter))
        switch first {
        case "offline": throw .offline
        case "busy": throw .busy
        case "missed":
            return RetellingFeedback(verdict: .missed, feedback: "Not quite. Listen for what they want you to describe.",
                                     missedPoints: ["what they asked you to describe"])
        case "partly":
            return RetellingFeedback(verdict: .partly, feedback: "Close. You missed the second part of the question.",
                                     missedPoints: ["the second part"])
        default:
            return RetellingFeedback(verdict: .understood, feedback: "Yes, that's what they asked.")
        }
    }
}
