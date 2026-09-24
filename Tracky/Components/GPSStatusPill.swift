import SwiftUI

/// Compact signal indicator for the top of the Drive screen.
struct GPSStatusPill: View {
    enum State: Equatable {
        case notAuthorized
        case searching
        case ready(accuracy: Double, quality: GPSQuality)
        case simulated
    }

    let state: State

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.35), lineWidth: 5)
                        .scaleEffect(isPulsing ? 1.7 : 1)
                        .opacity(isPulsing ? 0 : 1)
                        .animation(
                            isPulsing
                                ? .easeOut(duration: 1.3).repeatForever(autoreverses: false)
                                : .default,
                            value: isPulsing
                        )
                )
            Text(title)
                .font(Theme.Typeface.label(11))
                .kerning(0.9)
                .foregroundStyle(Theme.Palette.textSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            Capsule().fill(Theme.Palette.surface)
                .overlay(Capsule().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
        )
    }

    private var isPulsing: Bool {
        if case .searching = state { return true }
        return false
    }

    private var title: String {
        switch state {
        case .notAuthorized: return "Location access needed"
        case .searching: return "Searching for GPS"
        case .simulated: return "Simulated data"
        case .ready(let accuracy, let quality):
            return "GPS \(quality.title.uppercased()) · \(Format.accuracy(accuracy))"
        }
    }

    private var tint: Color {
        switch state {
        case .notAuthorized: return Theme.Palette.danger
        case .searching: return Theme.Palette.warning
        case .simulated: return Theme.Palette.accentAlt
        case .ready(_, let quality): return Theme.Palette.quality(quality)
        }
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 10) {
            GPSStatusPill(state: .searching)
            GPSStatusPill(state: .ready(accuracy: 2.1, quality: .excellent))
            GPSStatusPill(state: .ready(accuracy: 18, quality: .fair))
            GPSStatusPill(state: .simulated)
            GPSStatusPill(state: .notAuthorized)
        }
    }
}
