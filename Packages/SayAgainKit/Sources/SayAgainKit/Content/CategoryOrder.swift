/// The order of categories on the home screen: a default the user can change by dragging.
public enum CategoryOrder {
    /// What a new user sees first.
    public static let `default`: [QuestionCategory] = [
        .school, .agedCare, .qaIT, .intro, .behavioural, .logistics, .volunteering
    ]

    /// The user's saved order, with unknown ids dropped and categories added in later
    /// versions appended in default order, so an update never scrambles their list.
    public static func resolve(saved: [String]) -> [QuestionCategory] {
        var result: [QuestionCategory] = []
        for raw in saved {
            if let category = QuestionCategory(rawValue: raw), !result.contains(category) {
                result.append(category)
            }
        }
        let known = Set(result)
        let rest = (`default` + QuestionCategory.allCases).filter { !known.contains($0) }
        for category in rest where !result.contains(category) {
            result.append(category)
        }
        return result
    }

    /// Moves `category` to the position of `target` (dragging one card over another).
    public static func move(
        _ category: QuestionCategory, to target: QuestionCategory, in order: [QuestionCategory]
    ) -> [QuestionCategory] {
        guard category != target,
              let from = order.firstIndex(of: category),
              let to = order.firstIndex(of: target) else { return order }
        var result = order
        result.remove(at: from)
        result.insert(category, at: to)
        return result
    }

    /// One step up (-1) or down (+1), for VoiceOver actions.
    public static func shift(
        _ category: QuestionCategory, by offset: Int, in order: [QuestionCategory]
    ) -> [QuestionCategory] {
        guard let from = order.firstIndex(of: category) else { return order }
        let to = from + offset
        guard order.indices.contains(to) else { return order }
        return move(category, to: order[to], in: order)
    }
}
