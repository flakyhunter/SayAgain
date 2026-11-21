import SayAgainKit
import SwiftUI

/// Card on the home screen that opens a course.
struct CourseCard: View {
    let course: Course
    let passed: Int

    var body: some View {
        HStack(spacing: 16) {
            CategoryIcon(category: .agedCare)
            VStack(alignment: .leading, spacing: 6) {
                Text(course.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                RussianLine(text: course.titleRu)
                Text(Self.progressText(passed: passed, total: course.lessons.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ProgressView(value: Double(passed), total: Double(max(course.lessons.count, 1)))
                    .tint(QuestionCategory.agedCare.tint)
                    .scaleEffect(y: 0.8, anchor: .center)
            }
            Image(systemName: "chevron.right")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }

    static func progressText(passed: Int, total: Int) -> String {
        let lessons = "\(total) \(total == 1 ? "lesson" : "lessons")"
        return passed == 0 ? lessons : "\(passed) of \(lessons) passed"
    }
}

/// The list of lessons. A lesson opens when the previous check is passed.
struct CourseView: View {
    let environment: AppEnvironment
    let course: Course
    @State private var open: Lesson?
    /// Bumped when a lesson closes, so locks and scores are read again.
    @State private var version = 0
    @State private var confirmingReset = false

    private var store: CourseProgressStore { environment.courseStore }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(spacing: 12) {
                    ForEach(course.lessons) { lesson in
                        row(lesson)
                    }
                }
            }
            .padding(20)
        }
        .accessibilityIdentifier(A11yID.Course.list)
        .background(Color(.systemGroupedBackground))
        .navigationTitle(course.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if version >= 0, course.passedCount(store: store) > 0 || course.lessons.contains(where: { store.bestScore(for: $0.id) != nil }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Start over", systemImage: "arrow.counterclockwise") { confirmingReset = true }
                        .accessibilityIdentifier(A11yID.Course.resetButton)
                }
            }
        }
        .confirmationDialog("Start the course over?", isPresented: $confirmingReset, titleVisibility: .visible) {
            Button("Start over", role: .destructive) {
                course.resetProgress(store: store)
                version += 1
            }
        } message: {
            Text("All lessons except the first one lock again.")
        }
        .navigationDestination(item: $open) { lesson in
            LessonView(
                model: environment.makeLesson(lesson, in: course),
                onDone: { open = nil },
                onNextLesson: { next in open = next }
            )
            .id(lesson.id)
        }
        .onChange(of: open) { version += 1 }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(course.subtitle)
                .font(.title3.bold())
            RussianLine(text: course.titleRu)
            Text("Words, a dialogue, practice and a short check in every lesson. Pass the check to open the next one.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            RussianLine(text: "В каждом уроке слова, диалог, практика и короткая проверка. Сдайте проверку, чтобы открыть следующий урок.")
        }
    }

    private func row(_ lesson: Lesson) -> some View {
        let unlocked = version >= 0 && course.isUnlocked(lesson, store: store)
        let passed = course.isPassed(lesson, store: store)
        let best = store.bestScore(for: lesson.id)
        return Button {
            open = lesson
        } label: {
            HStack(spacing: 14) {
                Text("\(lesson.number)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(unlocked ? .white : .secondary)
                    .frame(width: 40, height: 40)
                    .background(
                        unlocked ? AnyShapeStyle(passed ? Theme.success : Theme.ocean) : AnyShapeStyle(Color(.tertiarySystemFill)),
                        in: .circle
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text(lesson.title)
                        .font(.headline)
                        .foregroundStyle(unlocked ? .primary : .secondary)
                    RussianLine(text: lesson.titleRu)
                    if let best {
                        Text(passed ? "Passed, best \(best)%" : "Best \(best)%, need \(lesson.passPercent)%")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(passed ? Theme.success : Theme.sunset)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: unlocked ? (passed ? "checkmark.circle.fill" : "chevron.right") : "lock.fill")
                    .foregroundStyle(passed ? Theme.success : Color.secondary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            .contentShape(.rect(cornerRadius: 18))
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Lesson \(lesson.number), \(lesson.title)")
        .accessibilityValue(Self.statusText(unlocked: unlocked, passed: passed, best: best))
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier(A11yID.Course.lessonRow(lesson.number))
    }

    static func statusText(unlocked: Bool, passed: Bool, best: Int?) -> String {
        if !unlocked { return "Locked" }
        if passed { return "Passed" }
        if let best { return "Best \(best)%" }
        return "Not started"
    }
}
