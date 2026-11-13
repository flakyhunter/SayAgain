import Foundation

/// Every phrase from the questions, grouped by category: the app's dictionary.
public struct PhrasebookEntry: Hashable, Identifiable, Sendable {
    public let phrase: String
    public let meaning: String
    public let translationRu: String?
    public let category: QuestionCategory
    /// Where the phrase was heard, to give an example.
    public let example: String

    public var id: String { "\(category.rawValue)|\(phrase)|\(meaning)" }

    /// Case- and accent-insensitive match on the phrase, its meaning or its translation.
    public func matches(_ query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return true }
        return [phrase, meaning, translationRu ?? ""].contains {
            $0.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }
}

public struct PhrasebookSection: Hashable, Identifiable, Sendable {
    public let category: QuestionCategory
    public let entries: [PhrasebookEntry]
    public var id: QuestionCategory { category }
}

public extension QuestionBank {
    /// Sections in the given category order; within a section, A to Z, without duplicates.
    func phrasebook(order: [QuestionCategory] = CategoryOrder.default, matching query: String = "") -> [PhrasebookSection] {
        CategoryOrder.resolve(saved: order.map(\.rawValue)).compactMap { category in
            let entries = phrasebookEntries(in: category).filter { $0.matches(query) }
            return entries.isEmpty ? nil : PhrasebookSection(category: category, entries: entries)
        }
    }

    private func phrasebookEntries(in category: QuestionCategory) -> [PhrasebookEntry] {
        var seen = Set<String>()
        var entries: [PhrasebookEntry] = []
        for question in questions(in: category) {
            for phrase in question.phrases {
                let key = phrase.phrase.lowercased() + "|" + phrase.meaning
                guard seen.insert(key).inserted else { continue }
                entries.append(PhrasebookEntry(
                    phrase: phrase.phrase, meaning: phrase.meaning, translationRu: phrase.translationRu,
                    category: category, example: question.text
                ))
            }
        }
        return entries.sorted { $0.phrase.localizedCaseInsensitiveCompare($1.phrase) == .orderedAscending }
    }
}
