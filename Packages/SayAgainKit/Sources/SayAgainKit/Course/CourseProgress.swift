import Foundation

/// Best check score per lesson. Kept on the device only.
public protocol CourseProgressStore: AnyObject {
    func bestScore(for lessonID: String) -> Int?
    func setBestScore(_ score: Int, for lessonID: String)
    func removeScore(for lessonID: String)
}

public final class InMemoryCourseProgressStore: CourseProgressStore {
    private var scores: [String: Int]

    public init(scores: [String: Int] = [:]) {
        self.scores = scores
    }

    public func bestScore(for lessonID: String) -> Int? { scores[lessonID] }
    public func setBestScore(_ score: Int, for lessonID: String) { scores[lessonID] = score }
    public func removeScore(for lessonID: String) { scores[lessonID] = nil }
}

public final class UserDefaultsCourseProgressStore: CourseProgressStore {
    static let key = "progress.courseScores"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var scores: [String: Int] {
        get { defaults.dictionary(forKey: Self.key) as? [String: Int] ?? [:] }
        set { defaults.set(newValue, forKey: Self.key) }
    }

    public func bestScore(for lessonID: String) -> Int? { scores[lessonID] }
    public func setBestScore(_ score: Int, for lessonID: String) { scores[lessonID] = score }
    public func removeScore(for lessonID: String) { scores[lessonID] = nil }
}

public extension Course {
    func isPassed(_ lesson: Lesson, store: CourseProgressStore) -> Bool {
        (store.bestScore(for: lesson.id) ?? 0) >= lesson.passPercent
    }

    /// The first lesson is always open; every other one opens when the previous check is passed.
    func isUnlocked(_ lesson: Lesson, store: CourseProgressStore) -> Bool {
        guard let index = lessons.firstIndex(of: lesson) else { return false }
        return index == 0 || isPassed(lessons[index - 1], store: store)
    }

    func passedCount(store: CourseProgressStore) -> Int {
        lessons.count { isPassed($0, store: store) }
    }

    /// Saves a check result. A worse retry never lowers the best score.
    func record(score: Int, for lesson: Lesson, store: CourseProgressStore) {
        let best = max(score, store.bestScore(for: lesson.id) ?? 0)
        store.setBestScore(best, for: lesson.id)
    }

    func resetProgress(store: CourseProgressStore) {
        for lesson in lessons { store.removeScore(for: lesson.id) }
    }
}
