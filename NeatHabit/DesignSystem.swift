import SwiftUI
import UIKit

@MainActor
enum ScreenScale {
    static let baseWidth: CGFloat = 375
    private static var screenWidth: CGFloat = baseWidth

    static var factor: CGFloat {
        max(1.0, screenWidth / baseWidth)
    }

    static func scale(_ value: CGFloat, cap: CGFloat = 1.35) -> CGFloat {
        value * min(factor, cap)
    }

    static func update(width: CGFloat) {
        screenWidth = max(width, baseWidth)
    }
}

@MainActor
enum AppFont {
    static func body(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .custom(postScriptName(for: weight), size: ScreenScale.scale(size), relativeTo: .body)
    }

    static func display(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .custom(postScriptName(for: weight), size: ScreenScale.scale(size), relativeTo: .largeTitle)
    }

    private static func postScriptName(for weight: Font.Weight) -> String {
        switch weight {
        case .black, .heavy:
            return "AvenirNext-Heavy"
        case .bold:
            return "AvenirNext-Bold"
        case .semibold:
            return "AvenirNext-DemiBold"
        case .medium:
            return "AvenirNext-Medium"
        default:
            return "AvenirNext-Regular"
        }
    }
}

enum Theme {
    static let ink = dynamic(light: (0.070, 0.080, 0.105), dark: (0.82, 0.87, 0.94))
    static let muted = dynamic(light: (0.36, 0.39, 0.46), dark: (0.55, 0.61, 0.70))
    static let canvas = dynamic(light: (0.955, 0.965, 0.98), dark: (0.075, 0.086, 0.105))
    static let surface = dynamic(light: (0.985, 0.99, 1.0), dark: (0.125, 0.140, 0.165)).opacity(0.90)
    static let cardFill = dynamic(light: (0.992, 0.995, 1.0), dark: (0.105, 0.120, 0.145))
    static let hairline = dynamic(light: (0.82, 0.86, 0.92), dark: (0.245, 0.285, 0.34))
    static let cardShadow = dynamic(light: (0.08, 0.11, 0.18), dark: (0.015, 0.025, 0.040))
    static let accent = dynamic(light: (0.16, 0.38, 0.86), dark: (0.48, 0.66, 0.92))
    static let glassBlue = dynamic(light: (0.38, 0.43, 0.56), dark: (0.54, 0.62, 0.73))
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

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Theme.canvas

            LinearGradient(
                colors: [
                    .white.opacity(colorScheme == .dark ? 0.055 : 0.26),
                    .clear,
                    Theme.accent.opacity(colorScheme == .dark ? 0.045 : 0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Theme.accent.opacity(colorScheme == .dark ? 0.10 : 0.16), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )

            RadialGradient(
                colors: [Theme.glassBlue.opacity(colorScheme == .dark ? 0.09 : 0.035), .clear],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}

struct LiquidGlassCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme

    let tint: Color
    let content: Content

    init(tint: Color = Theme.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(ScreenScale.scale(18))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.cardFill.opacity(colorScheme == .dark ? 0.84 : 0.92))
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(colorScheme == .dark ? 0.07 : 0.18),
                                tint.opacity(colorScheme == .dark ? 0.045 : 0.08),
                                .clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.10 : 0.24), lineWidth: 0.7)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(tint.opacity(colorScheme == .dark ? 0.14 : 0.20), lineWidth: 1)
            }
            .shadow(color: Theme.cardShadow.opacity(colorScheme == .dark ? 0.34 : 0.13), radius: 22, x: 0, y: 14)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbol)
                .font(.headline.weight(.bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.title3.weight(.black))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(Theme.ink)
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassControlBackground(tint: tint)
    }
}

struct ProgressRing: View {
    let fraction: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.13), lineWidth: 12)
            Circle()
                .trim(from: 0, to: max(0, min(fraction, 1)))
                .stroke(tint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 1) {
                Text(percent(fraction))
                    .font(.title3.weight(.black))
                    .monospacedDigit()
                Text("done")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.muted)
            }
        }
    }
}

struct SWShimmer<Content: View>: View {
    @State private var animate = false

    var duration: Double = 1.4
    var delay: Double = 2.8
    let content: Content

    init(duration: Double = 1.4, delay: Double = 2.8, @ViewBuilder content: () -> Content) {
        self.duration = duration
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let bandWidth = geometry.size.width * 0.42

                    LinearGradient(
                        colors: [.clear, .white.opacity(0.20), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: bandWidth)
                    .offset(x: animate ? geometry.size.width + bandWidth : -bandWidth * 1.5)
                    .animation(.linear(duration: duration).delay(delay).repeatForever(autoreverses: false), value: animate)
                }
                .allowsHitTesting(false)
                .clipped()
            }
            .task {
                try? await Task.sleep(nanoseconds: 100_000_000)
                animate = true
            }
    }
}

struct SWShimmerSweep: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    @State private var animate = false

    var duration: Double = 1.15
    var delay: Double = 0.9
    var cornerRadius: CGFloat = 22

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { geometry in
                    let bandWidth = max(56, geometry.size.width * 0.30)

                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(colorScheme == .dark ? 0.50 : 0.62),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(width: bandWidth, height: geometry.size.height * 1.8)
                    .blur(radius: 0.4)
                    .blendMode(.plusLighter)
                    .rotationEffect(.degrees(12))
                    .offset(x: animate ? geometry.size.width + bandWidth : -bandWidth * 1.8, y: -geometry.size.height * 0.35)
                    .animation(.linear(duration: duration).delay(delay).repeatForever(autoreverses: false), value: animate)
                }
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
            }
            .task {
                try? await Task.sleep(nanoseconds: 180_000_000)
                animate = true
            }
    }
}

struct SWPrimaryGlassButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, 18)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(tint.gradient)
                    .overlay {
                        LinearGradient(
                            colors: [.white.opacity(0.34), .clear, .black.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(0.34), lineWidth: 1)
            }
            .shadow(color: tint.opacity(configuration.isPressed ? 0.14 : 0.30), radius: configuration.isPressed ? 10 : 22, x: 0, y: configuration.isPressed ? 6 : 14)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

struct SWSecondaryGlassButtonStyle: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(tint)
            .padding(.vertical, 15)
            .padding(.horizontal, 16)
            .glassControlBackground(tint: tint, cornerRadius: 22)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.26, dampingFraction: 0.78), value: configuration.isPressed)
    }
}

enum Haptics {
    @MainActor
    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    @MainActor
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

extension Text {
    func eyebrow(color: Color = Theme.accent) -> some View {
        self
            .font(.caption.weight(.bold))
            .tracking(1.1)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}

extension View {
    func glassControlBackground(tint: Color = Theme.accent, cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassControlBackground(tint: tint, cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func compatibleGlassButtonStyle(tint: Color = Theme.accent, prominence: GlassButtonProminence = .secondary) -> some View {
        if #available(iOS 26.0, *) {
            self.buttonStyle(.glass)
        } else {
            switch prominence {
            case .primary:
                self.buttonStyle(SWPrimaryGlassButtonStyle(tint: tint))
            case .secondary:
                self.buttonStyle(SWSecondaryGlassButtonStyle(tint: tint))
            }
        }
    }

    func shimmerSweep(duration: Double = 1.15, delay: Double = 1.5, cornerRadius: CGFloat = 22) -> some View {
        modifier(SWShimmerSweep(duration: duration, delay: delay, cornerRadius: cornerRadius))
    }
}

enum GlassButtonProminence {
    case primary
    case secondary
}

private struct GlassControlBackground: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    let tint: Color
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(tint.opacity(colorScheme == .dark ? 0.045 : 0.07))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(colorScheme == .dark ? 0.10 : 0.26), lineWidth: 0.8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(tint.opacity(colorScheme == .dark ? 0.13 : 0.18), lineWidth: 1)
            }
    }
}

func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}
