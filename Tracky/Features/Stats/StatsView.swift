import SwiftUI
import SwiftData

/// Personal records and how things are trending.
struct StatsView: View {

    @Environment(SettingsStore.self) private var settings
    @Query private var runs: [Run]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var vehicleFilter: UUID?
    @State private var trendModeID: String?

    private var scoped: [Run] {
        vehicleFilter == nil ? runs : runs.filter { $0.vehicle?.id == vehicleFilter }
    }

    private var summaries: [RunSummary] { scoped.summaries }
    private var stats: StatsSummary { PersonalBestCalculator.summary(from: summaries) }

    /// Modes with enough history to be worth charting.
    private var trendableModes: [(id: String, title: String)] {
        var seen: [String: String] = [:]
        for summary in summaries where summary.countsTowardsRecords {
            seen[summary.modeID] = summary.modeTitle
        }
        let counts = Dictionary(grouping: summaries.filter(\.countsTowardsRecords), by: \.modeID)
        return seen
            .filter { (counts[$0.key]?.count ?? 0) >= 2 }
            .map { (id: $0.key, title: $0.value) }
            .sorted { $0.title < $1.title }
    }

    private var activeTrendMode: String? {
        trendModeID ?? trendableModes.first?.id
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        if runs.isEmpty {
                            EmptyStateView(
                                symbolName: "chart.line.uptrend.xyaxis",
                                title: "No records yet",
                                message: "Records appear once you have saved a run or two."
                            )
                        } else {
                            vehicleChip
                            overview
                            accelerationSection
                            gForceSection
                            distanceSection
                            trendSection
                        }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Stats")
        }
    }

    // MARK: - Sections

    private var vehicleChip: some View {
        Menu {
            Button("All vehicles") { vehicleFilter = nil }
            ForEach(vehicles) { vehicle in
                Button(vehicle.name) { vehicleFilter = vehicle.id }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "car.fill")
                    .font(.system(size: 11, weight: .bold))
                Text(vehicles.first { $0.id == vehicleFilter }?.name ?? "All vehicles")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                Spacer(minLength: 0)
            }
            .foregroundStyle(Theme.Palette.textSecondary)
            .padding(.horizontal, 14)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                    )
            )
        }
    }

    private var overview: some View {
        TelemetryGrid(columns: 3) {
            TelemetryTile(
                label: "Runs",
                value: "\(stats.totalRuns)",
                unit: nil,
                valueSize: 22
            )
            TelemetryTile(
                label: "Distance",
                value: Format.grouped(settings.distanceUnit.longValue(fromMeters: stats.totalDistance)),
                unit: settings.distanceUnit.longSymbol,
                valueSize: 22
            )
            TelemetryTile(
                label: "Top Speed",
                value: Format.speed(stats.highestSpeed, unit: settings.speedUnit),
                unit: settings.speedUnit.symbol,
                valueSize: 22
            )
        }
    }

    private var accelerationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Acceleration", subtitle: "Personal bests")
            GlassCard {
                if accelerationBests.isEmpty {
                    Text("No acceleration records yet.")
                        .font(Theme.Typeface.body(13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(accelerationBests.enumerated()), id: \.element.id) { index, best in
                            if index > 0 { Divider().overlay(Theme.Palette.stroke) }
                            StatRow(
                                label: best.modeTitle,
                                value: "\(Format.time(best.duration)) s",
                                detail: detailText(for: best),
                                isHighlighted: true
                            )
                        }
                    }
                }
            }
        }
    }

    private var accelerationBests: [PersonalBest] {
        stats.bests.filter { !$0.isDistanceRun }
    }

    private var distanceBests: [PersonalBest] {
        stats.bests.filter(\.isDistanceRun)
    }

    private func detailText(for best: PersonalBest) -> String? {
        var parts: [String] = [Format.compactDate.string(from: best.date)]
        if let vehicle = best.vehicleName { parts.append(vehicle) }
        if let improvement = best.improvementOverPrevious, improvement > 0.004 {
            parts.append("\(Format.time(improvement)) s clear of second place")
        }
        return parts.joined(separator: " · ")
    }

    private var gForceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "G-Force", subtitle: "Peaks across every recorded run")
            GlassCard {
                VStack(spacing: 0) {
                    StatRow(
                        label: "Max acceleration",
                        value: Format.gForceWithUnit(stats.maxAccelerationG),
                        accent: Theme.Palette.gAccel
                    )
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(
                        label: "Max braking",
                        value: Format.gForceWithUnit(stats.maxBrakingG),
                        accent: Theme.Palette.gBrake
                    )
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(
                        label: "Max lateral",
                        value: Format.gForceWithUnit(stats.maxLateralG),
                        accent: Theme.Palette.gLateral
                    )
                }
            }
        }
    }

    private var distanceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Distance")
            GlassCard {
                VStack(spacing: 0) {
                    ForEach(distanceBests) { best in
                        StatRow(
                            label: best.modeTitle,
                            value: "\(Format.time(best.duration)) s",
                            detail: detailText(for: best),
                            isHighlighted: true
                        )
                        Divider().overlay(Theme.Palette.stroke)
                    }
                    StatRow(
                        label: "Total measured distance",
                        value: Format.longDistance(stats.totalDistance, unit: settings.distanceUnit)
                    )
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(label: "Total runs", value: "\(stats.totalRuns)")
                    Divider().overlay(Theme.Palette.stroke)
                    StatRow(
                        label: "Valid runs",
                        value: "\(stats.validRuns)",
                        detail: "Runs with a usable GPS signal"
                    )
                }
            }
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Trend", subtitle: "Green points set a record at the time") {
                if trendableModes.count > 1 {
                    Menu {
                        ForEach(trendableModes, id: \.id) { mode in
                            Button(mode.title) { trendModeID = mode.id }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(trendableModes.first { $0.id == activeTrendMode }?.title ?? "Pick")
                                .font(Theme.Typeface.label(11))
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                        }
                        .foregroundStyle(Theme.Palette.accent)
                    }
                }
            }
            GlassCard(padding: 14) {
                if let modeID = activeTrendMode {
                    TrendChartView(
                        points: PersonalBestCalculator.trend(for: modeID, in: summaries)
                    )
                } else {
                    Text("Record a couple of runs of the same type and the trend shows up here.")
                        .font(Theme.Typeface.body(13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }
}
