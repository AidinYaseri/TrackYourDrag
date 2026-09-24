import SwiftUI
import Charts

/// "Am I getting quicker?" — every valid run for one mode, in order, with the
/// runs that set a record at the time picked out.
struct TrendChartView: View {
    let points: [TrendPoint]
    var height: CGFloat = 150

    private var best: Double { points.map(\.duration).min() ?? 0 }

    var body: some View {
        if points.count < 2 {
            Text("Record at least two runs of this type to see a trend.")
                .font(Theme.Typeface.body(13))
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
        } else {
            Chart {
                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Time", point.duration)
                    )
                    .foregroundStyle(Theme.Palette.accent)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.2, lineCap: .round))

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Time", point.duration)
                    )
                    .foregroundStyle(point.isRecord ? Theme.Palette.positive : Theme.Palette.accent)
                    .symbolSize(point.isRecord ? 70 : 28)
                }

                RuleMark(y: .value("Best", best))
                    .foregroundStyle(Theme.Palette.positive.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Best \(Format.time(best)) s")
                            .font(Theme.Typeface.label(9))
                            .foregroundStyle(Theme.Palette.positive)
                    }
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 4)) { value in
                    AxisGridLine().foregroundStyle(Theme.Palette.stroke.opacity(0.5))
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(Format.compactDate.string(from: date))
                                .font(Theme.Typeface.label(9))
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks { value in
                    AxisGridLine().foregroundStyle(Theme.Palette.stroke.opacity(0.5))
                    AxisValueLabel {
                        Text(Format.time(value.as(Double.self) ?? 0, decimals: 1))
                            .font(Theme.Typeface.label(9))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
            }
            .frame(height: height)
        }
    }
}
