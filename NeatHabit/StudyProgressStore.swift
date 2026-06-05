import Combine
import Foundation
import UserNotifications
import WidgetKit

private let onboardingStorageKey = "neatHabit.onboarding.v1"
private let dailyReminderIdentifier = "neatHabit.dailyReminder"
private let morningReminderPrefix = "neatHabit.morning."
private let maximumDailyMinutes = 240

@MainActor
final class StudyProgressStore: ObservableObject {
    @Published private(set) var progress: StoredProgress
    @Published private(set) var hasCompletedOnboarding: Bool

    private let onboardingDefaults: UserDefaults

    init(progress: StoredProgress = ProgressPersistence.load(), onboardingDefaults: UserDefaults = .standard) {
        self.onboardingDefaults = onboardingDefaults

        var normalizedProgress = progress
        normalizedProgress.settings.dailyMinutes = min(max(normalizedProgress.settings.dailyMinutes, 20), maximumDailyMinutes)
        self.progress = normalizedProgress

        if normalizedProgress != progress {
            ProgressPersistence.save(normalizedProgress)
        }

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

    func toggleSystemDesignCheck(_ checkID: String, day: Int, allCheckIDs: [String]) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)

        if daily.systemDesignChecks.contains(checkID) {
            daily.systemDesignChecks.remove(checkID)
        } else {
            daily.systemDesignChecks.insert(checkID)
        }

        if Set(allCheckIDs).isSubset(of: daily.systemDesignChecks) {
            daily.completedHabits.insert(.systemDesign)
        } else {
            daily.completedHabits.remove(.systemDesign)
        }

        nextProgress.dayProgress[max(day, 1)] = daily
        commit(nextProgress)
    }

    func setSystemDesignChecksCompleted(_ completed: Bool, day: Int, allCheckIDs: [String]) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)

        if completed {
            daily.systemDesignChecks.formUnion(allCheckIDs)
            daily.completedHabits.insert(.systemDesign)
        } else {
            daily.systemDesignChecks.subtract(allCheckIDs)
            daily.completedHabits.remove(.systemDesign)
        }

        nextProgress.dayProgress[max(day, 1)] = daily
        commit(nextProgress)
    }

    func setStatus(_ status: ProblemStatus, for problem: String, day: Int) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)
        let wasRed = daily.status(for: problem) == .red
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

        if status == .red || wasRed {
            Task { await scheduleMorningReminderIfNeeded() }
        }
    }

    func cycleStatus(for problem: String, day: Int) {
        let currentStatus = progress.dailyProgress(for: day).status(for: problem)
        setStatus(currentStatus.next, for: problem, day: day)
    }

    func updateRedoDate(_ date: Date, for problem: String, day: Int) {
        var nextProgress = progress
        var daily = nextProgress.dailyProgress(for: day)
        daily.problemStatuses[problem] = .red
        daily.redoDates[problem] = min(Calendar.current.startOfDay(for: date), redoGraceEndDate())

        nextProgress.dayProgress[max(day, 1)] = daily
        commit(nextProgress)
        Task { await scheduleMorningReminderIfNeeded() }
    }

    func suggestedRedoDate(for day: Int) -> Date {
        let calendar = Calendar.current
        let planDay = schedule.day(day)
        let sourceDate = calendar.startOfDay(for: planDay.date ?? Date())
        let fromPlan = calendar.date(byAdding: .day, value: 3, to: sourceDate) ?? sourceDate
        let fromToday = calendar.date(byAdding: .day, value: 3, to: calendar.startOfDay(for: Date())) ?? Date()
        return min(calendar.startOfDay(for: max(fromPlan, fromToday)), redoGraceEndDate())
    }

    func redoGraceEndDate() -> Date {
        let calendar = Calendar.current
        let lastPlanDate = schedule.days.last?.date ?? progress.settings.targetFinishDate
        let graceDate = calendar.date(byAdding: .day, value: 1, to: lastPlanDate) ?? lastPlanDate
        return calendar.startOfDay(for: graceDate)
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
        let clamped = min(max(minutes, 20), maximumDailyMinutes)
        nextProgress.settings.dailyMinutes = clamped
        nextProgress.settings.problemBlockMinutes = max(5, clamped - nextProgress.settings.systemDesignMinutes)
        commit(nextProgress)
        Task { await scheduleAllRemindersIfNeeded() }
    }

    func updateSystemDesignMinutes(_ minutes: Int) {
        var nextProgress = progress
        nextProgress.settings.systemDesignMinutes = min(max(minutes, 15), 40)
        nextProgress.settings.dailyMinutes = min(max(nextProgress.settings.systemDesignMinutes + nextProgress.settings.problemBlockMinutes, 20), maximumDailyMinutes)
        commit(nextProgress)
        Task { await scheduleAllRemindersIfNeeded() }
    }

    func updateProblemBlockMinutes(_ minutes: Int) {
        var nextProgress = progress
        let clamped = min(max(minutes, 5), 200)
        let capped = min(clamped, maximumDailyMinutes - nextProgress.settings.systemDesignMinutes)
        nextProgress.settings.problemBlockMinutes = max(5, capped)
        nextProgress.settings.dailyMinutes = nextProgress.settings.systemDesignMinutes + nextProgress.settings.problemBlockMinutes
        commit(nextProgress)
        Task { await scheduleAllRemindersIfNeeded() }
    }

    func updateReminderTime(_ date: Date) {
        var nextProgress = progress
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        nextProgress.settings.reminderHour = min(max(components.hour ?? 19, 0), 23)
        nextProgress.settings.reminderMinute = min(max(components.minute ?? 0, 0), 59)
        commit(nextProgress)
        Task { await scheduleAllRemindersIfNeeded() }
    }

    func updateNotificationsEnabled(_ enabled: Bool) {
        var nextProgress = progress
        nextProgress.settings.notificationsEnabled = enabled
        commit(nextProgress)

        if enabled {
            Task { await scheduleAllRemindersIfNeeded() }
        } else {
            Task {
                let center = UNUserNotificationCenter.current()
                center.removePendingNotificationRequests(withIdentifiers: [dailyReminderIdentifier])
                await removeMorningReminders()
            }
        }
    }

    func updateTargetFinishDate(_ date: Date) {
        var nextProgress = progress
        let start = Calendar.current.startOfDay(for: nextProgress.startDate)
        let target = Calendar.current.startOfDay(for: date)
        nextProgress.settings.targetFinishDate = max(target, start)

        let dayCount = (Calendar.current.dateComponents([.day], from: start, to: max(target, start)).day ?? 0) + 1
        if dayCount <= 30 {
            nextProgress.settings.systemDesignMinutes = 20
        } else if dayCount <= 60 {
            nextProgress.settings.systemDesignMinutes = 25
        } else {
            nextProgress.settings.systemDesignMinutes = 30
        }

        commit(nextProgress)
        Task { await scheduleAllRemindersIfNeeded() }
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
            await scheduleAllRemindersIfNeeded()
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

    private func scheduleAllRemindersIfNeeded() async {
        await scheduleDailyReminderIfNeeded()
        await scheduleMorningReminderIfNeeded()
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

    private func scheduleMorningReminderIfNeeded() async {
        guard progress.settings.notificationsEnabled else { return }

        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }

            await removeMorningReminders()

            let currentSchedule = schedule
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            var seenDates = Set<Date>()
            let maxMorningReminders = 60

            for day in 1...currentSchedule.totalDays {
                let candidates = progress.redoCandidates(for: day, in: currentSchedule)
                for candidate in candidates {
                    let dueDay = calendar.startOfDay(for: candidate.dueDate)
                    guard dueDay >= today, !seenDates.contains(dueDay), seenDates.count < maxMorningReminders else { continue }
                    seenDates.insert(dueDay)

                    let content = UNMutableNotificationContent()
                    content.title = "Redo work due today"
                    content.body = "You have redo problems scheduled. Tackle them before starting new work."
                    content.sound = .default

                    var components = calendar.dateComponents([.year, .month, .day], from: dueDay)
                    components.hour = 9
                    components.minute = 0

                    let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
                    let identifier = "\(morningReminderPrefix)\(Int(dueDay.timeIntervalSince1970))"
                    let request = UNNotificationRequest(
                        identifier: identifier,
                        content: content,
                        trigger: trigger
                    )
                    try await center.add(request)
                }
            }
        } catch {
            // Notification permission can be denied.
        }
    }

    private func removeMorningReminders() async {
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let morningIDs = pending.filter { $0.identifier.hasPrefix(morningReminderPrefix) }.map(\.identifier)
        guard !morningIDs.isEmpty else { return }
        center.removePendingNotificationRequests(withIdentifiers: morningIDs)
    }
}
