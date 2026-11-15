import Foundation

/// How well the learner's own words matched what the interviewer asked.
public enum FeedbackVerdict: String, Codable, Sendable, CaseIterable {
    case understood
    case partly
    case missed

    /// What the verdict means for spaced repetition.
    public var rating: Rating {
        switch self {
        case .understood: .gotIt
        case .partly: .partly
        case .missed: .missed
        }
    }
}

/// The checker's answer for one retelling. Shape fixed by `contract/feedback`.
public struct RetellingFeedback: Codable, Equatable, Sendable {
    public let verdict: FeedbackVerdict
    public let feedback: String
    public let missedPoints: [String]

    public init(verdict: FeedbackVerdict, feedback: String, missedPoints: [String] = []) {
        self.verdict = verdict
        self.feedback = feedback
        self.missedPoints = missedPoints
    }

    enum CodingKeys: String, CodingKey {
        case verdict
        case feedback
        case missedPoints = "missed_points"
    }
}

/// Rules for what the learner may send. The Worker applies the same limit.
public enum Retelling {
    public static let maxLength = 400

    /// The text to send, or nil when it is blank or too long.
    public static func prepared(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maxLength else { return nil }
        return trimmed
    }

    /// Categories that never send anything off the device. The kids' school category stays local.
    public static func isAvailable(for category: QuestionCategory) -> Bool {
        category != .school
    }
}
