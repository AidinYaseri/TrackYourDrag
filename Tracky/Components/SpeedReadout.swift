import SwiftUI

/// The dominant number on the Drive and Running screens.
struct SpeedReadout: View {
    let speed: Double
    let unit: SpeedUnit
    var size: CGFloat = 116
    var showsUnit = true
    var tint: Color = Theme.Palette.textPrimary

    var body: some View {
        VStack(spacing: 2) {
            Text(Format.speed(speed, unit: unit))
                .readoutStyle(size: size, color: tint)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                // The animation is on the value so the digits roll rather than
                // snap, without animating layout.
                .animation(Theme.Motion.telemetry, value: Int(unit.value(fromMetersPerSecond: speed).rounded()))
            if showsUnit {
                MicroLabel(text: unit.symbol, color: Theme.Palette.textSecondary, size: 13)
            }
        }
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        SpeedReadout(speed: 24.2, unit: .kmh)
    }
}
