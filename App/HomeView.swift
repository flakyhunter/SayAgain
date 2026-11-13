import SayAgainKit
import SwiftUI

/// A practice run: one category, or a mix of all when `category` is nil.
struct SessionRoute: Hashable {
    let category: QuestionCategory?
}

struct HomeView: View {
    let environment: AppEnvironment
    @State private var path: [SessionRoute] = []
    /// Category waiting for "Start over" confirmation.
    @State private var startOverCandidate: QuestionCategory?
    /// Bumped after a reset so the progress on the cards is read again.
    @State private var progressVersion = 0
    /// The card being dragged to a new place.
    @State private var dragging: QuestionCategory?
    private var summaries: [CategorySummary] { bank.categorySummaries(order: environment.settings.categoryOrder) }

    private func shift(_ category: QuestionCategory, by offset: Int) {
        environment.settings.categoryOrder = CategoryOrder.shift(category, by: offset, in: environment.settings.categoryOrder)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var bank: QuestionBank { environment.bank }
    /// Off in UI tests, snapshot tests and with Reduce Motion, so every frame is deterministic.
    private var motion: Bool { environment.animated && !reduceMotion }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HeroCard(phrases: tickerPhrases, animated: motion, canStart: !bank.questions.isEmpty)
                    categories
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .accessibilityIdentifier(A11yID.Home.list)
            .onDrop(of: [.text], isTargeted: nil) { _ in
                dragging = nil
                return true
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Say Again")
            // Back from practice (Done or the back button): progress may have changed.
            .onChange(of: path) {
                progressVersion += 1
                dragging = nil
            }
            .confirmationDialog(
                "Start \(startOverCandidate?.title ?? "") over?",
                isPresented: Binding(get: { startOverCandidate != nil }, set: { if !$0 { startOverCandidate = nil } }),
                titleVisibility: .visible
            ) {
                Button("Start over", role: .destructive) {
                    if let category = startOverCandidate {
                        bank.resetProgress(in: category, store: environment.store)
                        progressVersion += 1
                    }
                    startOverCandidate = nil
                }
                .accessibilityIdentifier(A11yID.Home.startOverConfirmButton)
            } message: {
                Text("Progress in this category goes back to zero. Other categories stay as they are.")
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        PhrasebookView(environment: environment)
                    } label: {
                        Image(systemName: "character.book.closed.fill")
                    }
                    .accessibilityLabel("Phrasebook")
                    .accessibilityIdentifier(A11yID.Home.phrasebookButton)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        SettingsView(model: SettingsViewModel(environment: environment))
                    } label: {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier(A11yID.Home.settingsButton)
                }
            }
            .navigationDestination(for: SessionRoute.self) { route in
                SessionView(
                    model: environment.makeSession(category: route.category),
                    onDone: { path.removeAll() }
                )
                .navigationTitle(route.category?.title ?? "Mixed practice")
            }
        }
        .environment(\.showRussian, environment.settings.showRussian)
    }

    private var tickerPhrases: [String] {
        let phrases = bank.questions.flatMap { $0.phrases.map(\.phrase) }
        return phrases.isEmpty ? ["G'day"] : Array(phrases.prefix(8))
    }

    @ViewBuilder
    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Categories")
                    .font(.title3.bold())
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if summaries.count > 1 {
                    Label("Hold and drag to reorder", systemImage: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
            }

            if summaries.isEmpty {
                Text("No questions yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                    .accessibilityIdentifier(A11yID.Home.emptyState)
            }

            LazyVStack(spacing: 12) {
                ForEach(Array(summaries.enumerated()), id: \.element.id) { index, summary in
                    // Reading the version makes SwiftUI recompute progress after a session or a reset.
                    let learned = progressVersion >= 0
                        ? bank.learnedCount(in: summary.category, store: environment.store) : 0
                    let mastered = learned == summary.count
                    ZStack(alignment: .trailing) {
                    NavigationLink(value: SessionRoute(category: summary.category)) {
                        CategoryCard(summary: summary, learned: learned, index: index, animated: motion)
                    }
                    .buttonStyle(PressableCardStyle(animated: motion))
                    .accessibilityLabel("\(summary.category.title), \(CategoryCard.countText(summary.count))")
                    .accessibilityValue(CategoryCard.progressText(learned: learned, count: summary.count)
                        + (mastered ? ", mastered" : ""))
                    .accessibilityHint("Starts practice in this category")
                    .accessibilityIdentifier(A11yID.Home.categoryRow(summary.category))

                        // A sibling of the link, not inside it, so it is its own button for VoiceOver and taps.
                        if mastered {
                            Button {
                                startOverCandidate = summary.category
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 40, height: 40)
                                    .background(Theme.accent.opacity(0.14), in: .circle)
                            }
                            .buttonStyle(.plain)
                            .padding(.trailing, 14)
                            .accessibilityLabel("Start \(summary.category.title) over")
                            .accessibilityIdentifier(A11yID.Home.startOverButton(summary.category))
                        }
                    }
                    .opacity(dragging == summary.category ? 0.35 : 1)
                    .onDrag {
                        dragging = summary.category
                        return NSItemProvider(object: summary.category.rawValue as NSString)
                    }
                    .onDrop(of: [.text], delegate: CategoryDropDelegate(
                        target: summary.category, dragging: $dragging, settings: environment.settings, animated: motion
                    ))
                    .contextMenu {
                        Button("Start over", systemImage: "arrow.counterclockwise", role: .destructive) {
                            startOverCandidate = summary.category
                        }
                        .disabled(learned == 0)
                    }
                    .accessibilityAction(named: "Move up") { shift(summary.category, by: -1) }
                    .accessibilityAction(named: "Move down") { shift(summary.category, by: 1) }

                    .scrollTransition(.interactive, axis: .vertical) { content, phase in
                        // Rows shrink and fade a little as they reach the screen edges.
                        let edge = motion && !phase.isIdentity
                        return content
                            .scaleEffect(edge ? 0.93 : 1)
                            .opacity(edge ? 0.55 : 1)
                            .blur(radius: edge ? 1.5 : 0)
                    }
                }
            }
        }
    }
}

/// Live reordering: while a card is dragged over another, they swap places.
private struct CategoryDropDelegate: DropDelegate {
    let target: QuestionCategory
    @Binding var dragging: QuestionCategory?
    let settings: AppSettings
    let animated: Bool

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != target else { return }
        let reorder = { settings.categoryOrder = CategoryOrder.move(dragging, to: target, in: settings.categoryOrder) }
        if animated { withAnimation(.spring(duration: 0.35, bounce: 0.25), reorder) } else { reorder() }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}

/// Cards sink a little under the finger.
private struct PressableCardStyle: ButtonStyle {
    let animated: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(animated && configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(duration: 0.25, bounce: 0.4), value: configuration.isPressed)
    }
}

// MARK: - Hero

private struct HeroCard: View {
    let phrases: [String]
    let animated: Bool
    let canStart: Bool

    @State private var phraseIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Understand Aussie interview questions by ear.")
                        .font(.title3.bold())
                    Text("Listen first, then check what they really asked.")
                        .font(.subheadline)
                        .opacity(0.85)
                }
                Spacer(minLength: 12)
                Image(systemName: "ear.badge.waveform")
                    .font(.system(size: 34, weight: .semibold))
                    .symbolEffect(.pulse, isActive: animated)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(A11yID.Home.header)

            Waveform(animated: animated)
                .frame(height: 44)
                .accessibilityHidden(true)

            HStack(alignment: .center) {
                phraseBubble
                Spacer(minLength: 8)
                if canStart { startButton }
            }
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(Theme.heroGradient, in: .rect(cornerRadius: 28))
        .shadow(color: Theme.ocean.opacity(0.25), radius: 18, y: 8)
        .task(id: animated) { await cyclePhrases() }
    }

    private var startButton: some View {
        NavigationLink(value: SessionRoute(category: nil)) {
            Label("Start", systemImage: "play.fill")
                .font(.headline)
                .foregroundStyle(Theme.ocean)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(.white, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start mixed practice")
        .accessibilityIdentifier(A11yID.Home.startButton)
    }

    private var phraseBubble: some View {
        HStack(spacing: 8) {
            Image(systemName: "quote.bubble.fill")
            Text("\u{201C}\(phrases[phraseIndex])\u{201D}")
                .id(phraseIndex)
                .transition(.push(from: .bottom).combined(with: .opacity))
                .lineLimit(1)
        }
        .font(.callout.weight(.semibold))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.white.opacity(0.18), in: .capsule)
        .clipped()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Example phrase: \(phrases[phraseIndex])")
    }

    private func cyclePhrases() async {
        guard animated, phrases.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(2.6))
            withAnimation(.spring(duration: 0.5)) {
                phraseIndex = (phraseIndex + 1) % phrases.count
            }
        }
    }
}

/// Audio-style bars. Static (fixed phase) when not animated.
private struct Waveform: View {
    let animated: Bool
    private let barCount = 28

    var body: some View {
        if animated {
            TimelineView(.animation) { context in
                bars(phase: context.date.timeIntervalSinceReferenceDate * 3)
            }
        } else {
            bars(phase: 0.8)
        }
    }

    private func bars(phase: Double) -> some View {
        GeometryReader { geometry in
            HStack(alignment: .center, spacing: 4) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(.white.opacity(0.9))
                        .frame(height: max(4, geometry.size.height * level(index, phase)))
                        .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private func level(_ index: Int, _ phase: Double) -> Double {
        let x = Double(index)
        let wave = sin(x * 0.55 + phase) * 0.5 + sin(x * 0.23 - phase * 0.7) * 0.5
        return 0.25 + 0.75 * abs(wave)
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let summary: CategorySummary
    let learned: Int
    let index: Int
    let animated: Bool

    @State private var appeared = false
    private var mastered: Bool { learned == summary.count && summary.count > 0 }

    var body: some View {
        HStack(spacing: 16) {
            CategoryIcon(category: summary.category, bounce: appeared && animated)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(summary.category.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if mastered {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Theme.gold)
                            .symbolEffect(.bounce, value: appeared && animated)
                    }
                }
                Text(Self.progressText(learned: learned, count: summary.count))
                    .font(.subheadline)
                    .foregroundStyle(mastered ? Theme.gold : .secondary)
                ProgressView(value: Double(learned), total: Double(max(summary.count, 1)))
                    .tint(mastered ? Theme.gold : summary.category.tint)
                    .scaleEffect(y: 0.8, anchor: .center)
            }

            if mastered {
                // Keeps room for the round "Start over" button drawn on top of the card.
                Color.clear.frame(width: 40, height: 40)
            } else {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 60)
        .onAppear {
            guard animated else { appeared = true; return }
            withAnimation(.spring(duration: 0.6, bounce: 0.3).delay(0.06 * Double(index))) { appeared = true }
        }
    }

    static func countText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "question" : "questions")"
    }

    /// "15 questions" before the first right answer, then "8 of 15 understood", then "All 15 understood".
    static func progressText(learned: Int, count: Int) -> String {
        if learned == 0 { return countText(count) }
        if learned == count { return count == 1 ? "Understood" : "All \(count) understood" }
        return "\(learned) of \(count) understood"
    }
}

/// Glossy two-tone app-style icon: gradient body, top highlight, hairline rim, duotone symbol.
struct CategoryIcon: View {
    let category: QuestionCategory
    var size: CGFloat = 56
    var bounce = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
        let colors = category.gradient
        ZStack {
            shape.fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            // Soft light from the top, like glass.
            shape.fill(LinearGradient(
                colors: [.white.opacity(0.38), .white.opacity(0.06), .clear],
                startPoint: .top, endPoint: .center
            ))
            // A glow behind the symbol.
            Circle()
                .fill(.white.opacity(0.22))
                .frame(width: size * 0.62)
                .blur(radius: size * 0.14)
            Image(systemName: category.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .white.opacity(0.62))
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1.5)
                .symbolEffect(.bounce, options: .speed(0.8), value: bounce)
        }
        .frame(width: size, height: size)
        .overlay(shape.strokeBorder(
            LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.05)], startPoint: .top, endPoint: .bottom),
            lineWidth: 1
        ))
        .shadow(color: colors.last!.opacity(0.4), radius: 10, y: 5)
        .accessibilityHidden(true)
    }
}

extension QuestionCategory {
    var symbol: String {
        switch self {
        case .intro: "hand.wave.fill"
        case .behavioural: "bubble.left.and.bubble.right.fill"
        case .logistics: "banknote.fill"
        case .qaIT: "ladybug.fill"
        case .volunteering: "hands.and.sparkles.fill"
        case .agedCare: "stethoscope"
        case .school: "graduationcap.fill"
        }
    }

    /// Two tones per category, light top-left to deep bottom-right.
    var gradient: [Color] {
        func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color { Color(red: r, green: g, blue: b) }
        return switch self {
        case .intro: [rgb(0.20, 0.78, 0.84), rgb(0.02, 0.40, 0.55)]
        case .behavioural: [rgb(0.62, 0.52, 1.00), rgb(0.33, 0.24, 0.78)]
        case .logistics: [rgb(0.38, 0.86, 0.58), rgb(0.07, 0.52, 0.36)]
        case .qaIT: [rgb(1.00, 0.72, 0.36), rgb(0.93, 0.36, 0.16)]
        case .volunteering: [rgb(1.00, 0.52, 0.66), rgb(0.80, 0.20, 0.45)]
        case .agedCare: [rgb(0.42, 0.70, 1.00), rgb(0.14, 0.36, 0.84)]
        case .school: [rgb(1.00, 0.84, 0.30), rgb(0.95, 0.52, 0.05)]
        }
    }

    /// Main colour of the category, used for its progress bar.
    var tint: Color { gradient.last! }
}

#Preview {
    HomeView(environment: .testing())
}
