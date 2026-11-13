import Foundation
import Testing
@testable import SayAgainKit

@Suite("Shipped content")
struct ShippedContentTests {
    @Test("Bundled questions decode and pass every content rule")
    func bundledContentIsValid() throws {
        let bank = try QuestionBank.bundled()
        #expect(!bank.questions.isEmpty)
        #expect(bank.validate() == [])
    }

    @Test("Every category has at least one question")
    func everyCategoryCovered() throws {
        let bank = try QuestionBank.bundled()
        #expect(bank.categorySummaries.map(\.category) == QuestionCategory.allCases)
    }

    @Test("Release needs at least 60 questions, 15 per category")
    func enoughContentForRelease() throws {
        let bank = try QuestionBank.bundled()
        #expect(bank.questions.count >= 60)
        for summary in bank.categorySummaries {
            #expect(summary.count >= 15, "\(summary.category) has only \(summary.count)")
        }
    }

    @Test("Content is not tied to one city")
    func noCitySpecificContent() throws {
        let cities = ["Perth", "Sydney", "Melbourne", "Brisbane", "Adelaide", "Canberra", "Hobart", "Darwin"]
        let bank = try QuestionBank.bundled()
        for question in bank.questions {
            let text = ([question.text, question.rephrase, question.gist] + question.distractors).joined(separator: " ")
            #expect(!cities.contains { text.contains($0) }, "\(question.id) mentions a city")
        }
    }

    @Test("Fixture content used by UI tests is valid too")
    func fixtureIsValid() {
        #expect(QuestionBank.fixture.validate() == [])
    }
}

@Suite("Content validation rules")
struct ValidationTests {
    private func question(
        id: String = "q1",
        text: String = "Text",
        gist: String = "Gist",
        distractors: [String] = ["A", "B"],
        phrases: [Phrase] = [Phrase(phrase: "p", meaning: "m")]
    ) -> Question {
        Question(id: id, category: .intro, text: text, rephrase: "Rephrase",
                 gist: gist, distractors: distractors, phrases: phrases)
    }

    @Test func duplicateIDs() {
        let bank = QuestionBank(questions: [question(), question()])
        #expect(bank.validate() == [.duplicateID("q1")])
    }

    @Test(arguments: [0, 1, 3])
    func wrongDistractorCount(count: Int) {
        let distractors = (0..<count).map { "D\($0)" }
        let bank = QuestionBank(questions: [question(distractors: distractors)])
        #expect(bank.validate() == [.wrongDistractorCount(id: "q1", count: count)])
    }

    @Test func distractorEqualToGistIgnoringCase() {
        let bank = QuestionBank(questions: [question(gist: "Same", distractors: ["same", "Other"])])
        #expect(bank.validate() == [.distractorMatchesGist(id: "q1")])
    }

    @Test(arguments: ["", "   "])
    func blankText(text: String) {
        let bank = QuestionBank(questions: [question(text: text)])
        #expect(bank.validate() == [.emptyField(id: "q1", field: "text")])
    }

    @Test func missingPhrases() {
        let bank = QuestionBank(questions: [question(phrases: [])])
        #expect(bank.validate() == [.emptyField(id: "q1", field: "phrases")])
    }

    @Test(arguments: QuestionBank.forbiddenCharacters)
    func forbiddenCharacter(character: String) {
        let bank = QuestionBank(questions: [question(text: "Before \(character) after")])
        #expect(bank.validate() == [.forbiddenCharacter(id: "q1", character: character)])
    }
}

@Suite("Category summaries")
struct CategorySummaryTests {
    @Test func countsAndOrderFollowCategoryOrder() {
        let summaries = QuestionBank.fixture.categorySummaries
        #expect(summaries == [
            CategorySummary(category: .intro, count: 1),
            CategorySummary(category: .behavioural, count: 2)
        ])
    }

    @Test func emptyBankHasNoCategories() {
        #expect(QuestionBank(questions: []).categorySummaries.isEmpty)
    }

    @Test func malformedJSONThrows() {
        #expect(throws: DecodingError.self) {
            try QuestionBank.decode(Data("{\"not\": \"an array\"}".utf8))
        }
    }
}
