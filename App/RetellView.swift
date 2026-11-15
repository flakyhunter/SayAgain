import SayAgainKit
import SwiftUI

/// "Say it in your own words": the learner types what they think was asked, and the AI checks it.
/// Asks for consent once before anything leaves the device.
struct RetellView: View {
    @Bindable var model: SessionViewModel
    /// Called after the learner accepts the feedback; the session then shows the question.
    var onFinished: () -> Void
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.needsConsent {
                        consent
                    } else {
                        switch model.retellState {
                        case .editing, .checking: editor
                        case let .result(feedback): result(feedback)
                        case let .failed(error): failure(error)
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Your own words")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier(A11yID.Retell.cancelButton)
                }
            }
        }
        .accessibilityIdentifier(A11yID.Retell.sheet)
        .presentationDetents([.large])
    }

    // MARK: Consent

    private var consent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Check your words with AI", systemImage: "sparkles")
                .font(.title3.bold())
            Text("Type what you think the interviewer asked. To check it, your text is sent to the Say Again server and to Claude, an AI by Anthropic. Nothing else leaves your iPhone: no name, no account, no progress.")
            Text("Don't type personal details. You can turn this off any time in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            VStack(spacing: 10) {
                wideButton("Allow AI feedback", primary: true, id: A11yID.Retell.allowButton) {
                    model.setConsent(true)
                    focused = true
                }
                wideButton("Not now", primary: false, id: A11yID.Retell.declineButton) {
                    model.setConsent(false)
                    dismiss()
                }
            }
            .padding(.top, 4)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(A11yID.Retell.consent)
    }

    // MARK: Editor

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("What did they ask?")
                .font(.title3.bold())
            Text("Write it the way you'd explain it to a friend. Any English is fine, or Russian.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("They want to know...", text: $model.retellText, axis: .vertical)
                .lineLimit(3...8)
                .padding(14)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
                .focused($focused)
                .disabled(model.retellState == .checking)
                .accessibilityIdentifier(A11yID.Retell.textField)
                .onAppear { focused = true }
            HStack {
                Spacer()
                Text("\(model.retellText.count) / \(Retelling.maxLength)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(model.retellText.count > Retelling.maxLength ? Theme.danger : .secondary)
            }
            if model.retellState == .checking {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking...").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(A11yID.Retell.checking)
            } else {
                wideButton("Check", primary: true, id: A11yID.Retell.checkButton) {
                    focused = false
                    Task { await model.submitRetelling() }
                }
                .disabled(!model.canSubmitRetelling)
                .opacity(model.canSubmitRetelling ? 1 : 0.5)
            }
        }
    }

    // MARK: Result

    private func result(_ feedback: RetellingFeedback) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            FeedbackCard(feedback: feedback, retelling: model.retellText)
            wideButton("See what they said", primary: true, id: A11yID.Retell.continueButton) {
                model.acceptFeedback()
                dismiss()
                onFinished()
            }
        }
    }

    // MARK: Failure

    private func failure(_ error: FeedbackServiceError) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(error.message, systemImage: "wifi.exclamationmark")
                .font(.headline)
                .foregroundStyle(Theme.sunset)
                .accessibilityIdentifier(A11yID.Retell.error)
            if error.isRetryable {
                wideButton("Try again", primary: true, id: A11yID.Retell.retryButton) {
                    model.editRetellingAgain()
                }
            }
            wideButton("Pick the meaning instead", primary: false, id: "retell.pickInstead") {
                model.editRetellingAgain()
                dismiss()
            }
        }
    }

    private func wideButton(_ title: String, primary: Bool, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(primary ? .white : Theme.accent)
                .background(primary ? AnyShapeStyle(Theme.ocean) : AnyShapeStyle(Theme.accent.opacity(0.15)),
                            in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

/// The AI's verdict and explanation. Used in the sheet and again with the revealed question.
struct FeedbackCard: View {
    let feedback: RetellingFeedback
    var retelling: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(Self.title(feedback.verdict), systemImage: Self.icon(feedback.verdict))
                .font(.headline)
                .foregroundStyle(Self.color(feedback.verdict))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Self.title(feedback.verdict))
                .accessibilityIdentifier(A11yID.Retell.verdict)
            if let retelling, !retelling.isEmpty {
                Text("\u{201C}\(retelling.trimmingCharacters(in: .whitespacesAndNewlines))\u{201D}")
                    .font(.subheadline.italic())
                    .foregroundStyle(.secondary)
            }
            Text(feedback.feedback)
                .accessibilityIdentifier(A11yID.Retell.feedback)
            if !feedback.missedPoints.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LISTEN FOR")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    ForEach(feedback.missedPoints, id: \.self) { point in
                        Label(point, systemImage: "ear")
                            .font(.subheadline)
                    }
                }
            }
            Text("AI feedback can be wrong.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .accessibilityElement(children: .contain)
    }

    static func title(_ verdict: FeedbackVerdict) -> String {
        switch verdict {
        case .understood: "You understood it"
        case .partly: "Partly there"
        case .missed: "Not quite"
        }
    }

    static func icon(_ verdict: FeedbackVerdict) -> String {
        switch verdict {
        case .understood: "hand.thumbsup.fill"
        case .partly: "circle.lefthalf.filled"
        case .missed: "ear.trianglebadge.exclamationmark"
        }
    }

    static func color(_ verdict: FeedbackVerdict) -> Color {
        switch verdict {
        case .understood: Theme.success
        case .partly: Theme.accent
        case .missed: Theme.sunset
        }
    }
}
