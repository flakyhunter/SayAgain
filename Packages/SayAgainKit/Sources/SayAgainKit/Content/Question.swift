import Foundation

/// A practice category shown on the home screen.
public enum QuestionCategory: String, Codable, CaseIterable, Sendable {
    case intro
    case behavioural
    case logistics
    case qaIT = "qa-it"
    case volunteering
    case agedCare = "aged-care"

    public var title: String {
        switch self {
        case .intro: "Intro and background"
        case .behavioural: "Behavioural"
        case .logistics: "Salary and logistics"
        case .qaIT: "QA and IT"
        case .volunteering: "Volunteering"
        case .agedCare: "Aged care"
        }
    }
}

/// A spoken phrase that often trips people up, with a plain-English meaning.
public struct Phrase: Codable, Hashable, Sendable {
    public let phrase: String
    public let meaning: String

    public init(phrase: String, meaning: String) {
        self.phrase = phrase
        self.meaning = meaning
    }
}

/// One interview question as an Australian interviewer would actually say it.
public struct Question: Codable, Hashable, Identifiable, Sendable {
    public let id: String
    public let category: QuestionCategory
    /// What the interviewer says, read aloud by the device voice.
    public let text: String
    /// The same question in simple English.
    public let rephrase: String
    /// One-line summary: the correct answer to "what did they ask?".
    public let gist: String
    /// Plausible but wrong summaries for the multiple-choice step.
    public let distractors: [String]
    public let phrases: [Phrase]
    /// BCP 47 voice locale, for example "en-AU".
    public let locale: String

    public init(
        id: String,
        category: QuestionCategory,
        text: String,
        rephrase: String,
        gist: String,
        distractors: [String],
        phrases: [Phrase],
        locale: String = "en-AU"
    ) {
        self.id = id
        self.category = category
        self.text = text
        self.rephrase = rephrase
        self.gist = gist
        self.distractors = distractors
        self.phrases = phrases
        self.locale = locale
    }
}
