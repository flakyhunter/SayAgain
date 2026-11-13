import Foundation

/// Number of questions available in a category.
public struct CategorySummary: Hashable, Identifiable, Sendable {
    public let category: QuestionCategory
    public let count: Int
    public var id: QuestionCategory { category }
}

/// A problem found in the question content.
public enum ContentIssue: Hashable, Sendable {
    case duplicateID(String)
    case emptyField(id: String, field: String)
    case wrongDistractorCount(id: String, count: Int)
    case distractorMatchesGist(id: String)
    case forbiddenCharacter(id: String, character: String)
}

/// All questions the app can play.
public struct QuestionBank: Sendable {
    public static let requiredDistractors = 2
    /// Typography rule of the project: no long dashes and no "yo" letter in any text.
    static let forbiddenCharacters = ["\u{2014}", "\u{2013}", "\u{0451}", "\u{0401}"]

    public let questions: [Question]

    public init(questions: [Question]) {
        self.questions = questions
    }

    /// Loads the questions shipped with the app.
    public static func bundled() throws -> QuestionBank {
        guard let url = Bundle.module.url(forResource: "questions", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> QuestionBank {
        QuestionBank(questions: try JSONDecoder().decode([Question].self, from: data))
    }

    public func questions(in category: QuestionCategory) -> [Question] {
        questions.filter { $0.category == category }
    }

    /// Categories that have at least one question, in display order.
    public var categorySummaries: [CategorySummary] {
        QuestionCategory.allCases.compactMap { category in
            let count = questions(in: category).count
            return count > 0 ? CategorySummary(category: category, count: count) : nil
        }
    }

    /// Checks the content rules. An empty result means the content is valid.
    public func validate() -> [ContentIssue] {
        var issues: [ContentIssue] = []
        var seen = Set<String>()

        for question in questions {
            if !seen.insert(question.id).inserted {
                issues.append(.duplicateID(question.id))
            }

            let fields: [(String, String)] = [
                ("id", question.id),
                ("text", question.text),
                ("rephrase", question.rephrase),
                ("gist", question.gist),
                ("locale", question.locale)
            ]
            for (name, value) in fields where value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                issues.append(.emptyField(id: question.id, field: name))
            }
            if question.phrases.isEmpty {
                issues.append(.emptyField(id: question.id, field: "phrases"))
            }

            if question.distractors.count != Self.requiredDistractors {
                issues.append(.wrongDistractorCount(id: question.id, count: question.distractors.count))
            }
            if question.distractors.contains(where: { $0.caseInsensitiveCompare(question.gist) == .orderedSame }) {
                issues.append(.distractorMatchesGist(id: question.id))
            }

            let allText = [question.text, question.rephrase, question.gist]
                + question.distractors
                + question.phrases.flatMap { [$0.phrase, $0.meaning] }
            for character in Self.forbiddenCharacters where allText.contains(where: { $0.contains(character) }) {
                issues.append(.forbiddenCharacter(id: question.id, character: character))
            }
        }
        return issues
    }
}
