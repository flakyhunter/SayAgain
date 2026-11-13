import SayAgainKit
import SwiftUI

struct HomeView: View {
    let bank: QuestionBank
    /// Off in UI tests, snapshot tests and with Reduce Motion, so every frame is deterministic.
    var animated: Bool = true

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Bool { animated && !reduceMotion }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HeroCard(phrases: tickerPhrases, animated: motion)
                    categories
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 32)
            }
            .accessibilityIdentifier(A11yID.Home.list)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Say Again")
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

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(Array(bank.categorySummaries.enumerated()), id: \.element.id) { index, summary in
                    CategoryCard(summary: summary, index: index, animated: motion)
                }
            }
        }
    }
}

// MARK: - Hero

private struct HeroCard: View {
    let phrases: [String]
    let animated: Bool

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

            phraseBubble
        }
        .foregroundStyle(.white)
        .padding(22)
        .background(Theme.heroGradient, in: .rect(cornerRadius: 28))
        .shadow(color: Theme.ocean.opacity(0.25), radius: 18, y: 8)
        .task(id: animated) { await cyclePhrases() }
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
    let index: Int
    let animated: Bool

    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: summary.category.symbol)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(summary.category.tint.gradient, in: .rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 2) {
                Text(summary.category.title)
                    .font(.headline)
                    .lineLimit(2, reservesSpace: true)
                Text(Self.countText(summary.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 16)
        .onAppear {
            guard animated else { appeared = true; return }
            withAnimation(.spring(duration: 0.55).delay(0.08 * Double(index))) { appeared = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(summary.category.title), \(Self.countText(summary.count))")
        .accessibilityIdentifier(A11yID.Home.categoryRow(summary.category))
    }

    static func countText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "question" : "questions")"
    }
}

// MARK: - Theme

enum Theme {
    static let ocean = Color(red: 0.02, green: 0.42, blue: 0.52)
    static let sunset = Color(red: 0.96, green: 0.52, blue: 0.22)
    static let heroGradient = LinearGradient(
        colors: [ocean, Color(red: 0.13, green: 0.55, blue: 0.62), sunset],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

extension QuestionCategory {
    var symbol: String {
        switch self {
        case .intro: "hand.wave.fill"
        case .behavioural: "person.2.fill"
        case .logistics: "dollarsign.circle.fill"
        case .qaIT: "ladybug.fill"
        }
    }

    var tint: Color {
        switch self {
        case .intro: Theme.ocean
        case .behavioural: Color(red: 0.42, green: 0.36, blue: 0.80)
        case .logistics: Color(red: 0.20, green: 0.62, blue: 0.36)
        case .qaIT: Theme.sunset
        }
    }
}

#Preview("Animated") {
    HomeView(bank: .fixture)
}

#Preview("Static") {
    HomeView(bank: .fixture, animated: false)
}
