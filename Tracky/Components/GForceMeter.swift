import SwiftUI

/// Circular traction-circle meter, the way a motorsport telemetry display shows
/// combined grip.
///
/// The dot is placed in the direction the car is being accelerated: up under
/// power, down under braking, right through a right-hand corner. A short fading
/// tail shows where it has just been.
struct GForceMeter: View {
    var reading: GForceReading
    /// G value at the outer ring.
    var scale: Double = 1.5
    var trace: [GTracePoint] = []
    var showsLabels = true

    private let rings: [Double] = [0.5, 1.0, 1.5]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let radius = side / 2
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)

            ZStack {
                grid(radius: radius)
                tail(center: center, radius: radius)
                dot(center: center, radius: radius)
                if showsLabels { labels(radius: radius) }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Pieces

    private func grid(radius: CGFloat) -> some View {
        ZStack {
            ForEach(rings, id: \.self) { ring in
                let fraction = min(1, ring / scale)
                Circle()
                    .strokeBorder(
                        ring == rings.last ? Theme.Palette.strokeStrong : Theme.Palette.stroke,
                        lineWidth: ring == rings.last ? 1.4 : 1
                    )
                    .frame(width: radius * 2 * fraction, height: radius * 2 * fraction)
            }
            Rectangle()
                .fill(Theme.Palette.stroke)
                .frame(width: radius * 2, height: 1)
            Rectangle()
                .fill(Theme.Palette.stroke)
                .frame(width: 1, height: radius * 2)
        }
    }

    private func position(longitudinal: Double, lateral: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        var x = lateral / scale
        var y = -longitudinal / scale
        let magnitude = (x * x + y * y).squareRoot()
        // Keep the dot inside the outer ring when the car exceeds the scale.
        if magnitude > 1 {
            x /= magnitude
            y /= magnitude
        }
        return CGPoint(x: center.x + x * radius, y: center.y + y * radius)
    }

    private func tail(center: CGPoint, radius: CGFloat) -> some View {
        Canvas { context, _ in
            guard trace.count > 1 else { return }
            let recent = trace.suffix(40)
            var previous: CGPoint?
            for (index, point) in recent.enumerated() {
                let position = position(
                    longitudinal: point.longitudinal,
                    lateral: point.lateral,
                    center: center,
                    radius: radius
                )
                if let previous {
                    var path = Path()
                    path.move(to: previous)
                    path.addLine(to: position)
                    let opacity = Double(index) / Double(recent.count) * 0.55
                    context.stroke(
                        path,
                        with: .color(Theme.Palette.accent.opacity(opacity)),
                        lineWidth: 2
                    )
                }
                previous = position
            }
        }
    }

    private func dot(center: CGPoint, radius: CGFloat) -> some View {
        let point = position(
            longitudinal: reading.longitudinal,
            lateral: reading.lateral,
            center: center,
            radius: radius
        )
        return Circle()
            .fill(dotColor)
            .frame(width: 18, height: 18)
            .shadow(color: dotColor.opacity(0.7), radius: 8)
            .overlay(Circle().strokeBorder(Color.white.opacity(0.75), lineWidth: 1.5))
            .position(point)
            .animation(Theme.Motion.telemetry, value: point)
    }

    private var dotColor: Color {
        if reading.longitudinal < -0.08 { return Theme.Palette.gBrake }
        if abs(reading.lateral) > abs(reading.longitudinal) { return Theme.Palette.gLateral }
        return Theme.Palette.gAccel
    }

    private func labels(radius: CGFloat) -> some View {
        let text = "\(Format.gForce(scale, decimals: 1))G"
        return ZStack {
            MicroLabel(text: "+\(text)", size: 9).offset(y: -radius + 12)
            MicroLabel(text: "-\(text)", size: 9).offset(y: radius - 12)
            MicroLabel(text: text, size: 9).offset(x: radius - 16)
            MicroLabel(text: text, size: 9).offset(x: -radius + 16)
        }
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        GForceMeter(
            reading: GForceReading(longitudinal: 0.62, lateral: -0.34, vertical: 0.02, source: .deviceMotion),
            trace: (0..<30).map {
                GTracePoint(
                    t: Double($0) * 0.05,
                    longitudinal: 0.6 * sin(Double($0) / 9),
                    lateral: 0.4 * cos(Double($0) / 7),
                    combined: 0.6
                )
            }
        )
        .frame(width: 240, height: 240)
    }
}
