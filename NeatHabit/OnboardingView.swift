import SwiftUI

struct OnboardingView: View {
    private let maxDailyMinutes = 240

    @EnvironmentObject private var store: StudyProgressStore
    @State private var appeared = false
    @State private var page = 0

    private var schedule: StudySchedule { store.schedule }
    private var settings: StudySettings { store.progress.settings }
    private var dailyMinutes: Int { min(settings.dailyMinutes, maxDailyMinutes) }
    private var perQuestionMinutes: Double {
        guard schedule.averageProblemsPerDay > 0 else { return Double(settings.problemBlockMinutes) }
        return Double(settings.problemBlockMinutes) / schedule.averageProblemsPerDay
    }
    private var problemMinutesText: String {
        guard schedule.averageProblemsPerDay > 0 else { return "Enough time for today's plan." }
        let minutes = Int(perQuestionMinutes.rounded())
        return "\(dailyMinutes)m/day - 20m design = \(settings.problemBlockMinutes)m questions. About \(minutes)m/question."
    }

    private var canStart: Bool {
        guard schedule.averageProblemsPerDay > 0 else { return true }
        return perQuestionMinutes >= 15
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

            VStack(spacing: 12) {
                TabView(selection: $page) {
                    OnboardingPageCard(
                        eyebrow: "Setup",
                        symbol: "sparkles.rectangle.stack.fill",
                        title: "Build your daily plan.",
                        subtitle: "NeetCode 150 plus one design rep each day."
                    ) {
                        VStack(spacing: 10) {
                            HStack(spacing: 10) {
                                CompactMetricTile(title: "Questions", value: "\(schedule.requiredProblemCount)", symbol: "checklist", tint: Theme.accent)
                                CompactMetricTile(title: "Starts", value: "Day \(store.progress.currentDayNumber(in: schedule))", symbol: "target", tint: Theme.glassBlue)
                            }

                            OnboardingStepRow(number: "01", title: "Finish date", bodyText: "Sets questions/day.")
                            OnboardingStepRow(number: "02", title: "Daily time", bodyText: "20m design. Rest is question time.")
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
                        VStack(spacing: 12) {
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
                            .padding(10)
                            .frame(maxHeight: 350)
                            .glassControlBackground(tint: Theme.accent)

                            TargetImpactCard(title: "Date impact", schedule: schedule)
                        }
                    }
                    .tag(1)

                    OnboardingPageCard(
                        eyebrow: "Time",
                        symbol: "timer",
                        title: "How much time daily?",
                        subtitle: problemMinutesText
                    ) {
                        VStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text("\(dailyMinutes)")
                                        .font(AppFont.display(size: 38, weight: .black))
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                        .foregroundStyle(Theme.ink)
                                    Text("minutes/day")
                                        .font(.headline.weight(.black))
                                        .foregroundStyle(Theme.muted)
                                    Spacer(minLength: 0)
                                }

                                Slider(
                                    value: Binding(
                                        get: { Double(dailyMinutes) },
                                        set: { updateDailyMinutes(Int($0)) }
                                    ),
                                    in: 80...Double(maxDailyMinutes),
                                    step: 10
                                )
                                .tint(canStart ? Theme.accent : Theme.red)

                                HStack {
                                    Text("80m")
                                    Spacer()
                                    Text("Max \(maxDailyMinutes)m/day")
                                }
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.muted)
                            }
                            .padding(14)
                            .glassControlBackground(tint: canStart ? Theme.accent : Theme.red)

                            TimeBudgetBreakdown(schedule: schedule)
                            TimeImpactCard(title: "Time impact", schedule: schedule)
                        }
                    }
                    .tag(2)

                    OnboardingPageCard(
                        eyebrow: "Reminder",
                        symbol: "bell.badge.fill",
                        title: "Set a reminder.",
                        subtitle: "Pick a time for the daily nudge."
                    ) {
                        VStack(spacing: 12) {
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
                            .frame(height: 138)
                            .clipped()
                            .padding(.horizontal, 10)
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
                            .padding(14)
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
                        VStack(spacing: 12) {
                            TargetImpactCard(title: "Date impact", schedule: schedule)
                            TimeImpactCard(title: "Time impact", schedule: schedule)
                            ReminderPreviewCard(settings: settings)
                        }
                    }
                    .tag(4)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                OnboardingProgressRail(page: page, count: 5)
                    .padding(.horizontal, 22)

                HStack(spacing: 12) {
                    if page > 0 {
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                page -= 1
                            }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                                .font(.headline.weight(.black))
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
                        SWShimmer {
                            Label(ctaTitle, systemImage: ctaSymbol)
                                .font(.headline.weight(.black))
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(SWPrimaryGlassButtonStyle(tint: canStart ? Theme.accent : Theme.red))
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
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

    private func updateDailyMinutes(_ minutes: Int) {
        let clampedMinutes = min(max(minutes, 80), maxDailyMinutes)
        guard settings.dailyMinutes != clampedMinutes else { return }
        store.updateDailyMinutes(clampedMinutes)
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
        guard settings.dailyMinutes > maxDailyMinutes else { return }
        store.updateDailyMinutes(maxDailyMinutes)
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
        VStack(spacing: 10) {
            LiquidGlassCard(tint: tint) {
                VStack(alignment: .center, spacing: 12) {
                    Image(systemName: symbol)
                        .font(AppFont.display(size: 42, weight: .black))
                        .foregroundStyle(tint)
                        .frame(width: 62, height: 62)
                        .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 22, style: .continuous))

                    Text(eyebrow)
                        .eyebrow(color: tint)
                    Text(title)
                        .font(AppFont.display(size: 30, weight: .black))
                        .tracking(-0.9)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Theme.ink)
                        .lineSpacing(-1)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
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
        .padding(.horizontal, 18)
        .padding(.top, 18)
    }
}

private struct TargetImpactCard: View {
    let title: String
    let schedule: StudySchedule

    private var isComfortable: Bool {
        schedule.averageProblemsPerDay <= 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(isComfortable ? "Balanced" : "Tight")
                    .font(.caption.weight(.black))
                    .foregroundStyle(isComfortable ? Theme.green : Theme.red)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background((isComfortable ? Theme.green : Theme.red).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                CompactMetricTile(title: "Plan days", value: "\(schedule.totalDays)", symbol: "calendar", tint: Theme.accent)
                CompactMetricTile(title: "Questions/day", value: String(format: "%.1f", schedule.averageProblemsPerDay), symbol: "keyboard.fill", tint: Theme.accent)
            }
        }
        .padding(13)
        .glassControlBackground(tint: isComfortable ? Theme.accent : Theme.red)
    }
}

private struct TimeImpactCard: View {
    let title: String
    let schedule: StudySchedule

    private var perQuestionMinutes: Int {
        guard schedule.averageProblemsPerDay > 0 else { return schedule.settings.problemBlockMinutes }
        return Int((Double(schedule.settings.problemBlockMinutes) / schedule.averageProblemsPerDay).rounded())
    }

    private var isComfortable: Bool {
        perQuestionMinutes >= 15
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Spacer(minLength: 8)
                Text(isComfortable ? "Enough" : "Tight")
                    .font(.caption.weight(.black))
                    .foregroundStyle(isComfortable ? Theme.green : Theme.red)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background((isComfortable ? Theme.green : Theme.red).opacity(0.12), in: Capsule())
            }

            HStack(spacing: 10) {
                CompactMetricTile(title: "Problem time", value: "\(schedule.settings.problemBlockMinutes)m", symbol: "hourglass", tint: Theme.glassBlue)
                CompactMetricTile(title: "Per question", value: "\(perQuestionMinutes)m", symbol: "timer", tint: isComfortable ? Theme.green : Theme.red)
            }
        }
        .padding(13)
        .glassControlBackground(tint: isComfortable ? Theme.accent : Theme.red)
    }
}

private struct TimeBudgetBreakdown: View {
    let schedule: StudySchedule

    private var designFraction: Double {
        Double(schedule.settings.fixedMinutes) / Double(max(schedule.settings.dailyMinutes, 1))
    }

    private var problemFraction: Double {
        Double(schedule.settings.problemBlockMinutes) / Double(max(schedule.settings.dailyMinutes, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label("Daily budget", systemImage: "chart.bar.fill")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text("\(schedule.settings.dailyMinutes)m")
                    .font(.subheadline.weight(.black))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(Theme.accent)
            }

            GeometryReader { proxy in
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.ink.opacity(0.72))
                        .frame(width: max(20, proxy.size.width * designFraction))
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: max(20, proxy.size.width * problemFraction))
                }
            }
            .frame(height: 10)

            HStack(spacing: 10) {
                BudgetLegendDot(title: "Design rep", value: "\(schedule.settings.fixedMinutes)m", color: Theme.ink)
                BudgetLegendDot(title: "Questions", value: "\(schedule.settings.problemBlockMinutes)m", color: Theme.accent)
            }
        }
        .padding(13)
        .glassControlBackground(tint: Theme.accent)
    }
}

private struct CompactMetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.black))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.weight(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassControlBackground(tint: tint, cornerRadius: 18)
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
        .font(.caption.weight(.bold))
        .foregroundStyle(Theme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ReminderPreviewCard: View {
    let settings: StudySettings

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(settings.notificationsEnabled ? Theme.accent.opacity(0.16) : Theme.glassBlue.opacity(0.12))

                Image(systemName: settings.notificationsEnabled ? "bell.and.waves.left.and.right.fill" : "bell.slash.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(settings.notificationsEnabled ? Theme.accent : Theme.glassBlue)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 4) {
                Text(settings.notificationsEnabled ? "Reminder on" : "Reminder off")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text(settings.notificationsEnabled ? "Daily nudge at \(settings.reminderDate.formatted(.dateTime.hour().minute()))." : "No daily nudge.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(13)
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
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(Theme.accent)
                .frame(width: 32, height: 32)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
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
        .padding(10)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}
