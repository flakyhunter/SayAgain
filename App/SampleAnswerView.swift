import SayAgainKit
import SwiftUI

/// What a good candidate could say. Placeholders in [brackets] are highlighted.
struct SampleAnswerView: View {
    let question: Question
    let onListen: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("THEY ASKED")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(question.rephrase)
                            .font(.headline)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        Text("YOU COULD SAY")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                        Self.highlighted(question.sampleAnswer)
                            .font(.title3)
                            .lineSpacing(4)
                            .accessibilityIdentifier(A11yID.SampleAnswer.text)
                        Button(action: onListen) {
                            Label("Listen", systemImage: "speaker.wave.2.fill")
                                .font(.headline)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                                .background(Theme.ocean, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Listen to the sample answer")
                        .accessibilityIdentifier(A11yID.SampleAnswer.listenButton)
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))

                    if AnswerTemplate.hasPlaceholders(question.sampleAnswer) {
                        Label("Swap the highlighted parts in [brackets] for your own details.", systemImage: "pencil")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Label("Keep it short: 30 to 60 seconds is plenty in an interview.", systemImage: "timer")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Sample answer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier(A11yID.SampleAnswer.closeButton)
                }
            }
        }
        .accessibilityIdentifier(A11yID.SampleAnswer.sheet)
        .presentationDetents([.medium, .large])
    }

    static func highlighted(_ text: String) -> Text {
        AnswerTemplate.segments(text).reduce(Text("")) { result, segment in
            let part = Text(segment.text)
            return result + (segment.isPlaceholder
                ? part.foregroundStyle(Theme.sunset).bold()
                : part)
        }
    }
}
