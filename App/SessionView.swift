import SayAgainKit
import SwiftUI

struct SessionView: View {
    @State var model: SessionViewModel
    var autoplay = true
    var onDone: () -> Void = {}
    @State private var showingSampleAnswer = false

    var body: some View {
        Group {
            if model.isFinished {
                SummaryView(
                    summary: model.session.summary,
                    mastered: model.justMastered ? model.category : nil,
                    masteredCount: model.categoryQuestionCount,
                    animated: model.animated,
                    onStartOver: {
                        model.startCategoryOver()
                        onDone()
                    },
                    onDone: onDone
                )
            } else if let question = model.session.current {
                questionScreen(question)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.leave() }
    }

    private func questionScreen(_ question: Question) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    progress.id("top")
                    ListenCard(model: model)
                    choices(for: question, proxy: proxy)
                    if model.isRevealed {
                        RevealCard(question: question, correct: model.choiceCorrect == true)
                            .id("reveal")
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .bottom) {
                if model.isRevealed { rateBar }
            }
            .onChange(of: model.isRevealed) { _, revealed in
                guard !revealed else { return }
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(120))
                    withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo("top", anchor: .top) }
                }
            }
        }
        .task(id: question.id) {
            if autoplay { model.playIfNotPlayedYet() }
        }
        .sheet(isPresented: $showingSampleAnswer) {
            SampleAnswerView(question: question, onListen: model.playSampleAnswer)
                .onDisappear { model.leave() }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Question \(model.session.position) of \(model.session.questions.count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            ProgressView(value: Double(model.session.index), total: Double(model.session.questions.count))
                .tint(Theme.accent)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Question \(model.session.position) of \(model.session.questions.count)")
        .accessibilityIdentifier(A11yID.Session.progress)
    }

    private func choices(for question: Question, proxy: ScrollViewProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What did they ask?")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(model.session.choices.enumerated()), id: \.element) { index, choice in
                ChoiceButton(
                    text: choice,
                    state: choiceState(choice, gist: question.gist)
                ) {
                    withAnimation(.spring(duration: 0.4)) {
                        model.choose(choice)
                    } completion: {
                        // Scroll only after the explanation has finished appearing, whatever it took.
                        // Bottom anchor: the whole explanation sits above the bottom bar
                        // and the chosen answer stays visible above it.
                        withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo("reveal", anchor: .bottom) }
                    }
                }
                // Not .disabled: it would fade the green and red answers.
                .allowsHitTesting(!model.isRevealed)
                .accessibilityIdentifier(A11yID.Session.choice(index))
            }
        }
    }

    private func choiceState(_ choice: String, gist: String) -> ChoiceButton.State {
        guard model.isRevealed else { return .idle }
        if choice == gist { return .correct }
        if choice == model.session.selectedChoice { return .wrong }
        return .dimmed
    }

    private var rateBar: some View {
        HStack(spacing: 12) {
            rateButton("Sample answer", systemImage: "text.bubble.fill", style: .secondary,
                       id: A11yID.Session.sampleAnswerButton, animated: false) { showingSampleAnswer = true }
            rateButton("Next", systemImage: "arrow.right", style: .primary,
                       id: A11yID.Session.nextButton) { model.next() }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.systemGroupedBackground).shadow(.drop(color: .black.opacity(0.08), radius: 8, y: -2)))
    }

    private enum RateStyle { case primary, secondary }

    private func rateButton(
        _ title: String, systemImage: String, style: RateStyle, id: String, animated: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if animated { withAnimation(.spring(duration: 0.4)) { action() } } else { action() }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(style == .primary ? .white : Theme.accent)
                .background(
                    style == .primary ? AnyShapeStyle(Theme.ocean) : AnyShapeStyle(Theme.accent.opacity(0.15)),
                    in: .rect(cornerRadius: 16)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

// MARK: - Listen

private struct ListenCard: View {
    @Bindable var model: SessionViewModel

    var body: some View {
        HStack(spacing: 18) {
            Button(action: model.play) {
                Image(systemName: model.playCount == 0 ? "play.fill" : "arrow.clockwise")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 76, height: 76)
                    .background(Theme.heroGradient, in: .circle)
                    .shadow(color: Theme.ocean.opacity(0.3), radius: 10, y: 5)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(model.playCount == 0 ? "Play question" : "Play again")
            .accessibilityValue(Self.playedText(model.playCount))
            .accessibilityIdentifier(A11yID.Session.playButton)

            VStack(alignment: .leading, spacing: 8) {
                if let speaker = model.speaker {
                    Label("\(speaker.name) is asking", systemImage: "person.wave.2.fill")
                        .font(.headline)
                        .foregroundStyle(Theme.accent)
                        .accessibilityIdentifier(A11yID.Session.speaker)
                }
                Text(model.isRevealed ? "Listen again with the text below." : "Listen. The text is hidden on purpose.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Toggle(isOn: Binding(get: { model.slow }, set: { model.setSlow($0) })) {
                    Label("Slower", systemImage: "tortoise.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .toggleStyle(.button)
                .tint(Theme.accent)
                .accessibilityIdentifier(A11yID.Session.slowToggle)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if model.canGetMoreVoices { moreVoicesHint }
        }
    }

    private var moreVoicesHint: some View {
        Label {
            Text("Want different interviewers? Download more English (Australia) voices in Settings > Accessibility > Spoken Content > Voices.")
        } icon: {
            Image(systemName: "person.3.fill")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .accessibilityIdentifier(A11yID.Session.moreVoicesHint)
    }

    static func playedText(_ count: Int) -> String {
        switch count {
        case 0: "Not played yet"
        case 1: "Played once"
        default: "Played \(count) times"
        }
    }
}

// MARK: - Choices

private struct ChoiceButton: View {
    enum State { case idle, correct, wrong, dimmed }

    let text: String
    let state: State
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(text)
                    .font(.body.weight(.medium))
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let icon {
                    Image(systemName: icon).font(.headline)
                }
            }
            .foregroundStyle(foreground)
            .padding(16)
            .background(background, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(border, lineWidth: 2))
            .opacity(state == .dimmed ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityValue(accessibilityValue)
    }

    private var icon: String? {
        switch state {
        case .correct: "checkmark.circle.fill"
        case .wrong: "xmark.circle.fill"
        default: nil
        }
    }

    private var foreground: Color {
        switch state {
        case .correct: Theme.success
        case .wrong: Theme.danger
        default: .primary
        }
    }

    private var background: Color {
        switch state {
        case .correct: Theme.success.opacity(0.12)
        case .wrong: Theme.danger.opacity(0.12)
        default: Color(.secondarySystemGroupedBackground)
        }
    }

    private var border: Color {
        switch state {
        case .correct: Theme.success
        case .wrong: Theme.danger
        default: .clear
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .correct: "Correct answer"
        case .wrong: "Your answer, wrong"
        default: ""
        }
    }
}

// MARK: - Reveal

private struct RevealCard: View {
    let question: Question
    let correct: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(correct ? "Nice, you got the meaning." : "Not quite. Here is what they asked.",
                  systemImage: correct ? "hand.thumbsup.fill" : "ear.trianglebadge.exclamationmark")
                .font(.headline)
                .foregroundStyle(correct ? Theme.success : Theme.sunset)
                .accessibilityIdentifier(A11yID.Session.resultBanner)

            section("They said") {
                Text("\u{201C}\(question.text)\u{201D}")
                    .font(.body.italic())
                    .accessibilityIdentifier(A11yID.Session.originalText)
            }
            section("In plain English") {
                Text(question.rephrase)
            }
            section("Phrases to know") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(question.phrases, id: \.self) { phrase in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(phrase.phrase).font(.body.weight(.semibold)).foregroundStyle(Theme.accent)
                            Text(phrase.meaning).font(.subheadline).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Session.reveal)
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
    }
}

// MARK: - Summary

struct SummaryView: View {
    let summary: PracticeSession.Summary
    /// Set when this session completed a whole category.
    var mastered: QuestionCategory? = nil
    var masteredCount = 0
    var animated = false
    var onStartOver: () -> Void = {}
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            if let mastered {
                CategoryIcon(category: mastered, size: 104, bounce: animated)
                VStack(spacing: 8) {
                    Text("You've mastered \(mastered.title)!")
                        .font(.largeTitle.bold())
                        .multilineTextAlignment(.center)
                    Text("You understand all \(masteredCount) questions by ear. Good on ya!")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(A11yID.Summary.masteredBanner)
            } else {
                Image(systemName: summary.missed == 0 ? "star.circle.fill" : "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(Theme.heroGradient)
                VStack(spacing: 6) {
                    Text("Session done").font(.largeTitle.bold())
                    Text(headline).font(.body).foregroundStyle(.secondary).multilineTextAlignment(.center)
                }
            }
            HStack(spacing: 12) {
                tile("Understood", value: summary.gotIt + summary.partly, color: Theme.success, id: A11yID.Summary.understood)
                tile("Missed", value: summary.missed, color: Theme.sunset, id: A11yID.Summary.missed)
            }
            Spacer()
            VStack(spacing: 10) {
                if mastered != nil {
                    Button(action: onStartOver) {
                        Label("Start over", systemImage: "arrow.counterclockwise")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .foregroundStyle(Theme.accent)
                            .background(Theme.accent.opacity(0.15), in: .rect(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Resets this category so you can practise it again from the start")
                    .accessibilityIdentifier(A11yID.Summary.startOverButton)
                }
                Button(action: onDone) {
                    Text("Back to home")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .foregroundStyle(.white)
                        .background(Theme.ocean, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(A11yID.Summary.doneButton)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .overlay {
            if mastered != nil && animated {
                ConfettiView().allowsHitTesting(false).ignoresSafeArea()
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Summary.root)
    }

    private var headline: String {
        summary.missed == 0
            ? "You understood every question. Good on ya!"
            : "Missed questions will come back sooner next time."
    }

    private func tile(_ title: String, value: Int, color: Color, id: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)").font(.system(size: 34, weight: .bold, design: .rounded)).foregroundStyle(color)
            Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityValue("\(value)")
        .accessibilityIdentifier(id)
    }
}

/// A short burst of falling confetti, drawn with Canvas. Stops by itself after a few seconds.
struct ConfettiView: View {
    private struct Piece {
        let x: Double, delay: Double, speed: Double, drift: Double, spin: Double, size: Double, color: Color
    }

    private static let colors: [Color] = [
        Theme.sunset, Theme.ocean, Color(red: 0.95, green: 0.78, blue: 0.20),
        Color(red: 0.62, green: 0.52, blue: 1.00), Color(red: 1.00, green: 0.52, blue: 0.66),
        Color(red: 0.38, green: 0.86, blue: 0.58)
    ]
    private static let duration = 4.0

    @State private var start = Date()
    private let pieces: [Piece] = {
        var generator = SeededGenerator(seed: 7)
        return (0..<90).map { _ in
            Piece(
                x: Double.random(in: 0...1, using: &generator),
                delay: Double.random(in: 0...0.8, using: &generator),
                speed: Double.random(in: 0.25...0.45, using: &generator),
                drift: Double.random(in: -40...40, using: &generator),
                spin: Double.random(in: 2...7, using: &generator),
                size: Double.random(in: 6...11, using: &generator),
                color: colors[Int.random(in: 0..<colors.count, using: &generator)]
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(paused: Date().timeIntervalSince(start) > Self.duration)) { context in
            Canvas { canvas, size in
                let elapsed = context.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed * size.height
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 2.2 + piece.x * 10) * piece.drift
                    let fade = max(0, 1 - max(0, elapsed - (Self.duration - 1)))
                    var context = canvas
                    context.opacity = fade
                    context.translateBy(x: x, y: y)
                    context.rotate(by: .radians(t * piece.spin))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(piece.color))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
