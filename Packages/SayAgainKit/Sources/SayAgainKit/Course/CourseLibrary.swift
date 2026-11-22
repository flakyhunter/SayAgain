import Foundation

/// A problem found in course content.
public enum CourseIssue: Hashable, Sendable {
    case duplicateID(String)
    case emptyField(id: String, field: String)
    case lessonNumberGap(courseID: String, expected: Int, found: Int)
    case wrongDistractorCount(id: String, count: Int)
    case distractorMatchesAnswer(id: String)
    case forbiddenCharacter(id: String, character: String)
    case bannedName(id: String, name: String)
    case invalidPassPercent(id: String, value: Int)
    /// English is the main language: Russian belongs only in the `...Ru` fields.
    case russianInEnglishField(id: String, field: String)
    /// Every English line the learner reads has a Russian translation, and the other way round.
    case missingTranslation(id: String, field: String)
}

/// All courses shipped with the app.
public struct CourseLibrary: Sendable {
    /// Real organisations and people from the source notes must never reach the public app,
    /// and the content stays the same for every Australian city.
    static let bannedNames = [
        "MercyCare", "Mercy Care", "Julia", "Caitlin",
        "Perth", "Sydney", "Melbourne", "Brisbane", "Adelaide", "Canberra", "Hobart", "Darwin",
        "Eagles", "Dockers"
    ]

    public let courses: [Course]

    public init(courses: [Course]) {
        self.courses = courses
    }

    public static func bundled() throws -> CourseLibrary {
        guard let url = Bundle.module.url(forResource: "courses", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    public static func decode(_ data: Data) throws -> CourseLibrary {
        CourseLibrary(courses: try JSONDecoder().decode([Course].self, from: data))
    }

    public func course(id: String) -> Course? {
        courses.first { $0.id == id }
    }

    /// Checks the content rules. An empty result means the content is valid.
    public func validate() -> [CourseIssue] {
        var issues: [CourseIssue] = []
        var seen = Set<String>()
        func unique(_ id: String) {
            if !seen.insert(id).inserted { issues.append(.duplicateID(id)) }
        }

        for course in courses {
            unique(course.id)
            issues += textIssues(id: course.id, [course.title, course.subtitle, course.titleRu, course.tipLabel, course.credits ?? ""])

            for (offset, lesson) in course.lessons.enumerated() {
                unique(lesson.id)
                if lesson.number != offset + 1 {
                    issues.append(.lessonNumberGap(courseID: course.id, expected: offset + 1, found: lesson.number))
                }
                if lesson.check.isEmpty {
                    issues.append(.emptyField(id: lesson.id, field: "check"))
                }
                if !(1...100).contains(lesson.passPercent) {
                    issues.append(.invalidPassPercent(id: lesson.id, value: lesson.passPercent))
                }
                var texts = [lesson.title, lesson.titleRu, lesson.goal, lesson.goalRu]
                texts += lesson.words.flatMap { [$0.text, $0.translationRu, $0.note ?? "", $0.noteRu ?? ""] }
                texts += lesson.dialogue.flatMap { [$0.speaker, $0.text, $0.translationRu] }
                if let tip = lesson.tip { texts += [tip.title, tip.rule, tip.ruleRu] + tip.examples }
                issues += textIssues(id: lesson.id, texts)

                var english = [("title", lesson.title), ("goal", lesson.goal)]
                english += lesson.words.flatMap { [("words.text", $0.text), ("words.note", $0.note ?? "")] }
                english += lesson.dialogue.map { ("dialogue.text", $0.text) }
                if let tip = lesson.tip { english += [("tip.rule", tip.rule)] + tip.examples.map { ("tip.examples", $0) } }
                issues += englishIssues(id: lesson.id, english)
                if lesson.goal.trimmingCharacters(in: .whitespaces).isEmpty || lesson.goalRu.isEmpty {
                    issues.append(.missingTranslation(id: lesson.id, field: "goal"))
                }
                if let tip = lesson.tip, tip.rule.isEmpty || tip.ruleRu.isEmpty {
                    issues.append(.missingTranslation(id: lesson.id, field: "tip.rule"))
                }
                if lesson.words.contains(where: { ($0.note == nil) != ($0.noteRu == nil) }) {
                    issues.append(.missingTranslation(id: lesson.id, field: "words.note"))
                }

                for exercise in lesson.practice + lesson.check {
                    unique(exercise.id)
                    issues += exerciseIssues(exercise)
                }
            }
        }
        return issues
    }

    private func exerciseIssues(_ exercise: Exercise) -> [CourseIssue] {
        var issues: [CourseIssue] = []
        if exercise.kind.needsVoice, (exercise.say ?? "").trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.emptyField(id: exercise.id, field: "say"))
        }
        for (name, value) in [("answer", exercise.answer), ("situationRu", exercise.situationRu)]
            where value.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.emptyField(id: exercise.id, field: name))
        }
        if exercise.distractors.count != QuestionBank.requiredDistractors {
            issues.append(.wrongDistractorCount(id: exercise.id, count: exercise.distractors.count))
        }
        if exercise.distractors.contains(where: { $0.caseInsensitiveCompare(exercise.answer) == .orderedSame }) {
            issues.append(.distractorMatchesAnswer(id: exercise.id))
        }
        if exercise.answerRu.trimmingCharacters(in: .whitespaces).isEmpty {
            issues.append(.missingTranslation(id: exercise.id, field: "answerRu"))
        }
        if exercise.distractorsRu.count != exercise.distractors.count {
            issues.append(.missingTranslation(id: exercise.id, field: "distractorsRu"))
        }
        issues += englishIssues(id: exercise.id, [
            ("say", exercise.say ?? ""), ("situation", exercise.situation), ("answer", exercise.answer),
            ("explanation", exercise.explanation)
        ] + exercise.distractors.map { ("distractors", $0) })
        let texts = [exercise.say ?? "", exercise.situation, exercise.situationRu, exercise.answer, exercise.answerRu,
                     exercise.explanation, exercise.explanationRu] + exercise.distractors + exercise.distractorsRu
        return issues + textIssues(id: exercise.id, texts)
    }

    private func englishIssues(id: String, _ fields: [(String, String)]) -> [CourseIssue] {
        var reported = Set<String>()
        return fields.compactMap { field, text in
            guard text.range(of: "\\p{Cyrillic}", options: .regularExpression) != nil,
                  reported.insert(field).inserted else { return nil }
            return .russianInEnglishField(id: id, field: field)
        }
    }

    private func textIssues(id: String, _ texts: [String]) -> [CourseIssue] {
        var issues: [CourseIssue] = []
        for character in QuestionBank.forbiddenCharacters where texts.contains(where: { $0.contains(character) }) {
            issues.append(.forbiddenCharacter(id: id, character: character))
        }
        for name in Self.bannedNames where texts.contains(where: { $0.range(of: "\\b\(name)\\b", options: .regularExpression) != nil }) {
            issues.append(.bannedName(id: id, name: name))
        }
        return issues
    }
}
