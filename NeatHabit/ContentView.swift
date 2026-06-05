import SwiftUI

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
        .font(AppFont.body())
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

                if !redoCandidates.isEmpty {
                    RedoQueueCard(
                        candidates: redoCandidates,
                        openDay: { selectedDay = $0 }
                    )
                }

                ProblemsCard(
                    day: day,
                    dailyProgress: dailyProgress
                )

                DailyFlowCard(
                    day: day,
                    dailyProgress: dailyProgress,
                    settings: schedule.settings,
                    hasRedoDue: !redoCandidates.isEmpty
                )

                NotesCard(day: day)
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

                QuestionBankRoadmapCard(
                    progress: store.progress,
                    toggleProblem: { problem in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            store.toggleRoadmapProblem(problem)
                        }
                    }
                )
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
                GuideSetupCard(schedule: store.schedule)
                SystemDesignTopicsCard()
                ExtraPracticeCard()
                GuideRulesCard()
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
        StudyHabit.activeCases(hasRedoDue: hasRedoDue)
    }
    private var activeHabitCount: Int {
        activeHabits.count
    }
    private var completedActiveHabitCount: Int {
        activeHabits.filter { dailyProgress.completedHabits.contains($0) }.count
    }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(day.day == currentDay ? "Current day" : "Selected day")
                            .eyebrow()

                        Text(day.topic)
                            .font(AppFont.display(size: 34, weight: .black))
                            .tracking(-1.0)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(day.problems.count) planned problems")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer(minLength: 12)
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
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct DaySelector: View {
    @Binding var selectedDay: Int
    let progress: StoredProgress
    let schedule: StudySchedule

    private var currentDay: Int { progress.currentDayNumber(in: schedule) }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(schedule.days) { day in
                    let fraction = progress.completionFraction(for: day, in: schedule)
                    let isSelected = selectedDay == day.day
                    let isToday = currentDay == day.day

                    Button {
                        selectedDay = day.day
                    } label: {
                        VStack(spacing: 5) {
                            Text(day.date.map(shortDateText) ?? "Day")
                                .font(.caption2.weight(.black))
                                .lineLimit(1)

                            Text("Day \(day.day)")
                                .font(.caption.weight(.black))
                                .monospacedDigit()

                            Circle()
                                .fill(progressColor(for: fraction))
                                .frame(width: isToday ? 8 : 6, height: isToday ? 8 : 6)
                        }
                        .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                        .frame(width: 72, height: 62)
                        .background((isSelected ? Theme.accent.opacity(0.16) : Theme.surface), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(isToday ? Theme.accent.opacity(0.72) : Theme.hairline.opacity(isSelected ? 0.7 : 0.38), lineWidth: isToday ? 1.5 : 1)
                        }
                        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open day \(day.day), \(day.topic)")
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 1)
        }
    }

    private func progressColor(for fraction: Double) -> Color {
        switch fraction {
        case 0:
            return Theme.muted.opacity(0.32)
        case 0..<0.5:
            return Theme.accent.opacity(0.72)
        case 0..<1:
            return Theme.accent
        default:
            return Theme.accent
        }
    }
}

private struct DailyFlowCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    let day: StudyDay
    let dailyProgress: DailyProgress
    let settings: StudySettings
    let hasRedoDue: Bool

    private var topic: SystemDesignTopic? {
        SystemDesignTopics.topic(for: day.systemDesignFocus)
    }

    private var understood: Bool {
        dailyProgress.completedHabits.contains(.systemDesign)
    }

    var body: some View {
        LiquidGlassCard(tint: understood ? Theme.accent : Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Daily system design")
                            .eyebrow()

                        if let topic {
                            Text(topic.title)
                                .font(AppFont.display(size: 24, weight: .black))
                                .tracking(-0.6)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(topic.category)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Theme.accent.opacity(0.11), in: Capsule())
                        } else {
                            Text(day.systemDesignFocus)
                                .font(AppFont.display(size: 24, weight: .black))
                                .tracking(-0.6)
                                .foregroundStyle(Theme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    Spacer(minLength: 8)

                    if understood {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title.weight(.black))
                            .foregroundStyle(Theme.accent)
                    }
                }

                HStack(spacing: 12) {
                    if let topic {
                        NavigationLink {
                            SystemDesignDetailView(topic: topic)
                        } label: {
                            Label("Read topic", systemImage: "book.pages.fill")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SWSecondaryGlassButtonStyle(tint: Theme.accent))
                    }

                    if understood {
                        Button {
                            let allIDs = systemDesignChecklist.map(\.id)
                            store.setSystemDesignChecksCompleted(false, day: day.day, allCheckIDs: allIDs)
                        } label: {
                            Label("Mark unread", systemImage: "arrow.uturn.backward")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SWSecondaryGlassButtonStyle(tint: Theme.glassBlue))
                    } else {
                        Button {
                            let allIDs = systemDesignChecklist.map(\.id)
                            store.setSystemDesignChecksCompleted(true, day: day.day, allCheckIDs: allIDs)
                        } label: {
                            Label("I understand", systemImage: "checkmark")
                                .font(.subheadline.weight(.black))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SWPrimaryGlassButtonStyle(tint: Theme.accent))
                    }
                }

                if hasRedoDue {
                    Divider()
                        .overlay(Theme.hairline)

                    HabitRow(
                        habit: .review,
                        settings: settings,
                        completed: dailyProgress.completedHabits.contains(.review)
                    ) {
                        store.toggleHabit(.review, day: day.day)
                    }
                }
            }
        }
    }
}

private struct SystemDesignChecklistItem: Identifiable {
    let id: String
    let title: String
    let prompt: String
}

private let systemDesignChecklist = [
    SystemDesignChecklistItem(id: "requirements", title: "Clarify scope", prompt: "Name users, core actions, non-goals, and 2 hard constraints."),
    SystemDesignChecklistItem(id: "apis-data", title: "Model API + data", prompt: "Write the main request/event and the tables, keys, or objects it touches."),
    SystemDesignChecklistItem(id: "architecture", title: "Draw the flow", prompt: "Client, edge/API, service, queue/cache if needed, storage, and the read/write path."),
    SystemDesignChecklistItem(id: "scale", title: "Find the bottleneck", prompt: "Pick the pressure point: reads, writes, fanout, storage, hot keys, or latency."),
    SystemDesignChecklistItem(id: "tradeoff", title: "Defend a tradeoff", prompt: "Say what you chose, what gets worse, and how you would monitor it.")
]

private struct HabitRow: View {
    let habit: StudyHabit
    let settings: StudySettings
    let completed: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(habit.tint.opacity(completed ? 0.22 : 0.12))

                    Image(systemName: completed ? "checkmark" : habit.systemImage)
                        .font(.headline.weight(.black))
                        .foregroundStyle(completed ? Theme.accent : habit.tint)
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

                    Text(habit.subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(completed ? Theme.accent.opacity(0.09) : Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(alignment: .trailing) {
                Image(systemName: completed ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(completed ? Theme.accent : Theme.muted.opacity(0.55))
                    .padding(.trailing, 12)
            }
        }
        .buttonStyle(.plain)
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
                        title: day.topic,
                        subtitle: "Tap a row to set confidence. Red schedules redo."
                    )

                    Spacer()

                    if problemBlockComplete {
                        CompletionBadge(title: "Complete", color: Theme.accent)
                    } else {
                        ProblemCountPill(done: counts.attempted, total: counts.total)
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
                latestDate: store.redoGraceEndDate(),
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

private struct ProblemCountPill: View {
    let done: Int
    let total: Int

    var body: some View {
        Text("\(done)/\(total)")
            .font(.caption.weight(.black))
            .monospacedDigit()
            .foregroundStyle(Theme.accent)
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(Theme.accent.opacity(0.12), in: Capsule())
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
    let latestDate: Date
    let save: (Date) -> Void
    let dismiss: () -> Void

    @State private var selectedDate: Date
    @State private var appeared = false

    init(
        day: StudyDay,
        problem: String,
        currentDate: Date,
        suggestedDate: Date,
        latestDate: Date,
        save: @escaping (Date) -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.day = day
        self.problem = problem
        self.suggestedDate = suggestedDate
        self.latestDate = Calendar.current.startOfDay(for: latestDate)
        self.save = save
        self.dismiss = dismiss

        let today = Calendar.current.startOfDay(for: Date())
        _selectedDate = State(initialValue: min(max(Calendar.current.startOfDay(for: currentDate), today), Calendar.current.startOfDay(for: latestDate)))
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
                        .font(AppFont.display(size: 38, weight: .black))
                        .foregroundStyle(Theme.red)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("Red means redo")
                            .eyebrow(color: Theme.red)
                        Text("Schedule the next attempt")
                            .font(AppFont.display(size: 28, weight: .black))
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
                    .padding(14)
                    .background(Theme.red.opacity(0.10), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Theme.red.opacity(0.25), lineWidth: 1)
                    }

                    DatePicker(
                        "Redo date",
                        selection: $selectedDate,
                        in: redoDateRange,
                        displayedComponents: .date
                    )
                    .font(.subheadline.weight(.bold))
                    .tint(Theme.accent)
                    .padding(12)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                HStack(spacing: 10) {
                    RedoSheetButton(
                        title: "Keep current",
                        symbol: "xmark",
                        tint: Theme.glassBlue,
                        filled: false
                    ) {
                        dismiss()
                    }

                    RedoSheetButton(
                        title: "Save date",
                        symbol: "checkmark",
                        tint: Theme.red,
                        filled: true
                    ) {
                        save(selectedDate)
                    }
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
        let latest = max(latestDate, today)
        return today...latest
    }
}

private struct RedoSheetButton: View {
    let title: String
    let symbol: String
    let tint: Color
    let filled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.black))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundStyle(filled ? .white : tint)
                .background(filled ? tint : tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(tint.opacity(filled ? 0 : 0.25), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct RedoQueueCard: View {
    let candidates: [RedoCandidate]
    let openDay: (Int) -> Void

    var body: some View {
        LiquidGlassCard(tint: candidates.isEmpty ? Theme.accent : Theme.red) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Review + redo",
                    subtitle: "Scheduled red problems due by this day. Clear them before new work."
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
                                        Text("Due \(shortDateText(candidate.dueDate)) - Day \(candidate.day) - \(candidate.topic)")
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
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    SectionHeader(
                        title: "Study notes",
                        subtitle: "Write the template, invariant, or bug that should stick."
                    )

                    Spacer(minLength: 0)

                    if notesFocused {
                        Button("Hide keyboard") {
                            notesFocused = false
                        }
                        .font(.caption.weight(.black))
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                    }
                }

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
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Roadmap")
                    .eyebrow()
                Text("The full 150-question bank, grouped by category.")
                    .font(AppFont.display(size: 30, weight: .black))
                    .tracking(-0.8)
                    .foregroundStyle(Theme.ink)
                Text("Questions auto-check when you mark them from Today. You can also check ahead here, and future days rebalance around work already done.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct QuestionBankRoadmapCard: View {
    let progress: StoredProgress
    let toggleProblem: (String) -> Void

    private var completedRequiredCount: Int {
        StudyPlanner.requiredProblemTitles.filter { progress.status(for: $0) != .untouched }.count
    }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Question checklist",
                    subtitle: "\(completedRequiredCount)/\(StudyPlanner.requiredProblemCount) required questions touched. Tap a row to check or clear it."
                )

                LazyVStack(spacing: 14) {
                    ForEach(StudyPlanner.sections) { section in
                        RoadmapSectionBlock(
                            section: section,
                            progress: progress,
                            toggleProblem: toggleProblem
                        )
                    }
                }
            }
        }
    }
}

private struct RoadmapSectionBlock: View {
    let section: ProblemSection
    let progress: StoredProgress
    let toggleProblem: (String) -> Void

    private var completedCount: Int {
        section.problems.filter { progress.status(for: $0) != .untouched }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(section.title)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Theme.ink)
                    Text(section.template)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text("\(completedCount)/\(section.problems.count)")
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Theme.accent.opacity(0.11), in: Capsule())
            }

            VStack(spacing: 8) {
                ForEach(section.problems, id: \.self) { problem in
                    RoadmapProblemChecklistRow(
                        problem: problem,
                        status: progress.status(for: problem),
                        toggle: { toggleProblem(problem) }
                    )
                }
            }
        }
        .padding(13)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct RoadmapProblemChecklistRow: View {
    let problem: String
    let status: ProblemStatus
    let toggle: () -> Void

    private var isChecked: Bool { status != .untouched }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isChecked ? status.tint : Theme.muted.opacity(0.55))

                Text(problem)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                if isChecked {
                    Text(status.shortTitle)
                        .font(.caption.weight(.black))
                        .foregroundStyle(status.tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(status.tint.opacity(0.12), in: Capsule())
                }
            }
            .padding(11)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isChecked ? status.tint.opacity(0.08) : Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isChecked ? "Clear" : "Check") \(problem)")
    }
}

private struct ProgressHeroCard: View {
    let summary: PlanSummary

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
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
        LiquidGlassCard(tint: Theme.glassBlue) {
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
                                    Text("Day \(day.day)")
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
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to use NeatHabit")
                    .eyebrow()
                Text("Tap any metric to adjust it inline. The plan rebalances automatically.")
                    .font(AppFont.display(size: 28, weight: .black))
                    .tracking(-0.7)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

private struct GuideSetupCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    let schedule: StudySchedule

    @State private var showDateEditor = false
    @State private var showTimeEditor = false
    @State private var showReminderEditor = false

    private var perQuestionMinutes: Int {
        guard schedule.averageProblemsPerDay > 0 else { return schedule.settings.problemBlockMinutes }
        return Int((Double(schedule.settings.problemBlockMinutes) / schedule.averageProblemsPerDay).rounded())
    }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Plan setup",
                    subtitle: "Tap any tile to adjust. The plan rebalances instantly."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.accent)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            showDateEditor.toggle()
                            showTimeEditor = false
                            showReminderEditor = false
                        }
                    } label: {
                        MetricTile(title: "Target", value: shortDateText(schedule.settings.targetFinishDate), symbol: "flag.checkered", tint: Theme.glassBlue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            showTimeEditor.toggle()
                            showDateEditor = false
                            showReminderEditor = false
                        }
                    } label: {
                        MetricTile(title: "Daily time", value: "\(schedule.settings.dailyMinutes)m", symbol: "timer", tint: Theme.glassBlue)
                    }
                    .buttonStyle(.plain)

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                            showReminderEditor.toggle()
                            showDateEditor = false
                            showTimeEditor = false
                        }
                    } label: {
                        MetricTile(title: "Reminder", value: schedule.settings.reminderDate.formatted(.dateTime.hour().minute()), symbol: settings.notificationsEnabled ? "bell.fill" : "bell.slash.fill", tint: Theme.glassBlue)
                    }
                    .buttonStyle(.plain)
                }

                if showDateEditor {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Target finish date")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button("Done") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    showDateEditor = false
                                }
                            }
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.accent)
                        }

                        DatePicker(
                            "Finish date",
                            selection: Binding(
                                get: { store.progress.settings.targetFinishDate },
                                set: { store.updateTargetFinishDate($0) }
                            ),
                            in: Calendar.current.startOfDay(for: store.progress.startDate)...,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(Theme.accent)
                        .padding(10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        HStack(spacing: 8) {
                            Text("\(schedule.totalDays) plan days")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text("·")
                            Text("~\(String(format: "%.1f", schedule.averageProblemsPerDay)) problems/day")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.muted)
                            Text("·")
                            Text("\(schedule.settings.systemDesignMinutes)m design")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.muted)
                        }
                        .padding(12)
                        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(14)
                    .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                if showTimeEditor {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Daily time budget")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button("Done") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    showTimeEditor = false
                                }
                            }
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.accent)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("\(schedule.settings.dailyMinutes)")
                                    .font(AppFont.display(size: 34, weight: .black))
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                                    .foregroundStyle(Theme.ink)
                                Text("minutes/day")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Theme.muted)
                                Spacer(minLength: 0)
                            }

                            Slider(
                                value: Binding(
                                    get: { Double(schedule.settings.dailyMinutes) },
                                    set: { store.updateDailyMinutes(Int($0)) }
                                ),
                                in: 80...240,
                                step: 10
                            )
                            .tint(Theme.accent)

                            HStack {
                                Text("80m")
                                Spacer()
                                Text("240m")
                            }
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("System design")
                                    .font(.subheadline.weight(.black))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(schedule.settings.systemDesignMinutes)m")
                                    .font(.title3.weight(.black))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.accent)
                            }

                            Stepper(
                                "Design rep duration",
                                value: Binding(
                                    get: { schedule.settings.systemDesignMinutes },
                                    set: { store.updateSystemDesignMinutes($0) }
                                ),
                                in: 10...60,
                                step: 5
                            )
                            .tint(Theme.accent)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.muted)

                            if schedule.settings.systemDesignMinutes > 20 {
                                Text("Longer plans benefit from deeper design reps. Each topic gets more thorough coverage.")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(Theme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        let effectiveSD = schedule.settings.systemDesignMinutes
                        let codingTime = schedule.settings.dailyMinutes - effectiveSD
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Budget: \(effectiveSD)m design + \(codingTime)m coding = ~\(perQuestionMinutes)m/question")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(perQuestionMinutes >= 20 ? Theme.green : Theme.red)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .background((perQuestionMinutes >= 20 ? Theme.green : Theme.red).opacity(0.10), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(14)
                    .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                if showReminderEditor {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("Daily reminder")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button("Done") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    showReminderEditor = false
                                }
                            }
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.accent)
                        }

                        DatePicker(
                            "Reminder time",
                            selection: Binding(
                                get: { settings.reminderDate },
                                set: { store.updateReminderTime($0) }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .tint(Theme.accent)
                        .frame(height: 138)
                        .clipped()
                        .padding(.horizontal, 10)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Toggle(
                            "Daily notification",
                            isOn: Binding(
                                get: { settings.notificationsEnabled },
                                set: { store.updateNotificationsEnabled($0) }
                            )
                        )
                        .font(.headline.weight(.bold))
                        .tint(Theme.accent)
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        Text("A 9am morning check-in is also scheduled when notifications are on.")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.horizontal, 4)
                    }
                    .padding(14)
                    .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                }

                if schedule.dailyLoadIsOverCapacity {
                    EmptyStateRow(
                        symbol: "exclamationmark.triangle.fill",
                        title: "Target is aggressive",
                        subtitle: "This target needs about \(String(format: "%.1f", schedule.averageProblemsPerDay)) problems/day, above your estimated capacity of \(schedule.settings.estimatedProblemCapacity)/day."
                    )
                }

                VStack(spacing: 10) {
                    Button {
                        store.restartOnboarding()
                    } label: {
                        Label("Redo onboarding", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.glass)

                    Button(role: .destructive) {
                        store.restartOnboarding(resetTimeline: true)
                    } label: {
                        Label("Reset timeline + redo onboarding", systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.glass)
                }
            }
        }
    }

    private var settings: StudySettings {
        store.progress.settings
    }
}

private struct GuideRulesCard: View {
    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 14) {
                SectionHeader(
                    title: "Rules",
                    subtitle: "The app only tracks decisions that change what you do next."
                )

                GuideRuleRow(
                    symbol: "checklist",
                    title: "Problem block",
                    bodyText: "Complete when every planned question has a color."
                )

                GuideRuleRow(
                    symbol: "calendar.badge.clock",
                    title: "Red status",
                    bodyText: "Schedules a redo date. There is no separate redo color."
                )

                GuideRuleRow(
                    symbol: "server.rack",
                    title: "System design",
                    bodyText: "Work through one design topic per day: scope, API/data, flow, bottleneck, tradeoff. Tap the topic on the Today tab for a deep dive."
                )
            }
        }
    }
}

private struct SystemDesignTopicsCard: View {
    @State private var selectedCategory: String?

    private var categories: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for topic in SystemDesignTopics.all where !seen.contains(topic.category) {
            seen.insert(topic.category)
            result.append(topic.category)
        }
        return result
    }

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "System design topics",
                    subtitle: "31 topics covering fundamentals, scale, reliability, and classic interview problems. Tap any topic for a deep dive."
                )

                VStack(spacing: 12) {
                    ForEach(categories, id: \.self) { category in
                        DisclosureGroup(
                            isExpanded: Binding(
                                get: { selectedCategory == category },
                                set: { selectedCategory = $0 ? category : nil }
                            )
                        ) {
                            VStack(spacing: 8) {
                                ForEach(SystemDesignTopics.all.filter { $0.category == category }) { topic in
                                    NavigationLink {
                                        SystemDesignDetailView(topic: topic)
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: topic.icon)
                                                .font(.caption.weight(.black))
                                                .foregroundStyle(Theme.accent)
                                                .frame(width: 30, height: 30)
                                                .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                                            VStack(alignment: .leading, spacing: 1) {
                                                Text(topic.title)
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(Theme.ink)
                                                Text(topic.concepts.count > 0 ? "\(topic.concepts.count) concepts" : "")
                                                    .font(.caption2.weight(.medium))
                                                    .foregroundStyle(Theme.muted)
                                            }

                                            Spacer(minLength: 0)

                                            Image(systemName: "chevron.right")
                                                .font(.caption2.weight(.bold))
                                                .foregroundStyle(Theme.muted.opacity(0.5))
                                        }
                                        .padding(10)
                                        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.top, 8)
                        } label: {
                            HStack {
                                Text(category)
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Theme.ink)

                                Spacer()

                                Text("\(SystemDesignTopics.all.filter { $0.category == category }.count)")
                                    .font(.caption.weight(.black))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.accent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Theme.accent.opacity(0.10), in: Capsule())
                            }
                        }
                        .tint(Theme.accent)
                    }
                }
            }
        }
    }
}

private struct GuideRuleRow: View {
    let symbol: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
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

private struct ExtraPracticeCard: View {
    @EnvironmentObject private var store: StudyProgressStore
    @State private var isExpanded = false
    @State private var title = ""
    @State private var section = "Extra Practice"

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            DisclosureGroup(isExpanded: $isExpanded) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Use this only for questions outside the required 150.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)

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
                .padding(.top, 12)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Optional extras")
                            .font(.title3.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text("\(store.progress.settings.extraProblems.count) added")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer(minLength: 0)
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
                .foregroundStyle(Theme.accent)
                .frame(width: 42, height: 42)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 15, style: .continuous))

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

private extension StudyHabit {
    var tint: Color {
        switch self {
        case .pattern:
            return Theme.glassBlue
        case .problems:
            return Theme.accent
        case .review:
            return Theme.red
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

#Preview {
    ContentView()
        .environmentObject(StudyProgressStore())
}
