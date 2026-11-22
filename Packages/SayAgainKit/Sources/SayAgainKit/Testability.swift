/// Launch arguments shared by the app and the UI tests.
public enum LaunchArgument {
    /// Deterministic mode: fixture content, silent speech, fresh progress, fixed seed, no animations.
    public static let uiTesting = "-uiTesting"
    /// With `uiTesting`: use the real shipped questions instead of the small fixture.
    public static let bundledContent = "-bundledContent"
    /// With `uiTesting`: send retellings to the real Worker from the build settings instead of the
    /// scripted service. Used by the end-to-end test against `wrangler dev`.
    public static let liveFeedback = "-liveFeedback"
    /// With `uiTesting`: use the real on-device speech recogniser instead of the scripted one.
    public static let liveDictation = "-liveDictation"
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
        public static let phrasebookButton = "home.phrasebook"
        public static let emptyState = "home.emptyState"
        public static let startOverConfirmButton = "home.startOverConfirm"
        /// Folds and unfolds the interview categories. Value: "Expanded" or "Collapsed".
        public static let categoriesToggle = "home.categoriesToggle"
        public static func startOverButton(_ category: QuestionCategory) -> String {
            "home.category.\(category.rawValue).startOver"
        }
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
        public static let sampleAnswerButton = "session.sampleAnswer"
        public static let nextButton = "session.next"
        public static let retellButton = "session.retell"
        public static let aiFeedback = "session.aiFeedback"
        public static func choice(_ index: Int) -> String { "session.choice.\(index)" }
    }

    public enum Retell {
        public static let sheet = "retell.sheet"
        public static let consent = "retell.consent"
        public static let allowButton = "retell.allow"
        public static let declineButton = "retell.decline"
        public static let textField = "retell.text"
        public static let micButton = "retell.mic"
        public static let listening = "retell.listening"
        public static let dictationError = "retell.dictationError"
        public static let checkButton = "retell.check"
        public static let checking = "retell.checking"
        public static let verdict = "retell.verdict"
        public static let feedback = "retell.feedback"
        public static let error = "retell.error"
        public static let retryButton = "retell.retry"
        public static let continueButton = "retell.continue"
        public static let cancelButton = "retell.cancel"
    }

    public enum Settings {
        public static let aiFeedbackToggle = "settings.aiFeedback"
        public static let slowByDefaultToggle = "settings.slowByDefault"
        public static let resetButton = "settings.reset"
        public static let resetOrderButton = "settings.resetOrder"
        public static let russianToggle = "settings.russian"
        public static let resetConfirmButton = "settings.resetConfirm"
        public static let resetDoneLabel = "settings.resetDone"
        public static let version = "settings.version"
        public static func voiceRow(_ name: String) -> String { "settings.voice.\(name)" }
        public static func previewButton(_ name: String) -> String { "settings.voice.\(name).play" }
    }

    public enum Phrasebook {
        public static let list = "phrasebook.list"
        public static func row(_ phrase: String) -> String { "phrasebook.row.\(phrase)" }
    }

    public enum SampleAnswer {
        public static let sheet = "sampleAnswer.sheet"
        public static let text = "sampleAnswer.text"
        public static let listenButton = "sampleAnswer.listen"
        public static let closeButton = "sampleAnswer.close"
    }

    public enum Summary {
        public static let root = "summary.root"
        public static let understood = "summary.understood"
        public static let missed = "summary.missed"
        public static let masteredBanner = "summary.mastered"
        public static let startOverButton = "summary.startOver"
        public static let doneButton = "summary.done"
    }

    public enum Course {
        public static let card = "course.card"
        public static let list = "course.list"
        public static let resetButton = "course.reset"
        public static func lessonRow(_ number: Int) -> String { "course.lesson.\(number)" }
    }

    public enum Lesson {
        public static let step = "lesson.step"
        public static let continueButton = "lesson.continue"
        public static let playAllButton = "lesson.playAll"
        public static let exercisePlay = "lesson.exercise.play"
        public static let explanation = "lesson.explanation"
        public static let nextButton = "lesson.next"
        public static let result = "lesson.result"
        public static let retryButton = "lesson.retry"
        public static let nextLessonButton = "lesson.nextLesson"
        public static let doneButton = "lesson.done"
        public static func word(_ index: Int) -> String { "lesson.word.\(index)" }
        public static func line(_ index: Int) -> String { "lesson.line.\(index)" }
        public static func choice(_ index: Int) -> String { "lesson.choice.\(index)" }
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
            phrases: [Phrase(phrase: "to kick things off", meaning: "to start", translationRu: "для начала")],
            sampleAnswer: "Sure. I'm a [your role] with [number] years of experience."
        ),
        Question(
            id: "fixture-behavioural-1",
            category: .behavioural,
            text: "Can you tell me about a time you tracked down a really tricky bug?",
            rephrase: "Tell me about a difficult bug you found.",
            gist: "Describe a hard bug you investigated.",
            distractors: ["How many bugs do you find a week?", "Which bug tracker do you use?"],
            phrases: [Phrase(phrase: "tracked down", meaning: "found after searching", translationRu: "докопался")],
            sampleAnswer: "Yes. I collected logs, found the exact steps and wrote a clear bug report."
        ),
        Question(
            id: "fixture-behavioural-2",
            category: .behavioural,
            text: "If a developer pushes back and reckons your bug isn't really a bug, how do you handle that?",
            rephrase: "If a developer says your bug is not a real bug, what do you do?",
            gist: "How do you handle a developer who disagrees with your bug?",
            distractors: ["How do you report a bug?", "Have you ever worked as a developer?"],
            phrases: [Phrase(phrase: "reckons", meaning: "thinks", translationRu: "считает")],
            sampleAnswer: "I listen first, then show the facts and the impact on users."
        )
    ])
}

public extension CourseLibrary {
    /// A tiny two-lesson course for UI and snapshot tests, independent of the shipped JSON.
    static let fixture: CourseLibrary = {
        func exercise(_ id: String, kind: Exercise.Kind, say: String?, answer: String, distractors: [String]) -> Exercise {
            Exercise(id: id, kind: kind, say: say, situation: "A resident speaks.", situationRu: "Житель говорит.",
                     answer: answer, distractors: distractors, explanation: "Because.", explanationRu: "Потому что.")
        }
        func lesson(_ number: Int, title: String) -> Lesson {
            Lesson(
                id: "fixture-l\(number)", number: number, title: title, titleRu: "Урок \(number)",
                goalRu: "Цель урока \(number).",
                words: [
                    VocabItem(text: "G'day!", translationRu: "Привет!", aussie: true),
                    VocabItem(text: "I'm a volunteer.", translationRu: "Я волонтер.")
                ],
                dialogue: [
                    DialogueLine(role: .volunteer, speaker: "Nina", text: "Good morning!", translationRu: "Доброе утро!"),
                    DialogueLine(role: .resident, speaker: "Mrs Brown", text: "Pardon, love?", translationRu: "Простите, дорогая?")
                ],
                tip: GrammarTip(title: "to be", ruleRu: "I am, you are, she is.", examples: ["I'm a volunteer."]),
                practice: [exercise("fixture-l\(number)-p1", kind: .listen, say: "Pardon, love?",
                                    answer: "Просит повторить", distractors: ["Просит уйти", "Зовет медсестру"])],
                check: [
                    exercise("fixture-l\(number)-c1", kind: .reply, say: nil,
                             answer: "I'm a volunteer, I'm not allowed to do that.", distractors: ["Sure.", "No."]),
                    exercise("fixture-l\(number)-c2", kind: .slang, say: "Ta.",
                             answer: "Thanks.", distractors: ["Tea.", "Take it."])
                ]
            )
        }
        return CourseLibrary(courses: [Course(
            id: Course.agedCareVolunteerID, title: "Aged care volunteer", subtitle: "English for your first shifts",
            titleRu: "Английский для волонтера", locale: "en-AU",
            lessons: [lesson(1, title: "Meeting a resident"), lesson(2, title: "Who's who")]
        )])
    }()
}
