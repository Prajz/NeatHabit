import SwiftUI
import UIKit

private enum AppTab: Hashable {
    case today
    case roadmap
    case progress
    case guide
}

struct ContentView: View {
    @EnvironmentObject private var store: StudyProgressStore
    @State private var selectedTab: AppTab = .today
    @State private var selectedDay = 1
    @State private var selectedInitialDay = false

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TodayTab(selectedDay: $selectedDay)
            }
            .tabItem { Label("Today", systemImage: "target") }
            .tag(AppTab.today)

            NavigationStack {
                RoadmapTab(selectedDay: $selectedDay, selectedTab: $selectedTab)
            }
            .tabItem { Label("Roadmap", systemImage: "map.fill") }
            .tag(AppTab.roadmap)

            NavigationStack {
                ProgressTab(selectedDay: $selectedDay, selectedTab: $selectedTab)
            }
            .tabItem { Label("Progress", systemImage: "chart.bar.xaxis") }
            .tag(AppTab.progress)

            NavigationStack {
                GuideTab()
            }
            .tabItem { Label("Guide", systemImage: "questionmark.circle.fill") }
            .tag(AppTab.guide)
        }
        .tint(Theme.accent)
        .onAppear {
            guard !selectedInitialDay else { return }
            selectedDay = store.progress.currentDayNumber(in: store.schedule)
            selectedInitialDay = true
        }
    }
}

private struct TodayTab: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var selectedDay: Int

    private var schedule: StudySchedule { store.schedule }
    private var day: StudyDay { schedule.day(selectedDay) }
    private var dailyProgress: DailyProgress { store.progress.dailyProgress(for: selectedDay) }

    var body: some View {
        StudyScreen(title: "Today") {
            VStack(spacing: 18) {
                DaySelector(
                    selectedDay: $selectedDay,
                    progress: store.progress,
                    schedule: schedule
                )

                HeroPanel(
                    day: day,
                    dailyProgress: dailyProgress,
                    settings: schedule.settings,
                    currentDay: store.progress.currentDayNumber(in: schedule)
                )

                DailyFlowCard(
                    day: day,
                    dailyProgress: dailyProgress,
                    settings: schedule.settings
                )

                ProblemsCard(
                    day: day,
                    dailyProgress: dailyProgress
                )

                RedoQueueCard(
                    candidates: store.progress.redoCandidates(for: selectedDay, in: schedule),
                    openDay: { selectedDay = $0 }
                )

                NotesCard(day: day)
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Jump to today") {
                        selectedDay = store.progress.currentDayNumber(in: schedule)
                    }

                    Button("Set today as Day 1") {
                        store.resetTimeline()
                        selectedDay = 1
                    }
                } label: {
                    Image(systemName: "calendar.badge.clock")
                }
                .accessibilityLabel("Plan calendar actions")
            }
        }
    }
}

private struct RoadmapTab: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var selectedDay: Int
    @Binding var selectedTab: AppTab

    var body: some View {
        StudyScreen(title: "Roadmap") {
            VStack(spacing: 18) {
                RoadmapIntroCard()

                GeneratedPlanCard(
                    progress: store.progress,
                    schedule: store.schedule,
                    selectedDay: selectedDay,
                    openDay: { day in
                        selectedDay = day
                        selectedTab = .today
                    }
                )

                QuestionBankCard()

                ForEach(RoadmapPhase.all) { phase in
                    RoadmapPhaseCard(
                        phase: phase,
                        progress: store.progress,
                        schedule: store.schedule,
                        selectedDay: selectedDay,
                        openDay: { day in
                            selectedDay = day
                            selectedTab = .today
                        }
                    )
                }
            }
        }
    }
}

private struct ProgressTab: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var selectedDay: Int
    @Binding var selectedTab: AppTab

    private var schedule: StudySchedule { store.schedule }
    private var summary: PlanSummary { store.progress.summary(for: schedule) }

    var body: some View {
        StudyScreen(title: "Progress") {
            VStack(spacing: 18) {
                ProgressHeroCard(summary: summary)

                TargetCard(summary: summary)

                HabitStatsCard(progress: store.progress, schedule: schedule)

                StatusLegendCard()

                UpcomingCard(
                    progress: store.progress,
                    schedule: schedule,
                    selectedDay: $selectedDay,
                    selectedTab: $selectedTab
                )
            }
        }
    }
}

private struct GuideTab: View {
    @EnvironmentObject private var store: StudyProgressStore

    var body: some View {
        StudyScreen(title: "Guide") {
            VStack(spacing: 18) {
                GuideHeaderCard()
                PlanSettingsCard(schedule: store.schedule)
                ExtraPracticeCard()
                GuideStepCard(
                    number: "01",
                    title: "Start the clock",
                    bodyText: "Set a target finish date. The app deterministically spreads the 150 required questions across the available days."
                )
                GuideStepCard(
                    number: "02",
                    title: "Run the daily loop",
                    bodyText: "Choose how much time you want to study each day. Review and system design stay fixed; the problem block adjusts. Pattern study is optional."
                )
                GuideStepCard(
                    number: "03",
                    title: "Mark problem quality",
                    bodyText: "Tap a problem row to cycle Todo -> Green -> Yellow -> Red. Use the menu on the right if you want to pick a color directly."
                )
                GuideStepCard(
                    number: "04",
                    title: "Trust the redo queue",
                    bodyText: "If a problem is Red, it appears again 2-3 days later. You can also manually mark any question as redo later from the problem menu."
                )
                GuideStepCard(
                    number: "05",
                    title: "Add widgets",
                    bodyText: "Add the medium Home Screen widget for daily status. Add the circular or rectangular Lock Screen widget for quick habit pressure without opening the app."
                )
            }
        }
    }
}

private struct StudyScreen<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                content
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
                    .padding(.bottom, 34)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
    }
}

private struct HeroPanel: View {
    let day: StudyDay
    let dailyProgress: DailyProgress
    let settings: StudySettings
    let currentDay: Int

    private var counts: StatusCounts { dailyProgress.counts(for: day) }
    private var fraction: Double { dailyProgress.completionFraction(for: day, settings: settings) }
    private var activeHabitCount: Int { StudyHabit.activeCases(includePatternStudy: settings.includePatternStudy).count }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent, holographic: true) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(day.day == currentDay ? "Current day" : "Selected day")
                            .eyebrow()

                        Text(day.topic)
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .tracking(-1.0)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(day.systemDesignFocus)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 12)

                    DayPill(day: day.day, currentDay: currentDay)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: fraction)
                        .tint(Theme.accent)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)

                    HStack(spacing: 10) {
                        HeroMetric(label: "Complete", value: percent(fraction))
                        HeroMetric(label: "Problems", value: "\(counts.attempted)/\(day.problems.count)")
                        HeroMetric(label: "Habits", value: "\(dailyProgress.completedHabits.count)/\(activeHabitCount)")
                    }
                }
            }
        }
    }
}

private struct DayPill: View {
    let day: Int
    let currentDay: Int

    var body: some View {
        VStack(spacing: 3) {
            Text("D\(day)")
                .font(.system(size: 27, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(day == currentDay ? "today" : "planned")
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .frame(width: 82, height: 82)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.16)).interactive(), in: .rect(cornerRadius: 28))
    }
}

private struct HeroMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.headline.weight(.black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(.white.opacity(0.18)), in: .rect(cornerRadius: 18))
    }
}

private struct DaySelector: View {
    @Binding var selectedDay: Int
    let progress: StoredProgress
    let schedule: StudySchedule

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(schedule.days) { day in
                        let daily = progress.dailyProgress(for: day.day)
                        let fraction = daily.completionFraction(for: day, settings: schedule.settings)
                        let isSelected = selectedDay == day.day
                        let isToday = progress.currentDayNumber(in: schedule) == day.day

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedDay = day.day
                            }
                        } label: {
                            VStack(spacing: 6) {
                                Text("\(day.day)")
                                    .font(.headline.weight(.black))
                                    .monospacedDigit()

                                Circle()
                                    .fill(progressColor(for: fraction))
                                    .frame(width: isToday ? 8 : 6, height: isToday ? 8 : 6)
                            }
                            .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                            .frame(width: 48, height: 58)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            .regular.tint((isSelected ? Theme.accent : .white).opacity(isSelected ? 0.22 : 0.1)).interactive(),
                            in: .rect(cornerRadius: 18)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isToday ? Theme.accent.opacity(0.72) : .white.opacity(isSelected ? 0.45 : 0.16), lineWidth: isToday ? 1.5 : 1)
                        }
                        .accessibilityLabel("Open day \(day.day), \(day.topic)")
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 1)
            }
        }
    }

    private func progressColor(for fraction: Double) -> Color {
        switch fraction {
        case 0:
            return Theme.muted.opacity(0.32)
        case 0..<0.5:
            return Theme.amber
        case 0..<1:
            return Theme.accent
        default:
            return Theme.green
        }
    }
}

private struct DailyFlowCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    let day: StudyDay
    let dailyProgress: DailyProgress
    let settings: StudySettings

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Daily flow",
                    subtitle: "Your time budget creates the problem block automatically."
                )

                VStack(spacing: 11) {
                    ForEach(StudyHabit.activeCases(includePatternStudy: settings.includePatternStudy)) { habit in
                        HabitRow(
                            habit: habit,
                            systemDesignFocus: day.systemDesignFocus,
                            settings: settings,
                            completed: dailyProgress.completedHabits.contains(habit)
                        ) {
                            store.toggleHabit(habit, day: day.day)
                        }
                    }
                }
            }
        }
    }
}

private struct HabitRow: View {
    let habit: StudyHabit
    let systemDesignFocus: String
    let settings: StudySettings
    let completed: Bool
    let toggle: () -> Void

    private var subtitle: String {
        habit == .systemDesign ? systemDesignFocus : habit.subtitle
    }

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(habit.tint.opacity(completed ? 0.22 : 0.12))

                    Image(systemName: completed ? "checkmark" : habit.systemImage)
                        .font(.headline.weight(.black))
                        .foregroundStyle(completed ? Theme.green : habit.tint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(habit.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.ink)

                        Text("\(habit.durationMinutes(settings: settings))m")
                            .font(.caption2.weight(.black))
                            .monospacedDigit()
                            .foregroundStyle(habit.tint)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(habit.tint.opacity(0.12), in: Capsule())
                    }

                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(completed ? Theme.green.opacity(0.08) : .white.opacity(0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .trailing) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(completed ? Theme.green : Theme.muted.opacity(0.55))
                    .padding(.trailing, 12)
            }
        }
        .buttonStyle(.glass)
    }
}

private struct ProblemsCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    let day: StudyDay
    let dailyProgress: DailyProgress

    private var counts: StatusCounts { dailyProgress.counts(for: day) }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    SectionHeader(
                        title: "Problem block",
                        subtitle: "Tap rows to cycle quality. Use the menu for a direct status."
                    )

                    Spacer()

                    StatusCountCluster(counts: counts)
                }

                VStack(spacing: 10) {
                    ForEach(day.problems, id: \.self) { problem in
                        ProblemRow(
                            problem: problem,
                            status: dailyProgress.status(for: problem),
                            markedRedoLater: dailyProgress.isMarkedRedoLater(problem),
                            cycleStatus: {
                                store.cycleStatus(for: problem, day: day.day)
                            },
                            setStatus: { status in
                                store.setStatus(status, for: problem, day: day.day)
                            },
                            toggleRedoLater: {
                                store.toggleRedoLater(for: problem, day: day.day)
                            }
                        )
                    }
                }
            }
        }
    }
}

private struct StatusCountCluster: View {
    let counts: StatusCounts

    var body: some View {
        HStack(spacing: 5) {
            CountBadge(count: counts.green, color: Theme.green, label: "G")
            CountBadge(count: counts.yellow, color: Theme.amber, label: "Y")
            CountBadge(count: counts.red, color: Theme.red, label: "R")
        }
    }
}

private struct CountBadge: View {
    let count: Int
    let color: Color
    let label: String

    var body: some View {
        VStack(spacing: 1) {
            Text("\(count)")
                .font(.caption.weight(.black))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.heavy))
        }
        .foregroundStyle(color)
        .frame(width: 30, height: 34)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct ProblemRow: View {
    let problem: String
    let status: ProblemStatus
    let markedRedoLater: Bool
    let cycleStatus: () -> Void
    let setStatus: (ProblemStatus) -> Void
    let toggleRedoLater: () -> Void

    var body: some View {
        Button(action: cycleStatus) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(status.tint.opacity(0.14))
                    Image(systemName: status.symbol)
                        .font(.caption.weight(.black))
                        .foregroundStyle(status.tint)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 3) {
                    Text(problem)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(status.description)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Menu {
                    ForEach(ProblemStatus.allCases) { option in
                        Button(option.title) {
                            setStatus(option)
                        }
                    }

                    Divider()

                    Button(markedRedoLater ? "Remove redo later" : "Redo later") {
                        toggleRedoLater()
                    }
                } label: {
                    HStack(spacing: 5) {
                        if markedRedoLater {
                            Image(systemName: "bookmark.fill")
                        }
                        Text(status.shortTitle)
                    }
                    .font(.caption.weight(.black))
                    .foregroundStyle(markedRedoLater ? Theme.accent : status.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background((markedRedoLater ? Theme.accent : status.tint).opacity(0.13), in: Capsule())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct RedoQueueCard: View {
    let candidates: [RedoCandidate]
    let openDay: (Int) -> Void

    var body: some View {
        LiquidGlassCard(tint: candidates.isEmpty ? Theme.green : Theme.red) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Redo queue",
                    subtitle: "Red problems are automatic. Bookmarked problems are manual."
                )

                if candidates.isEmpty {
                    EmptyStateRow(
                        symbol: "checkmark.seal.fill",
                        title: "No red redo due",
                        subtitle: "Keep moving. Future red problems will appear here automatically."
                    )
                } else {
                    VStack(spacing: 10) {
                        ForEach(candidates) { candidate in
                            Button {
                                openDay(candidate.day)
                            } label: {
                                HStack(spacing: 12) {
                                    Text(candidate.reason.title)
                                        .font(.caption.weight(.black))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 9)
                                        .padding(.vertical, 6)
                                        .background(Theme.red, in: Capsule())

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(candidate.problem)
                                            .font(.subheadline.weight(.bold))
                                            .foregroundStyle(Theme.ink)
                                        Text("Day \(candidate.day) - \(candidate.topic)")
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(Theme.muted)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.muted)
                                }
                                .padding(12)
                                .background(Theme.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct NotesCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    let day: StudyDay

    var body: some View {
        LiquidGlassCard(tint: Theme.amber) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Pattern notes",
                    subtitle: "Write the template, invariant, or bug that should stick."
                )

                TextEditor(text: Binding(
                    get: { store.progress.dailyProgress(for: day.day).note },
                    set: { store.updateNote($0, day: day.day) }
                ))
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)
                .frame(minHeight: 112)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }
    }
}

private struct RoadmapIntroCard: View {
    var body: some View {
        LiquidGlassCard(tint: Theme.accent, holographic: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Roadmap")
                    .eyebrow()
                Text("A generated plan from a fixed 150-question bank.")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ink)
                Text("Target date controls the number of days. Daily time controls the problem block and capacity warning. No AI scheduling guesswork."
                )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GeneratedPlanCard: View {
    let progress: StoredProgress
    let schedule: StudySchedule
    let selectedDay: Int
    let openDay: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 138), spacing: 10)]

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Generated days",
                    subtitle: "All \(schedule.requiredProblemCount) required questions are distributed across \(schedule.totalDays) days."
                )

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(schedule.days) { day in
                        let daily = progress.dailyProgress(for: day.day)
                        RoadmapDayButton(
                            day: day,
                            fraction: daily.completionFraction(for: day, settings: schedule.settings),
                            isSelected: selectedDay == day.day,
                            isToday: progress.currentDayNumber(in: schedule) == day.day,
                            tint: Theme.accent,
                            action: { openDay(day.day) }
                        )
                    }
                }
            }
        }
    }
}

private struct QuestionBankCard: View {
    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Question bank",
                    subtitle: "The planner consumes these sections in order, then appends optional extras."
                )

                VStack(spacing: 10) {
                    ForEach(StudyPlanner.sections) { section in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(section.problems.count)")
                                .font(.headline.weight(.black))
                                .monospacedDigit()
                                .foregroundStyle(Theme.accent)
                                .frame(width: 40, height: 40)
                                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                            VStack(alignment: .leading, spacing: 4) {
                                Text(section.title)
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(Theme.ink)
                                Text(section.template)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct RoadmapPhaseCard: View {
    let phase: RoadmapPhase
    let progress: StoredProgress
    let schedule: StudySchedule
    let selectedDay: Int
    let openDay: (Int) -> Void

    private let columns = [GridItem(.adaptive(minimum: 138), spacing: 10)]

    var body: some View {
        LiquidGlassCard(tint: phase.tint) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(phase.label)
                            .eyebrow(color: phase.tint)
                        Text(phase.title)
                            .font(.title3.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text(phase.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer()

                    Text(phase.dayRangeText)
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(phase.tint)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(phase.tint.opacity(0.12), in: Capsule())
                }

                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(Array(phase.days).filter { $0 <= schedule.totalDays }, id: \.self) { dayNumber in
                        let planDay = schedule.day(dayNumber)
                        let daily = progress.dailyProgress(for: dayNumber)

                        RoadmapDayButton(
                            day: planDay,
                            fraction: daily.completionFraction(for: planDay, settings: schedule.settings),
                            isSelected: selectedDay == dayNumber,
                            isToday: progress.currentDayNumber(in: schedule) == dayNumber,
                            tint: phase.tint,
                            action: { openDay(dayNumber) }
                        )
                    }
                }
            }
        }
    }
}

private struct RoadmapDayButton: View {
    let day: StudyDay
    let fraction: Double
    let isSelected: Bool
    let isToday: Bool
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    Text("D\(day.day)")
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? tint : Theme.muted)
                    Spacer()
                    Circle()
                        .fill(progressColor)
                        .frame(width: 8, height: 8)
                }

                Text(day.topic)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(minHeight: 86, alignment: .top)
            .background((isSelected ? tint.opacity(0.12) : .white.opacity(0.16)), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isToday ? Theme.accent.opacity(0.65) : .white.opacity(0.12), lineWidth: isToday ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var progressColor: Color {
        switch fraction {
        case 0:
            return Theme.muted.opacity(0.28)
        case 0..<1:
            return Theme.amber
        default:
            return Theme.green
        }
    }
}

private struct ProgressHeroCard: View {
    let summary: PlanSummary

    var body: some View {
        LiquidGlassCard(tint: Theme.accent, holographic: true) {
            HStack(spacing: 18) {
                ProgressRing(fraction: summary.completionFraction, tint: Theme.accent)
                    .frame(width: 108, height: 108)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Month status")
                        .eyebrow()
                    Text("\(summary.completedProblems)/\(summary.totalProblems) problems touched")
                        .font(.title2.weight(.black))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Green matters most, yellow is acceptable, red is a redo signal.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                }

                Spacer(minLength: 0)
            }
        }
    }
}

private struct TargetCard: View {
    let summary: PlanSummary

    var body: some View {
        LiquidGlassCard(tint: Theme.green) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Targets",
                    subtitle: "These are the success thresholds for the month."
                )

                VStack(spacing: 12) {
                    TargetBar(title: "Green", value: summary.problemCounts.green, target: 80, color: Theme.green, rule: "at least")
                    TargetBar(title: "Yellow", value: summary.problemCounts.yellow, target: 40, color: Theme.amber, rule: "around")
                    TargetBar(title: "Red", value: summary.problemCounts.red, target: 30, color: Theme.red, rule: "under")
                }
            }
        }
    }
}

private struct TargetBar: View {
    let title: String
    let value: Int
    let target: Int
    let color: Color
    let rule: String

    private var fraction: Double {
        min(Double(value) / Double(max(target, 1)), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(value) / \(rule) \(target)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.muted)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(color.opacity(0.12))
                    Capsule()
                        .fill(color)
                        .frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 10)
        }
        .padding(12)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct HabitStatsCard: View {
    let progress: StoredProgress
    let schedule: StudySchedule

    private var completedByHabit: [(StudyHabit, Int)] {
        StudyHabit.activeCases(includePatternStudy: schedule.settings.includePatternStudy).map { habit in
            let count = schedule.days.filter { day in
                progress.dailyProgress(for: day.day).completedHabits.contains(habit)
            }.count

            return (habit, count)
        }
    }

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Habit consistency",
                    subtitle: "Each block compounds. System design is tracked like the coding work."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(completedByHabit, id: \.0.id) { habit, count in
                        MetricTile(
                            title: habit.shortTitle,
                            value: "\(count)/\(schedule.totalDays)",
                            symbol: habit.systemImage,
                            tint: habit.tint
                        )
                    }
                }
            }
        }
    }
}

private struct StatusLegendCard: View {
    var body: some View {
        LiquidGlassCard(tint: Theme.amber) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Color rules",
                    subtitle: "Use colors to measure interview readiness, not effort."
                )

                ForEach([ProblemStatus.green, .yellow, .red], id: \.self) { status in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(status.tint)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(status.title)
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(Theme.ink)
                            Text(status.description)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .padding(12)
                    .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
    }
}

private struct UpcomingCard: View {
    let progress: StoredProgress
    let schedule: StudySchedule
    @Binding var selectedDay: Int
    @Binding var selectedTab: AppTab

    private var upcomingDays: [StudyDay] {
        let start = progress.currentDayNumber(in: schedule)
        guard start <= schedule.totalDays else { return [] }
        return (start...min(start + 2, schedule.totalDays)).map(schedule.day)
    }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Next few days",
                    subtitle: "Preview the shape of the work ahead."
                )

                VStack(spacing: 10) {
                    ForEach(upcomingDays) { day in
                        Button {
                            selectedDay = day.day
                            selectedTab = .today
                        } label: {
                            HStack(spacing: 12) {
                                Text("D\(day.day)")
                                    .font(.caption.weight(.black))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Theme.accent.opacity(0.12), in: Capsule())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(day.topic)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                    Text("\(day.problems.count) problems")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Theme.muted)
                                }

                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.muted)
                            }
                            .padding(12)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct GuideHeaderCard: View {
    var body: some View {
        LiquidGlassCard(tint: Theme.accent, holographic: true) {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to use NeatHabit")
                    .eyebrow()
                Text("Set the target, finish the required 150, add extras only if you want more practice.")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct PlanSettingsCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    let schedule: StudySchedule

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Plan controls",
                    subtitle: "The generated plan always includes all 150 required questions."
                )

                VStack(spacing: 12) {
                    DatePicker(
                        "Target finish date",
                        selection: Binding(
                            get: { store.progress.settings.targetFinishDate },
                            set: { store.updateTargetFinishDate($0) }
                        ),
                        displayedComponents: .date
                    )
                    .font(.subheadline.weight(.bold))

                    Stepper(
                        "Daily time: \(store.progress.settings.dailyMinutes)m",
                        value: Binding(
                            get: { store.progress.settings.dailyMinutes },
                            set: { store.updateDailyMinutes($0) }
                        ),
                        in: 80...600,
                        step: 10
                    )
                    .font(.subheadline.weight(.bold))

                    Toggle(
                        "Include optional pattern study",
                        isOn: Binding(
                            get: { store.progress.settings.includePatternStudy },
                            set: { store.updatePatternStudyEnabled($0) }
                        )
                    )
                    .font(.subheadline.weight(.bold))
                }
                .padding(14)
                .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.accent)
                    MetricTile(title: "Required", value: "\(schedule.requiredProblemCount)", symbol: "checklist", tint: Theme.green)
                    MetricTile(title: "Extras", value: "\(schedule.extraProblemCount)", symbol: "plus.circle.fill", tint: Theme.glassBlue)
                    MetricTile(title: "Block", value: "\(schedule.settings.problemBlockMinutes)m", symbol: "timer", tint: Theme.amber)
                }

                if schedule.dailyLoadIsOverCapacity {
                    EmptyStateRow(
                        symbol: "exclamationmark.triangle.fill",
                        title: "Target is aggressive",
                        subtitle: "This target needs about \(String(format: "%.1f", schedule.averageProblemsPerDay)) problems/day, above your estimated capacity of \(schedule.settings.estimatedProblemCapacity)/day."
                    )
                }

                HStack(spacing: 10) {
                    Button("Reset timeline") {
                        store.resetTimeline()
                    }
                    .buttonStyle(.glass)

                    Button("Clear progress") {
                        store.clearAllProgressKeepPlan()
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }
}

private struct ExtraPracticeCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    @State private var title = ""
    @State private var section = "Extra Practice"

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Optional extras",
                    subtitle: "Extras are added after the required 150 and included in the generated plan."
                )

                VStack(spacing: 10) {
                    TextField("Problem name", text: $title)
                        .textFieldStyle(.roundedBorder)
                    TextField("Section", text: $section)
                        .textFieldStyle(.roundedBorder)

                    Button("Add extra problem") {
                        store.addExtraProblem(title: title, sectionTitle: section)
                        title = ""
                        section = "Extra Practice"
                    }
                    .buttonStyle(.glass)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !store.progress.settings.extraProblems.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(store.progress.settings.extraProblems) { problem in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(problem.title)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Theme.ink)
                                    Text(problem.sectionTitle)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(Theme.muted)
                                }
                                Spacer()
                                Button("Remove") {
                                    store.removeExtraProblem(problem)
                                }
                                .font(.caption.weight(.bold))
                            }
                            .padding(12)
                            .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        }
                    }
                }
            }
        }
    }
}

private struct GuideStepCard: View {
    let number: String
    let title: String
    let bodyText: String

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            HStack(alignment: .top, spacing: 14) {
                Text(number)
                    .font(.headline.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.tint(Theme.accent.opacity(0.16)), in: .rect(cornerRadius: 18))

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text(bodyText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct EmptyStateRow: View {
    let symbol: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.green)
                .frame(width: 42, height: 42)
                .background(Theme.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.headline.weight(.black))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.black))
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ProgressRing: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.13), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(percent(fraction))
                    .font(.title3.weight(.black))
                    .monospacedDigit()
                Text("done")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct LiquidGlassCard<Content: View>: View {
    let tint: Color
    let holographic: Bool
    let content: Content

    init(tint: Color = Theme.accent, holographic: Bool = false, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.holographic = holographic
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        if holographic {
                            HolographicWash()
                                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        }
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.72), tint.opacity(0.2), .white.opacity(0.18)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(.regular.tint(tint.opacity(0.12)), in: .rect(cornerRadius: 30))
            .shadow(color: Theme.ink.opacity(0.08), radius: 24, x: 0, y: 18)
    }
}

private struct HolographicWash: View {
    var body: some View {
        ZStack {
            AngularGradient(
                colors: [
                    Theme.accent.opacity(0.0),
                    Theme.accent.opacity(0.28),
                    Theme.amber.opacity(0.18),
                    Theme.glassBlue.opacity(0.24),
                    Theme.accent.opacity(0.0)
                ],
                center: .topTrailing,
                angle: .degrees(18)
            )
            .blur(radius: 18)

            LinearGradient(
                colors: [.white.opacity(0.42), .clear, .white.opacity(0.16)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .blendMode(.plusLighter)
        .opacity(0.72)
    }
}

private struct AppBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.canvasTop, Theme.canvas, Theme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Circle()
                .fill(Theme.accent.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 38)
                .offset(x: -160, y: -260)

            Circle()
                .fill(Theme.amber.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 44)
                .offset(x: 160, y: -90)

            Circle()
                .fill(Theme.glassBlue.opacity(0.17))
                .frame(width: 280, height: 280)
                .blur(radius: 52)
                .offset(x: 130, y: 330)
        }
        .ignoresSafeArea()
    }
}

private struct RoadmapPhase: Identifiable {
    let id: String
    let label: String
    let title: String
    let subtitle: String
    let days: ClosedRange<Int>
    let tint: Color

    var dayRangeText: String { "D\(days.lowerBound)-D\(days.upperBound)" }

    static let all = [
        RoadmapPhase(
            id: "foundations",
            label: "Phase 1",
            title: "Foundations and pointers",
            subtitle: "Arrays, hashing, two pointers, sliding windows, stack, binary search.",
            days: 1...7,
            tint: Theme.accent
        ),
        RoadmapPhase(
            id: "structures",
            label: "Phase 2",
            title: "Core data structures",
            subtitle: "Linked lists, trees, heaps, tries, and the harder design-style structures.",
            days: 8...15,
            tint: Theme.glassBlue
        ),
        RoadmapPhase(
            id: "search",
            label: "Phase 3",
            title: "Search space and graphs",
            subtitle: "Backtracking, grid traversal, graph modeling, topo sort, shortest path.",
            days: 16...21,
            tint: Theme.amber
        ),
        RoadmapPhase(
            id: "dp",
            label: "Phase 4",
            title: "Dynamic programming",
            subtitle: "Memo first, then bottom-up, with 1D, 2D, and final boss problems.",
            days: 22...26,
            tint: Theme.green
        ),
        RoadmapPhase(
            id: "finish",
            label: "Phase 5",
            title: "Intervals, greedy, math",
            subtitle: "Finish with scheduling, greedy decisions, matrix work, and bit manipulation.",
            days: 27...30,
            tint: Theme.red
        )
    ]
}

private enum Theme {
    static let ink = dynamic(light: (0.075, 0.092, 0.125), dark: (0.90, 0.94, 0.92))
    static let muted = dynamic(light: (0.35, 0.39, 0.43), dark: (0.65, 0.71, 0.68))
    static let canvasTop = dynamic(light: (0.96, 0.975, 0.965), dark: (0.045, 0.060, 0.070))
    static let canvas = dynamic(light: (0.925, 0.95, 0.935), dark: (0.060, 0.082, 0.090))
    static let canvasBottom = dynamic(light: (0.875, 0.91, 0.90), dark: (0.035, 0.050, 0.060))
    static let accent = Color(red: 0.06, green: 0.52, blue: 0.45)
    static let glassBlue = Color(red: 0.18, green: 0.42, blue: 0.66)
    static let green = Color(red: 0.20, green: 0.58, blue: 0.34)
    static let amber = Color(red: 0.78, green: 0.49, blue: 0.16)
    static let red = Color(red: 0.72, green: 0.25, blue: 0.24)

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let values = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: values.0, green: values.1, blue: values.2, alpha: 1)
        })
    }
}

private extension Text {
    func eyebrow(color: Color = Theme.accent) -> some View {
        self
            .font(.caption.weight(.black))
            .tracking(1.1)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}

private extension StudyHabit {
    var tint: Color {
        switch self {
        case .pattern:
            return Theme.glassBlue
        case .problems:
            return Theme.accent
        case .review:
            return Theme.amber
        case .systemDesign:
            return Theme.ink
        }
    }
}

private extension ProblemStatus {
    var tint: Color {
        switch self {
        case .untouched:
            return Theme.muted
        case .green:
            return Theme.green
        case .yellow:
            return Theme.amber
        case .red:
            return Theme.red
        }
    }

    var symbol: String {
        switch self {
        case .untouched:
            return "circle"
        case .green:
            return "checkmark"
        case .yellow:
            return "lightbulb.fill"
        case .red:
            return "exclamationmark"
        }
    }
}

private func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}

#Preview {
    ContentView()
        .environmentObject(StudyProgressStore())
}
