import SwiftUI

struct ProgressTab: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var selectedDay: Int
    @Binding var selectedTab: AppTab

    private var schedule: StudySchedule { store.schedule }
    private var summary: PlanSummary { store.progress.summary(for: schedule) }

    var body: some View {
        StudyScreen(title: "Progress", tourStep: .constant(nil), tourFrames: .constant([:])) {
            VStack(spacing: ScreenScale.scale(18)) {
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
                    .font(.subheadline.weight(.bold))
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
                                .font(.subheadline.weight(.bold))
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
                                    .font(.caption2.weight(.bold))
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
                                    .font(.caption.weight(.semibold))
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
