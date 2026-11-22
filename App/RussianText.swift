import SwiftUI

extension EnvironmentValues {
    /// Show Russian translations (Settings > Translation). Follows the phone language by default.
    @Entry var showRussian = false
}

/// A small grey Russian line under English text. Hidden while translation is off.
struct RussianLine: View {
    let text: String
    @Environment(\.showRussian) private var showRussian

    var body: some View {
        if showRussian { line }
    }

    private var line: some View {
        Text(text)
            .font(.subheadline)
            .italic()
            .foregroundStyle(.secondary)
            .environment(\.locale, Locale(identifier: "ru"))
            .accessibilityLabel(Text(text))
            .accessibilityIdentifier("ru")
    }
}
