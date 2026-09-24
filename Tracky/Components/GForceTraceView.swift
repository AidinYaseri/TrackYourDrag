import SwiftUI

/// Live strip chart of G over the last few seconds, drawn with Canvas so it can
/// redraw many times a second without building a view tree each frame.
struct GForceTraceView: View {
    var trace: [GTracePoint]
    /// Seconds shown across the full width.
    var window: TimeInterval = 6
    /// G value at the top and bottom edges.
    var scale: Double = 1.5

    var body: some View {
        Canvas { context, size in
            let midY = size.height / 2

            // Zero line plus half-G guides.
            for level in [-1.0, -0.5, 0.0, 0.5, 1.0] {
                let y = midY - CGFloat(level / scale) * midY
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(
                    path,
                    with: .color(level == 0 ? Theme.Palette.strokeStrong : Theme.Palette.stroke.opacity(0.6)),
                    lineWidth: level == 0 ? 1 : 0.5
                )
            }

            guard let last = trace.last, trace.count > 1 else { return }
            let start = last.t - window

            func point(_ t: TimeInterval, _ value: Double) -> CGPoint {
                let x = CGFloat((t - start) / window) * size.width
                let clamped = max(-scale, min(scale, value))
                return CGPoint(x: x, y: midY - CGFloat(clamped / scale) * midY)
            }

            func line(_ keyPath: KeyPath<GTracePoint, Double>) -> Path {
                var path = Path()
                var started = false
                for sample in trace where sample.t >= start {
                    let position = point(sample.t, sample[keyPath: keyPath])
                    if started {
                        path.addLine(to: position)
                    } else {
                        path.move(to: position)
                        started = true
                    }
                }
                return path
            }

            context.stroke(
                line(\.lateral),
                with: .color(Theme.Palette.gLateral.opacity(0.75)),
                style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
            )
            context.stroke(
                line(\.longitudinal),
                with: .color(Theme.Palette.accent),
                style: StrokeStyle(lineWidth: 2.2, lineCap: .round)
            )
        }
        .drawingGroup()
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        GForceTraceView(
            trace: (0..<120).map {
                GTracePoint(
                    t: Double($0) * 0.05,
                    longitudinal: 0.8 * sin(Double($0) / 20),
                    lateral: 0.5 * cos(Double($0) / 13),
                    combined: 0.9
                )
            }
        )
        .frame(height: 90)
        .padding()
    }
}
