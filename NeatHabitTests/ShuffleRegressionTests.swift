import XCTest
@testable import NeatHabitat

final class ShuffleRegressionTests: XCTestCase {
    @MainActor
    func testShuffledFutureProblemCannotBeStoredTwiceWhenMarkedAgain() {
        let start = Calendar.current.startOfDay(for: Date())
        let settings = StudySettings(
            targetFinishDate: Calendar.current.date(byAdding: .day, value: 29, to: start) ?? start
        )
        let progress = StoredProgress(startDate: start, settings: settings)
        let store = StudyProgressStore(
            progress: progress,
            onboardingDefaults: UserDefaults(suiteName: "ShuffleRegressionTests-") ?? .standard,
            saveProgress: { _ in }
        )
        let problem = "Valid Parentheses"
        let baseSchedule = StudyPlanner.plan(startDate: start, settings: settings)
        guard let originalDay = baseSchedule.days.first(where: { $0.problems.contains(problem) })?.day else {
            XCTFail("Expected base schedule to contain \(problem)")
            return
        }

        store.setStatus(.green, for: problem, day: originalDay)

        XCTAssertEqual(store.shuffleCompletedFutureProblems(), 1)
        XCTAssertEqual(storedDays(for: problem, in: store.progress).count, 1)

        store.setStatus(.green, for: problem, day: originalDay)

        XCTAssertEqual(storedDays(for: problem, in: store.progress), [originalDay])
        XCTAssertEqual(occurrences(of: problem, in: store.schedule(lockingThrough: originalDay)), 1)
    }

    func testPlannerDoesNotRenderDuplicateTitlesFromCorruptedProgress() {
        let start = Calendar.current.startOfDay(for: Date())
        let settings = StudySettings(
            targetFinishDate: Calendar.current.date(byAdding: .day, value: 29, to: start) ?? start
        )
        let problem = "Valid Parentheses"
        let baseSchedule = StudyPlanner.plan(startDate: start, settings: settings)
        guard let originalDay = baseSchedule.days.first(where: { $0.problems.contains(problem) })?.day else {
            XCTFail("Expected base schedule to contain \(problem)")
            return
        }
        let progress = StoredProgress(
            startDate: start,
            settings: settings,
            dayProgress: [
                1: DailyProgress(problemStatuses: [problem: .green]),
                originalDay: DailyProgress(problemStatuses: [problem: .green])
            ]
        )

        let schedule = StudyPlanner.plan(for: progress, lockThroughDay: originalDay)

        XCTAssertEqual(occurrences(of: problem, in: schedule), 1)
    }

    @MainActor
    func testCustomProblemDifficultyIsStored() {
        let store = StudyProgressStore(
            progress: StoredProgress(),
            onboardingDefaults: UserDefaults(suiteName: "CustomProblemDifficultyTests-") ?? .standard,
            saveProgress: { _ in }
        )

        store.addExtraProblem(title: "Alien Dictionary Variant", sectionTitle: "Graphs", difficulty: .hard)

        XCTAssertEqual(store.progress.settings.extraProblems.first?.difficulty, .hard)
        XCTAssertEqual(StudyPlanner.difficulty(for: "Alien Dictionary Variant", settings: store.progress.settings), .hard)
    }

    private func storedDays(for problem: String, in progress: StoredProgress) -> [Int] {
        progress.dayProgress.keys.sorted().filter { day in
            progress.dailyProgress(for: day).problemStatuses[problem] != nil
        }
    }

    private func occurrences(of problem: String, in schedule: StudySchedule) -> Int {
        schedule.days.reduce(0) { count, day in
            count + day.problems.filter { $0 == problem }.count
        }
    }
}
