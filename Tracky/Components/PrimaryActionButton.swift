import SwiftUI

/// Full-width action button. Everything primary in Tracky uses this so the
/// target is always big enough to hit without looking.
struct PrimaryActionButton: View {
    enum Style {
        case accent
        case danger
        case neutral
    }

    let title: String
    var subtitle: String?
    var symbolName: String?
    var style: Style = .accent
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.fire(.medium)
            action()
        }) {
            VStack(spacing: 2) {
                HStack(spacing: 10) {
                    if let symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text(title.uppercased())
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .kerning(1.6)
                }
                if let subtitle {
                    Text(subtitle)
                        .font(Theme.Typeface.body(12))
                        .opacity(0.75)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.touchTarget + 4)
            .foregroundStyle(foreground)
            .background {
                RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius + 4, style: .continuous)
                    .fill(background)
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius + 4, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled)
    }

    private var foreground: Color {
        switch style {
        case .accent: return Theme.Palette.base
        case .danger: return Theme.Palette.danger
        case .neutral: return Theme.Palette.textPrimary
        }
    }

    private var background: AnyShapeStyle {
        switch style {
        case .accent: return AnyShapeStyle(Theme.Gradients.accent)
        case .danger: return AnyShapeStyle(Theme.Palette.danger.opacity(0.12))
        case .neutral: return AnyShapeStyle(Theme.Palette.surfaceRaised)
        }
    }

    private var borderColor: Color {
        switch style {
        case .accent: return .clear
        case .danger: return Theme.Palette.danger.opacity(0.5)
        case .neutral: return Theme.Palette.stroke
        }
    }
}

/// Subtle press feedback, used everywhere instead of the default highlight.
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 12) {
            PrimaryActionButton(title: "Start Run", symbolName: "bolt.fill") {}
            PrimaryActionButton(title: "Cancel", style: .danger) {}
            PrimaryActionButton(title: "Discard", style: .neutral) {}
        }
        .padding()
    }
}
