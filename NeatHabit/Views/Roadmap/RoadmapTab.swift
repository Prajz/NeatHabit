import SwiftUI

struct RoadmapTab: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var selectedDay: Int
    @Binding var selectedTab: AppTab

    var body: some View {
        StudyScreen(title: "Roadmap", tourStep: .constant(nil), tourFrames: .constant([:])) {
            VStack(spacing: ScreenScale.scale(14)) {
                RoadmapIntroCard()

                QuestionBankRoadmapCard(
                    progress: store.progress,
                    toggleProblem: { problem in
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            store.toggleRoadmapProblem(problem, lockingThrough: selectedDay)
                        }
                    }
                )
            }
        }
    }
}

private struct RoadmapIntroCard: View {
    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 9) {
                Text("Roadmap")
                    .eyebrow()
                Text("150 questions, grouped by pattern")
                    .font(AppFont.display(size: 28, weight: .black))
                    .tracking(-0.7)
                    .foregroundStyle(Theme.ink)
                Text("Tap ahead to mark work done. Future days rebalance around anything already touched.")
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
        VStack(alignment: .leading, spacing: 12) {
            LiquidGlassCard(tint: Theme.glassBlue) {
                HStack(alignment: .center, spacing: 12) {
                    SectionHeader(
                        title: "Question checklist",
                        subtitle: "\(completedRequiredCount)/\(StudyPlanner.requiredProblemCount) required questions touched. Tap a row to check or clear it."
                    )

                    Spacer(minLength: 0)

                    Text("\(completedRequiredCount)")
                        .font(AppFont.display(size: 26, weight: .black))
                        .monospacedDigit()
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.accent.opacity(0.11), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            LazyVStack(spacing: 10) {
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

private struct RoadmapSectionBlock: View {
    let section: ProblemSection
    let progress: StoredProgress
    let toggleProblem: (String) -> Void

    private var completedCount: Int {
        section.problems.filter { progress.status(for: $0) != .untouched }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                    Text(section.template)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Text("\(completedCount)/\(section.problems.count)")
                    .font(.caption.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(Theme.accent.opacity(0.11), in: Capsule())
            }

            VStack(spacing: 6) {
                ForEach(section.problems, id: \.self) { problem in
                    RoadmapProblemChecklistRow(
                        problem: problem,
                        status: progress.status(for: problem),
                        toggle: { toggleProblem(problem) }
                    )
                }
            }
        }
        .padding(12)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Theme.hairline.opacity(0.55), lineWidth: 1)
        }
    }
}

private struct RoadmapProblemChecklistRow: View {
    let problem: String
    let status: ProblemStatus
    let toggle: () -> Void

    private var isChecked: Bool { status != .untouched }

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 10) {
                Image(systemName: isChecked ? "checkmark.circle.fill" : "circle")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(isChecked ? status.tint : Theme.muted.opacity(0.55))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(problem)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    ProblemDifficultyBadge(difficulty: StudyPlanner.difficulty(for: problem))
                }

                Spacer(minLength: 8)

                if isChecked {
                    Text(status.shortTitle)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(status.tint)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(status.tint.opacity(0.12), in: Capsule())
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isChecked ? status.tint.opacity(0.08) : Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(isChecked ? "Clear" : "Check") \(problem)")
    }
}
