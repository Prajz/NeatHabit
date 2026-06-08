import SwiftUI

struct GuideTab: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var selectedTab: AppTab

    var body: some View {
        StudyScreen(title: "Guide", tourStep: .constant(nil), tourFrames: .constant([:])) {
            VStack(spacing: ScreenScale.scale(18)) {
                GuideHeaderCard()
                GuideSetupCard(schedule: store.schedule, selectedTab: $selectedTab)
                SystemDesignTopicsCard()
                ExtraPracticeCard()
                GuideRulesCard()
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
    @Binding var selectedTab: AppTab

    @State private var showDateEditor = false
    @State private var showTimeEditor = false
    @State private var showReminderEditor = false
    @State private var shuffleSummary: String?

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
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button("Done") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    showDateEditor = false
                                }
                            }
                            .font(.subheadline.weight(.bold))
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
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button("Done") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    showTimeEditor = false
                                }
                            }
                            .font(.subheadline.weight(.bold))
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
                                in: 20...240,
                                step: 5
                            )
                            .tint(Theme.accent)

                            HStack {
                                Text("20m")
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
                                    .font(.subheadline.weight(.bold))
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
                                in: 15...40,
                                step: 5
                            )
                            .tint(Theme.accent)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("LeetCode questions")
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(Theme.ink)
                                Spacer()
                                Text("\(schedule.settings.problemBlockMinutes)m")
                                    .font(.title3.weight(.black))
                                    .monospacedDigit()
                                    .foregroundStyle(Theme.accent)
                            }

                            Stepper(
                                "Coding duration",
                                value: Binding(
                                    get: { schedule.settings.problemBlockMinutes },
                                    set: { store.updateProblemBlockMinutes($0) }
                                ),
                                in: 5...200,
                                step: 5
                            )
                            .tint(Theme.accent)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.muted)
                        }
                        .padding(14)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                        let effectiveSD = schedule.settings.systemDesignMinutes
                        let codingTime = schedule.settings.problemBlockMinutes
                        let totalTime = effectiveSD + codingTime
                        VStack(alignment: .leading, spacing: 6) {
                            Text("\(effectiveSD)m design + \(codingTime)m coding = \(totalTime)m total")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Text("~\(perQuestionMinutes)m/question")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(perQuestionMinutes >= 20 ? Theme.green : Theme.red)
                            if perQuestionMinutes < 20 {
                                Text("Under 20 min/question is tight. Add time or push the finish date.")
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(Theme.red)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
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
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Button("Done") {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
                                    showReminderEditor = false
                                }
                            }
                            .font(.subheadline.weight(.bold))
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
                        withAnimation(.smooth(duration: 0.4)) {
                            store.restartWelcomeTour()
                            selectedTab = .today
                        }
                    } label: {
                        Label("Show app tour", systemImage: "sparkles")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .compatibleGlassButtonStyle(tint: Theme.accent)

                    Button {
                        let moved = store.shuffleCompletedFutureProblems()
                        Haptics.selection()
                        withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                            shuffleSummary = moved == 0 ? "No completed future problems to move." : "Moved \(moved) completed \(moved == 1 ? "problem" : "problems") into earlier open slots."
                        }
                    } label: {
                        Label("Shuffle problems", systemImage: "shuffle")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .compatibleGlassButtonStyle(tint: Theme.glassBlue)

                    if let shuffleSummary {
                        Text(shuffleSummary)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.muted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                    }

                    Button {
                        store.restartOnboarding()
                    } label: {
                        Label("Redo onboarding", systemImage: "rectangle.portrait.and.arrow.right")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .compatibleGlassButtonStyle(tint: Theme.glassBlue)

                    Button(role: .destructive) {
                        store.restartOnboarding(resetTimeline: true)
                    } label: {
                        Label("Reset timeline + redo onboarding", systemImage: "calendar.badge.clock")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .compatibleGlassButtonStyle(tint: Theme.red)
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
                    subtitle: "\(SystemDesignTopics.all.count) topics covering fundamentals, scale, reliability, and classic interview problems. Tap any topic for a deep dive."
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
                                            .font(.caption.weight(.bold))
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
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(Theme.ink)

                                Spacer()

                                Text("\(SystemDesignTopics.all.filter { $0.category == category }.count)")
                                    .font(.caption.weight(.bold))
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
                    .font(.subheadline.weight(.bold))
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
                        .compatibleGlassButtonStyle(tint: Theme.accent, prominence: .primary)
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
                            .font(.title3.weight(.bold))
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
