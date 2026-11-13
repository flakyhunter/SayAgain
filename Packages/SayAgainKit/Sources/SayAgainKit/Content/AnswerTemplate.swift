/// Sample answers mark the user's own details as [placeholders].
public enum AnswerTemplate {
    public struct Segment: Equatable, Sendable {
        public let text: String
        public let isPlaceholder: Bool

        public init(text: String, isPlaceholder: Bool) {
            self.text = text
            self.isPlaceholder = isPlaceholder
        }
    }

    /// Splits text into plain parts and [placeholder] parts (brackets kept in the text).
    public static func segments(_ text: String) -> [Segment] {
        var result: [Segment] = []
        var current = ""
        var inside = false
        for character in text {
            if character == "[", !inside {
                if !current.isEmpty { result.append(Segment(text: current, isPlaceholder: false)) }
                current = "["
                inside = true
            } else if character == "]", inside {
                current.append(character)
                result.append(Segment(text: current, isPlaceholder: true))
                current = ""
                inside = false
            } else {
                current.append(character)
            }
        }
        if !current.isEmpty { result.append(Segment(text: current, isPlaceholder: inside)) }
        return result
    }

    /// Text for speech: brackets removed, so the voice reads "your role" instead of symbols.
    public static func spoken(_ text: String) -> String {
        text.replacingOccurrences(of: "[", with: "").replacingOccurrences(of: "]", with: "")
    }

    public static func hasPlaceholders(_ text: String) -> Bool {
        segments(text).contains { $0.isPlaceholder }
    }
}
