import SwiftUI

/// GPS quality chip shown on run results and history cards.
struct QualityBadge: View {
    let quality: GPSQuality
    var compact = false

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.system(size: compact ? 9 : 10, weight: .bold))
            Text(quality.title.uppercased())
                .font(Theme.Typeface.label(compact ? 9 : 10))
                .kerning(0.8)
        }
        .foregroundStyle(Theme.Palette.quality(quality))
        .padding(.horizontal, compact ? 7 : 9)
        .padding(.vertical, compact ? 3 : 5)
        .background(
            Capsule().fill(Theme.Palette.quality(quality).opacity(0.13))
        )
    }

    private var symbolName: String {
        switch quality {
        case .excellent: return "antenna.radiowaves.left.and.right"
        case .good: return "antenna.radiowaves.left.and.right"
        case .fair: return "exclamationmark.triangle.fill"
        case .poor: return "exclamationmark.triangle.fill"
        }
    }
}

/// Small "PB" flag on record-setting runs.
struct RecordBadge: View {
    var text = "Personal Best"

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 9, weight: .bold))
            Text(text.uppercased())
                .font(Theme.Typeface.label(9))
                .kerning(0.8)
        }
        .foregroundStyle(Theme.Palette.base)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Theme.Gradients.accent))
    }
}

/// Selectable chip used by the run mode picker.
struct ModeChip: View {
    let title: String
    var subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: {
            Haptics.fire(.light)
            action()
        }) {
            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                if let subtitle {
                    Text(subtitle.uppercased())
                        .font(Theme.Typeface.label(9))
                        .kerning(0.6)
                        .opacity(0.75)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: Theme.Metrics.touchTarget)
            .padding(.horizontal, 10)
            .foregroundStyle(isSelected ? Theme.Palette.base : Theme.Palette.textPrimary)
            .background {
                RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.Gradients.accent) : AnyShapeStyle(Theme.Palette.surface))
            }
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                    .strokeBorder(isSelected ? Color.clear : Theme.Palette.stroke, lineWidth: 1)
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Shown when a list has nothing in it yet.
struct EmptyStateView: View {
    let symbolName: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Theme.Palette.textTertiary)
            Text(title)
                .font(Theme.Typeface.title(18))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text(message)
                .font(Theme.Typeface.body(14))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 44)
        .padding(.horizontal, 24)
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 14) {
            HStack {
                QualityBadge(quality: .excellent)
                QualityBadge(quality: .fair)
                RecordBadge()
            }
            HStack {
                ModeChip(title: "0–100", subtitle: "km/h", isSelected: true) {}
                ModeChip(title: "1/4", subtitle: "mile", isSelected: false) {}
            }
            EmptyStateView(
                symbolName: "flag.checkered",
                title: "No runs yet",
                message: "Arm a run on the Drive tab and Tracky will record it here."
            )
        }
        .padding()
    }
}
