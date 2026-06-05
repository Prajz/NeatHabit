import SwiftUI
import UIKit

enum AppFont {
    static func body(size: CGFloat = 15, weight: Font.Weight = .regular) -> Font {
        .custom(postScriptName(for: weight), size: size, relativeTo: .body)
    }

    static func display(size: CGFloat, weight: Font.Weight = .black) -> Font {
        .custom(postScriptName(for: weight), size: size, relativeTo: .largeTitle)
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
    static let ink = dynamic(light: (0.070, 0.080, 0.105), dark: (0.90, 0.92, 0.96))
    static let muted = dynamic(light: (0.36, 0.39, 0.46), dark: (0.64, 0.68, 0.76))
    static let canvas = dynamic(light: (0.955, 0.965, 0.98), dark: (0.050, 0.056, 0.070))
    static let surface = dynamic(light: (0.985, 0.99, 1.0), dark: (0.095, 0.105, 0.13)).opacity(0.88)
    static let cardFill = dynamic(light: (0.992, 0.995, 1.0), dark: (0.070, 0.078, 0.098))
    static let hairline = dynamic(light: (0.82, 0.86, 0.92), dark: (0.20, 0.23, 0.29))
    static let cardShadow = dynamic(light: (0.08, 0.11, 0.18), dark: (0.0, 0.0, 0.0))
    static let accent = Color(red: 0.16, green: 0.38, blue: 0.86)
    static let glassBlue = Color(red: 0.38, green: 0.43, blue: 0.56)
    static let green = Color(red: 0.20, green: 0.58, blue: 0.34)
    static let amber = Color(red: 0.78, green: 0.49, blue: 0.16)
    static let red = Color(red: 0.72, green: 0.25, blue: 0.24)

    private static func dynamic(light: (Double, Double, Double), dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let values = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: values.0, green: values.1, blue: values.2, alpha: 1)
        })
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            Theme.canvas

            LinearGradient(
                colors: [
                    .white.opacity(0.26),
                    .clear,
                    Theme.accent.opacity(0.06)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Theme.accent.opacity(0.16), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

struct LiquidGlassCard<Content: View>: View {
    let tint: Color
    let content: Content

    init(tint: Color = Theme.accent, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Theme.cardFill.opacity(0.92))
                    .overlay {
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                tint.opacity(0.08),
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
                    .strokeBorder(.white.opacity(0.24), lineWidth: 0.7)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .strokeBorder(tint.opacity(0.20), lineWidth: 1)
            }
            .shadow(color: Theme.cardShadow.opacity(0.13), radius: 22, x: 0, y: 14)
    }
}

struct SectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.black))
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
                .font(.headline.weight(.black))
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
                    .font(.caption2.weight(.bold))
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
            .font(.caption.weight(.black))
            .tracking(1.1)
            .foregroundStyle(color)
            .textCase(.uppercase)
    }
}

extension View {
    func glassControlBackground(tint: Color = Theme.accent, cornerRadius: CGFloat = 20) -> some View {
        self
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.surface)
                    .overlay(tint.opacity(0.07))
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(0.26), lineWidth: 0.8)
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(tint.opacity(0.18), lineWidth: 1)
            }
    }
}

func percent(_ fraction: Double) -> String {
    "\(Int((fraction * 100).rounded()))%"
}
