import SwiftUI

/// One row in the history list.
struct RunCardView: View {
    let run: Run
    let speedUnit: SpeedUnit
    let distanceUnit: DistanceUnit
    var isRecord = false
    var isSelected = false
    var selectionEnabled = false

    var body: some View {
        GlassCard(padding: 14, highlight: isSelected ? Theme.Palette.accent : nil) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(run.vehicle.map { Color(hexString: $0.colorHex) } ?? Theme.Palette.stroke)
                    .frame(width: 4, height: 46)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 7) {
                        Text(run.modeTitle)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        if isRecord { RecordBadge(text: "PB") }
                    }
                    HStack(spacing: 8) {
                        Text(Format.runDate.string(from: run.date))
                            .font(Theme.Typeface.body(12))
                            .foregroundStyle(Theme.Palette.textTertiary)
                        if let vehicle = run.vehicle {
                            Text("·").foregroundStyle(Theme.Palette.textTertiary)
                            Text(vehicle.name)
                                .font(Theme.Typeface.body(12))
                                .foregroundStyle(Theme.Palette.textTertiary)
                                .lineLimit(1)
                        }
                    }
                    HStack(spacing: 10) {
                        metric(Format.gForceWithUnit(run.maxAccelerationG), "bolt.fill")
                        metric(Format.speedWithUnit(run.maxSpeed, unit: speedUnit), "speedometer")
                        if run.isDistanceRun {
                            metric(Format.shortDistance(run.distance, unit: distanceUnit), "ruler")
                        }
                    }
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 3) {
                        Text(Format.time(run.duration))
                            .font(Theme.Typeface.value(26))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("s")
                            .font(Theme.Typeface.label(11))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    QualityBadge(quality: run.quality, compact: true)
                }

                if selectionEnabled {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Theme.Palette.accent : Theme.Palette.stroke)
                }
            }
        }
    }

    private func metric(_ text: String, _ symbol: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol)
                .font(.system(size: 8, weight: .bold))
            Text(text)
                .font(Theme.Typeface.label(10))
        }
        .foregroundStyle(Theme.Palette.textSecondary)
    }
}
