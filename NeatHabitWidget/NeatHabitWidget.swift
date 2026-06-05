import AppIntents
import SwiftUI
import UIKit
import WidgetKit

struct NeatHabitEntry: TimelineEntry {
    let date: Date
    let progress: StoredProgress
}

struct NeatHabitProvider: TimelineProvider {
    func placeholder(in context: Context) -> NeatHabitEntry {
        NeatHabitEntry(date: Date(), progress: StoredProgress())
    }

    func getSnapshot(in context: Context, completion: @escaping (NeatHabitEntry) -> Void) {
        completion(NeatHabitEntry(date: Date(), progress: ProgressPersistence.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NeatHabitEntry>) -> Void) {
        let entry = NeatHabitEntry(date: Date(), progress: ProgressPersistence.load())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1800)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }
}

struct NeatHabitWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NeatHabitEntry

    var body: some View {
        let schedule = StudyPlanner.plan(for: entry.progress)
        let day = schedule.day(entry.progress.currentDayNumber(in: schedule))
        let daily = entry.progress.dailyProgress(for: day.day)
        let summary = entry.progress.summary(for: schedule)
        let activeHabits = entry.progress.activeHabits(for: day.day, in: schedule)

        switch family {
        case .systemSmall:
            SmallHomeWidget(day: day, daily: daily, settings: schedule.settings, activeHabits: activeHabits)
        case .systemMedium:
            MediumHomeWidget(day: day, daily: daily, summary: summary, settings: schedule.settings, activeHabits: activeHabits)
        case .accessoryCircular:
            CircularLockWidget(day: day, daily: daily, settings: schedule.settings, activeHabits: activeHabits)
        case .accessoryRectangular:
            RectangularLockWidget(day: day, daily: daily, settings: schedule.settings, activeHabits: activeHabits)
        case .accessoryInline:
            InlineLockWidget(day: day, daily: daily, settings: schedule.settings, activeHabits: activeHabits)
        default:
            MediumHomeWidget(day: day, daily: daily, summary: summary, settings: schedule.settings, activeHabits: activeHabits)
        }
    }
}

struct SmallHomeWidget: View {
    let day: StudyDay
    let daily: DailyProgress
    let settings: StudySettings
    let activeHabits: [StudyHabit]

    private var fraction: Double { daily.completionFraction(for: day, settings: settings, hasRedoDue: activeHabits.contains(.review)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Day \(day.day)")
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                    Text("NeatHabit")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(WidgetTheme.muted)
                }

                Spacer()

                Text(widgetPercent(fraction))
                    .font(.title3.weight(.black))
                    .monospacedDigit()
            }

            Text(day.topic)
                .font(.headline.weight(.black))
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 0)

            ProgressView(value: fraction)
                .tint(WidgetTheme.accent)

            HabitDots(daily: daily, activeHabits: activeHabits, bright: true)
        }
        .foregroundStyle(WidgetTheme.ink)
        .containerBackground(for: .widget) {
            WidgetAdaptiveBackground()
        }
    }
}

struct MediumHomeWidget: View {
    let day: StudyDay
    let daily: DailyProgress
    let summary: PlanSummary
    let settings: StudySettings
    let activeHabits: [StudyHabit]

    private var fraction: Double { daily.completionFraction(for: day, settings: settings, hasRedoDue: activeHabits.contains(.review)) }
    private var counts: StatusCounts { daily.counts(for: day) }
    private var activeHabitCount: Int { activeHabits.count }
    private var completedActiveHabitCount: Int { activeHabits.filter { daily.completedHabits.contains($0) }.count }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 8) {
                    Text("DAY \(day.day)")
                        .font(.caption2.weight(.black))
                        .tracking(1)
                        .foregroundStyle(WidgetTheme.accent)
                    Text(widgetPercent(fraction))
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(WidgetTheme.ink.opacity(0.7))
                }

                Text(day.topic)
                    .font(.title3.weight(.black))
                    .foregroundStyle(WidgetTheme.ink)
                    .lineLimit(2)

                Text(day.systemDesignFocus)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(WidgetTheme.muted)
                    .lineLimit(2)

                Spacer(minLength: 0)

                ProgressView(value: fraction)
                    .tint(WidgetTheme.accent)

                HStack(spacing: 7) {
                    WidgetChip(label: "Habits", value: "\(completedActiveHabitCount)/\(activeHabitCount)", color: WidgetTheme.accent)
                    WidgetChip(label: "Problems", value: "\(counts.attempted)/\(day.problems.count)", color: WidgetTheme.blue)
                }
            }

            VStack(spacing: 7) {
                ForEach(activeHabits) { habit in
                    Button(intent: ToggleHabitIntent(habitRawValue: habit.rawValue)) {
                        Image(systemName: daily.completedHabits.contains(habit) ? "checkmark.circle.fill" : habit.systemImage)
                            .font(.caption.weight(.black))
                            .foregroundStyle(daily.completedHabits.contains(habit) ? WidgetTheme.accent : WidgetTheme.muted)
                            .frame(width: 36, height: 30)
                            .background((daily.completedHabits.contains(habit) ? WidgetTheme.accent : WidgetTheme.muted).opacity(0.12), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 44)
        }
        .containerBackground(for: .widget) {
            WidgetAdaptiveBackground()
        }
    }
}

struct CircularLockWidget: View {
    let day: StudyDay
    let daily: DailyProgress
    let settings: StudySettings
    let activeHabits: [StudyHabit]

    private var fraction: Double { daily.completionFraction(for: day, settings: settings, hasRedoDue: activeHabits.contains(.review)) }

    var body: some View {
        Gauge(value: fraction) {
            Text("Day \(day.day)")
        } currentValueLabel: {
            Text("\(Int((fraction * 100).rounded()))")
                .font(.caption2.weight(.black))
                .monospacedDigit()
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .widgetAccentable()
        .containerBackground(.clear, for: .widget)
    }
}

struct RectangularLockWidget: View {
    let day: StudyDay
    let daily: DailyProgress
    let settings: StudySettings
    let activeHabits: [StudyHabit]

    private var fraction: Double { daily.completionFraction(for: day, settings: settings, hasRedoDue: activeHabits.contains(.review)) }
    private var counts: StatusCounts { daily.counts(for: day) }
    private var activeHabitCount: Int { activeHabits.count }
    private var completedActiveHabitCount: Int { activeHabits.filter { daily.completedHabits.contains($0) }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Day \(day.day)")
                    .font(.caption2.weight(.black))
                    .monospacedDigit()
                Text(day.topic)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }

            HStack(spacing: 6) {
                HabitDots(daily: daily, activeHabits: activeHabits, bright: false)
                Text("\(completedActiveHabitCount)/\(activeHabitCount) habits")
                    .font(.caption2.weight(.semibold))
                Text("\(counts.attempted)/\(day.problems.count) problems")
                    .font(.caption2.weight(.semibold))
            }

            ProgressView(value: fraction)
                .tint(.primary)
        }
        .widgetAccentable()
        .containerBackground(.clear, for: .widget)
    }
}

struct InlineLockWidget: View {
    let day: StudyDay
    let daily: DailyProgress
    let settings: StudySettings
    let activeHabits: [StudyHabit]

    private var counts: StatusCounts { daily.counts(for: day) }
    private var activeHabitCount: Int { activeHabits.count }
    private var completedActiveHabitCount: Int { activeHabits.filter { daily.completedHabits.contains($0) }.count }

    var body: some View {
        Text("Day \(day.day) - \(completedActiveHabitCount)/\(activeHabitCount) habits - \(counts.attempted)/\(day.problems.count) problems")
            .widgetAccentable()
            .containerBackground(.clear, for: .widget)
    }
}

struct HabitDots: View {
    let daily: DailyProgress
    let activeHabits: [StudyHabit]
    let bright: Bool

    var body: some View {
        HStack(spacing: 5) {
            ForEach(activeHabits) { habit in
                Circle()
                    .fill(dotColor(for: habit))
                    .frame(width: bright ? 8 : 6, height: bright ? 8 : 6)
            }
        }
    }

    private func dotColor(for habit: StudyHabit) -> Color {
        guard daily.completedHabits.contains(habit) else {
            return bright ? WidgetTheme.muted.opacity(0.28) : .primary.opacity(0.2)
        }

        return bright ? WidgetTheme.accent : .primary
    }
}

struct WidgetChip: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(color)
            Text(label)
                .font(.caption2.weight(.bold))
                .foregroundStyle(WidgetTheme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color.opacity(0.11), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct WidgetStat: View {
    let label: String
    let value: Int
    let color: Color

    var body: some View {
        VStack(spacing: 1) {
            Text("\(value)")
                .font(.headline.weight(.black))
                .monospacedDigit()
            Text(label)
                .font(.caption2.weight(.heavy))
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct WidgetAdaptiveBackground: View {
    var body: some View {
        ZStack {
            WidgetTheme.canvas
            LinearGradient(
                colors: [
                    .white.opacity(0.12),
                    .clear,
                    WidgetTheme.accent.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(
                colors: [WidgetTheme.accent.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 8,
                endRadius: 150
            )
        }
    }
}

struct NeatHabitWidget: Widget {
    let kind = "NeatHabitWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NeatHabitProvider()) { entry in
            NeatHabitWidgetView(entry: entry)
        }
        .configurationDisplayName("NeatHabit")
        .description("Track today's NeetCode plan, daily habits, and lock screen pressure.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

@main
struct NeatHabitWidgetBundle: WidgetBundle {
    var body: some Widget {
        NeatHabitWidget()
    }
}

private enum WidgetTheme {
    static let ink = dynamic(light: (0.075, 0.092, 0.125), dark: (0.82, 0.87, 0.94))
    static let muted = dynamic(light: (0.36, 0.40, 0.43), dark: (0.55, 0.61, 0.70))
    static let canvas = dynamic(light: (0.955, 0.965, 0.98), dark: (0.075, 0.086, 0.105))
    static let accent = dynamic(light: (0.16, 0.38, 0.86), dark: (0.48, 0.66, 0.92))
    static let blue = dynamic(light: (0.38, 0.43, 0.56), dark: (0.54, 0.62, 0.73))
    static let green = dynamic(light: (0.20, 0.58, 0.34), dark: (0.45, 0.72, 0.55))
    static let amber = dynamic(light: (0.78, 0.49, 0.16), dark: (0.86, 0.65, 0.34))
    static let red = dynamic(light: (0.72, 0.25, 0.24), dark: (0.90, 0.48, 0.46))

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let values = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: values.0, green: values.1, blue: values.2, alpha: 1)
        })
    }
}

private func widgetPercent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}
