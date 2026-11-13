import SayAgainKit
import SwiftUI

/// A practice run: one category, or a mix of all when `category` is nil.
struct SessionRoute: Hashable {
    let category: QuestionCategory?
}

struct HomeView: View {
    let environment: AppEnvironment
    @State private var path: [SessionRoute] = []

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
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Say Again")
            .toolbar {
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
    }

    private var tickerPhrases: [String] {
        let phrases = bank.questions.flatMap { $0.phrases.map(\.phrase) }
        return phrases.isEmpty ? ["G'day"] : Array(phrases.prefix(8))
    }

    @ViewBuilder
    private var categories: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Categories")
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)

            if bank.categorySummaries.isEmpty {
                Text("No questions yet.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
                    .accessibilityIdentifier(A11yID.Home.emptyState)
            }

            LazyVStack(spacing: 12) {
                ForEach(Array(bank.categorySummaries.enumerated()), id: \.element.id) { index, summary in
                    let learned = bank.learnedCount(in: summary.category, store: environment.store)
                    NavigationLink(value: SessionRoute(category: summary.category)) {
                        CategoryCard(summary: summary, learned: learned, index: index, animated: motion)
                    }
                    .buttonStyle(PressableCardStyle(animated: motion))
                    .accessibilityLabel("\(summary.category.title), \(CategoryCard.countText(summary.count))")
                    .accessibilityValue("\(learned) of \(summary.count) learned")
                    .accessibilityHint("Starts practice in this category")
                    .accessibilityIdentifier(A11yID.Home.categoryRow(summary.category))
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

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: summary.category.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .symbolEffect(.bounce, options: .speed(0.8), value: appeared && animated)
                .frame(width: 54, height: 54)
                .background(summary.category.tint.gradient, in: .rect(cornerRadius: 16))
                .shadow(color: summary.category.tint.opacity(0.35), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(summary.category.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                HStack(spacing: 6) {
                    Text(Self.countText(summary.count))
                    if learned > 0 {
                        Text("\u{00B7}")
                        Text("\(learned) learned")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                ProgressView(value: Double(learned), total: Double(max(summary.count, 1)))
                    .tint(summary.category.tint)
                    .scaleEffect(y: 0.8, anchor: .center)
            }

            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
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
}

extension QuestionCategory {
    var symbol: String {
        switch self {
        case .intro: "hand.wave.fill"
        case .behavioural: "person.2.fill"
        case .logistics: "dollarsign.circle.fill"
        case .qaIT: "ladybug.fill"
        case .volunteering: "hands.and.sparkles.fill"
        case .agedCare: "heart.text.square.fill"
        case .school: "backpack.fill"
        }
    }

    var tint: Color {
        switch self {
        case .intro: Theme.ocean
        case .behavioural: Color(red: 0.42, green: 0.36, blue: 0.80)
        case .logistics: Color(red: 0.20, green: 0.62, blue: 0.36)
        case .qaIT: Theme.sunset
        case .volunteering: Color(red: 0.84, green: 0.33, blue: 0.52)
        case .agedCare: Color(red: 0.20, green: 0.45, blue: 0.82)
        case .school: Color(red: 0.91, green: 0.58, blue: 0.08)
        }
    }
}

#Preview {
    HomeView(environment: .testing())
}
