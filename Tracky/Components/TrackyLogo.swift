import SwiftUI

/// The Tracky mark: a speedometer sweep wrapped around a "T" whose stem leans
/// like a racing line, with the needle tip doubling as a location pin dot.
///
/// Drawn with shapes rather than an image so it scales to any size and is used
/// for the app icon, the wordmark and the share card.
struct TrackyMark: View {
    var lineWidthRatio: CGFloat = 0.085
    var tint: LinearGradient = Theme.Gradients.accent

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let stroke = side * lineWidthRatio

            ZStack {
                // Speedometer sweep, open at the bottom.
                Circle()
                    .trim(from: 0.07, to: 0.43)
                    .rotation(.degrees(126))
                    .stroke(tint, style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .frame(width: side * 0.92, height: side * 0.92)

                // Needle dot at the top of the sweep.
                Circle()
                    .fill(tint)
                    .frame(width: stroke * 1.15, height: stroke * 1.15)
                    .offset(x: side * 0.33, y: -side * 0.20)

                TrackyTShape()
                    .fill(tint)
                    .frame(width: side * 0.62, height: side * 0.62)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

/// The "T". The crossbar is level; the stem leans right so the whole letter
/// reads as a line through a corner.
struct TrackyTShape: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        var path = Path()

        // Crossbar.
        path.addRoundedRect(
            in: CGRect(x: width * 0.10, y: height * 0.18, width: width * 0.80, height: height * 0.175),
            cornerSize: CGSize(width: width * 0.06, height: width * 0.06)
        )

        // Slanted stem.
        path.move(to: CGPoint(x: width * 0.40, y: height * 0.33))
        path.addLine(to: CGPoint(x: width * 0.585, y: height * 0.33))
        path.addLine(to: CGPoint(x: width * 0.66, y: height * 0.90))
        path.addLine(to: CGPoint(x: width * 0.475, y: height * 0.90))
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
