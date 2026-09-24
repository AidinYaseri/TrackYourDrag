import SwiftUI

/// Small card showing one live number: label on top, value underneath.
struct TelemetryTile: View {
    let label: String
    let value: String
    var unit: String?
    var accent: Color = Theme.Palette.textPrimary
    var symbolName: String?
    var valueSize: CGFloat = 24

    var body: some View {
        GlassCard(cornerRadius: Theme.Metrics.tileRadius, padding: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    if let symbolName {
                        Image(systemName: symbolName)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    MicroLabel(text: label)
                    Spacer(minLength: 0)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(Theme.Typeface.value(valueSize))
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                    if let unit {
                        Text(unit)
                            .font(Theme.Typeface.label(11))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Two-column grid of telemetry tiles.
struct TelemetryGrid<Content: View>: View {
    var columns: Int = 2
    @ViewBuilder var content: () -> Content

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: Theme.Metrics.tileSpacing),
                count: columns
            ),
            spacing: Theme.Metrics.tileSpacing
        ) {
            content()
        }
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        TelemetryGrid {
            TelemetryTile(label: "G-Force", value: "0.82", unit: "G", accent: Theme.Palette.gAccel)
            TelemetryTile(label: "Elevation", value: "42", unit: "m")
            TelemetryTile(label: "Distance", value: "0.00", unit: "km")
            TelemetryTile(label: "GPS Accuracy", value: "±2 m", accent: Theme.Palette.positive)
        }
        .padding()
    }
}
