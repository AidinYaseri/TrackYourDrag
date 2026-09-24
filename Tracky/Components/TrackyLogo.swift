import SwiftUI

/// The Tracky mark: a speedometer sweep wrapped around a "T" whose stem leans
/// like a racing line and runs out through the open bottom of the gauge.
///
/// Drawn with shapes rather than an image so it scales to any size, and shared
/// by the app icon, the wordmark and the share card.
struct TrackyMark: View {
    /// Stroke width of the sweep, as a fraction of the mark's side.
    var lineWidthRatio: CGFloat = 0.092
    var tint: LinearGradient = Theme.Gradients.accent

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)

            ZStack {
                // 270 degrees of speedometer sweep, open at the bottom. The
                // trim starts at 3 o'clock, so rotating by 135 degrees puts the
                // opening symmetrically below the mark.
                Circle()
                    .trim(from: 0, to: 0.75)
                    .rotation(.degrees(135))
                    .stroke(tint, style: StrokeStyle(lineWidth: side * lineWidthRatio, lineCap: .round))
                    .frame(width: side * 0.92, height: side * 0.92)

                TrackyTShape()
                    .fill(tint)
                    .frame(width: side, height: side)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The "T". The crossbar is level; the stem leans right and runs out through
/// the open bottom of the sweep, so the letter reads as a line taken through a
/// corner. Proportions match `Tools/generate_app_icon.py` exactly, so the app
/// icon and the in-app mark are the same drawing.
struct TrackyTShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let originX = rect.minX
        let originY = rect.minY
        var path = Path()

        path.addRoundedRect(
            in: CGRect(
                x: originX + width * 0.225,
                y: originY + height * 0.235,
                width: width * 0.550,
                height: height * 0.120
            ),
            cornerSize: CGSize(width: width * 0.030, height: width * 0.030)
        )

        path.move(to: CGPoint(x: originX + width * 0.443, y: originY + height * 0.355))
        path.addLine(to: CGPoint(x: originX + width * 0.557, y: originY + height * 0.355))
        path.addLine(to: CGPoint(x: originX + width * 0.645, y: originY + height * 1.000))
        path.addLine(to: CGPoint(x: originX + width * 0.530, y: originY + height * 1.000))
        path.closeSubpath()

        return path
    }
}

/// Mark plus wordmark, used on the launch header and the share card.
struct TrackyWordmark: View {
    var size: CGFloat = 22
    var showsTagline = false

    var body: some View {
        HStack(spacing: size * 0.42) {
            TrackyMark()
                .frame(width: size * 1.25, height: size * 1.25)
            VStack(alignment: .leading, spacing: 1) {
                Text("TRACKY")
                    .font(.system(size: size, weight: .heavy, design: .rounded))
                    .kerning(size * 0.14)
                    .foregroundStyle(Theme.Palette.textPrimary)
                if showsTagline {
                    Text("Measure Your Drive.")
                        .font(Theme.Typeface.body(size * 0.48))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
        }
    }
}

#Preview {
    ZStack {
        ScreenBackground()
        VStack(spacing: 30) {
            TrackyMark().frame(width: 140, height: 140)
            TrackyWordmark(size: 26, showsTagline: true)
        }
    }
}
