import Foundation

/// One processed sample of a run.
///
/// This is a value type rather than a SwiftData `@Model`: a single run holds
/// hundreds to thousands of points, and storing them as one encoded blob on the
/// run (see `Run.telemetryBlob`) is dramatically faster to read back for charts
/// than materialising thousands of managed objects.
struct TelemetryPoint: Codable, Hashable, Identifiable {
    /// Seconds since the start of the recording.
    var t: TimeInterval
    /// Filtered ground speed, metres per second.
    var speed: Double
    /// Cumulative distance travelled since the start of the recording, metres.
    var distance: Double
    /// Filtered altitude, metres above sea level.
    var altitude: Double
    /// Acceleration along the direction of travel, in G. Positive = accelerating.
    var longitudinalG: Double
    /// Cornering acceleration, in G. Positive = turning right.
    var lateralG: Double
    /// Vertical acceleration, in G, gravity removed.
    var verticalG: Double
    var latitude: Double
    var longitude: Double
    /// Horizontal accuracy reported by Core Location, metres.
    var horizontalAccuracy: Double

    var id: TimeInterval { t }

    /// Magnitude of the combined longitudinal + lateral vector.
    var combinedG: Double {
        (longitudinalG * longitudinalG + lateralG * lateralG).squareRoot()
    }

    init(
        t: TimeInterval,
        speed: Double,
        distance: Double = 0,
        altitude: Double = 0,
        longitudinalG: Double = 0,
        lateralG: Double = 0,
        verticalG: Double = 0,
        latitude: Double = 0,
        longitude: Double = 0,
        horizontalAccuracy: Double = -1
    ) {
        self.t = t
        self.speed = speed
        self.distance = distance
        self.altitude = altitude
        self.longitudinalG = longitudinalG
        self.lateralG = lateralG
        self.verticalG = verticalG
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
    }

    /// Short keys keep the encoded blob small; a 20 second run at 10 Hz is
    /// ~200 points and this roughly halves the stored size.
    enum CodingKeys: String, CodingKey {
        case t
        case speed = "v"
        case distance = "d"
        case altitude = "a"
        case longitudinalG = "gl"
        case lateralG = "gt"
        case verticalG = "gv"
        case latitude = "lat"
        case longitude = "lon"
        case horizontalAccuracy = "acc"
    }
}

extension Array where Element == TelemetryPoint {
    /// Linear interpolation of speed at an arbitrary time inside the series.
    func speed(at time: TimeInterval) -> Double? {
        guard let first, let last else { return nil }
        if time <= first.t { return first.speed }
        if time >= last.t { return last.speed }
        for index in 1..<count {
            let previous = self[index - 1]
            let current = self[index]
            if current.t >= time {
                let span = current.t - previous.t
                guard span > 0 else { return current.speed }
                let ratio = (time - previous.t) / span
                return previous.speed + (current.speed - previous.speed) * ratio
            }
        }
        return last.speed
    }

    /// Evenly thins a series down to at most `limit` points.
    ///
    /// A 20 second run recorded at motion rate is around a thousand points,
    /// which a line chart cannot show any detail from anyway. Keeping the first
    /// and last point means the start line and the finish line never move.
    func downsampled(to limit: Int) -> [TelemetryPoint] {
        guard limit > 2, count > limit else { return self }
        let step = Double(count - 1) / Double(limit - 1)
        var result: [TelemetryPoint] = []
        result.reserveCapacity(limit)
        for index in 0..<limit {
            let position = Int((Double(index) * step).rounded())
            result.append(self[Swift.min(position, count - 1)])
        }
        return result
    }
}
