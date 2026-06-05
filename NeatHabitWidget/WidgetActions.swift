import AppIntents
import Foundation
import WidgetKit

struct ToggleHabitIntent: AppIntent {
    static let title: LocalizedStringResource = "Toggle Habit"
    static let description = IntentDescription("Toggle a NeatHabit daily habit from the widget.")

    @Parameter(title: "Habit") var habitRawValue: String

    init() {
        habitRawValue = StudyHabit.systemDesign.rawValue
    }

    init(habitRawValue: String) {
        self.habitRawValue = habitRawValue
    }

    func perform() async throws -> some IntentResult {
        guard let habit = StudyHabit(rawValue: habitRawValue) else {
            return .result()
        }

        var progress = ProgressPersistence.load()
        let schedule = StudyPlanner.plan(for: progress)
        let day = progress.currentDayNumber(in: schedule)
        var daily = progress.dailyProgress(for: day)

        if daily.completedHabits.contains(habit) {
            daily.completedHabits.remove(habit)
        } else {
            daily.completedHabits.insert(habit)
        }

        progress.dayProgress[day] = daily
        ProgressPersistence.save(progress)
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
