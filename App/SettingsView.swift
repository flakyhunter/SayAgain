import SayAgainKit
import SwiftUI

@MainActor
@Observable
final class SettingsViewModel {
    static let previewLine = "G'day! Ready for your interview?"
    static let locale = "en-AU"
    static let sourceURL = URL(string: "https://github.com/flakyhunter/SayAgain")!

    let settings: AppSettings
    /// Injected so snapshots do not change with every version bump.
    let version: String
    private(set) var progressWasReset = false

    @ObservationIgnored private let speech: SpeechService
    @ObservationIgnored private let store: ProgressStore

    init(environment: AppEnvironment, version: String = SettingsViewModel.appVersion) {
        settings = environment.settings
        self.version = version
        speech = environment.speech
        store = environment.store
    }

    /// One row per interviewer, best quality first per person.
    var voices: [VoiceOption] {
        VoiceRoster.cast(from: speech.voices(for: Self.locale))
    }

    func preview(_ voice: VoiceOption) {
        speech.speak(Self.previewLine, voice: voice, locale: Self.locale, slow: settings.slowByDefault)
    }

    func resetProgress() {
        store.reset()
        progressWasReset = true
    }

    func leave() {
        speech.stop()
    }

    static func qualityName(_ quality: Int) -> String {
        switch quality {
        case 3...: "Premium"
        case 2: "Enhanced"
        default: "Default"
        }
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

struct SettingsView: View {
    @State var model: SettingsViewModel
    @State private var confirmingReset = false

    var body: some View {
        @Bindable var settings = model.settings
        Form {
            Section {
                ForEach(model.voices, id: \.id) { voice in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(voice.name).font(.body.weight(.semibold))
                            Text(SettingsViewModel.qualityName(voice.quality))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Play", systemImage: "play.circle.fill") { model.preview(voice) }
                            .labelStyle(.iconOnly)
                            .font(.title2)
                            .tint(Theme.accent)
                            .accessibilityLabel("Play \(voice.name)")
                            .accessibilityIdentifier(A11yID.Settings.previewButton(voice.name))
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(A11yID.Settings.voiceRow(voice.name))
                }
            } header: {
                Text("Interviewers")
            } footer: {
                Text("Questions are read by these Australian voices in turn. Premium voices sound the most natural. Add more in Settings > Accessibility > Spoken Content > Voices > English > English (Australia).")
            }

            Section {
                Toggle(isOn: $settings.slowByDefault) {
                    Label("Start every question slower", systemImage: "tortoise.fill")
                }
                .tint(Theme.accent)
                .accessibilityIdentifier(A11yID.Settings.slowByDefaultToggle)
            } header: {
                Text("Listening")
            } footer: {
                Text("Handy at the start. Turn it off when normal speed feels easy.")
            }

            Section {
                Button(role: .destructive) {
                    confirmingReset = true
                } label: {
                    Label("Reset progress", systemImage: "arrow.counterclockwise")
                        .foregroundStyle(.red)
                }
                .accessibilityIdentifier(A11yID.Settings.resetButton)
                .confirmationDialog("Reset all progress?", isPresented: $confirmingReset, titleVisibility: .visible) {
                    Button("Reset", role: .destructive) { model.resetProgress() }
                        .accessibilityIdentifier(A11yID.Settings.resetConfirmButton)
                } message: {
                    Text("Every question goes back to the start. This cannot be undone.")
                }
            } header: {
                Text("Progress")
            } footer: {
                if model.progressWasReset {
                    Text("Progress reset. Every question will come up as new.")
                        .accessibilityIdentifier(A11yID.Settings.resetDoneLabel)
                }
            }

            Section {
                LabeledContent("Version", value: model.version)
                    .accessibilityIdentifier(A11yID.Settings.version)
                LabeledContent("Data collected", value: "None")
                Link(destination: SettingsViewModel.sourceURL) {
                    Label("Source code on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            } header: {
                Text("About")
            } footer: {
                Text("Say Again is free, has no ads and no accounts. Your progress stays on this device.")
            }
        }
        .tint(Theme.accent)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { model.leave() }
    }
}
