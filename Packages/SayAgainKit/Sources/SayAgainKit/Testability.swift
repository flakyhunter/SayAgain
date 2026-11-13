/// Launch arguments shared by the app and the UI tests.
public enum LaunchArgument {
    /// Deterministic mode: fixture content, silent speech, fresh progress, fixed seed, no animations.
    public static let uiTesting = "-uiTesting"
    /// Seed used in UI-test mode, so tests know the order of questions and answers.
    public static let uiTestingSeed: UInt64 = 42
}

/// Accessibility identifiers shared by the app and the UI tests.
/// UI tests find elements only through these, never through visible text.
public enum A11yID {
    public enum Home {
        public static let list = "home.list"
        public static let header = "home.header"
        public static let startButton = "home.start"
        public static let settingsButton = "home.settings"
        public static let emptyState = "home.emptyState"
        public static func categoryRow(_ category: QuestionCategory) -> String {
            "home.category.\(category.rawValue)"
        }
    }

    public enum Session {
        public static let progress = "session.progress"
        public static let playButton = "session.play"
        public static let slowToggle = "session.slow"
        public static let speaker = "session.speaker"
        public static let moreVoicesHint = "session.moreVoicesHint"
        public static let reveal = "session.reveal"
        public static let resultBanner = "session.result"
        public static let originalText = "session.originalText"
        public static let gotItButton = "session.rate.gotIt"
        public static let partlyButton = "session.rate.partly"
        public static let nextButton = "session.next"
        public static func choice(_ index: Int) -> String { "session.choice.\(index)" }
    }

    public enum Settings {
        public static let slowByDefaultToggle = "settings.slowByDefault"
        public static let resetButton = "settings.reset"
        public static let resetConfirmButton = "settings.resetConfirm"
        public static let resetDoneLabel = "settings.resetDone"
        public static let version = "settings.version"
        public static func voiceRow(_ name: String) -> String { "settings.voice.\(name)" }
        public static func previewButton(_ name: String) -> String { "settings.voice.\(name).play" }
    }

    public enum Summary {
        public static let root = "summary.root"
        public static let gotIt = "summary.gotIt"
        public static let partly = "summary.partly"
        public static let missed = "summary.missed"
        public static let doneButton = "summary.done"
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
