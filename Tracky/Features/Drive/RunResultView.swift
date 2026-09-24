import SwiftUI

/// The payoff screen. One big time, the numbers behind it, swipeable graphs,
/// and an honest note about signal quality.
struct RunResultView: View {

    @Environment(SettingsStore.self) private var settings

    let result: PerformanceResult
    let mode: RunMode
    let vehicle: Vehicle?
    let existingRuns: [RunSummary]
    let onSave: (PerformanceResult) -> Void
    let onDiscard: () -> Void
    let onRunAgain: () -> Void

    @State private var chartKind: TelemetryChartKind = .speedOverTime
    @State private var hasAppeared = false

    private var isPersonalBest: Bool {
        PersonalBestCalculator.isPersonalBest(
            result.makeSummary(category: mode.category, vehicle: vehicle),
            among: existingRuns
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    statsGrid
                    if !result.splits.isEmpty { splitsCard }
                    chartCard
                    qualityCard
                }
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.top, 10)
                .padding(.bottom, 16)
            }
            actions
                .padding(.horizontal, Theme.Metrics.screenPadding)
                .padding(.bottom, 6)
        }
        .onAppear {
            withAnimation(Theme.Motion.stage.delay(0.05)) { hasAppeared = true }
        }
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            if isPersonalBest {
                RecordBadge()
                    .scaleEffect(hasAppeared ? 1 : 0.6)
                    .opacity(hasAppeared ? 1 : 0)
            }
            MicroLabel(text: result.modeTitle, color: Theme.Palette.textSecondary, size: 13)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(Format.time(result.duration))
                    .font(Theme.Typeface.readout(78))
                    .foregroundStyle(Theme.Palette.textPrimary)
                MicroLabel(text: "sec", color: Theme.Palette.textSecondary, size: 15)
            }
            .scaleEffect(hasAppeared ? 1 : 0.9)

            if let vehicle {
                Text(vehicle.name)
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Numbers

    private var statsGrid: some View {
        TelemetryGrid {
            TelemetryTile(
                label: "Max Speed",
                value: Format.speed(result.maxSpeed, unit: settings.speedUnit),
                unit: settings.speedUnit.symbol
            )
            TelemetryTile(
                label: result.trapSpeed != nil ? "Trap Speed" : "Avg Accel",
                value: result.trapSpeed != nil
                    ? Format.speed(result.endSpeed, unit: settings.speedUnit)
                    : Format.gForce(result.averageAccelerationG),
                unit: result.trapSpeed != nil ? settings.speedUnit.symbol : "G"
            )
            TelemetryTile(
                label: "Max Accel G",
                value: Format.gForce(result.maxAccelerationG),
                unit: "G",
                accent: Theme.Palette.gAccel
            )
            TelemetryTile(
                label: "Max Braking G",
                value: Format.gForce(result.maxBrakingG),
                unit: "G",
                accent: Theme.Palette.gBrake
            )
            TelemetryTile(
                label: "Max Lateral G",
                value: Format.gForce(result.maxLateralG),
                unit: "G",
                accent: Theme.Palette.gLateral
            )
            TelemetryTile(
                label: "Distance",
                value: Format.shortDistance(result.distance, unit: settings.distanceUnit),
                unit: nil
            )
            TelemetryTile(
                label: "Elevation",
                value: Format.signedElevation(result.elevation.change, unit: settings.distanceUnit),
                unit: nil,
                accent: result.elevation.change >= 0 ? Theme.Palette.textPrimary : Theme.Palette.warning
            )
            TelemetryTile(
                label: "GPS Accuracy",
                value: Format.accuracy(result.accuracy.average),
                unit: nil,
                accent: Theme.Palette.quality(result.quality)
            )
        }
    }

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Splits")
            GlassCard {
                VStack(spacing: 0) {
                    ForEach(Array(result.splits.enumerated()), id: \.element.id) { index, split in
                        if index > 0 {
                            Divider().overlay(Theme.Palette.stroke)
                        }
                        StatRow(
                            label: split.label,
                            value: "\(Format.time(split.time)) s",
                            detail: splitDetail(split)
                        )
                    }
                }
            }
        }
    }

    private func splitDetail(_ split: Split) -> String? {
        if let speed = split.speed, split.distance != nil {
            return "at \(Format.speedWithUnit(speed, unit: settings.speedUnit))"
        }
        if let distance = split.distance {
            return "after \(Format.shortDistance(distance, unit: settings.distanceUnit))"
        }
        return nil
    }

    // MARK: - Graphs

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Telemetry", subtitle: "Swipe between graphs")
            GlassCard(padding: 12) {
                VStack(spacing: 8) {
                    TabView(selection: $chartKind) {
                        ForEach(TelemetryChartKind.allCases) { kind in
                            TelemetryChartView(
                                points: result.samples,
                                kind: kind,
                                speedUnit: settings.speedUnit,
                                distanceUnit: settings.distanceUnit,
                                primaryLabel: kind.title,
                                height: 190
                            )
                            .padding(.bottom, 26)
                            .tag(kind)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: 226)

                    Text(chartKind.title)
                        .font(Theme.Typeface.label(11))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
    }

    // MARK: - Quality

    private var qualityCard: some View {
        GlassCard(highlight: result.quality < .good ? Theme.Palette.warning : nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MicroLabel(text: "GPS Quality")
                    Spacer()
                    QualityBadge(quality: result.quality)
                }
                Text(result.quality.detail)
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                if !result.warnings.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(result.warnings, id: \.self) { warning in
                            HStack(alignment: .top, spacing: 7) {
                                Image(systemName: "exclamationmark.circle")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Theme.Palette.warning)
                                    .padding(.top, 2)
                                Text(warning)
                                    .font(Theme.Typeface.body(12))
                                    .foregroundStyle(Theme.Palette.textTertiary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                HStack(spacing: 14) {
                    detail("Fixes", "\(result.accuracy.sampleCount)")
                    detail("Rate", String(format: "%.1f Hz", result.accuracy.sampleRate))
                    detail("Elevation", result.elevation.source.description)
                }
                .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detail(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(text: label, size: 9)
            Text(value)
                .font(Theme.Typeface.body(12))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            PrimaryActionButton(title: "Save Run", symbolName: "square.and.arrow.down") {
                onSave(result)
            }
            HStack(spacing: 10) {
                Button {
                    Haptics.fire(.light)
                    onDiscard()
                } label: {
                    Text("DISCARD")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(Theme.Palette.danger)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                                .fill(Theme.Palette.danger.opacity(0.1))
                        )
                }
                .buttonStyle(PressableButtonStyle())

                Button {
                    Haptics.fire(.medium)
                    onRunAgain()
                } label: {
                    Text("RUN AGAIN")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .kerning(1.2)
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                                .fill(Theme.Palette.surfaceRaised)
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
    }
}
