import SwiftUI

extension EnvironmentValues {
    /// Show Russian translations (Settings > Translation). Off by default.
    @Entry var showRussian = false
}

/// A small grey Russian line under English text.
struct RussianLine: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .italic()
            .foregroundStyle(.secondary)
            .environment(\.locale, Locale(identifier: "ru"))
            .accessibilityLabel(Text(text))
            .accessibilityIdentifier("ru")
    }
}
