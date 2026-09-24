import SwiftUI

/// The shareable summary card. Rendered to an image by `ExportService`, so it is
/// laid out at a fixed size and never depends on the device it came from.
struct ShareCardView: View {

    let run: Run
    let speedUnit: SpeedUnit
    let distanceUnit: DistanceUnit

    static let size = CGSize(width: 1080, height: 1350)
    /// Design is laid out at 1x and scaled up when rendered.
    static let designSize = CGSize(width: 360, height: 450)

    var body: some View {
        ZStack {
            Theme.Palette.base
            RadialGradient(
                colors: [Theme.Palette.accent.opacity(0.22), .clear],
                center: .init(x: 0.5, y: 0.02),
                startRadius: 0,
                endRadius: 320
            )

            VStack(spacing: 0) {
                HStack {
                    TrackyWordmark(size: 16)
                    Spacer()
                    QualityBadge(quality: run.quality, compact: true)
                }

                Spacer(minLength: 10)

                VStack(spacing: 4) {
                    MicroLabel(text: run.modeTitle, color: Theme.Palette.accent, size: 13)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Format.time(run.duration))
                            .font(Theme.Typeface.readout(88))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        MicroLabel(text: "sec", color: Theme.Palette.textSecondary, size: 15)
                    }
                }

                Spacer(minLength: 10)

                TelemetryChartView(
                    points: run.telemetry,
                    kind: .speedOverTime,
                    speedUnit: speedUnit,
                    distanceUnit: distanceUnit,
                    height: 96
                )
                .padding(.bottom, 12)

                HStack(spacing: 0) {
                    cell("Max Speed", Format.speed(run.maxSpeed, unit: speedUnit), speedUnit.symbol)
                    divider
                    cell("Max G", Format.gForce(run.maxAccelerationG), "G")
                    divider
                    cell("Distance", Format.shortDistance(run.distance, unit: distanceUnit), nil)
                }
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.Palette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                        )
                )

                Spacer(minLength: 12)

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        MicroLabel(text: "Date", size: 9)
                        Text(Format.runDate.string(from: run.date))
                            .font(Theme.Typeface.body(12))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }
                    Spacer()
                    if let vehicle = run.vehicle {
                        VStack(alignment: .trailing, spacing: 2) {
                            MicroLabel(text: "Vehicle", size: 9)
                            Text(vehicle.name)
                                .font(Theme.Typeface.body(12))
                                .foregroundStyle(Color(hexString: vehicle.colorHex))
                        }
                    }
                }

                Text("Measure Your Drive.")
                    .font(Theme.Typeface.label(10))
                    .kerning(1.4)
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .padding(.top, 14)
            }
            .padding(22)
        }
        .frame(width: Self.designSize.width, height: Self.designSize.height)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.Palette.stroke)
            .frame(width: 1, height: 34)
    }

    private func cell(_ label: String, _ value: String, _ unit: String?) -> some View {
        VStack(spacing: 5) {
            MicroLabel(text: label, size: 9)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value)
                    .font(Theme.Typeface.value(24))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let unit {
                    Text(unit)
                        .font(Theme.Typeface.label(9))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}
