import Foundation

/// How well the user understood a question.
public enum Rating: String, Codable, CaseIterable, Sendable {
    /// Picked the right meaning and understood the whole question.
    case gotIt
    /// Picked the right meaning but missed some of the words.
    case partly
    /// Picked the wrong meaning.
    case missed
}

/// Leitner boxes: 1 = needs practice, 5 = well known. Lower boxes come first.
public enum LeitnerScheduler {
    public static let firstBox = 1
    public static let lastBox = 5

    public static func nextBox(current: Int, rating: Rating) -> Int {
        let current = min(max(current, firstBox), lastBox)
        switch rating {
        case .gotIt: return min(current + 1, lastBox)
        case .partly: return current
        case .missed: return firstBox
        }
    }

    /// Lowest boxes first; questions in the same box are shuffled.
    public static func order<G: RandomNumberGenerator>(
        _ questions: [Question],
        box: (Question) -> Int,
        using generator: inout G
    ) -> [Question] {
        questions
            .shuffled(using: &generator)
            .enumerated()
            .sorted { lhs, rhs in
                let (left, right) = (box(lhs.element), box(rhs.element))
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            .map(\.element)
    }
}

/// Where Leitner boxes are kept. Unseen questions are in the first box.
public protocol ProgressStore: AnyObject {
    func box(for questionID: String) -> Int
    func setBox(_ box: Int, for questionID: String)
    func reset()
}

public final class InMemoryProgressStore: ProgressStore {
    private var boxes: [String: Int]

    public init(boxes: [String: Int] = [:]) {
        self.boxes = boxes
    }

    public func box(for questionID: String) -> Int {
        boxes[questionID] ?? LeitnerScheduler.firstBox
    }

    public func setBox(_ box: Int, for questionID: String) {
        boxes[questionID] = box
    }

    public func reset() {
        boxes = [:]
    }
}

/// Keeps progress on the device only. Nothing leaves the phone.
public final class UserDefaultsProgressStore: ProgressStore {
    static let key = "progress.leitnerBoxes"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var boxes: [String: Int] {
        get { defaults.dictionary(forKey: Self.key) as? [String: Int] ?? [:] }
        set { defaults.set(newValue, forKey: Self.key) }
    }

    public func box(for questionID: String) -> Int {
        boxes[questionID] ?? LeitnerScheduler.firstBox
    }

    public func setBox(_ box: Int, for questionID: String) {
        boxes[questionID] = box
    }

    public func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}
