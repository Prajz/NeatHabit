import Foundation

struct DailyProgress: Codable, Equatable {
    var completedHabits: Set<StudyHabit>
    var problemStatuses: [String: ProblemStatus]
    var redoLaterProblems: Set<String>
    var note: String

    init(
        completedHabits: Set<StudyHabit> = [],
        problemStatuses: [String: ProblemStatus] = [:],
        redoLaterProblems: Set<String> = [],
        note: String = ""
    ) {
        self.completedHabits = completedHabits
        self.problemStatuses = problemStatuses
        self.redoLaterProblems = redoLaterProblems
        self.note = note
    }

    func status(for problem: String) -> ProblemStatus {
        problemStatuses[problem] ?? .untouched
    }

    func isMarkedRedoLater(_ problem: String) -> Bool {
        redoLaterProblems.contains(problem)
    }

    func counts(for day: StudyDay) -> StatusCounts {
        day.problems.reduce(into: StatusCounts()) { counts, problem in
            counts.add(status(for: problem))
        }
    }

    func completionFraction(for day: StudyDay, settings: StudySettings) -> Double {
        let activeHabits = StudyHabit.activeCases(includePatternStudy: settings.includePatternStudy)
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
        case redoLaterProblems
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        completedHabits = try container.decodeIfPresent(Set<StudyHabit>.self, forKey: .completedHabits) ?? []
        problemStatuses = try container.decodeIfPresent([String: ProblemStatus].self, forKey: .problemStatuses) ?? [:]
        redoLaterProblems = try container.decodeIfPresent(Set<String>.self, forKey: .redoLaterProblems) ?? []
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
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

    func summary(for schedule: StudySchedule) -> PlanSummary {
        schedule.days.reduce(into: PlanSummary(totalRequiredProblems: schedule.requiredProblemCount)) { summary, day in
            let daily = dailyProgress(for: day.day)
            let activeHabits = StudyHabit.activeCases(includePatternStudy: schedule.settings.includePatternStudy)
            summary.completedHabits += activeHabits.filter { daily.completedHabits.contains($0) }.count
            summary.totalHabits += activeHabits.count

            for problem in day.problems {
                summary.problemCounts.add(daily.status(for: problem))
            }
        }
    }

    func redoCandidates(for day: Int, in schedule: StudySchedule) -> [RedoCandidate] {
        var seen = Set<String>()
        var candidates: [RedoCandidate] = []

        for previousDay in [day - 3, day - 2] where previousDay >= 1 && previousDay <= schedule.totalDays {
            let planDay = schedule.day(previousDay)
            let daily = dailyProgress(for: previousDay)

            for problem in planDay.problems where daily.status(for: problem) == .red {
                let key = "auto-\(problem)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                candidates.append(RedoCandidate(day: previousDay, topic: planDay.topic, problem: problem, reason: .red))
            }
        }

        for previousDay in 1..<day where previousDay <= schedule.totalDays {
            let planDay = schedule.day(previousDay)
            let daily = dailyProgress(for: previousDay)

            for problem in planDay.problems where daily.redoLaterProblems.contains(problem) {
                let key = "manual-\(problem)"
                guard !seen.contains(key) else { continue }
                seen.insert(key)
                candidates.append(RedoCandidate(day: previousDay, topic: planDay.topic, problem: problem, reason: .manual))
            }
        }

        return candidates
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
    case manual

    var title: String {
        switch self {
        case .red:
            return "Red"
        case .manual:
            return "Marked"
        }
    }
}

struct RedoCandidate: Identifiable, Equatable {
    let day: Int
    let topic: String
    let problem: String
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
