import SwiftUI
import MapKit

/// The route a run took, with the line coloured by speed.
///
/// Routes are only ever stored locally and only when the user leaves route
/// recording on. Nothing here shares a location anywhere.
struct RunMapView: View {

    let run: Run
    var isInteractive = true
    var speedUnit: SpeedUnit = .kmh

    @State private var position: MapCameraPosition = .automatic

    private struct Segment: Identifiable {
        let id: Int
        let coordinates: [CLLocationCoordinate2D]
        let color: Color
    }

    var body: some View {
        Group {
            if run.hasRoute, !segments.isEmpty {
                map
            } else {
                placeholder
            }
        }
    }

    private var map: some View {
        Map(position: $position, interactionModes: isInteractive ? .all : []) {
            ForEach(segments) { segment in
                MapPolyline(coordinates: segment.coordinates)
                    .stroke(segment.color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
            if let start = coordinates.first {
                Annotation("Start", coordinate: start) {
                    marker(symbol: "flag.fill", color: Theme.Palette.positive)
                }
            }
            if let finish = coordinates.last {
                Annotation("Finish", coordinate: finish) {
                    marker(symbol: "flag.checkered", color: Theme.Palette.danger)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
        .onAppear {
            if let region { position = .region(region) }
        }
    }

    private func marker(symbol: String, color: Color) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(Theme.Palette.base)
            .padding(7)
            .background(Circle().fill(color))
            .overlay(Circle().strokeBorder(Color.white.opacity(0.8), lineWidth: 1.5))
    }

    private var placeholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "map")
                .font(.system(size: 24, weight: .light))
            Text(run.storesRoute ? "No route recorded for this run." : "Location data was removed from this run.")
                .font(Theme.Typeface.body(13))
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(Theme.Palette.textTertiary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    // MARK: - Route shaping

    private var points: [TelemetryPoint] {
        run.telemetry.filter { $0.latitude != 0 || $0.longitude != 0 }
    }

    private var coordinates: [CLLocationCoordinate2D] {
        points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    /// The line is split into short pieces so each piece can take the colour of
    /// the speed at that point: a single polyline cannot carry a gradient.
    private var segments: [Segment] {
        let source = points.downsampled(to: 240)
        guard source.count > 1 else { return [] }
        let maxSpeed = max(source.map(\.speed).max() ?? 1, 1)
        let chunk = 6
        var result: [Segment] = []
        var index = 0
        while index < source.count - 1 {
            let upper = min(index + chunk, source.count - 1)
            let slice = Array(source[index...upper])
            let average = slice.map(\.speed).reduce(0, +) / Double(slice.count)
            result.append(
                Segment(
                    id: index,
                    coordinates: slice.map {
                        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
                    },
                    color: color(forFraction: average / maxSpeed)
                )
            )
            index = upper
        }
        return result
    }

    /// Slow is cool-toned, fast is hot, which reads instantly on a map.
    private func color(forFraction fraction: Double) -> Color {
        let clamped = min(max(fraction, 0), 1)
        switch clamped {
        case ..<0.35: return Theme.Palette.accentAlt
        case ..<0.6: return Theme.Palette.accent
        case ..<0.85: return Theme.Palette.positive
        default: return Theme.Palette.warning
        }
    }

    private var region: MKCoordinateRegion? {
        guard !coordinates.isEmpty else { return nil }
        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        guard let minLat = latitudes.min(), let maxLat = latitudes.max(),
              let minLon = longitudes.min(), let maxLon = longitudes.max() else { return nil }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        // A little padding, and a floor so a short run is not zoomed to the kerb.
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.0035),
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.0035)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

/// Full-screen version, reached from a run's detail screen.
struct RunMapScreen: View {
    let run: Run
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        ZStack(alignment: .bottom) {
            RunMapView(run: run, isInteractive: true, speedUnit: settings.speedUnit)
                .ignoresSafeArea(edges: .bottom)

            GlassCard(padding: 14) {
                HStack(spacing: 18) {
                    legend("Slow", Theme.Palette.accentAlt)
                    legend("", Theme.Palette.accent)
                    legend("", Theme.Palette.positive)
                    legend("Fast", Theme.Palette.warning)
                    Spacer(minLength: 0)
                    Text(Format.adaptiveDistance(run.distance, unit: settings.distanceUnit))
                        .font(Theme.Typeface.value(16))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
        .navigationTitle("Route")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func legend(_ label: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 22, height: 4)
            if !label.isEmpty {
                MicroLabel(text: label, size: 8)
            }
        }
    }
}
