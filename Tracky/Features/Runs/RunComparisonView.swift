import SwiftUI

/// Two runs side by side, with the speed curves overlaid.
///
/// Works across vehicles and dates on purpose: comparing the same car before
/// and after a change is the interesting case, but so is comparing two cars.
struct RunComparisonView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let runA: Run
    let runB: Run

    @State private var chartKind: TelemetryChartKind = .speedOverTime

    /// Negative means A was quicker.
    private var delta: TimeInterval { runA.duration - runB.duration }
    private var comparable: Bool { runA.modeID == runB.modeID }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        verdict
                        columns
                        chart
                        if !comparable { mismatchNote }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
        }
    }

    private var verdict: some View {
        VStack(spacing: 6) {
            MicroLabel(
                text: delta < 0 ? "Run A is quicker" : (delta > 0 ? "Run B is quicker" : "Dead heat"),
                color: Theme.Palette.textSecondary,
                size: 12
            )
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(Format.time(abs(delta)))
                    .font(Theme.Typeface.readout(62))
                    .foregroundStyle(delta == 0 ? Theme.Palette.textPrimary : Theme.Palette.accent)
                MicroLabel(text: "sec", color: Theme.Palette.textSecondary, size: 14)
            }
            if runA.duration > 0 && runB.duration > 0 {
                Text(String(
                    format: "%.1f%% difference",
                    abs(delta) / max(runA.duration, runB.duration) * 100
                ))
                .font(Theme.Typeface.body(12))
                .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
        .padding(.vertical, 6)
    }

    private var columns: some View {
        HStack(alignment: .top, spacing: 12) {
            column(label: "Run A", run: runA, tint: Theme.Palette.accent, isWinner: delta < 0)
            column(label: "Run B", run: runB, tint: Theme.Palette.accentAlt, isWinner: delta > 0)
        }
    }

    private func column(label: String, run: Run, tint: Color, isWinner: Bool) -> some View {
        GlassCard(padding: 14, highlight: isWinner ? tint : nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(tint).frame(width: 7, height: 7)
                    MicroLabel(text: label, color: tint, size: 10)
                }
                Text(run.modeTitle)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.textPrimary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(Format.time(run.duration))
                        .font(Theme.Typeface.value(28))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text("s")
                        .font(Theme.Typeface.label(10))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                Divider().overlay(Theme.Palette.stroke)
                row("Max speed", Format.speedWithUnit(run.maxSpeed, unit: settings.speedUnit))
                row("Max accel", Format.gForceWithUnit(run.maxAccelerationG))
                row("Distance", Format.shortDistance(run.distance, unit: settings.distanceUnit))
                row("Elevation", Format.signedElevation(run.elevationChange, unit: settings.distanceUnit))
                row("Quality", run.quality.title)
                row("Vehicle", run.vehicle?.name ?? "Not set")
                row("Date", Format.compactDate.string(from: run.date))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            MicroLabel(text: label, size: 8)
            Text(value)
                .font(Theme.Typeface.body(12))
                .foregroundStyle(Theme.Palette.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var chart: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Overlay") {
                Picker("Chart", selection: $chartKind) {
                    ForEach(TelemetryChartKind.allCases) { kind in
                        Text(kind.shortTitle).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
            }
            GlassCard(padding: 12) {
                TelemetryChartView(
                    points: runA.telemetry,
                    kind: chartKind,
                    speedUnit: settings.speedUnit,
                    distanceUnit: settings.distanceUnit,
                    primaryLabel: "Run A",
                    comparisonPoints: runB.telemetry,
                    comparisonLabel: "Run B",
                    height: 210
                )
            }
        }
    }

    private var mismatchNote: some View {
        GlassCard(highlight: Theme.Palette.warning) {
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Palette.warning)
                Text("These runs measured different things (\(runA.modeTitle) and \(runB.modeTitle)), so the time difference is not a like-for-like result. The speed curves are still worth a look.")
                    .font(Theme.Typeface.body(12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
