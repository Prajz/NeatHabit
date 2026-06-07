import SwiftUI

struct TodayTab: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var selectedDay: Int
    @Binding var tourStep: Int?
    @Binding var tourFrames: [TourAnchorID: CGRect]

    private var schedule: StudySchedule { store.schedule(lockingThrough: selectedDay) }
    private var day: StudyDay { schedule.day(selectedDay) }
    private var dailyProgress: DailyProgress { store.progress.dailyProgress(for: selectedDay) }
    private var redoCandidates: [RedoCandidate] { store.progress.redoCandidates(for: selectedDay, in: schedule) }

    var body: some View {
        StudyScreen(title: "Today", tourStep: $tourStep, tourFrames: $tourFrames) {
            VStack(spacing: ScreenScale.scale(18)) {
                TourElementProbe(anchorID: .dayStrip) {
                    DaySelector(
                        selectedDay: $selectedDay,
                        progress: store.progress,
                        schedule: schedule
                    )
                }

                if !redoCandidates.isEmpty {
                    TourElementProbe(anchorID: .redoQueue) {
                        RedoQueueCard(
                            candidates: redoCandidates,
                            openDay: { selectedDay = $0 }
                        )
                    }
                }

                TourElementProbe(anchorID: .problems) {
                    ProblemsCard(
                        day: day,
                        dailyProgress: dailyProgress
                    )
                }

                TourElementProbe(anchorID: .systemDesign) {
                    DailyFlowCard(
                        day: day,
                        dailyProgress: dailyProgress,
                        settings: schedule.settings,
                        hasRedoDue: !redoCandidates.isEmpty
                    )
                }

                TourElementProbe(anchorID: .notes) {
                    NotesCard(day: day)
                }
            }
        }
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
            VStack(alignment: .leading, spacing: ScreenScale.scale(22)) {
                HStack(alignment: .top, spacing: ScreenScale.scale(16)) {
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
                    .font(.headline.weight(.bold))
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
                                .font(.caption2.weight(.bold))
                                .lineLimit(1)

                            Text("Day \(day.day)")
                                .font(.caption.weight(.bold))
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
                            .font(.title.weight(.bold))
                            .foregroundStyle(Theme.accent)
                    }
                }

                HStack(spacing: 12) {
                    if let topic {
                        NavigationLink {
                            SystemDesignDetailView(topic: topic)
                        } label: {
                            Label("Read topic", systemImage: "book.pages.fill")
                                .font(.headline.weight(.bold))
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
                                .font(.headline.weight(.bold))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(SWSecondaryGlassButtonStyle(tint: Theme.glassBlue))
                    } else {
                        Button {
                            let allIDs = systemDesignChecklist.map(\.id)
                            store.setSystemDesignChecksCompleted(true, day: day.day, allCheckIDs: allIDs)
                        } label: {
                            Label("Done?", systemImage: "checkmark")
                                .font(.headline.weight(.bold))
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
                        .font(.headline.weight(.bold))
                        .foregroundStyle(completed ? Theme.accent : habit.tint)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(habit.title)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Theme.ink)

                        Text("\(habit.durationMinutes(settings: settings))m")
                            .font(.caption2.weight(.bold))
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
            .font(.caption.weight(.bold))
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
        .font(.caption.weight(.bold))
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
                .font(.caption.weight(.bold))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.bold))
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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(status.tint)
                }
                .frame(width: 32, height: 32)

                VStack(alignment: .leading, spacing: 6) {
                    Text(problem)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    ProblemDifficultyBadge(difficulty: StudyPlanner.difficulty(for: problem))
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
                    .font(.caption.weight(.bold))
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
                        .font(.subheadline.weight(.bold))
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
                    .font(.subheadline.weight(.bold))
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
                                        .font(.caption.weight(.bold))
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
                                        .font(.caption.weight(.semibold))
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
                        .font(.caption.weight(.bold))
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
                        .font(.headline.weight(.semibold))
                    }
                }
            }
        }
    }
}
