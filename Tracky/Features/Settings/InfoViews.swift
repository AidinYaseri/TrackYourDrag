import SwiftUI

/// Plain-language explanation of what changes a result. Being upfront about this
/// is the difference between a measurement tool and a magic number generator.
struct AccuracyInfoView: View {
    var body: some View {
        InfoScreen(
            title: "Accuracy",
            intro: "Tracky is as good as the signal it is given. A phone is not a timing beam or a survey receiver, and Tracky will never pretend otherwise. Every saved run carries the signal quality it was recorded with.",
            sections: [
                .init(
                    symbol: "antenna.radiowaves.left.and.right",
                    title: "GPS reception",
                    body: "Open sky gives the best result. Tall buildings, tree cover, tunnels, bridges and underground car parks all bend or block the signal, and the receiver can report a confident-looking position that is several metres out."
                ),
                .init(
                    symbol: "iphone.gen3",
                    title: "The device",
                    body: "Receiver quality varies between iPhone models and generations. Two phones in the same car can disagree slightly, and neither is lying."
                ),
                .init(
                    symbol: "car.side",
                    title: "Mounting position",
                    body: "A phone flat on the dash with a clear view of the sky does better than one in a cupholder or a pocket. A rigid mount also stops the accelerometer picking up the phone rattling instead of the car moving."
                ),
                .init(
                    symbol: "road.lanes",
                    title: "Road and conditions",
                    body: "Surface, gradient, wind, altitude, air temperature, fuel load and tyre temperature all move a real result by more than most people expect. Compare runs from the same session on the same stretch."
                ),
                .init(
                    symbol: "globe",
                    title: "Satellite visibility",
                    body: "Accuracy depends on how many satellites are in view and how they are spread across the sky. It changes through the day, in the same place, for reasons nothing on your phone controls."
                ),
                .init(
                    symbol: "rotate.3d",
                    title: "Phone orientation",
                    body: "G-force is worked out in the car's frame using the device attitude and the GPS course, so the phone does not need to be aligned with the car. It does need to stay put during the run: if it shifts, the G reading shifts with it."
                )
            ]
        )
    }
}

/// How the numbers are actually produced. Written out because a performance
/// figure without a method behind it is just a claim.
struct MethodologyView: View {
    var body: some View {
        InfoScreen(
            title: "How Tracky measures",
            intro: "The short version: speed comes from GPS, timing comes from interpolating between GPS samples, and G-force comes from device motion resolved into the car's frame.",
            sections: [
                .init(
                    symbol: "speedometer",
                    title: "Speed",
                    body: "Core Location derives ground speed from Doppler shift, not from the gap between positions, which makes it far more precise than it looks. Tracky runs that speed through a Kalman filter that also takes acceleration from the accelerometer, so the value stays smooth between fixes without lagging behind the car."
                ),
                .init(
                    symbol: "timer",
                    title: "Timing",
                    body: "GPS arrives about ten times a second, so a car is almost never sampled at exactly 100 km/h or exactly 402 m. Tracky takes the two samples either side of the target and interpolates the instant the trace crossed it. A standing start is back-projected from the first two moving samples to estimate the moment the car actually left the line."
                ),
                .init(
                    symbol: "ruler",
                    title: "Distance",
                    body: "Distance is integrated from filtered speed rather than summed between positions. Consecutive fixes can wander several metres; over a twelve second quarter mile that noise would swamp the answer, while speed error stays a fraction of a metre per second."
                ),
                .init(
                    symbol: "arrow.up.and.down.and.arrow.left.and.right",
                    title: "G-force",
                    body: "Core Motion separates gravity from vehicle acceleration and solves the device attitude against true north. Rotating the acceleration by that attitude gives it in world terms, and projecting onto the GPS course splits it into longitudinal and lateral in the car's frame. If the attitude is not north-referenced, the longitudinal value falls back to differentiated GPS speed and the lateral value is flagged as an estimate."
                ),
                .init(
                    symbol: "mountain.2",
                    title: "Elevation",
                    body: "GPS altitude is stable over time but coarse; a barometer resolves centimetres of change but knows nothing about sea level and drifts with the weather. Tracky low-passes GPS altitude for the reference and adds the barometer's relative altitude on top, so short-term detail comes from the barometer and the long-term truth from GPS."
                ),
                .init(
                    symbol: "trash",
                    title: "What gets thrown away",
                    body: "Fixes worse than the accuracy limit are discarded, as are fixes implying an acceleration no car can produce, which is what a receiver reports when it re-acquires satellites after a bridge. Discarded fixes are counted and reported on the run."
                ),
                .init(
                    symbol: "flag.checkered",
                    title: "After the finish line",
                    body: "Recording carries on for a few seconds past the finish so the chart shows the car slowing and the braking and cornering peaks are real numbers. The time, distance and speeds are only ever taken from between the start and finish lines."
                )
            ]
        )
    }
}

/// Shared layout for the two explanation screens.
struct InfoScreen: View {
    struct Section: Identifiable {
        let symbol: String
        let title: String
        let body: String
        var id: String { title }
    }

    let title: String
    let intro: String
    let sections: [Section]

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(intro)
                        .font(Theme.Typeface.body(14))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    ForEach(sections) { section in
                        GlassCard {
                            HStack(alignment: .top, spacing: 13) {
                                Image(systemName: section.symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.Palette.accent)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(section.title)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Theme.Palette.textPrimary)
                                    Text(section.body)
                                        .font(Theme.Typeface.body(13))
                                        .foregroundStyle(Theme.Palette.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { MethodologyView() }
}
