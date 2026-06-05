import SwiftUI
import UIKit

struct SystemDesignDetailView: View {
    let topic: SystemDesignTopic
    @State private var appeared = false
    @State private var showCopiedAlert = false

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    TopicHeroSection(topic: topic, appeared: appeared)

                    ArchitectureDiagramView(topic: topic)

                    ConceptsSection(concepts: topic.concepts)

                    TalkingPointsSection(points: topic.talkingPoints)

                    TradeoffsSection(tradeoffs: topic.tradeoffs)

                    Button {
                        copyTopicForLLM(topic)
                        showCopiedAlert = true
                    } label: {
                        Label("Ask AI", systemImage: "brain.head.profile")
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(SWSecondaryGlassButtonStyle(tint: Theme.glassBlue))
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 34)
            }
        }
        .navigationTitle(topic.title)
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            withAnimation(.smooth(duration: 0.5)) {
                appeared = true
            }
        }
        .alert("Copied to clipboard", isPresented: $showCopiedAlert) {
            Button("Got it") {}
        } message: {
            Text("Paste into any LLM and ask follow-up questions. You think I'm paying for API costs? lol")
        }
    }

    private func copyTopicForLLM(_ topic: SystemDesignTopic) {
        var parts: [String] = []

        parts.append("System Design: \(topic.title)")
        parts.append("Category: \(topic.category)")

        if !topic.overview.isEmpty {
            parts.append("")
            parts.append("Overview:")
            parts.append(topic.overview)
        }

        if !topic.concepts.isEmpty {
            parts.append("")
            parts.append("Key Concepts:")
            for concept in topic.concepts {
                parts.append("- \(concept.title): \(concept.detail)")
            }
        }

        if !topic.talkingPoints.isEmpty {
            parts.append("")
            parts.append("Talking Points:")
            for point in topic.talkingPoints {
                parts.append("- \(point)")
            }
        }

        if !topic.tradeoffs.isEmpty {
            parts.append("")
            parts.append("Tradeoffs:")
            for tradeoff in topic.tradeoffs {
                parts.append("- \(tradeoff)")
            }
        }

        parts.append("")
        parts.append("Explain this to me simply.")

        UIPasteboard.general.string = parts.joined(separator: "\n")
    }
}

private struct TopicHeroSection: View {
    let topic: SystemDesignTopic
    let appeared: Bool

    var body: some View {
        LiquidGlassCard(tint: tintForCategory(topic.category)) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    Image(systemName: topic.icon)
                        .font(.title.weight(.black))
                        .foregroundStyle(tintForCategory(topic.category))
                        .frame(width: 52, height: 52)
                        .background(tintForCategory(topic.category).opacity(0.13), in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(topic.category.uppercased())
                            .font(.caption2.weight(.black))
                            .tracking(1.2)
                            .foregroundStyle(tintForCategory(topic.category))

                        Text(topic.title)
                            .font(AppFont.display(size: 26, weight: .black))
                            .tracking(-0.6)
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }

                Text(topic.overview)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }
}

private struct ArchitectureDiagramView: View {
    let topic: SystemDesignTopic

    var body: some View {
        LiquidGlassCard(tint: Theme.glassBlue) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Architecture",
                    subtitle: diagramSubtitle
                )

                switch topic.diagramStyle {
                case .flow:
                    FlowDiagramView(nodes: topic.diagramNodes)
                case .architecture:
                    ArchitectureStackView(nodes: topic.diagramNodes)
                case .comparison:
                    ComparisonDiagramView(nodes: topic.diagramNodes)
                case .cycle:
                    FlowDiagramView(nodes: topic.diagramNodes)
                }
            }
        }
    }

    private var diagramSubtitle: String {
        switch topic.diagramStyle {
        case .flow:
            return "Data flow through the system"
        case .architecture:
            return "Layered architecture"
        case .comparison:
            return "Options and tradeoffs"
        case .cycle:
            return "Lifecycle and flow"
        }
    }
}

private struct FlowDiagramView: View {
    let nodes: [DiagramNode]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                DiagramNodeView(node: node)

                if index < nodes.count - 1 {
                    DiagramArrow(tint: colorForRole(node.role))
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ArchitectureStackView: View {
    let nodes: [DiagramNode]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                HStack(spacing: 12) {
                    Image(systemName: node.icon)
                        .font(.headline.weight(.black))
                        .foregroundStyle(colorForRole(node.role))
                        .frame(width: 36, height: 36)
                        .background(colorForRole(node.role).opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.title)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text(node.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.muted)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(colorForRole(node.role).opacity(0.06), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(colorForRole(node.role).opacity(0.2), lineWidth: 1)
                }

                if index < nodes.count - 1 {
                    Image(systemName: "arrow.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.muted.opacity(0.5))
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct ComparisonDiagramView: View {
    let nodes: [DiagramNode]

    var body: some View {
        VStack(spacing: 8) {
            ForEach(nodes) { node in
                HStack(spacing: 12) {
                    Image(systemName: node.icon)
                        .font(.headline.weight(.black))
                        .foregroundStyle(colorForRole(node.role))
                        .frame(width: 40, height: 40)
                        .background(colorForRole(node.role).opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(node.title)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.ink)
                        Text(node.subtitle)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(16)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct DiagramNodeView: View {
    let node: DiagramNode

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(colorForRole(node.role).opacity(0.12))

                Image(systemName: node.icon)
                    .font(.headline.weight(.black))
                    .foregroundStyle(colorForRole(node.role))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(node.title)
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(Theme.ink)
                Text(node.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Theme.cardFill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(colorForRole(node.role).opacity(0.25), lineWidth: 1)
        }
    }
}

private struct DiagramArrow: View {
    let tint: Color

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(tint.opacity(0.3))
                .frame(width: 2, height: 16)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(tint.opacity(0.5))
        }
        .padding(.vertical, 2)
    }
}

private struct ConceptsSection: View {
    let concepts: [DesignConcept]

    var body: some View {
        LiquidGlassCard(tint: Theme.accent) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Key concepts",
                    subtitle: "The building blocks you need to explain this topic clearly."
                )

                VStack(spacing: 10) {
                    ForEach(concepts) { concept in
                        ConceptCard(concept: concept)
                    }
                }
            }
        }
    }
}

private struct ConceptCard: View {
    let concept: DesignConcept
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: isExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 28, height: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(concept.title)
                            .font(.subheadline.weight(.black))
                            .foregroundStyle(Theme.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(concept.detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.muted)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .padding(.leading, 40)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Theme.hairline.opacity(0.3), lineWidth: 1)
        }
    }
}

private struct TalkingPointsSection: View {
    let points: [String]

    var body: some View {
        LiquidGlassCard(tint: Theme.green) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Interview talking points",
                    subtitle: "Say these things to demonstrate senior-level understanding."
                )

                VStack(spacing: 10) {
                    ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.black))
                                .monospacedDigit()
                                .foregroundStyle(Theme.green)
                                .frame(width: 28, height: 28)
                                .background(Theme.green.opacity(0.12), in: Circle())

                            Text(point)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }
}

private struct TradeoffsSection: View {
    let tradeoffs: [String]

    var body: some View {
        LiquidGlassCard(tint: Theme.amber) {
            VStack(alignment: .leading, spacing: 16) {
                SectionHeader(
                    title: "Tradeoffs to discuss",
                    subtitle: "Every design decision has a cost. Name it explicitly."
                )

                VStack(spacing: 10) {
                    ForEach(tradeoffs, id: \.self) { tradeoff in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "arrow.left.arrow.right")
                                .font(.caption.weight(.black))
                                .foregroundStyle(Theme.amber)
                                .frame(width: 28, height: 28)
                                .background(Theme.amber.opacity(0.12), in: Circle())

                            Text(tradeoff)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(Theme.ink)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                }
            }
        }
    }
}

private func colorForRole(_ role: DiagramNode.NodeRole) -> Color {
    switch role {
    case .client:
        return Theme.glassBlue
    case .edge:
        return Theme.accent
    case .service:
        return Theme.accent
    case .cache:
        return Theme.green
    case .storage:
        return Theme.amber
    case .queue:
        return Theme.glassBlue
    case .external:
        return Theme.red
    case .monitor:
        return Theme.accent
    }
}

private func tintForCategory(_ category: String) -> Color {
    switch category {
    case "Fundamentals":
        return Theme.accent
    case "Data & Storage":
        return Theme.amber
    case "Performance":
        return Theme.green
    case "Scale":
        return Theme.glassBlue
    case "Reliability":
        return Theme.red
    case "Application Design":
        return Theme.accent
    case "Classic Problems":
        return Theme.glassBlue
    case "Operations":
        return Theme.green
    case "Interview Prep":
        return Theme.accent
    default:
        return Theme.accent
    }
}
