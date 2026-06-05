import SwiftUI

struct OnboardingView: View {
    private let minDailyMinutes = 20
    private let maxDailyMinutes = 240
    private let minSystemDesignMinutes = 15
    private let maxSystemDesignMinutes = 40
    private let minQuestionMinutes = 5
    private let maxQuestionMinutes = 200
    private let comfortablePerQuestionMinutes = 20

    @EnvironmentObject private var store: StudyProgressStore
    @State private var appeared = false
    @State private var page = 0

    private var schedule: StudySchedule { store.schedule }
    private var settings: StudySettings { store.progress.settings }
    private var codingMinutes: Int {
        min(max(settings.problemBlockMinutes, minQuestionMinutes), maxQuestionMinutes)
    }
    private var totalMinutes: Int {
        settings.systemDesignMinutes + codingMinutes
    }
    private var perQuestionMinutes: Double {
        guard schedule.averageProblemsPerDay > 0 else { return Double(settings.problemBlockMinutes) }
        return Double(settings.problemBlockMinutes) / schedule.averageProblemsPerDay
    }
    private var perQuestionLabel: String {
        guard schedule.averageProblemsPerDay > 0 else { return "Enough time for today's plan." }
        let minutes = Int(perQuestionMinutes.rounded())
        if perQuestionMinutes >= Double(comfortablePerQuestionMinutes) {
            return "~\(minutes) min/question — comfortable"
        }
        return "~\(minutes) min/question — under 20 min is tight"
    }

    private var canStart: Bool {
        guard schedule.averageProblemsPerDay > 0 else { return true }
        return perQuestionMinutes >= Double(comfortablePerQuestionMinutes)
    }

    private var ctaTitle: String {
        if page == 4 {
            return canStart ? "Start today" : "Adjust time"
        }

        return "Next"
    }

    private var ctaSymbol: String {
        if page == 4 {
            return canStart ? "checkmark" : "timer"
        }

        return "arrow.right"
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: ScreenScale.scale(8)) {
                TabView(selection: $page) {
                    OnboardingPageCard(
                        eyebrow: "Setup",
                        symbol: "sparkles.rectangle.stack.fill",
                        title: "Build your daily plan.",
                        subtitle: "NeetCode 150 plus a daily system design rep."
                    ) {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                CompactMetricTile(title: "Questions", value: "\(schedule.requiredProblemCount)", symbol: "checklist", tint: Theme.accent)
                                CompactMetricTile(title: "Starts", value: "Day \(store.progress.currentDayNumber(in: schedule))", symbol: "target", tint: Theme.glassBlue)
                            }

                            OnboardingStepRow(number: "01", title: "Finish date", bodyText: "Sets questions/day.")
                            OnboardingStepRow(number: "02", title: "Daily time", bodyText: "System design reps. Rest is coding time.")
                            OnboardingStepRow(number: "03", title: "Reminder", bodyText: "A nudge, not plan math.")
                        }
                    }
                    .tag(0)

                    OnboardingPageCard(
                        eyebrow: "Finish",
                        symbol: "calendar.badge.clock",
                        title: "Pick a finish date.",
                        subtitle: "More days means fewer questions/day."
                    ) {
                        VStack(spacing: 8) {
                            DatePicker(
                                "Target finish date",
                                selection: Binding(
                                    get: { settings.targetFinishDate },
                                    set: { updateTargetDate($0) }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(Theme.accent)
                            .padding(8)
                            .frame(maxHeight: 320)
                            .glassControlBackground(tint: Theme.accent)

                            TargetImpactCard(title: "Date impact", schedule: schedule)
                        }
                    }
                    .tag(1)

                    OnboardingPageCard(
                        eyebrow: "Time",
                        symbol: "timer",
                        title: "How much time daily?",
                        subtitle: "Split your day between system design and LeetCode."
                    ) {
                        VStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(settings.systemDesignMinutes)")
                                        .font(AppFont.display(size: 26, weight: .black))
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .foregroundStyle(Theme.ink)
                                    Text("min system design")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.muted)
                                    Spacer(minLength: 0)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(settings.systemDesignMinutes) },
                                        set: { updateSystemDesignMinutes(Int($0)) }
                                    ),
                                    in: Double(minSystemDesignMinutes)...Double(maxSystemDesignMinutes),
                                    step: 5
                                )
                                .tint(Theme.ink.opacity(0.72))

                                HStack {
                                    Text("\(minSystemDesignMinutes)m")
                                    Spacer()
                                    Text("\(maxSystemDesignMinutes)m max")
                                }
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.muted)
                            }
                            .padding(10)
                            .glassControlBackground(tint: Theme.ink.opacity(0.72))

                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(codingMinutes)")
                                        .font(AppFont.display(size: 26, weight: .black))
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .foregroundStyle(Theme.ink)
                                    Text("min LeetCode")
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(Theme.muted)
                                    Spacer(minLength: 0)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(codingMinutes) },
                                        set: { updateProblemBlockMinutes(Int($0)) }
                                    ),
                                    in: Double(minQuestionMinutes)...Double(maxQuestionMinutes),
                                    step: 5
                                )
                                .tint(Theme.accent)

                                HStack {
                                    Text("\(minQuestionMinutes)m")
                                    Spacer()
                                    Text("\(maxQuestionMinutes)m max")
                                }
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(Theme.muted)
                            }
                            .padding(10)
                            .glassControlBackground(tint: Theme.accent)

                            HStack {
                            Text("\(settings.systemDesignMinutes)m + \(codingMinutes)m")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.muted)
                            Text("= \(totalMinutes)m total")
                                .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                    .monospacedDigit()
                                    .contentTransition(.numericText())
                            }

                            if !canStart && schedule.averageProblemsPerDay > 0 {
                                Label(perQuestionLabel, systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.red)
                            } else if schedule.averageProblemsPerDay > 0 {
                                Text(perQuestionLabel)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Theme.green)
                            }
                        }
                    }
                    .tag(2)

                    OnboardingPageCard(
                        eyebrow: "Reminder",
                        symbol: "bell.badge.fill",
                        title: "Set a reminder.",
                        subtitle: "Pick a time for the daily nudge."
                    ) {
                        VStack(spacing: 8) {
                            DatePicker(
                                "Reminder time",
                                selection: Binding(
                                    get: { settings.reminderDate },
                                    set: { updateReminderTime($0) }
                                ),
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .tint(Theme.accent)
                            .frame(height: 120)
                            .clipped()
                            .padding(.horizontal, 8)
                            .glassControlBackground(tint: Theme.glassBlue)

                            Toggle(
                                "Daily notification",
                                isOn: Binding(
                                    get: { settings.notificationsEnabled },
                                    set: { updateNotificationsEnabled($0) }
                                )
                            )
                            .font(.headline.weight(.bold))
                            .tint(Theme.accent)
                            .padding(10)
                            .glassControlBackground(tint: settings.notificationsEnabled ? Theme.accent : Theme.glassBlue)

                            ReminderPreviewCard(settings: settings)
                        }
                    }
                    .tag(3)

                    OnboardingPageCard(
                        eyebrow: "Summary",
                        symbol: canStart ? "checkmark.seal.fill" : "exclamationmark.triangle.fill",
                        tint: canStart ? Theme.accent : Theme.red,
                        title: canStart ? "Start your plan." : "Add more time.",
                        subtitle: "You can change this later from Guide."
                    ) {
                        VStack(spacing: 8) {
                            TargetImpactCard(title: "Date impact", schedule: schedule)
                            TimeBudgetBreakdown(schedule: schedule)
                            if schedule.averageProblemsPerDay > 0 {
                                HStack {
                                    Text(perQuestionLabel)
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(canStart ? Theme.green : Theme.red)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }
                            ReminderPreviewCard(settings: settings)
                        }
                    }
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                OnboardingProgressRail(page: page, count: 5)
                    .padding(.horizontal, ScreenScale.scale(22))

                HStack(spacing: 12) {
                    if page > 0 {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                page -= 1
                            }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.headline.weight(.bold))
                        }
                        .buttonStyle(SWSecondaryGlassButtonStyle(tint: Theme.glassBlue))
                    }

                    Button {
                        if page < 4 {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                page += 1
                            }
                        } else {
                            guard canStart else {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    page = 2
                                }
                                return
                            }

                            Haptics.success()
                            withAnimation(.smooth(duration: 0.45)) {
                                store.completeOnboarding()
                            }
                        }
                    } label: {
                        Label(ctaTitle, systemImage: ctaSymbol)
                            .font(.headline.weight(.bold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SWPrimaryGlassButtonStyle(tint: canStart ? Theme.accent : Theme.red))
                    .shimmerSweep(duration: 1.15, delay: 0.8)
                }
                .padding(.horizontal, ScreenScale.scale(22))
                .padding(.bottom, ScreenScale.scale(16))
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 18)
        .onAppear {
            clampDailyMinutesIfNeeded()
            withAnimation(.smooth(duration: 0.55)) {
                appeared = true
            }
        }
        .onChange(of: page) { _, _ in
            Haptics.selection()
        }
    }

    private func updateTargetDate(_ date: Date) {
        let calendar = Calendar.current
        let current = calendar.startOfDay(for: settings.targetFinishDate)
        let next = calendar.startOfDay(for: date)
        store.updateTargetFinishDate(date)

        if current != next {
            Haptics.selection()
        }
    }

    private func updateSystemDesignMinutes(_ minutes: Int) {
        let clampedMinutes = min(max(minutes, minSystemDesignMinutes), maxSystemDesignMinutes)
        guard settings.systemDesignMinutes != clampedMinutes else { return }
        store.updateSystemDesignMinutes(clampedMinutes)
        Haptics.selection()
    }

    private func updateProblemBlockMinutes(_ minutes: Int) {
        let clampedMinutes = min(max(minutes, minQuestionMinutes), maxQuestionMinutes)
        guard settings.problemBlockMinutes != clampedMinutes else { return }
        store.updateProblemBlockMinutes(clampedMinutes)
        Haptics.selection()
    }

    private func updateReminderTime(_ date: Date) {
        let current = Calendar.current.dateComponents([.hour, .minute], from: settings.reminderDate)
        let next = Calendar.current.dateComponents([.hour, .minute], from: date)
        store.updateReminderTime(date)

        if current.hour != next.hour || current.minute != next.minute {
            Haptics.selection()
        }
    }

    private func updateNotificationsEnabled(_ enabled: Bool) {
        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
            store.updateNotificationsEnabled(enabled)
        }
        Haptics.selection()
    }

    private func clampDailyMinutesIfNeeded() {
        let sd = min(max(settings.systemDesignMinutes, minSystemDesignMinutes), maxSystemDesignMinutes)
        let pb = min(max(settings.problemBlockMinutes, minQuestionMinutes), maxQuestionMinutes)
        if sd != settings.systemDesignMinutes {
            store.updateSystemDesignMinutes(sd)
        }
        if pb != settings.problemBlockMinutes {
            store.updateProblemBlockMinutes(pb)
        }
    }
}

private struct OnboardingPageCard<Content: View>: View {
    let eyebrow: String
    let symbol: String
    let tint: Color
    let title: String
    let subtitle: String
    let content: Content

    init(
        eyebrow: String,
        symbol: String,
        tint: Color = Theme.accent,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.eyebrow = eyebrow
        self.symbol = symbol
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(spacing: ScreenScale.scale(6)) {
            LiquidGlassCard(tint: tint) {
                VStack(alignment: .center, spacing: ScreenScale.scale(6)) {
                    Image(systemName: symbol)
                        .font(AppFont.display(size: 30, weight: .black))
                        .foregroundStyle(tint)
                        .frame(width: 48, height: 48)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    Text(eyebrow)
                        .eyebrow(color: tint)
                    Text(title)
                        .font(AppFont.display(size: 24, weight: .black))
                        .tracking(-0.7)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.muted)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)
                    content
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, ScreenScale.scale(14))
        .padding(.top, ScreenScale.scale(8))
    }
}

private struct TargetImpactCard: View {
    let title: String
    let schedule: StudySchedule

    private var isComfortable: Bool {
        schedule.averageProblemsPerDay <= 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(isComfortable ? "Balanced" : "Tight")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isComfortable ? Theme.green : Theme.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isComfortable ? Theme.green : Theme.red).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 8) {
                CompactMetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.accent)
                CompactMetricTile(title: "Questions/day", value: String(format: "%.1f", schedule.averageProblemsPerDay), symbol: "keyboard.fill", tint: Theme.accent)
            }
        }
        .padding(10)
        .glassControlBackground(tint: isComfortable ? Theme.accent : Theme.red)
    }
}

private struct TimeImpactCard: View {
    let title: String
    let schedule: StudySchedule
    private let comfortablePerQuestionMinutes = 20

    private var perQuestionMinutes: Int {
        guard schedule.averageProblemsPerDay > 0 else { return schedule.settings.problemBlockMinutes }
        return Int((Double(schedule.settings.problemBlockMinutes) / schedule.averageProblemsPerDay).rounded())
    }

    private var isComfortable: Bool {
        perQuestionMinutes >= comfortablePerQuestionMinutes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(isComfortable ? "Enough" : "Tight")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(isComfortable ? Theme.green : Theme.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((isComfortable ? Theme.green : Theme.red).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 8) {
                CompactMetricTile(title: "Coding time", value: "\(schedule.settings.problemBlockMinutes)m", symbol: "keyboard.fill", tint: Theme.glassBlue)
                CompactMetricTile(title: "Per question", value: "\(perQuestionMinutes)m", symbol: "timer", tint: isComfortable ? Theme.green : Theme.red)
            }

            if !isComfortable {
                Text("19m/question or under is tight. Add time or push the finish date.")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .glassControlBackground(tint: isComfortable ? Theme.accent : Theme.red)
    }
}

private struct TimeBudgetBreakdown: View {
    let schedule: StudySchedule

    private var designFraction: Double {
        Double(schedule.settings.systemDesignBlockMinutes) / Double(max(schedule.settings.dailyMinutes, 1))
    }

    private var problemFraction: Double {
        Double(schedule.settings.problemBlockMinutes) / Double(max(schedule.settings.dailyMinutes, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                    Label("Daily budget", systemImage: "chart.bar.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("\(schedule.settings.dailyMinutes)m")
                        .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.accent)
            }

            GeometryReader { proxy in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.ink.opacity(0.72))
                        .frame(width: max(16, proxy.size.width * designFraction))
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: max(16, proxy.size.width * problemFraction))
                }
            }
            .frame(height: 8)

            HStack(spacing: 8) {
                BudgetLegendDot(title: "System design", value: "\(schedule.settings.systemDesignBlockMinutes)m", color: Theme.ink)
                BudgetLegendDot(title: "Coding", value: "\(schedule.settings.problemBlockMinutes)m", color: Theme.accent)
            }
        }
        .padding(10)
        .glassControlBackground(tint: Theme.accent)
    }
}

private struct CompactMetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .glassControlBackground(tint: tint, cornerRadius: 14)
    }
}

private struct BudgetLegendDot: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
            Text(value)
                .monospacedDigit()
                .foregroundStyle(Theme.ink)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReminderPreviewCard: View {
    let settings: StudySettings

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(settings.notificationsEnabled ? Theme.accent.opacity(0.16) : Theme.glassBlue.opacity(0.12))

                Image(systemName: settings.notificationsEnabled ? "bell.and.waves.left.and.right.fill" : "bell.slash.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(settings.notificationsEnabled ? Theme.accent : Theme.glassBlue)
            }
            .frame(width: 38, height: 38)

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.notificationsEnabled ? "Reminder on" : "Reminder off")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(settings.notificationsEnabled ? "Daily nudge at \(settings.reminderDate.formatted(.dateTime.hour().minute()))." : "No daily nudge.")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .glassControlBackground(tint: settings.notificationsEnabled ? Theme.accent : Theme.glassBlue)
    }
}

private struct OnboardingProgressRail: View {
    let page: Int
    let count: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index <= page ? Theme.accent : Theme.hairline.opacity(0.42))
                    .frame(height: 5)
                    .frame(maxWidth: index == page ? 34 : 16)
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: page)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel("Onboarding step \(page + 1) of \(count)")
    }
}

private struct OnboardingStepRow: View {
    let number: String
    let title: String
    let bodyText: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption2.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .frame(width: 28, height: 28)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.ink)
                Text(bodyText)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
