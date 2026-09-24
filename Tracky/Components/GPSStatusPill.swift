import SwiftUI

/// Compact signal indicator for the top of the Drive screen.
///
/// The nested type is called `Status` rather than `State` on purpose: a nested
/// `State` would shadow SwiftUI's property wrapper inside this view.
struct GPSStatusPill: View {

    enum Status: Equatable {
        case notAuthorized
        case searching
        case ready(accuracy: Double, quality: GPSQuality)
        case simulated
    }

    let status: Status

    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
                .overlay(
                    Circle()
                        .stroke(tint.opacity(0.4), lineWidth: 4)
                        .scaleEffect(isPulsing ? 2.1 : 1)
                        .opacity(isPulsing ? 0 : 1)
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
        .animation(
            .easeOut(duration: 1.3).repeatForever(autoreverses: false),
            value: isPulsing
        )
        .onAppear { isPulsing = shouldPulse }
        .onChange(of: shouldPulse) { _, newValue in
            isPulsing = newValue
        }
    }

    /// Only the searching state animates; a steady signal should be steady.
    private var shouldPulse: Bool {
        if case .searching = status { return true }
        return false
    }

    private var title: String {
        switch status {
        case .notAuthorized: return "Location access needed"
        case .searching: return "Searching for GPS"
        case .simulated: return "Simulated data"
        case .ready(let accuracy, let quality):
            return "GPS \(quality.title.uppercased()) · \(Format.accuracy(accuracy))"
        }
    }

    private var tint: Color {
        switch status {
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
            GPSStatusPill(status: .searching)
            GPSStatusPill(status: .ready(accuracy: 2.1, quality: .excellent))
            GPSStatusPill(status: .ready(accuracy: 18, quality: .fair))
            GPSStatusPill(status: .simulated)
            GPSStatusPill(status: .notAuthorized)
        }
    }
}
