import SayAgainKit
import SwiftUI

struct HomeView: View {
    let bank: QuestionBank

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Understand Aussie interview questions by ear.")
                            .font(.headline)
                        Text("Listen first, then check what they really asked.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(A11yID.Home.header)
                }

                Section("Categories") {
                    if bank.categorySummaries.isEmpty {
                        Text("No questions yet.")
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier(A11yID.Home.emptyState)
                    }
                    ForEach(bank.categorySummaries) { summary in
                        CategoryRow(summary: summary)
                    }
                }
            }
            .accessibilityIdentifier(A11yID.Home.list)
            .navigationTitle("Say Again")
        }
    }
}

private struct CategoryRow: View {
    let summary: CategorySummary

    var body: some View {
        HStack {
            Text(summary.category.title)
            Spacer()
            Text("\(summary.count)")
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.label(for: summary))
        .accessibilityIdentifier(A11yID.Home.categoryRow(summary.category))
    }

    static func label(for summary: CategorySummary) -> String {
        let noun = summary.count == 1 ? "question" : "questions"
        return "\(summary.category.title), \(summary.count) \(noun)"
    }
}

#Preview {
    HomeView(bank: .fixture)
}
