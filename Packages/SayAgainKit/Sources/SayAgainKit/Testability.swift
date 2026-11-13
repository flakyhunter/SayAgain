/// Launch arguments shared by the app and the UI tests.
public enum LaunchArgument {
    /// Deterministic mode: fixture content, no animations.
    public static let uiTesting = "-uiTesting"
}

/// Accessibility identifiers shared by the app and the UI tests.
/// UI tests find elements only through these, never through visible text.
public enum A11yID {
    public enum Home {
        public static let list = "home.list"
        public static let header = "home.header"
        public static let emptyState = "home.emptyState"
        public static func categoryRow(_ category: QuestionCategory) -> String {
            "home.category.\(category.rawValue)"
        }
    }
}

public extension QuestionBank {
    /// Small fixed content for UI and snapshot tests, independent of the shipped JSON.
    static let fixture = QuestionBank(questions: [
        Question(
            id: "fixture-intro-1",
            category: .intro,
            text: "So, just to kick things off, could you walk me through your background?",
            rephrase: "Tell me about yourself and your experience.",
            gist: "Tell me about your background.",
            distractors: ["Why do you want this job?", "What are your weaknesses?"],
            phrases: [Phrase(phrase: "to kick things off", meaning: "to start")]
        ),
        Question(
            id: "fixture-behavioural-1",
            category: .behavioural,
            text: "Can you tell me about a time you tracked down a really tricky bug?",
            rephrase: "Tell me about a difficult bug you found.",
            gist: "Describe a hard bug you investigated.",
            distractors: ["How many bugs do you find a week?", "Which bug tracker do you use?"],
            phrases: [Phrase(phrase: "tracked down", meaning: "found after searching")]
        ),
        Question(
            id: "fixture-behavioural-2",
            category: .behavioural,
            text: "If a developer pushes back and reckons your bug isn't really a bug, how do you handle that?",
            rephrase: "If a developer says your bug is not a real bug, what do you do?",
            gist: "How do you handle a developer who disagrees with your bug?",
            distractors: ["How do you report a bug?", "Have you ever worked as a developer?"],
            phrases: [Phrase(phrase: "reckons", meaning: "thinks")]
        )
    ])
}
