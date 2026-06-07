import SwiftUI

struct ProblemDifficultyBadge: View {
    let difficulty: ProblemDifficulty

    var body: some View {
        HStack(spacing: 5) {
            Text("Difficulty")
                .foregroundStyle(Theme.muted)
            Text(difficulty.title)
                .foregroundStyle(Theme.ink)
        }
        .font(.caption2.weight(.bold))
        .tracking(0.25)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Theme.cardFill, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Theme.hairline.opacity(0.55), lineWidth: 1)
        }
        .accessibilityLabel("Difficulty: \(difficulty.title)")
    }
}

struct EmptyStateRow: View {
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
                    .font(.subheadline.weight(.bold))
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

extension StudyHabit {
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

extension ProblemStatus {
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

func shortDateText(_ date: Date) -> String {
    date.formatted(.dateTime.month(.abbreviated).day())
}

func longDateText(_ date: Date) -> String {
    date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
}
