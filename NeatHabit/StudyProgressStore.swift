import Combine
import Foundation
import UserNotifications
import WidgetKit

private let onboardingStorageKey = "neatHabit.onboarding.v1"
private let dailyReminderIdentifier = "neatHabit.dailyReminder"

@MainActor
final class StudyProgressStore: ObservableObject {
    @Published private(set) var progress: StoredProgress
    @Published private(set) var hasCompletedOnboarding: Bool

    private let onboardingDefaults: UserDefaults

    init(progress: StoredProgress = ProgressPersistence.load(), onboardingDefaults: UserDefaults = .standard) {
        self.onboardingDefaults = onboardingDefaults
        self.progress = progress

        if let storedValue = onboardingDefaults.object(forKey: onboardingStorageKey) as? Bool {
            hasCompletedOnboarding = storedValue
        } else {
            hasCompletedOnboarding = ProgressPersistence.hasSavedProgress()
        }
    }

    var schedule: StudySchedule {
        StudyPlanner.plan(for: progress)
    }

    func toggleHabit(_ habit: StudyHabit, day: Int) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)

        if daily.completedHabits.contains(habit) {
            daily.completedHabits.remove(habit)
        } else {
            daily.completedHabits.insert(habit)
        }

        nextProgress.dayProgress[max(day, 1)] = daily
        commit(nextProgress)
    }

    func setStatus(_ status: ProblemStatus, for problem: String, day: Int) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)
        daily.problemStatuses[problem] = status

        if status == .red {
            if daily.redoDates[problem] == nil {
                daily.redoDates[problem] = suggestedRedoDate(for: day)
            }
        } else {
            daily.redoDates.removeValue(forKey: problem)
        }

        nextProgress.dayProgress[max(day, 1)] = daily
        commit(nextProgress)
    }

    func cycleStatus(for problem: String, day: Int) {
        let currentStatus = progress.dailyProgress(for: day).status(for: problem)
        setStatus(currentStatus.next, for: problem, day: day)
    }

    func updateRedoDate(_ date: Date, for problem: String, day: Int) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)
        daily.problemStatuses[problem] = .red
        daily.redoDates[problem] = Calendar.current.startOfDay(for: date)

        nextProgress.dayProgress[max(day, 1)] = daily
        commit(nextProgress)
    }

    func suggestedRedoDate(for day: Int) -> Date {
        let calendar = Calendar.current
        let planDay = schedule.day(day)
        let sourceDate = calendar.startOfDay(for: planDay.date ?? Date())
        let fromPlan = calendar.date(byAdding: .day, value: 3, to: sourceDate) ?? sourceDate
        let fromToday = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: Date())) ?? Date()
        return calendar.startOfDay(for: max(fromPlan, fromToday))
    }

    func updateNote(_ note: String, day: Int) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)
        daily.note = note
        nextProgress.dayProgress[max(day, 1)] = daily
        commit(nextProgress)
    }

    func updateDailyMinutes(_ minutes: Int) {
        var nextProgress = progress
        nextProgress.settings.dailyMinutes = min(max(minutes, 80), 600)
        commit(nextProgress)
    }

    func updateReminderTime(_ date: Date) {
        var nextProgress = progress
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        nextProgress.settings.reminderHour = min(max(components.hour ?? 19, 0), 23)
        nextProgress.settings.reminderMinute = min(max(components.minute ?? 0, 0), 59)
        commit(nextProgress)
    }

    func updateNotificationsEnabled(_ enabled: Bool) {
        var nextProgress = progress
        nextProgress.settings.notificationsEnabled = enabled
        commit(nextProgress)

        if !enabled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
        }
    }

    func updateTargetFinishDate(_ date: Date) {
        var nextProgress = progress
        let start = Calendar.current.startOfDay(for: nextProgress.startDate)
        let target = Calendar.current.startOfDay(for: date)
        nextProgress.settings.targetFinishDate = max(target, start)
        commit(nextProgress)
    }

    func addExtraProblem(title: String, sectionTitle: String) {
        let cleanedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedSection = sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanedTitle.isEmpty else { return }

        var nextProgress = progress
        nextProgress.settings.extraProblems.append(
            CustomProblem(
                title: cleanedTitle,
                sectionTitle: cleanedSection.isEmpty ? "Extra Practice" : cleanedSection
            )
        )
        commit(nextProgress)
    }

    func removeExtraProblem(_ problem: CustomProblem) {
        var nextProgress = progress
        nextProgress.settings.extraProblems.removeAll { $0.id == problem.id }
        commit(nextProgress)
    }

    func toggleRoadmapProblem(_ problem: String) {
        if progress.status(for: problem) == .untouched {
            setStatus(.green, for: problem, day: plannedDay(for: problem))
        } else {
            clearProblemStatus(problem)
        }
    }

    private func clearProblemStatus(_ problem: String) {
        var nextProgress = progress

        for day in nextProgress.dayProgress.keys {
            var daily = nextProgress.dailyProgress(for: day)
            daily.problemStatuses.removeValue(forKey: problem)
            daily.redoDates.removeValue(forKey: problem)
            nextProgress.dayProgress[day] = daily
        }

        commit(nextProgress)
    }

    private func plannedDay(for problem: String) -> Int {
        let baseSchedule = StudyPlanner.plan(startDate: progress.startDate, settings: progress.settings)
        return baseSchedule.days.first { $0.problems.contains(problem) }?.day ?? progress.currentDayNumber(in: schedule)
    }

    func resetTimeline(startDate: Date = Date(), keepSettings: Bool = true) {
        let start = Calendar.current.startOfDay(for: startDate)
        let currentSettings = keepSettings ? progress.settings : StudySettings()
        var nextSettings = currentSettings
        nextSettings.targetFinishDate = Calendar.current.date(byAdding: .day, value: 29, to: start) ?? start
        commit(StoredProgress(startDate: start, settings: nextSettings, dayProgress: [:]))
    }

    func clearAllProgressKeepPlan() {
        commit(StoredProgress(startDate: progress.startDate, settings: progress.settings, dayProgress: [:]))
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        onboardingDefaults.set(true, forKey: onboardingStorageKey)

        Task {
            await scheduleDailyReminderIfNeeded()
        }
    }

    func restartOnboarding(resetTimeline: Bool = false) {
        if resetTimeline {
            self.resetTimeline()
        }

        hasCompletedOnboarding = false
        onboardingDefaults.set(false, forKey: onboardingStorageKey)
    }

    private func commit(_ nextProgress: StoredProgress) {
        progress = nextProgress
        ProgressPersistence.save(nextProgress)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func scheduleDailyReminderIfNeeded() async {
        guard progress.settings.notificationsEnabled else { return }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }

            center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])

            let content = UNMutableNotificationContent()
            content.title = "NeatHabit"
            content.body = "Time for today's interview reps. Open your plan and keep the streak moving."
            content.sound = .default

            var components = DateComponents()
            components.hour = progress.settings.reminderHour
            components.minute = progress.settings.reminderMinute

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: dailyReminderIdentifier,
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        } catch {
            // Notification permission can be denied; the plan should still start.
        }
    }
}
