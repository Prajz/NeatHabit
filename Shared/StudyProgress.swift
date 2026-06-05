import Foundation

struct DailyProgress: Codable, Equatable {
    var completedHabits: Set<StudyHabit>
    var problemStatuses: [String: ProblemStatus]
    var redoDates: [String: Date]
    var note: String

    init(
        completedHabits: Set<StudyHabit> = [],
        problemStatuses: [String: ProblemStatus] = [:],
        redoDates: [String: Date] = [:],
        note: String = ""
    ) {
        self.completedHabits = completedHabits
        self.problemStatuses = problemStatuses
        self.redoDates = redoDates
        self.note = note
    }

    func status(for problem: String) -> ProblemStatus {
        problemStatuses[problem] ?? .untouched
    }

    func redoDate(for problem: String) -> Date? {
        redoDates[problem]
    }

    func isRedoScheduled(_ problem: String) -> Bool {
        redoDates[problem] != nil
    }

    func counts(for day: StudyDay) -> StatusCounts {
        day.problems.reduce(into: StatusCounts()) { counts, problem in
            counts.add(status(for: problem))
        }
    }

    func completionFraction(for day: StudyDay, settings: StudySettings, hasRedoDue: Bool = false) -> Double {
        let activeHabits = StudyHabit.activeCases(hasRedoDue: hasRedoDue)
        let completedHabitCount = activeHabits.filter { completedHabits.contains($0) }.count
        let completedProblems = day.problems.filter { status(for: $0) != .untouched }.count
        let completedItems = completedHabitCount + completedProblems
        let totalItems = activeHabits.count + day.problems.count

        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }

    enum CodingKeys: String, CodingKey {
        case completedHabits
        case problemStatuses
        case redoDates
        case redoLaterProblems
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedHabits = try container.decodeIfPresent(Set<StudyHabit>.self, forKey: .completedHabits) ?? []
        problemStatuses = try container.decodeIfPresent([String: ProblemStatus].self, forKey: .problemStatuses) ?? [:]
        redoDates = try container.decodeIfPresent([String: Date].self, forKey: .redoDates) ?? [:]

        let legacyRedoLaterProblems = try container.decodeIfPresent(Set<String>.self, forKey: .redoLaterProblems) ?? []
        if !legacyRedoLaterProblems.isEmpty {
            let fallbackDate = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
            )

            for problem in legacyRedoLaterProblems where redoDates[problem] == nil {
                redoDates[problem] = fallbackDate
            }
        }

        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(completedHabits, forKey: .completedHabits)
        try container.encode(problemStatuses, forKey: .problemStatuses)
        try container.encode(redoDates, forKey: .redoDates)
        try container.encode(note, forKey: .note)
    }
}

struct StoredProgress: Codable, Equatable {
    var startDate: Date
    var settings: StudySettings
    var dayProgress: [Int: DailyProgress]

    init(
        startDate: Date = Calendar.current.startOfDay(for: Date()),
        settings: StudySettings? = nil,
        dayProgress: [Int: DailyProgress] = [:]
    ) {
        let start = Calendar.current.startOfDay(for: startDate)
        self.startDate = start
        self.settings = settings ?? StudySettings(
            targetFinishDate: Calendar.current.date(byAdding: .day, value: 29, to: start) ?? start
        )
        self.dayProgress = dayProgress
    }

    func currentDayNumber(in schedule: StudySchedule) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let today = calendar.startOfDay(for: Date())
        let elapsedDays = calendar.dateComponents([.day], from: start, to: today).day ?? 0
        return schedule.clampedDay(elapsedDays + 1)
    }

    func dailyProgress(for day: Int) -> DailyProgress {
        dayProgress[max(day, 1)] ?? DailyProgress()
    }

    var touchedProblemTitles: Set<String> {
        dayProgress.values.reduce(into: Set<String>()) { result, daily in
            for (problem, status) in daily.problemStatuses where status != .untouched {
                result.insert(problem)
            }
        }
    }

    func status(for problem: String) -> ProblemStatus {
        for day in dayProgress.keys.sorted() {
            let status = dailyProgress(for: day).status(for: problem)
            if status != .untouched {
                return status
            }
        }

        return .untouched
    }

    func summary(for schedule: StudySchedule) -> PlanSummary {
        var summary = PlanSummary(totalRequiredProblems: schedule.requiredProblemCount)

        for day in schedule.days {
            let daily = dailyProgress(for: day.day)
            let activeHabits = activeHabits(for: day.day, in: schedule)
            summary.completedHabits += activeHabits.filter { daily.completedHabits.contains($0) }.count
            summary.totalHabits += activeHabits.count
        }

        var countedProblems = Set<String>()
        let requiredProblems = StudyPlanner.requiredProblemTitles
        let allProblems = requiredProblems + settings.extraProblems.map(\.title)

        for problem in allProblems where !countedProblems.contains(problem) {
            countedProblems.insert(problem)
            summary.problemCounts.add(status(for: problem))
        }

        return summary
    }

    func activeHabits(for day: Int, in schedule: StudySchedule) -> [StudyHabit] {
        StudyHabit.activeCases(hasRedoDue: !redoCandidates(for: day, in: schedule).isEmpty)
    }

    func completionFraction(for day: StudyDay, in schedule: StudySchedule) -> Double {
        dailyProgress(for: day.day).completionFraction(
            for: day,
            settings: schedule.settings,
            hasRedoDue: !redoCandidates(for: day.day, in: schedule).isEmpty
        )
    }

    func redoCandidates(for day: Int, in schedule: StudySchedule) -> [RedoCandidate] {
        let calendar = Calendar.current
        let selectedDay = schedule.day(day)
        let selectedDate = calendar.startOfDay(for: selectedDay.date ?? Date())
        var seen = Set<String>()
        var candidates: [RedoCandidate] = []

        for previousDay in 1...min(max(day, 1), schedule.totalDays) {
            let planDay = schedule.day(previousDay)
            let daily = dailyProgress(for: previousDay)

            for problem in planDay.problems where daily.status(for: problem) == .red {
                let dueDate = daily.redoDate(for: problem) ?? legacyAutomaticRedoDate(for: previousDay, in: schedule)
                guard dueDate <= selectedDate else { continue }

                let key = "red-\(problem)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                candidates.append(
                    RedoCandidate(
                        day: previousDay,
                        topic: planDay.topic,
                        problem: problem,
                        dueDate: dueDate,
                        reason: .red
                    )
                )
            }
        }

        return candidates.sorted { first, second in
            if first.dueDate == second.dueDate {
                return first.day < second.day
            }

            return first.dueDate < second.dueDate
        }
    }

    private func legacyAutomaticRedoDate(for day: Int, in schedule: StudySchedule) -> Date {
        let calendar = Calendar.current
        let sourceDate = schedule.day(day).date ?? startDate
        return calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 3, to: sourceDate) ?? sourceDate
        )
    }

    enum CodingKeys: String, CodingKey {
        case startDate
        case settings
        case dayProgress
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedStart = try container.decodeIfPresent(Date.self, forKey: .startDate) ?? Calendar.current.startOfDay(for: Date())
        startDate = Calendar.current.startOfDay(for: decodedStart)
        settings = try container.decodeIfPresent(StudySettings.self, forKey: .settings) ?? StudySettings(
            targetFinishDate: Calendar.current.date(byAdding: .day, value: 29, to: startDate) ?? startDate
        )
        dayProgress = try container.decodeIfPresent([Int: DailyProgress].self, forKey: .dayProgress) ?? [:]
    }
}

enum RedoReason: String, Codable, Equatable {
    case red

    var title: String {
        switch self {
        case .red:
            return "Redo"
        }
    }
}

struct RedoCandidate: Identifiable, Equatable {
    let day: Int
    let topic: String
    let problem: String
    let dueDate: Date
    let reason: RedoReason

    var id: String { "\(reason.rawValue)-\(day)-\(problem)" }
}

struct StatusCounts: Codable, Equatable {
    var green = 0
    var yellow = 0
    var red = 0
    var untouched = 0

    var attempted: Int { green + yellow + red }
    var total: Int { attempted + untouched }

    mutating func add(_ status: ProblemStatus) {
        switch status {
        case .untouched:
            untouched += 1
        case .green:
            green += 1
        case .yellow:
            yellow += 1
        case .red:
            red += 1
        }
    }
}

struct PlanSummary: Codable, Equatable {
    var completedHabits = 0
    var totalHabits = 0
    var problemCounts = StatusCounts()
    var totalRequiredProblems = 150

    var totalProblems: Int { problemCounts.total }
    var completedProblems: Int { problemCounts.attempted }
    var extraProblems: Int { max(0, totalProblems - totalRequiredProblems) }

    var completionFraction: Double {
        let completedItems = completedHabits + completedProblems
        let totalItems = totalHabits + totalProblems

        guard totalItems > 0 else { return 0 }
        return Double(completedItems) / Double(totalItems)
    }
}

enum ProgressPersistence {
    static func hasSavedProgress(defaults: UserDefaults = sharedDefaults) -> Bool {
        defaults.data(forKey: progressStorageKey) != nil
    }

    static func load(defaults: UserDefaults = sharedDefaults) -> StoredProgress {
        guard
            let data = defaults.data(forKey: progressStorageKey),
            let progress = try? JSONDecoder().decode(StoredProgress.self, from: data)
        else {
            return StoredProgress()
        }

        return progress
    }

    static func save(
        _ progress: StoredProgress,
        defaults: UserDefaults = sharedDefaults
    ) {
        guard let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: progressStorageKey)
    }

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }
}
