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
                ExtraPracticeCard()
                GuideRulesCard()
            }
        }
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var store: StudyProgressStore
    @State private var appeared = false
    @State private var page = 0

    private var schedule: StudySchedule { store.schedule }
    private var problemMinutesText: String {
        guard schedule.averageProblemsPerDay > 0 else { return "Enough time for today's plan." }
        let minutes = Double(store.progress.settings.problemBlockMinutes) / schedule.averageProblemsPerDay
        return minutes < 15
            ? "Raise daily time. This plan gives about \(Int(minutes.rounded())) min per question, under the 15 min floor."
            : "About \(Int(minutes.rounded())) min per question after the 20-minute design block."
    }

    private var canStart: Bool {
        guard schedule.averageProblemsPerDay > 0 else { return true }
        return Double(store.progress.settings.problemBlockMinutes) / schedule.averageProblemsPerDay >= 15
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                HStack {
                    Text("NeatHabit")
                        .eyebrow()
                    Spacer()
                    Text("\(page + 1)/5")
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 22)
                .padding(.top, 18)

                TabView(selection: $page) {
                    OnboardingPageCard(
                        eyebrow: "Start",
                        title: "Make the plan feel automatic.",
                        subtitle: "NeatHabit turns the 150-question bank into a daily interview loop. One screen, one decision at a time."
                    ) {
                        HStack(spacing: 10) {
                            MetricTile(title: "Required", value: "\(schedule.requiredProblemCount)", symbol: "checklist", tint: Theme.accent)
                            MetricTile(title: "Current pace", value: String(format: "%.1f/day", schedule.averageProblemsPerDay), symbol: "speedometer", tint: Theme.glassBlue)
                        }
                    }
                    .tag(0)

                    OnboardingPageCard(
                        eyebrow: "Finish",
                        title: "When do you want the 150 done?",
                        subtitle: "The plan spreads extra questions across the whole timeline instead of front-loading them."
                    ) {
                        DatePicker(
                            "Target finish date",
                            selection: Binding(
                                get: { store.progress.settings.targetFinishDate },
                                set: { store.updateTargetFinishDate($0) }
                            ),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .tint(Theme.accent)
                        .padding(12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .tag(1)

                    OnboardingPageCard(
                        eyebrow: "Time",
                        title: "How much time can you actually give daily?",
                        subtitle: problemMinutesText
                    ) {
                        VStack(spacing: 14) {
                            Stepper(
                                "\(store.progress.settings.dailyMinutes) minutes/day",
                                value: Binding(
                                    get: { store.progress.settings.dailyMinutes },
                                    set: { store.updateDailyMinutes($0) }
                                ),
                                in: 80...600,
                                step: 10
                            )
                            .font(.headline.weight(.black))
                            .tint(Theme.accent)

                            HStack(spacing: 10) {
                                MetricTile(title: "Problems/day", value: String(format: "%.1f", schedule.averageProblemsPerDay), symbol: "keyboard.fill", tint: Theme.accent)
                                MetricTile(title: "Question time", value: "\(store.progress.settings.problemBlockMinutes)m", symbol: "timer", tint: canStart ? Theme.glassBlue : Theme.red)
                            }
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .tag(2)

                    OnboardingPageCard(
                        eyebrow: "Reminder",
                        title: "When are you most likely to do it?",
                        subtitle: "NeatHabit will ask iOS for notification permission and schedule a daily reminder at this time."
                    ) {
                        VStack(spacing: 14) {
                            DatePicker(
                                "Reminder time",
                                selection: Binding(
                                    get: { store.progress.settings.reminderDate },
                                    set: { store.updateReminderTime($0) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .tint(Theme.accent)

                            Toggle(
                                "Daily notification",
                                isOn: Binding(
                                    get: { store.progress.settings.notificationsEnabled },
                                    set: { store.updateNotificationsEnabled($0) }
                                )
                            )
                            .font(.headline.weight(.bold))
                            .tint(Theme.accent)
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .tag(3)

                    OnboardingPageCard(
                        eyebrow: "Ready",
                        title: "Keep it lean. Adjust only what matters.",
                        subtitle: "System design stays daily. Red questions come back on scheduled redo dates."
                    ) {
                        VStack(spacing: 14) {
                            HStack(spacing: 10) {
                                MetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.accent)
                                MetricTile(title: "Reminder", value: store.progress.settings.reminderDate.formatted(.dateTime.hour().minute()), symbol: "bell.fill", tint: Theme.glassBlue)
                            }
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 12) {
                    if page > 0 {
                        Button("Back") {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                page -= 1
                            }
                        }
                        .buttonStyle(.glass)
                    }

                    Button {
                        if page < 4 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                page += 1
                            }
                        } else {
                            store.completeOnboarding()
                        }
                    } label: {
                        Label(page == 4 ? "Start today" : "Next", systemImage: page == 4 ? "checkmark" : "arrow.right")
                            .font(.headline.weight(.black))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
                    .disabled(page >= 2 && !canStart)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
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

private struct OnboardingPageCard<Content: View>: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let content: Content

    init(eyebrow: String, title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.eyebrow = eyebrow
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 22) {
                Spacer(minLength: 24)

                LiquidGlassCard(tint: Theme.accent) {
                    VStack(alignment: .center, spacing: 18) {
                        Text(eyebrow)
                            .eyebrow()
                        Text(title)
                            .font(AppFont.display(size: 38, weight: .black))
                            .tracking(-1.2)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.ink)
                            .lineSpacing(-2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(subtitle)
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(2)
                            .fixedSize(horizontal: false, vertical: true)
                        content
                    }
                    .frame(maxWidth: .infinity)
                }

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 18)
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
                .foregroundStyle(Theme.accent)
                .frame(width: 34, height: 34)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

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

                            Text("D\(day.day)")
                                .font(.caption.weight(.black))
                                .monospacedDigit()

                            Circle()
                                .fill(progressColor(for: fraction))
                                .frame(width: isToday ? 8 : 6, height: isToday ? 8 : 6)
                        }
                        .foregroundStyle(isSelected ? Theme.ink : Theme.muted)
                        .frame(width: 62, height: 62)
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

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "System design",
                    subtitle: "One small design prompt per day. Mark it done after you can explain the tradeoffs out loud."
                )

                VStack(spacing: 11) {
                    SystemDesignFocusRow(
                        focus: day.systemDesignFocus,
                        completed: dailyProgress.completedHabits.contains(.systemDesign)
                    ) {
                        store.toggleHabit(.systemDesign, day: day.day)
                    }

                    if hasRedoDue {
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
}

private struct SystemDesignFocusRow: View {
    let focus: String
    let completed: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: completed ? "checkmark.circle.fill" : "sparkles.rectangle.stack.fill")
                        .font(.title3.weight(.black))
                        .foregroundStyle(completed ? Theme.accent : Theme.glassBlue)
                        .frame(width: 44, height: 44)
                        .background((completed ? Theme.accent : Theme.glassBlue).opacity(0.13), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("20-minute design rep")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text(completed ? "Done for today" : "Read, sketch, then explain")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer(minLength: 0)
                }

                Text(focus)
                    .font(.title3.weight(.black))
                    .tracking(-0.35)
                    .foregroundStyle(Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    DesignStepChip(title: "Read")
                    DesignStepChip(title: "Sketch")
                    DesignStepChip(title: "Explain")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Theme.surface)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke((completed ? Theme.accent : Theme.glassBlue).opacity(0.35), lineWidth: 1)
            }
            .shadow(color: Theme.cardShadow.opacity(0.12), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
}

private struct DesignStepChip: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.black))
            .foregroundStyle(Theme.glassBlue)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Theme.glassBlue.opacity(0.11), in: Capsule())
    }
}

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
                        title: "Problem block",
                        subtitle: "This completes automatically when every planned question is touched."
                    )

                    Spacer()

                    if problemBlockComplete {
                        CompletionBadge(title: "Complete", color: Theme.accent)
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
                    .padding(12)
                    .background(Theme.red.opacity(0.11), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

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
        LiquidGlassCard(tint: candidates.isEmpty ? Theme.accent : Theme.red) {
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
        LiquidGlassCard(tint: Theme.glassBlue) {
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
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 12) {
                Text("How to use NeatHabit")
                    .eyebrow()
                Text("Adjust setup only when the plan needs to change.")
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

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Plan setup",
                    subtitle: "Use onboarding when you want to change the plan shape."
                )

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    MetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.accent)
                    MetricTile(title: "Target", value: shortDateText(schedule.settings.targetFinishDate), symbol: "flag.checkered", tint: Theme.glassBlue)
                    MetricTile(title: "Daily", value: "\(schedule.settings.dailyMinutes)m", symbol: "timer", tint: Theme.glassBlue)
                    MetricTile(title: "Reminder", value: schedule.settings.reminderDate.formatted(.dateTime.hour().minute()), symbol: "bell.fill", tint: Theme.glassBlue)
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
                    bodyText: "One focused topic stays in the daily loop."
                )
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
    let content: Content

    init(tint: Color = Theme.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.cardFill)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(Theme.hairline.opacity(0.56), lineWidth: 1)
            }
            .shadow(color: Theme.cardShadow.opacity(0.18), radius: 24, x: 0, y: 18)
    }
}

private struct AppBackground: View {
    var body: some View {
        Theme.canvas
        .ignoresSafeArea()
    }
}

private enum AppFont {
    static func body(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .custom(postScriptName(for: weight), size: size, relativeTo: .body)
    }

    static func display(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .custom(postScriptName(for: weight), size: size, relativeTo: .largeTitle)
    }

    private static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy:
            return "AvenirNext-Heavy"
        case .bold:
            return "AvenirNext-Bold"
        case .semibold:
            return "AvenirNext-DemiBold"
        case .medium:
            return "AvenirNext-Medium"
        default:
            return "AvenirNext-Regular"
        }
    }
}

private enum Theme {
    static let ink = dynamic(light: (0.070, 0.080, 0.105), dark: (0.90, 0.92, 0.96))
    static let muted = dynamic(light: (0.36, 0.39, 0.46), dark: (0.64, 0.68, 0.76))
    static let canvas = dynamic(light: (0.955, 0.965, 0.98), dark: (0.050, 0.056, 0.070))
    static let surface = dynamic(light: (0.985, 0.99, 1.0), dark: (0.095, 0.105, 0.13)).opacity(0.88)
    static let cardFill = dynamic(light: (0.992, 0.995, 1.0), dark: (0.070, 0.078, 0.098))
    static let hairline = dynamic(light: (0.82, 0.86, 0.92), dark: (0.20, 0.23, 0.29))
    static let cardShadow = dynamic(light: (0.08, 0.11, 0.18), dark: (0.0, 0.0, 0.0))
    static let accent = Color(red: 0.16, green: 0.38, blue: 0.86)
    static let glassBlue = Color(red: 0.38, green: 0.43, blue: 0.56)
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

private func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}

#Preview {
    ContentView()
        .environmentObject(StudyProgressStore())
}
