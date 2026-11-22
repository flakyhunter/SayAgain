import Foundation

/// A step-by-step course: lessons that open one after another.
/// Unlike the interview categories, a course teaches from zero, so Russian help is always on.
public struct Course: Codable, Hashable, Identifiable, Sendable {
    public static let agedCareVolunteerID = "aged-care-volunteer"
    public static let careSkillsID = "volunteer-care-skills"
    public static let dementiaID = "volunteer-dementia"
    public static let defaultTipLabel = "Grammar"

    public let id: String
    public let title: String
    public let subtitle: String
    public let titleRu: String
    /// BCP 47 voice locale, for example "en-AU".
    public let locale: String
    public let lessons: [Lesson]
    /// Name of the rule step: "Grammar" in the English course, "Key points" in care skills.
    public let tipLabel: String
    /// Attribution for licensed source material, shown under the lesson list.
    public let credits: String?

    public init(
        id: String, title: String, subtitle: String, titleRu: String, locale: String, lessons: [Lesson],
        tipLabel: String = Course.defaultTipLabel, credits: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.titleRu = titleRu
        self.locale = locale
        self.lessons = lessons
        self.tipLabel = tipLabel
        self.credits = credits
    }

    enum CodingKeys: String, CodingKey {
        case id, title, subtitle, titleRu, locale, lessons, tipLabel, credits
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(String.self, forKey: .id),
            title: c.decode(String.self, forKey: .title),
            subtitle: c.decode(String.self, forKey: .subtitle),
            titleRu: c.decode(String.self, forKey: .titleRu),
            locale: c.decode(String.self, forKey: .locale),
            lessons: c.decode([Lesson].self, forKey: .lessons),
            tipLabel: c.decodeIfPresent(String.self, forKey: .tipLabel) ?? Course.defaultTipLabel,
            credits: c.decodeIfPresent(String.self, forKey: .credits)
        )
    }

    public func lesson(after lesson: Lesson) -> Lesson? {
        guard let index = lessons.firstIndex(of: lesson), lessons.indices.contains(index + 1) else { return nil }
        return lessons[index + 1]
    }
}

/// One lesson: words, a dialogue, a grammar tip, practice and a short check that opens the next lesson.
public struct Lesson: Codable, Hashable, Identifiable, Sendable {
    /// Parts of a lesson in the order the learner goes through them.
    public enum Step: String, Hashable, Sendable {
        case words, dialogue, tip, practice, check
    }

    public static let defaultPassPercent = 80

    public let id: String
    public let number: Int
    public let title: String
    public let titleRu: String
    public let goalRu: String
    public let words: [VocabItem]
    public let dialogue: [DialogueLine]
    public let tip: GrammarTip?
    public let practice: [Exercise]
    public let check: [Exercise]
    /// Score the check needs to open the next lesson. Safety lessons use 100.
    public let passPercent: Int

    public init(
        id: String, number: Int, title: String, titleRu: String, goalRu: String,
        words: [VocabItem], dialogue: [DialogueLine], tip: GrammarTip?,
        practice: [Exercise], check: [Exercise], passPercent: Int = Lesson.defaultPassPercent
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.titleRu = titleRu
        self.goalRu = goalRu
        self.words = words
        self.dialogue = dialogue
        self.tip = tip
        self.practice = practice
        self.check = check
        self.passPercent = passPercent
    }

    enum CodingKeys: String, CodingKey {
        case id, number, title, titleRu, goalRu, words, dialogue, tip, practice, check, passPercent
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            id: c.decode(String.self, forKey: .id),
            number: c.decode(Int.self, forKey: .number),
            title: c.decode(String.self, forKey: .title),
            titleRu: c.decode(String.self, forKey: .titleRu),
            goalRu: c.decode(String.self, forKey: .goalRu),
            words: c.decodeIfPresent([VocabItem].self, forKey: .words) ?? [],
            dialogue: c.decodeIfPresent([DialogueLine].self, forKey: .dialogue) ?? [],
            tip: c.decodeIfPresent(GrammarTip.self, forKey: .tip),
            practice: c.decodeIfPresent([Exercise].self, forKey: .practice) ?? [],
            check: c.decodeIfPresent([Exercise].self, forKey: .check) ?? [],
            passPercent: c.decodeIfPresent(Int.self, forKey: .passPercent) ?? Lesson.defaultPassPercent
        )
    }

    /// Steps that have content, in order. The check is always last.
    public var steps: [Step] {
        var result: [Step] = []
        if !words.isEmpty { result.append(.words) }
        if !dialogue.isEmpty { result.append(.dialogue) }
        if tip != nil { result.append(.tip) }
        if !practice.isEmpty { result.append(.practice) }
        if !check.isEmpty { result.append(.check) }
        return result
    }
}

/// A word or phrase to learn, read aloud on tap.
public struct VocabItem: Codable, Hashable, Sendable {
    public let text: String
    public let translationRu: String
    /// A usage hint, for example "older Aussies say this to be friendly".
    public let noteRu: String?
    /// Australian slang or a typically Australian way to say it.
    public let aussie: Bool

    public init(text: String, translationRu: String, noteRu: String? = nil, aussie: Bool = false) {
        self.text = text
        self.translationRu = translationRu
        self.noteRu = noteRu
        self.aussie = aussie
    }

    enum CodingKeys: String, CodingKey { case text, translationRu, noteRu, aussie }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        text = try c.decode(String.self, forKey: .text)
        translationRu = try c.decode(String.self, forKey: .translationRu)
        noteRu = try c.decodeIfPresent(String.self, forKey: .noteRu)
        aussie = try c.decodeIfPresent(Bool.self, forKey: .aussie) ?? false
    }
}

/// One line of a dialogue. Each role gets its own voice.
public struct DialogueLine: Codable, Hashable, Sendable {
    public enum Role: String, Codable, Sendable {
        /// The learner's side.
        case volunteer
        /// Older residents: read slower.
        case resident
        /// Nurses, reception, coordinators.
        case staff
    }

    public let role: Role
    public let speaker: String
    public let text: String
    public let translationRu: String

    public init(role: Role, speaker: String, text: String, translationRu: String) {
        self.role = role
        self.speaker = speaker
        self.text = text
        self.translationRu = translationRu
    }
}

/// One short grammar rule with examples. No written exercises: the app trains listening.
public struct GrammarTip: Codable, Hashable, Sendable {
    public let title: String
    public let ruleRu: String
    public let examples: [String]

    public init(title: String, ruleRu: String, examples: [String]) {
        self.title = title
        self.ruleRu = ruleRu
        self.examples = examples
    }
}

/// A multiple-choice task: hear a line or read a situation, pick the right option.
public struct Exercise: Codable, Hashable, Identifiable, Sendable {
    public enum Kind: String, Codable, CaseIterable, Sendable {
        /// Hear what someone says, pick what they mean.
        case listen
        /// Read the situation (and maybe hear a line), pick what the volunteer says.
        case reply
        /// Hear Aussie slang, pick the plain English.
        case slang
        /// Read the situation (and maybe hear a line), pick what the volunteer does.
        case scenario

        /// The task is built around a line read aloud, so `say` is required.
        public var needsVoice: Bool { self == .listen || self == .slang }

        /// The right answer is English the volunteer can say, so it can be played back.
        public var answerIsEnglish: Bool { self == .reply || self == .slang }
    }

    public let id: String
    public let kind: Kind
    /// Read aloud by the device voice. Required for listen and slang.
    public let say: String?
    public let situation: String
    public let situationRu: String
    public let answer: String
    public let distractors: [String]
    public let explanation: String
    public let explanationRu: String

    public init(
        id: String, kind: Kind, say: String?, situation: String, situationRu: String,
        answer: String, distractors: [String], explanation: String, explanationRu: String
    ) {
        self.id = id
        self.kind = kind
        self.say = say
        self.situation = situation
        self.situationRu = situationRu
        self.answer = answer
        self.distractors = distractors
        self.explanation = explanation
        self.explanationRu = explanationRu
    }
}
