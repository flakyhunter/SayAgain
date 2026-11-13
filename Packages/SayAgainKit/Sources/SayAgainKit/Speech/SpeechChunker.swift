import Foundation

/// Splits a question into short phrases for slow mode, so each phrase can be followed by a pause.
/// Splits after a comma, "?" or "!", and after a full stop that ends a word ("me. If"),
/// but not inside abbreviations like "A.I." or "L.L.M.".
public enum SpeechChunker {
    public static func chunks(_ text: String) -> [String] {
        var result: [String] = []
        var current = ""
        let characters = Array(text)

        for (index, character) in characters.enumerated() {
            current.append(character)
            let next = index + 1 < characters.count ? characters[index + 1] : nil
            guard next == nil || next == " " else { continue }

            let previous = index > 0 ? characters[index - 1] : nil
            let endsPhrase: Bool
            switch character {
            case ",", "?", "!": endsPhrase = true
            case ".": endsPhrase = previous?.isLowercase == true
            default: endsPhrase = false
            }
            if endsPhrase {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            }
        }
        let rest = current.trimmingCharacters(in: .whitespaces)
        if !rest.isEmpty { result.append(rest) }
        return result
    }
}
