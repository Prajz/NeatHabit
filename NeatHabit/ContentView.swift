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
        Group {
            if store.hasCompletedOnboarding {
                mainTabs
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                OnboardingView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.smooth(duration: 0.45), value: store.hasCompletedOnboarding)
    }

    private var mainTabs: some View {
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
    private var redoCandidates: [RedoCandidate] { store.progress.redoCandidates(for: selectedDay, in: schedule) }

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
                    currentDay: store.progress.currentDayNumber(in: schedule),
                    hasRedoDue: !redoCandidates.isEmpty
                )

                DailyFlowCard(
                    day: day,
                    dailyProgress: dailyProgress,
                    settings: schedule.settings,
                    hasRedoDue: !redoCandidates.isEmpty
                )

                ProblemsCard(
                    day: day,
                    dailyProgress: dailyProgress
                )

                if !redoCandidates.isEmpty {
                    RedoQueueCard(
                        candidates: redoCandidates,
                        openDay: { selectedDay = $0 }
                    )
                }

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

                QuestionBankCard(schedule: store.schedule)

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
                    bodyText: "Choose how much time you want to study each day. System design stays daily, pattern study is optional, and redo appears only when due."
                )
                GuideStepCard(
                    number: "03",
                    title: "Mark problem quality",
                    bodyText: "Tap a problem row to cycle Todo -> Green -> Yellow -> Red. The problem block is complete when every planned question has a color."
                )
                GuideStepCard(
                    number: "04",
                    title: "Schedule red problems",
                    bodyText: "When a problem turns Red, keep the automatic redo date or pick the exact date you want it to come back."
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

private struct OnboardingView: View {
    @EnvironmentObject private var store: StudyProgressStore
    @State private var appeared = false

    private var schedule: StudySchedule { store.schedule }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    LiquidGlassCard(tint: Theme.accent, holographic: true) {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack {
                                Text("NeatHabit")
                                    .eyebrow()

                                Spacer()

                                Text("\(schedule.requiredProblemCount) required")
                                    .font(.caption.weight(.black))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 7)
                                    .background(Theme.accent.opacity(0.12), in: Capsule())
                            }

                            Text("Build the daily loop before the plan starts.")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .tracking(-1.2)
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(-2)
                                .fixedSize(horizontal: false, vertical: true)

                            Text("Choose the finish date and study budget. The app spreads the fixed question bank, keeps pattern study optional, and brings red problems back on scheduled redo dates.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.muted)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    LiquidGlassCard(tint: Theme.glassBlue) {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeader(
                                title: "Set the plan",
                                subtitle: "These controls can still be changed later in Guide."
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
                                    "Add optional pattern study",
                                    isOn: Binding(
                                        get: { store.progress.settings.includePatternStudy },
                                        set: { store.updatePatternStudyEnabled($0) }
                                    )
                                )
                                .font(.subheadline.weight(.bold))
                            }
                            .padding(14)
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                            HStack(spacing: 10) {
                                MetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.accent)
                                MetricTile(title: "Problems/day", value: String(format: "%.1f", schedule.averageProblemsPerDay), symbol: "keyboard.fill", tint: Theme.green)
                            }
                        }
                    }

                    LiquidGlassCard(tint: Theme.amber) {
                        VStack(alignment: .leading, spacing: 14) {
                            SectionHeader(
                                title: "The daily rule",
                                subtitle: "No duplicate checkboxes for work you already recorded."
                            )

                            OnboardingStepRow(
                                number: "01",
                                title: "Solve the planned questions",
                                bodyText: "The problem block is complete when every row has a color."
                            )

                            OnboardingStepRow(
                                number: "02",
                                title: "Use red as a redo signal",
                                bodyText: "Mark red, then keep the automatic redo date or pick the exact date."
                            )

                            OnboardingStepRow(
                                number: "03",
                                title: "Keep system design daily",
                                bodyText: "One focused design topic stays in the loop. Pattern study is optional."
                            )
                        }
                    }

                    Button {
                        store.completeOnboarding()
                    } label: {
                        HStack {
                            Text("Start today")
                                .font(.headline.weight(.black))
                            Spacer()
                            Image(systemName: "arrow.right")
                                .font(.headline.weight(.black))
                        }
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: Theme.accent.opacity(0.28), radius: 22, x: 0, y: 14)
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 28)
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .onAppear {
            withAnimation(.smooth(duration: 0.55)) {
                appeared = true
            }
        }
    }
}

private struct OnboardingStepRow: View {
    let number: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(Theme.amber)
                .frame(width: 34, height: 34)
                .background(Theme.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text(bodyText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            .scrollDismissesKeyboard(.interactively)
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
    let hasRedoDue: Bool

    private var counts: StatusCounts { dailyProgress.counts(for: day) }
    private var fraction: Double { dailyProgress.completionFraction(for: day, settings: settings, hasRedoDue: hasRedoDue) }
    private var activeHabits: [StudyHabit] {
        StudyHabit.activeCases(includePatternStudy: settings.includePatternStudy, hasRedoDue: hasRedoDue)
    }
    private var activeHabitCount: Int {
        activeHabits.count
    }
    private var completedActiveHabitCount: Int {
        activeHabits.filter { dailyProgress.completedHabits.contains($0) }.count
    }

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

                    DayPill(day: day, currentDay: currentDay)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: fraction)
                        .tint(Theme.accent)
                        .scaleEffect(x: 1, y: 1.8, anchor: .center)

                    HStack(spacing: 10) {
                        HeroMetric(label: "Complete", value: percent(fraction))
                        HeroMetric(label: "Problems", value: "\(counts.attempted)/\(day.problems.count)")
                        HeroMetric(label: "Habits", value: "\(completedActiveHabitCount)/\(activeHabitCount)")
                    }
                }
            }
        }
    }
}

private struct DayPill: View {
    let day: StudyDay
    let currentDay: Int

    var body: some View {
        VStack(spacing: 3) {
            Text(day.date.map(shortDateText) ?? "Day")
                .font(.caption.weight(.black))
                .monospacedDigit()
            Text("D\(day.day)")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .monospacedDigit()
            Text(day.day == currentDay ? "today" : "planned")
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
        .glassEffect(.regular.tint(Theme.surface.opacity(0.26)), in: .rect(cornerRadius: 18))
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
                        let fraction = progress.completionFraction(for: day, in: schedule)
                        let isSelected = selectedDay == day.day
                        let isToday = progress.currentDayNumber(in: schedule) == day.day

                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                selectedDay = day.day
                            }
                        } label: {
                            VStack(spacing: 5) {
                                Text(day.date.map(shortDateText) ?? "Day")
                                    .font(.caption2.weight(.black))
                                    .lineLimit(1)

                                Text("D\(day.day)")
                                    .font(.caption.weight(.black))
                                    .monospacedDigit()

                                Circle()
                                    .fill(progressColor(for: fraction))
                                    .frame(width: isToday ? 8 : 6, height: isToday ? 8 : 6)
                            }
                            .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                            .frame(width: 62, height: 62)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(
                            .regular.tint((isSelected ? Theme.accent : Theme.surface).opacity(isSelected ? 0.22 : 0.18)).interactive(),
                            in: .rect(cornerRadius: 18)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isToday ? Theme.accent.opacity(0.72) : Theme.hairline.opacity(isSelected ? 0.7 : 0.38), lineWidth: isToday ? 1.5 : 1)
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
    let hasRedoDue: Bool

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Daily essentials",
                    subtitle: "Problems complete from rows. Redo appears only when scheduled."
                )

                VStack(spacing: 11) {
                    ForEach(StudyHabit.activeCases(includePatternStudy: settings.includePatternStudy, hasRedoDue: hasRedoDue)) { habit in
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
            .background(completed ? Theme.green.opacity(0.09) : Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
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
    @State private var redoPrompt: RedoPrompt?
    let day: StudyDay
    let dailyProgress: DailyProgress

    private var counts: StatusCounts { dailyProgress.counts(for: day) }
    private var problemBlockComplete: Bool { counts.total > 0 && counts.untouched == 0 }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    SectionHeader(
                        title: "Problem block",
                        subtitle: "This completes automatically when every planned question is touched."
                    )

                    Spacer()

                    if problemBlockComplete {
                        CompletionBadge(title: "Complete", color: Theme.green)
                    } else {
                        StatusCountCluster(counts: counts)
                    }
                }

                VStack(spacing: 10) {
                    ForEach(day.problems, id: \.self) { problem in
                        ProblemRow(
                            problem: problem,
                            status: dailyProgress.status(for: problem),
                            redoDate: dailyProgress.redoDate(for: problem),
                            cycleStatus: {
                                applyStatus(dailyProgress.status(for: problem).next, for: problem)
                            },
                            setStatus: { status in
                                applyStatus(status, for: problem)
                            },
                            editRedoDate: {
                                redoPrompt = RedoPrompt(day: day, problem: problem)
                            }
                        )
                    }
                }
            }
        }
        .sheet(item: $redoPrompt) { prompt in
            let currentDate = store.progress.dailyProgress(for: prompt.day.day).redoDate(for: prompt.problem) ?? store.suggestedRedoDate(for: prompt.day.day)
            RedoScheduleSheet(
                day: prompt.day,
                problem: prompt.problem,
                currentDate: currentDate,
                suggestedDate: store.suggestedRedoDate(for: prompt.day.day),
                save: { date in
                    store.updateRedoDate(date, for: prompt.problem, day: prompt.day.day)
                    redoPrompt = nil
                },
                dismiss: {
                    redoPrompt = nil
                }
            )
            .presentationDetents([.height(440), .medium])
        }
    }

    private func applyStatus(_ status: ProblemStatus, for problem: String) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            store.setStatus(status, for: problem, day: day.day)
        }

        if status == .red {
            redoPrompt = RedoPrompt(day: day, problem: problem)
        }
    }
}

private struct CompletionBadge: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.circle.fill")
            Text(title)
        }
        .font(.caption.weight(.black))
        .foregroundStyle(color)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.12), in: Capsule())
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
    let redoDate: Date?
    let cycleStatus: () -> Void
    let setStatus: (ProblemStatus) -> Void
    let editRedoDate: () -> Void

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
                    Text(redoSubtitle)
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
                    if status == .red {
                        Divider()

                        Button("Change redo date") {
                            editRedoDate()
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        if status == .red {
                            Image(systemName: "calendar.badge.clock")
                        }
                        Text(statusChipText)
                    }
                    .font(.caption.weight(.black))
                    .foregroundStyle(status.tint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(status.tint.opacity(0.13), in: Capsule())
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var redoSubtitle: String {
        guard status == .red, let redoDate else {
            return status.description
        }

        return "Redo scheduled for \(longDateText(redoDate))"
    }

    private var statusChipText: String {
        guard status == .red, let redoDate else {
            return status.shortTitle
        }

        return shortDateText(redoDate)
    }
}

private struct RedoPrompt: Identifiable {
    let day: StudyDay
    let problem: String

    var id: String { "\(day.day)-\(problem)" }
}

private struct RedoScheduleSheet: View {
    let day: StudyDay
    let problem: String
    let suggestedDate: Date
    let save: (Date) -> Void
    let dismiss: () -> Void

    @State private var selectedDate: Date
    @State private var appeared = false

    init(
        day: StudyDay,
        problem: String,
        currentDate: Date,
        suggestedDate: Date,
        save: @escaping (Date) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.day = day
        self.problem = problem
        self.suggestedDate = suggestedDate
        self.save = save
        self.dismiss = dismiss

        let today = Calendar.current.startOfDay(for: Date())
        _selectedDate = State(initialValue: max(Calendar.current.startOfDay(for: currentDate), today))
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(alignment: .leading, spacing: 18) {
                Capsule()
                    .fill(Theme.muted.opacity(0.28))
                    .frame(width: 44, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 38, weight: .black))
                        .foregroundStyle(Theme.red)
                        .symbolEffect(.pulse, value: appeared)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Red means redo")
                            .eyebrow(color: Theme.red)
                        Text("Schedule the next attempt")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .tracking(-0.7)
                            .foregroundStyle(Theme.ink)
                        Text(problem)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("A few days of spacing is usually enough. Keep the automatic date or choose the exact day you want this to come back.")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(2)

                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.84)) {
                            selectedDate = suggestedDate
                        }
                    } label: {
                        HStack {
                            Label("Use automatic", systemImage: "wand.and.stars")
                            Spacer()
                            Text(shortDateText(suggestedDate))
                                .monospacedDigit()
                        }
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Theme.red)
                    }
                    .buttonStyle(.plain)
                    .padding(12)
                    .background(Theme.red.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    DatePicker(
                        "Redo date",
                        selection: $selectedDate,
                        in: redoDateRange,
                        displayedComponents: .date
                    )
                    .font(.subheadline.weight(.bold))
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                HStack(spacing: 10) {
                    Button("Keep current") {
                        dismiss()
                    }
                    .buttonStyle(.glass)

                    Button("Save redo date") {
                        save(selectedDate)
                    }
                    .buttonStyle(.glass)
                    .tint(Theme.red)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(22)
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
        }
        .onAppear {
            withAnimation(.smooth(duration: 0.36)) {
                appeared = true
            }
        }
    }

    private var redoDateRange: ClosedRange<Date> {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let latest = calendar.date(byAdding: .day, value: 180, to: today) ?? today
        return today...latest
    }
}

private struct RedoQueueCard: View {
    let candidates: [RedoCandidate]
    let openDay: (Int) -> Void

    var body: some View {
        LiquidGlassCard(tint: candidates.isEmpty ? Theme.green : Theme.red) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Redo due",
                    subtitle: "Only scheduled red problems appear here."
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
                                        Text("Due \(shortDateText(candidate.dueDate)) - D\(candidate.day) - \(candidate.topic)")
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
    @FocusState private var notesFocused: Bool
    let day: StudyDay

    var body: some View {
        LiquidGlassCard(tint: Theme.amber) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Study notes",
                    subtitle: "Write the template, invariant, or bug that should stick."
                )

                TextEditor(text: Binding(
                    get: { store.progress.dailyProgress(for: day.day).note },
                    set: { store.updateNote($0, day: day.day) }
                ))
                .font(.body.weight(.medium))
                .foregroundStyle(Theme.ink)
                .focused($notesFocused)
                .frame(minHeight: 112)
                .padding(12)
                .scrollContentBackground(.hidden)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            notesFocused = false
                        }
                        .font(.headline.weight(.bold))
                    }
                }
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
                        RoadmapDayButton(
                            day: day,
                            fraction: progress.completionFraction(for: day, in: schedule),
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
    let schedule: StudySchedule

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Question bank",
                    subtitle: "The planner consumes these sections in order, then appends optional extras."
                )

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 10) {
                        MetricTile(title: "Required", value: "\(schedule.requiredProblemCount)", symbol: "checklist", tint: Theme.accent)
                        MetricTile(title: "Sections", value: "\(StudyPlanner.sections.count)", symbol: "square.grid.2x2.fill", tint: Theme.glassBlue)
                    }

                    HStack(spacing: 10) {
                        MetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.green)
                        MetricTile(title: "Avg/day", value: String(format: "%.1f", schedule.averageProblemsPerDay), symbol: "chart.line.uptrend.xyaxis", tint: Theme.amber)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("First stretch")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Theme.muted)

                        ForEach(Array(StudyPlanner.sections.prefix(3))) { section in
                            HStack(spacing: 8) {
                                Text("\(section.problems.count)")
                                    .font(.caption.weight(.black))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.accent)
                                    .frame(width: 28, height: 28)
                                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                Text(section.title)
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(Theme.ink)

                                Spacer()
                            }
                        }
                    }
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }

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
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                        RoadmapDayButton(
                            day: planDay,
                            fraction: progress.completionFraction(for: planDay, in: schedule),
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
                    Text(day.date.map(shortDateText) ?? "D\(day.day)")
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? tint : Theme.muted)
                    Spacer()
                    Circle()
                        .fill(progressColor)
                        .frame(width: 8, height: 8)
                }

                Text("D\(day.day)")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()

                Text(day.topic)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .frame(minHeight: 86, alignment: .top)
            .background((isSelected ? tint.opacity(0.12) : Theme.surface), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(isToday ? Theme.accent.opacity(0.65) : Theme.hairline.opacity(0.35), lineWidth: isToday ? 1.5 : 1)
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
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct HabitStatsCard: View {
    let progress: StoredProgress
    let schedule: StudySchedule

    private var visibleHabits: [StudyHabit] {
        var result: [StudyHabit] = []

        for day in schedule.days {
            for habit in progress.activeHabits(for: day.day, in: schedule) where !result.contains(habit) {
                result.append(habit)
            }
        }

        return result
    }

    private var completedByHabit: [(StudyHabit, Int)] {
        visibleHabits.map { habit in
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
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
                                VStack(spacing: 1) {
                                    Text(day.date.map(shortDateText) ?? "Day")
                                    Text("D\(day.day)")
                                }
                                    .font(.caption2.weight(.black))
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
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                    subtitle: "The plan includes all 150 required questions. Redo dates are scheduled from red marks."
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
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

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
                            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
                        RoundedRectangle(cornerRadius: 30, style: .continuous)
                            .fill(Theme.cardFill.opacity(0.54))
                    }
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
                            colors: [Theme.cardHighlight.opacity(0.78), tint.opacity(0.26), Theme.hairline.opacity(0.32)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .glassEffect(.regular.tint(tint.opacity(0.12)), in: .rect(cornerRadius: 30))
            .shadow(color: Theme.cardShadow.opacity(0.18), radius: 24, x: 0, y: 18)
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
                colors: [Theme.cardHighlight.opacity(0.42), .clear, Theme.cardHighlight.opacity(0.16)],
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
    static let surface = dynamic(light: (0.985, 1.0, 0.98), dark: (0.105, 0.135, 0.14)).opacity(0.82)
    static let cardFill = dynamic(light: (0.985, 1.0, 0.98), dark: (0.075, 0.098, 0.105))
    static let cardHighlight = dynamic(light: (1.0, 1.0, 1.0), dark: (0.34, 0.42, 0.40))
    static let hairline = dynamic(light: (1.0, 1.0, 1.0), dark: (0.28, 0.36, 0.34))
    static let cardShadow = dynamic(light: (0.07, 0.11, 0.10), dark: (0.0, 0.0, 0.0))
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

private func shortDateText(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
}

private func longDateText(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
}

private func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}

#Preview {
    ContentView()
        .environmentObject(StudyProgressStore())
}
