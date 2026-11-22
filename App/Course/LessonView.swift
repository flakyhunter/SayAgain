import SayAgainKit
import SwiftUI

struct LessonView: View {
    @State var model: LessonViewModel
    var onDone: () -> Void = {}
    var onNextLesson: (Lesson) -> Void = { _ in }

    var body: some View {
        Group {
            if let result = model.result {
                LessonResultView(
                    result: result,
                    lesson: model.lesson,
                    nextLesson: model.nextLesson,
                    animated: model.animated,
                    onRetry: model.retryCheck,
                    onNextLesson: onNextLesson,
                    onDone: onDone
                )
            } else {
                stepScreen
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Lesson \(model.lesson.number)")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.leave() }
    }

    private var stepScreen: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    stepHeader.id("top")
                    switch model.step {
                    case .words: WordsStep(model: model)
                    case .dialogue: DialogueStep(model: model)
                    case .tip: if let tip = model.lesson.tip { TipStep(tip: tip) }
                    case .practice, .check: ExerciseStep(model: model, proxy: proxy)
                    case nil: EmptyView()
                    }
                }
                .padding(20)
            }
            .onChange(of: model.stepIndex) { scrollToTop(proxy) }
            .onChange(of: model.run?.index) { scrollToTop(proxy) }
        }
        .safeAreaInset(edge: .bottom) { bottomBar }
    }

    private func scrollToTop(_ proxy: ScrollViewProxy) {
        if model.animated {
            withAnimation(.easeInOut(duration: 0.3)) { proxy.scrollTo("top", anchor: .top) }
        } else {
            proxy.scrollTo("top", anchor: .top)
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(Self.stepText(model.step, index: model.stepIndex, count: model.steps.count, run: model.run,
                               tipLabel: model.course.tipLabel))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ProgressView(value: Double(model.stepIndex), total: Double(max(model.steps.count, 1)))
                .tint(Theme.accent)
            if model.stepIndex == 0 {
                Text(model.lesson.title).font(.title2.bold())
                Text(model.lesson.goal)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                RussianLine(text: model.lesson.goalRu)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(A11yID.Lesson.step)
    }

    static func stepText(
        _ step: Lesson.Step?, index: Int, count: Int, run: ExerciseRun?, tipLabel: String = Course.defaultTipLabel
    ) -> String {
        let name = switch step {
        case .words: "Words"
        case .dialogue: "Dialogue"
        case .tip: tipLabel
        case .practice: "Practice"
        case .check: "Check"
        case nil: ""
        }
        let base = "Step \(index + 1) of \(count): \(name)"
        guard let run, run.phase != .finished else { return base }
        return "\(base), \(run.position) of \(run.exercises.count)"
    }

    @ViewBuilder
    private var bottomBar: some View {
        let exerciseStep = model.step == .practice || model.step == .check
        if !exerciseStep || model.isRevealed {
            Button {
                if model.animated {
                    withAnimation(.spring(duration: 0.4)) { exerciseStep ? model.next() : model.advance() }
                } else {
                    exerciseStep ? model.next() : model.advance()
                }
            } label: {
                Label(exerciseStep ? "Next" : "Continue", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.white)
                    .background(Theme.ocean, in: .rect(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(exerciseStep ? A11yID.Lesson.nextButton : A11yID.Lesson.continueButton)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemGroupedBackground).shadow(.drop(color: .black.opacity(0.08), radius: 8, y: -2)))
        }
    }
}

// MARK: - Words

private struct WordsStep: View {
    let model: LessonViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tap a word to hear it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(Array(model.lesson.words.enumerated()), id: \.offset) { index, word in
                Button { model.play(word: word) } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "speaker.wave.2.fill")
                            .foregroundStyle(Theme.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(word.text).font(.body.weight(.semibold))
                                if word.aussie { AussieBadge() }
                            }
                            RussianLine(text: word.translationRu)
                            if let note = word.note {
                                Text(note)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let noteRu = word.noteRu {
                                RussianLine(text: noteRu)
                                    .font(.footnote)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .multilineTextAlignment(.leading)
                    }
                    .padding(14)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                    .contentShape(.rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Plays the word")
                .accessibilityIdentifier(A11yID.Lesson.word(index))
            }
        }
    }
}

/// Marks Australian slang and typically Aussie ways to say things.
struct AussieBadge: View {
    var body: some View {
        Text("Aussie")
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(Theme.sunset, in: .capsule)
            .accessibilityLabel("Australian slang")
    }
}

/// Marks a "what do you do" task, so it is not mistaken for a language question.
struct ScenarioBadge: View {
    var body: some View {
        Text("What do you do?")
            .font(.caption2.weight(.bold))
            .textCase(.uppercase)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .foregroundStyle(.white)
            .background(Theme.ocean, in: .capsule)
    }
}

// MARK: - Dialogue

private struct DialogueStep: View {
    let model: LessonViewModel
    @Environment(\.showRussian) private var showRussian

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: model.playDialogue) {
                Label("Play the whole dialogue", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundStyle(Theme.accent)
                    .background(Theme.accent.opacity(0.15), in: .rect(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(A11yID.Lesson.playAllButton)

            Text("Tap a line to hear it again.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(Array(model.lesson.dialogue.enumerated()), id: \.offset) { index, line in
                let mine = line.role == .volunteer
                Button { model.play(line: line) } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(line.speaker)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(mine ? .white.opacity(0.85) : Theme.accent)
                        Text(line.text)
                            .font(.body.weight(.medium))
                            .foregroundStyle(mine ? .white : .primary)
                        if showRussian {
                            Text(line.translationRu)
                                .font(.subheadline)
                                .italic()
                                .foregroundStyle(mine ? .white.opacity(0.8) : .secondary)
                        }
                    }
                    .multilineTextAlignment(.leading)
                    .padding(12)
                    .background(
                        mine ? AnyShapeStyle(Theme.ocean) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)),
                        in: .rect(cornerRadius: 16)
                    )
                    .frame(maxWidth: 300, alignment: mine ? .trailing : .leading)
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: mine ? .trailing : .leading)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Plays the line")
                .accessibilityIdentifier(A11yID.Lesson.line(index))
            }
        }
    }
}

// MARK: - Tip

private struct TipStep: View {
    let tip: GrammarTip

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(tip.title, systemImage: "lightbulb.fill")
                .font(.title3.bold())
                .foregroundStyle(Theme.accent)
            Text(tip.rule)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            RussianLine(text: tip.ruleRu)
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(tip.examples, id: \.self) { example in
                    Text(example).font(.body.weight(.semibold))
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.1), in: .rect(cornerRadius: 14))
        }
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
    }
}

// MARK: - Exercises

private struct ExerciseStep: View {
    let model: LessonViewModel
    let proxy: ScrollViewProxy

    var body: some View {
        if let run = model.run, let exercise = run.current {
            VStack(alignment: .leading, spacing: 16) {
                if model.step == .check {
                    Label("Check: \(model.lesson.passPercent)% to open the next lesson", systemImage: "checkmark.seal")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.sunset)
                }
                prompt(exercise)
                VStack(spacing: 10) {
                    ForEach(Array(run.choices.enumerated()), id: \.element) { index, choice in
                        ChoiceButton(text: choice, translation: exercise.translationRu(of: choice),
                                     state: state(choice, run: run, exercise: exercise)) {
                            if model.animated {
                                withAnimation(.spring(duration: 0.4)) { model.choose(choice) } completion: {
                                    withAnimation { proxy.scrollTo("explanation", anchor: .bottom) }
                                }
                            } else {
                                model.choose(choice)
                            }
                        }
                        .allowsHitTesting(!model.isRevealed)
                        .accessibilityIdentifier(A11yID.Lesson.choice(index))
                    }
                }
                if model.isRevealed {
                    explanation(exercise, correct: run.phase == .revealed(correct: true))
                        .id("explanation")
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .task(id: exercise.id) { model.autoplayExerciseIfNew() }
        }
    }

    private func prompt(_ exercise: Exercise) -> some View {
        HStack(alignment: .center, spacing: 16) {
            if exercise.say != nil {
                Button(action: model.playExercise) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(Theme.heroGradient, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play again")
                .accessibilityIdentifier(A11yID.Lesson.exercisePlay)
            }
            VStack(alignment: .leading, spacing: 6) {
                if exercise.kind == .slang { AussieBadge() }
                if exercise.kind == .scenario { ScenarioBadge() }
                Text(exercise.situation)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
                RussianLine(text: exercise.situationRu)
                    .fixedSize(horizontal: false, vertical: true)
                if model.isRevealed, let say = exercise.say {
                    Text("\u{201C}\(say)\u{201D}")
                        .font(.subheadline.italic())
                        .foregroundStyle(.secondary)
                } else if exercise.say != nil {
                    Text(Self.listenHint(exercise.kind))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }

    static func listenHint(_ kind: Exercise.Kind) -> String {
        switch kind {
        case .reply: "Listen, then choose your reply."
        case .scenario: "Listen, then choose what you do."
        case .listen, .slang: "Listen. The text is hidden on purpose."
        }
    }

    private func state(_ choice: String, run: ExerciseRun, exercise: Exercise) -> ChoiceButton.State {
        guard model.isRevealed else { return .idle }
        if choice == exercise.answer { return .correct }
        if choice == run.selected { return .wrong }
        return .dimmed
    }

    private func explanation(_ exercise: Exercise, correct: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(correct ? "Right!" : "Not quite", systemImage: correct ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.headline)
                .foregroundStyle(correct ? Theme.success : Theme.danger)
            Text(exercise.explanation)
                .font(.body)
                .fixedSize(horizontal: false, vertical: true)
            RussianLine(text: exercise.explanationRu)
                .fixedSize(horizontal: false, vertical: true)
            if exercise.kind.answerIsEnglish {
                Button(action: model.playAnswer) {
                    Label("Hear the right answer", systemImage: "speaker.wave.2.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Lesson.explanation)
    }
}

// MARK: - Result

private struct LessonResultView: View {
    let result: LessonResult
    let lesson: Lesson
    let nextLesson: Lesson?
    let animated: Bool
    let onRetry: () -> Void
    let onNextLesson: (Lesson) -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()
            Image(systemName: result.passed ? "checkmark.seal.fill" : "arrow.clockwise.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(result.passed ? Theme.gold : Theme.sunset)
                .symbolEffect(.bounce, value: animated)
            VStack(spacing: 8) {
                Text(result.passed ? "Lesson \(lesson.number) passed!" : "Almost there")
                    .font(.title.bold())
                Text("\(result.correct) of \(result.total) right, \(result.score)%")
                    .font(.title3)
                RussianLine(text: result.passed
                    ? (result.unlockedNext != nil ? "Следующий урок открыт." : "Урок пройден.")
                    : "Нужно \(result.passPercent)%. Повторите проверку, слова и диалог можно пересмотреть.")
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11yID.Lesson.result)
            Spacer()
            VStack(spacing: 12) {
                if result.passed, let nextLesson {
                    primary("Next lesson", systemImage: "arrow.right", id: A11yID.Lesson.nextLessonButton) { onNextLesson(nextLesson) }
                }
                if !result.passed {
                    primary("Try the check again", systemImage: "arrow.clockwise", id: A11yID.Lesson.retryButton, action: onRetry)
                }
                Button("Back to lessons", action: onDone)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Theme.accent)
                    .background(Theme.accent.opacity(0.15), in: .rect(cornerRadius: 16))
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(A11yID.Lesson.doneButton)
            }
        }
        .padding(24)
    }

    private func primary(_ title: String, systemImage: String, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(.white)
                .background(Theme.ocean, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
