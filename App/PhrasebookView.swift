import SayAgainKit
import SwiftUI

/// Every phrase from the questions, by category, with search and audio.
struct PhrasebookView: View {
    let environment: AppEnvironment
    @State private var query = ""
    @Environment(\.showRussian) private var showRussian

    private var sections: [PhrasebookSection] {
        environment.bank.phrasebook(order: environment.settings.categoryOrder, matching: query)
    }

    static func searchPrompt(showRussian: Bool) -> String {
        showRussian ? "Search phrases, meanings, перевод" : "Search phrases and meanings"
    }

    var body: some View {
        PhrasebookList(sections: sections, onSpeak: speak)
            .overlay {
                if sections.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: Self.searchPrompt(showRussian: showRussian))
            .navigationTitle("Phrasebook")
            .navigationBarTitleDisplayMode(.large)
            .onDisappear { environment.speech.stop() }
    }

    private func speak(_ phrase: String) {
        let voice = VoiceRoster.voice(forTurn: 0, from: environment.speech.voices(for: "en-AU"))
        environment.speech.speak(phrase, voice: voice, locale: "en-AU", slow: environment.settings.slowByDefault)
    }
}

/// The phrase list itself, without system chrome (search bar, navigation bar),
/// so snapshots do not depend on how a given iOS version draws that chrome.
struct PhrasebookList: View {
    let sections: [PhrasebookSection]
    let onSpeak: (String) -> Void
    @Environment(\.showRussian) private var showRussian

    var body: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.entries) { entry in
                        Button { onSpeak(entry.phrase) } label: { row(entry) }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityHint("Plays the phrase")
                            .accessibilityIdentifier(A11yID.Phrasebook.row(entry.phrase))
                    }
                } header: {
                    HStack(spacing: 10) {
                        CategoryIcon(category: section.category, size: 26)
                        Text(section.category.title)
                        Spacer()
                        Text("\(section.entries.count)")
                    }
                    .font(.subheadline.weight(.semibold))
                    .textCase(nil)
                }
            }
        }
        .accessibilityIdentifier(A11yID.Phrasebook.list)
    }

    private func row(_ entry: PhrasebookEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.phrase)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.accent)
                Text(entry.meaning)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                if showRussian, let russian = entry.translationRu {
                    RussianLine(text: russian)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "speaker.wave.2.fill")
                .font(.subheadline)
                .foregroundStyle(Theme.accent.opacity(0.7))
                .padding(.top, 2)
        }
        .contentShape(.rect)
        .padding(.vertical, 2)
    }
}
