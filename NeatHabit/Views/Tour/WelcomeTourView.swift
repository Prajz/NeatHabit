import SwiftUI
import UIKit

private struct TourStep: Identifiable {
    let id = UUID()
    let symbol: String
    let tint: Color
    let eyebrow: String
    let title: String
    let body: String
    let anchorID: TourAnchorID
    let highlightMode: HighlightMode

    enum HighlightMode {
        case element
        case tabBar
    }
}

enum TourAnchorID: String, CaseIterable {
    case dayStrip = "tour.anchor.dayStrip"
    case redoQueue = "tour.anchor.redoQueue"
    case problems = "tour.anchor.problems"
    case systemDesign = "tour.anchor.systemDesign"
    case notes = "tour.anchor.notes"

    static func anchor(for step: Int) -> TourAnchorID? {
        switch step {
        case 0: return .dayStrip
        case 1: return .problems
        case 2: return .systemDesign
        case 3: return .notes
        default: return nil
        }
    }
}

enum TourCoordinateSpace {
    static let name = "tourScroll"
}

struct TourElementFrameKey: PreferenceKey {
    nonisolated(unsafe) static var defaultValue: [TourAnchorID: CGRect] = [:]
    static func reduce(value: inout [TourAnchorID: CGRect], nextValue: () -> [TourAnchorID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}

struct TourElementProbe<Content: View>: View {
    let anchorID: TourAnchorID
    let content: Content

    init(anchorID: TourAnchorID, @ViewBuilder content: () -> Content) {
        self.anchorID = anchorID
        self.content = content()
    }

    var body: some View {
        content
            .id(anchorID.rawValue)
            .background(
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: TourElementFrameKey.self,
                        value: [anchorID: proxy.frame(in: .global)]
                    )
                }
            )
    }
}

struct WelcomeTourView: View {
    @EnvironmentObject private var store: StudyProgressStore
    @Binding var tourStep: Int?
    let tourFrames: [TourAnchorID: CGRect]
    @State private var stepIndex = 0
    @State private var appeared = false

    private let steps: [TourStep] = [
        TourStep(
            symbol: "calendar",
            tint: Theme.accent,
            eyebrow: "Day strip",
            title: "Swipe to peek ahead",
            body: "Tap any day in the strip to jump to its plan. The accent ring marks today.",
            anchorID: .dayStrip,
            highlightMode: .element
        ),
        TourStep(
            symbol: "checklist",
            tint: Theme.accent,
            eyebrow: "Problems",
            title: "Rate each question",
            body: "Tap a question to cycle colors: green if you got it solo, yellow if you needed a hint, red to schedule a redo.",
            anchorID: .problems,
            highlightMode: .element
        ),
        TourStep(
            symbol: "server.rack",
            tint: Theme.glassBlue,
            eyebrow: "System design",
            title: "Your daily design rep",
            body: "Open the topic, walk through scope, API, flow, bottleneck, and a tradeoff. Then mark it done.",
            anchorID: .systemDesign,
            highlightMode: .element
        ),
        TourStep(
            symbol: "square.and.pencil",
            tint: Theme.amber,
            eyebrow: "Notes",
            title: "Capture what sticks",
            body: "Jot the template, invariant, or bug that should live in your head for the next interview.",
            anchorID: .notes,
            highlightMode: .element
        ),
        TourStep(
            symbol: "square.grid.2x2.fill",
            tint: Theme.glassBlue,
            eyebrow: "Other tabs",
            title: "Roadmap, Progress, Guide",
            body: "Roadmap has every question. Progress shows your stats. Guide holds settings and the redo-onboarding button.",
            anchorID: .notes,
            highlightMode: .tabBar
        )
    ]

    private var currentStep: TourStep { steps[stepIndex] }
    private var isLast: Bool { stepIndex == steps.count - 1 }
    private var measuredTabBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .compactMap { window in findTabBar(in: window)?.bounds.height }
            .first ?? 49
    }

    var body: some View {
        GeometryReader { geo in
            let safeTop = geo.safeAreaInsets.top
            let safeBottom = geo.safeAreaInsets.bottom
            let tabBarHeight = max(49, measuredTabBarHeight - safeBottom)
            let fullHeight = geo.size.height + safeTop + safeBottom

            let frame = tourFrames[currentStep.anchorID] ?? .zero
            let midLine = fullHeight * 0.5
            let calloutAtTop = !frame.isEmpty && frame.midY > midLine && currentStep.highlightMode == .element

            ZStack {
                scrimAndHighlight(
                    fullSize: CGSize(width: geo.size.width, height: fullHeight),
                    safeTop: safeTop,
                    safeBottom: safeBottom,
                    tabBarHeight: tabBarHeight
                )
                .ignoresSafeArea()

                if calloutAtTop {
                    VStack(spacing: 0) {
                        calloutCard
                            .padding(.horizontal, 14)
                            .padding(.top, 10)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 0) {
                        Spacer()
                        calloutCard
                            .padding(.horizontal, 14)
                            .padding(.bottom, tabBarHeight + 10)
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .onAppear {
            tourStep = 0
            withAnimation(.smooth(duration: 0.35)) {
                appeared = true
            }
        }
        .onChange(of: stepIndex) { _, newIndex in
            tourStep = newIndex
        }
    }

    private func findTabBar(in view: UIView) -> UITabBar? {
        if let tabBar = view as? UITabBar {
            return tabBar
        }

        for subview in view.subviews {
            if let tabBar = findTabBar(in: subview) {
                return tabBar
            }
        }

        return nil
    }

    @ViewBuilder
    private func scrimAndHighlight(fullSize: CGSize, safeTop: CGFloat, safeBottom: CGFloat, tabBarHeight: CGFloat) -> some View {
        switch currentStep.highlightMode {
        case .element:
            elementHighlight(fullSize: fullSize, safeTop: safeTop, safeBottom: safeBottom, tabBarHeight: tabBarHeight)
        case .tabBar:
            tabBarHighlight(fullSize: fullSize, safeBottom: safeBottom, tabBarHeight: tabBarHeight)
        }
    }

    private func elementHighlight(fullSize: CGSize, safeTop: CGFloat, safeBottom: CGFloat, tabBarHeight: CGFloat) -> some View {
        let frame = tourFrames[currentStep.anchorID] ?? .zero
        let visibleTop = safeTop + 8
        let visibleBottom = fullSize.height - safeBottom - tabBarHeight - 8

        let pad: CGFloat = 8
        let maxHoleHeight: CGFloat = 220
        let minHoleHeight: CGFloat = 60

        let rawHoleWidth: CGFloat = frame.isEmpty ? 280 : frame.width + pad * 2
        let rawHoleHeight: CGFloat = frame.isEmpty ? 120 : frame.height + pad * 2
        let holeWidth = min(rawHoleWidth, fullSize.width - 24)
        let holeHeight = min(max(rawHoleHeight, minHoleHeight), maxHoleHeight)

        let holeX: CGFloat = frame.isEmpty ? fullSize.width / 2 : frame.midX
        let holeY: CGFloat
        if frame.isEmpty {
            holeY = visibleTop + (visibleBottom - visibleTop) * 0.30
        } else {
            let topClamp = visibleTop + holeHeight / 2 + 6
            let bottomClamp = visibleBottom - holeHeight / 2 - 6
            let target = frame.minY + holeHeight / 2
            holeY = min(max(target, topClamp), bottomClamp)
        }

        return ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .frame(width: holeWidth, height: holeHeight)
                .position(x: holeX, y: holeY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(currentStep.tint, lineWidth: 2.5)
                .frame(width: holeWidth, height: holeHeight)
                .position(x: holeX, y: holeY)
                .shadow(color: currentStep.tint.opacity(0.55), radius: 16)
                .allowsHitTesting(false)
        }
    }

    private func tabBarHighlight(fullSize: CGSize, safeBottom: CGFloat, tabBarHeight: CGFloat) -> some View {
        let tabBarY = fullSize.height - safeBottom - tabBarHeight / 2
        let tabBarWidth = fullSize.width
        return ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .frame(width: tabBarWidth - 32, height: 60)
                .position(x: fullSize.width / 2, y: tabBarY)
                .blendMode(.destinationOut)
        }
        .compositingGroup()
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(currentStep.tint, lineWidth: 2.5)
                .frame(width: tabBarWidth - 32, height: 60)
                .position(x: fullSize.width / 2, y: tabBarY)
                .shadow(color: currentStep.tint.opacity(0.55), radius: 16)
                .allowsHitTesting(false)
        }
        .overlay(alignment: .top) {
            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(currentStep.tint)
                .shadow(color: .black.opacity(0.4), radius: 4)
                .position(x: fullSize.width / 2, y: tabBarY - 42)
                .allowsHitTesting(false)
        }
    }

    private var calloutCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(currentStep.tint.opacity(0.18))
                    Image(systemName: currentStep.symbol)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(currentStep.tint)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(currentStep.eyebrow)
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .textCase(.uppercase)
                        .foregroundStyle(currentStep.tint)
                    Text(currentStep.title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)
            }

            Text(currentStep.body)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    skipTour()
                } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)

                Spacer()

                HStack(spacing: 4) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Capsule()
                            .fill(index == stepIndex ? currentStep.tint : Theme.hairline.opacity(0.5))
                            .frame(width: index == stepIndex ? 18 : 6, height: 6)
                    }
                }

                Button {
                    advance()
                } label: {
                    Label(
                        isLast ? "Start studying" : "Next",
                        systemImage: isLast ? "checkmark" : "arrow.right"
                    )
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 11)
                    .background(currentStep.tint.gradient, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Theme.cardFill)
                .shadow(color: .black.opacity(0.35), radius: 28, x: 0, y: 12)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.16), lineWidth: 0.7)
        }
    }

    private func advance() {
        Haptics.selection()
        if isLast {
            Haptics.success()
            withAnimation(.smooth(duration: 0.35)) {
                store.completeWelcomeTour()
            }
        } else {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                stepIndex += 1
            }
        }
    }

    private func skipTour() {
        Haptics.selection()
        withAnimation(.smooth(duration: 0.35)) {
            store.completeWelcomeTour()
        }
    }
}
