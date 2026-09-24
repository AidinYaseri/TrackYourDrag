import SwiftUI
import Charts

enum TelemetryChartKind: String, CaseIterable, Identifiable {
    case speedOverTime
    case gOverTime
    case speedOverDistance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speedOverTime: return "Speed"
        case .gOverTime: return "G-Force"
        case .speedOverDistance: return "Speed / Distance"
        }
    }

    var shortTitle: String {
        switch self {
        case .speedOverTime: return "Speed"
        case .gOverTime: return "G"
        case .speedOverDistance: return "Distance"
        }
    }
}

/// One plotted value, flattened so two runs can be drawn on the same chart.
private struct ChartPoint: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let series: String
}

/// Charts for a finished run: speed against time, G against time, and speed
/// against distance. Also used to overlay two runs in the comparison screen.
struct TelemetryChartView: View {
    let points: [TelemetryPoint]
    let kind: TelemetryChartKind
    let speedUnit: SpeedUnit
    let distanceUnit: DistanceUnit
    var primaryLabel = "Run"
    var comparisonPoints: [TelemetryPoint] = []
    var comparisonLabel = "Run B"
    var height: CGFloat = 200

    var body: some View {
        Chart {
            switch kind {
            case .speedOverTime, .speedOverDistance:
                speedMarks
            case .gOverTime:
                gMarks
            }
        }
        .chartForegroundStyleScale(colorScale)
        .chartLegend(comparisonPoints.isEmpty && kind != .gOverTime ? .hidden : .visible)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Theme.Palette.stroke.opacity(0.5))
                AxisValueLabel {
                    Text(xLabel(for: value.as(Double.self) ?? 0))
                        .font(Theme.Typeface.label(9))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine().foregroundStyle(Theme.Palette.stroke.opacity(0.5))
                AxisValueLabel {
                    Text(yLabel(for: value.as(Double.self) ?? 0))
                        .font(Theme.Typeface.label(9))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
        .frame(height: height)
    }

    // MARK: - Marks

    @ChartContentBuilder
    private var speedMarks: some ChartContent {
        ForEach(series(for: points, label: primaryLabel)) { point in
            LineMark(
                x: .value("x", point.x),
                y: .value("Speed", point.y),
                series: .value("Run", point.series)
            )
            .foregroundStyle(by: .value("Run", point.series))
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
        }
        if comparisonPoints.isEmpty {
            ForEach(series(for: points, label: primaryLabel)) { point in
                AreaMark(x: .value("x", point.x), y: .value("Speed", point.y))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Theme.Palette.accent.opacity(0.35), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.monotone)
            }
        } else {
            ForEach(series(for: comparisonPoints, label: comparisonLabel)) { point in
                LineMark(
                    x: .value("x", point.x),
                    y: .value("Speed", point.y),
                    series: .value("Run", point.series)
                )
                .foregroundStyle(by: .value("Run", point.series))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 2.4, lineCap: .round))
            }
        }
    }

    @ChartContentBuilder
    private var gMarks: some ChartContent {
        ForEach(gSeries(for: points, suffix: comparisonPoints.isEmpty ? "" : " A")) { point in
            LineMark(
                x: .value("Time", point.x),
                y: .value("G", point.y),
                series: .value("Run", point.series)
            )
            .foregroundStyle(by: .value("Run", point.series))
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
        }
        if !comparisonPoints.isEmpty {
            ForEach(gSeries(for: comparisonPoints, suffix: " B")) { point in
                LineMark(
                    x: .value("Time", point.x),
                    y: .value("G", point.y),
                    series: .value("Run", point.series)
                )
                .foregroundStyle(by: .value("Run", point.series))
                .interpolationMethod(.monotone)
                .lineStyle(StrokeStyle(lineWidth: 1.6, lineCap: .round))
            }
        }
    }

    // MARK: - Data shaping

    private func series(for source: [TelemetryPoint], label: String) -> [ChartPoint] {
        let sampled = source.downsampled(to: 320)
        return sampled.map { point in
            ChartPoint(
                x: kind == .speedOverDistance
                    ? distanceUnit.shortValue(fromMeters: max(0, point.distance))
                    : point.t,
                y: speedUnit.value(fromMetersPerSecond: point.speed),
                series: label
            )
        }
    }

    private func gSeries(for source: [TelemetryPoint], suffix: String) -> [ChartPoint] {
        let sampled = source.downsampled(to: 320)
        var result: [ChartPoint] = []
        for point in sampled {
            result.append(ChartPoint(x: point.t, y: point.longitudinalG, series: "Longitudinal" + suffix))
            result.append(ChartPoint(x: point.t, y: point.lateralG, series: "Lateral" + suffix))
        }
        return result
    }

    private var colorScale: KeyValuePairs<String, Color> {
        switch kind {
        case .gOverTime:
            return [
                "Longitudinal": Theme.Palette.accent,
                "Lateral": Theme.Palette.gLateral,
                "Longitudinal A": Theme.Palette.accent,
                "Lateral A": Theme.Palette.gLateral,
                "Longitudinal B": Theme.Palette.accentAlt,
                "Lateral B": Theme.Palette.warning
            ]
        default:
            return [
                primaryLabel: Theme.Palette.accent,
                comparisonLabel: Theme.Palette.accentAlt
            ]
        }
    }

    private func xLabel(for value: Double) -> String {
        kind == .speedOverDistance
            ? "\(Int(value))"
            : Format.time(value, decimals: value < 10 ? 1 : 0)
    }

    private func yLabel(for value: Double) -> String {
        kind == .gOverTime ? Format.gForce(value, decimals: 1) : "\(Int(value))"
    }
}
