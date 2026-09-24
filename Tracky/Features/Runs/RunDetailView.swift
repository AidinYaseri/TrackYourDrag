import SwiftUI
import SwiftData

/// The complete record of one run.
struct RunDetailView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    let run: Run

    @State private var chartKind: TelemetryChartKind = .speedOverTime
    @State private var showsDeleteConfirmation = false
    @State private var share: SharePayload?

    private var telemetry: [TelemetryPoint] { run.telemetry }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 16) {
                    hero
                    statsGrid
                    if !run.splits.isEmpty { splitsCard }
                    chartCard
                    elevationCard
                    if run.hasRoute { mapCard }
                    qualityCard
                    exportCard
                    dangerZone
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle(run.modeTitle)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this run?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete run", role: .destructive) {
                RunStore(context: context).delete(run)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $share) { payload in
            ShareSheet(payload: payload)
        }
    }

    // MARK: - Export

    private var exportCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Export")
            GlassCard {
                VStack(spacing: 0) {
                    exportRow(
                        title: "Share summary card",
                        detail: "A single image with the result, the speed trace and the headline numbers",
                        symbol: "square.and.arrow.up"
                    ) {
                        var items: [Any] = []
                        if let image = ExportService.shareCardImage(
                            for: run,
                            speedUnit: settings.speedUnit,
                            distanceUnit: settings.distanceUnit
                        ) {
                            items.append(image)
                        }
                        items.append("Tracky · \(run.modeTitle) in \(Format.time(run.duration)) s")
                        share = SharePayload(items: items)
                    }

                    Divider().overlay(Theme.Palette.stroke)

                    exportRow(
                        title: "Export telemetry (CSV)",
                        detail: run.storesRoute
                            ? "Every sample, including coordinates"
                            : "Every sample. This run has no location data.",
                        symbol: "tablecells"
                    ) {
                        if let url = ExportService.telemetryFile(
                            for: run,
                            speedUnit: settings.speedUnit,
                            distanceUnit: settings.distanceUnit
                        ) {
                            share = SharePayload(items: [url])
                        }
                    }
                }
            }
        }
    }

    private func exportRow(
        title: String,
        detail: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            Haptics.fire(.light)
            action()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.Palette.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typeface.body(15))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(detail)
                        .font(Theme.Typeface.body(12))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(minHeight: Theme.Metrics.touchTarget)
        }
    }

    // MARK: - Sections

    private var hero: some View {
        VStack(spacing: 8) {
            MicroLabel(text: run.modeTitle, color: Theme.Palette.textSecondary, size: 13)
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(Format.time(run.duration))
                    .font(Theme.Typeface.readout(70))
                    .foregroundStyle(Theme.Palette.textPrimary)
                MicroLabel(text: "sec", color: Theme.Palette.textSecondary, size: 14)
            }
            HStack(spacing: 8) {
                Text(Format.runDateTime.string(from: run.date))
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textTertiary)
                if let vehicle = run.vehicle {
                    Text("·").foregroundStyle(Theme.Palette.textTertiary)
                    Text(vehicle.name)
                        .font(Theme.Typeface.body(13))
                        .foregroundStyle(Color(hexString: vehicle.colorHex))
                }
            }
        }
        .padding(.vertical, 6)
    }

    private var statsGrid: some View {
        TelemetryGrid {
            TelemetryTile(
                label: "Max Speed",
                value: Format.speed(run.maxSpeed, unit: settings.speedUnit),
                unit: settings.speedUnit.symbol
            )
            TelemetryTile(
                label: run.isDistanceRun ? "Trap Speed" : "Avg Accel",
                value: run.isDistanceRun
                    ? Format.speed(run.endSpeed, unit: settings.speedUnit)
                    : Format.gForce(run.averageAcceleration / UnitConversion.standardGravity),
                unit: run.isDistanceRun ? settings.speedUnit.symbol : "G"
            )
            TelemetryTile(
                label: "Max Accel G",
                value: Format.gForce(run.maxAccelerationG),
                unit: "G",
                accent: Theme.Palette.gAccel
            )
            TelemetryTile(
                label: "Max Braking G",
                value: Format.gForce(run.maxBrakingG),
                unit: "G",
                accent: Theme.Palette.gBrake
            )
            TelemetryTile(
                label: "Max Lateral G",
                value: Format.gForce(run.maxLateralG),
                unit: "G",
                accent: Theme.Palette.gLateral
            )
            TelemetryTile(
                label: "Distance",
                value: Format.shortDistance(run.distance, unit: settings.distanceUnit),
                unit: nil
            )
        }
    }

    private var splitsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Splits")
            GlassCard {
                VStack(spacing: 0) {
                    ForEach(Array(run.splits.enumerated()), id: \.element.id) { index, split in
                        if index > 0 { Divider().overlay(Theme.Palette.stroke) }
                        StatRow(
                            label: split.label,
                            value: "\(Format.time(split.time)) s",
                            detail: split.speed.map {
                                "at \(Format.speedWithUnit($0, unit: settings.speedUnit))"
                            }
                        )
                    }
                }
            }
        }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Telemetry", subtitle: "Swipe between graphs")
            GlassCard(padding: 12) {
                TabView(selection: $chartKind) {
                    ForEach(TelemetryChartKind.allCases) { kind in
                        TelemetryChartView(
                            points: telemetry,
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
                .frame(height: 228)
            }
        }
    }

    private var elevationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Elevation", subtitle: run.elevationSource.description)
            GlassCard {
                VStack(spacing: 0) {
                    StatRow(
                        label: "Change over the run",
                        value: Format.signedElevation(run.elevationChange, unit: settings.distanceUnit)
                    )
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(
                        label: "Start",
                        value: Format.elevation(run.startAltitude, unit: settings.distanceUnit)
                    )
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(
                        label: "Highest",
                        value: Format.elevation(run.maxAltitude, unit: settings.distanceUnit)
                    )
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(
                        label: "Lowest",
                        value: Format.elevation(run.minAltitude, unit: settings.distanceUnit)
                    )
                }
            }
        }
    }

    private var mapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Route", subtitle: "Coloured by speed") {
                NavigationLink {
                    RunMapScreen(run: run)
                } label: {
                    Text("Expand")
                        .font(Theme.Typeface.label(11))
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            RunMapView(run: run, isInteractive: false, speedUnit: settings.speedUnit)
                .frame(height: 190)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                        .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                )
        }
    }

    private var qualityCard: some View {
        GlassCard(highlight: run.quality < .good ? Theme.Palette.warning : nil) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    MicroLabel(text: "GPS Quality")
                    Spacer()
                    QualityBadge(quality: run.quality)
                }
                Text(run.quality.detail)
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(run.warnings, id: \.self) { warning in
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

                HStack(spacing: 16) {
                    small("Average", Format.accuracy(run.averageAccuracy))
                    small("Best", Format.accuracy(run.bestAccuracy))
                    small("Worst", Format.accuracy(run.worstAccuracy))
                    small("Rate", String(format: "%.1f Hz", run.sampleRate))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func small(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(text: label, size: 9)
            Text(value)
                .font(Theme.Typeface.body(12))
                .foregroundStyle(Theme.Palette.textSecondary)
        }
    }

    private var dangerZone: some View {
        VStack(spacing: 10) {
            if run.hasRoute {
                Button {
                    RunStore(context: context).stripLocationData(from: [run])
                    Haptics.fire(.warning)
                } label: {
                    Label("Remove location data from this run", systemImage: "location.slash")
                        .font(Theme.Typeface.body(14))
                        .foregroundStyle(Theme.Palette.warning)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                                .fill(Theme.Palette.warning.opacity(0.1))
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }

            PrimaryActionButton(title: "Delete Run", symbolName: "trash", style: .danger) {
                showsDeleteConfirmation = true
            }
        }
        .padding(.top, 4)
    }
}
