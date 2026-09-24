import SwiftUI

/// "0 — 100 KM/H · 87 / 100" with a progress rail underneath.
struct RunProgressView: View {
    let title: String
    let currentText: String
    let targetText: String
    let unitText: String
    let fraction: Double
    var tint: Color = Theme.Palette.accent

    var body: some View {
        VStack(spacing: 10) {
            MicroLabel(text: title, color: Theme.Palette.textSecondary, size: 13)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(currentText)
                    .font(Theme.Typeface.value(32))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                Text("/")
                    .font(Theme.Typeface.value(22))
                    .foregroundStyle(Theme.Palette.textTertiary)
                Text(targetText)
                    .font(Theme.Typeface.value(22))
                    .foregroundStyle(Theme.Palette.textSecondary)
                Text(unitText.uppercased())
                    .font(Theme.Typeface.label(11))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }

            ProgressRail(fraction: fraction, tint: tint)
        }
    }
}

/// Thin animated progress bar.
struct ProgressRail: View {
    let fraction: Double
    var tint: Color = Theme.Palette.accent
    var height: CGFloat = 8

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.Palette.surfaceRaised)
                Capsule()
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.75), tint],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: max(0, min(1, fraction)) * proxy.size.width)
                    .shadow(color: tint.opacity(0.5), radius: 6)
            }
        }
        .frame(height: height)
        .animation(Theme.Motion.telemetry, value: fraction)
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        RunProgressView(
            title: "0 – 100 km/h",
            currentText: "87",
            targetText: "100",
            unitText: "km/h",
            fraction: 0.87
        )
        .padding()
    }
}
