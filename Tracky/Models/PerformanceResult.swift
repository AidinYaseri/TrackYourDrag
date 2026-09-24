import Foundation

/// A plain latitude/longitude pair so the core stays free of Core Location.
struct Coordinate: Codable, Hashable {
    var latitude: Double
    var longitude: Double
}

/// An intermediate marker recorded on the way to the finish, e.g. the 60 ft
/// time on a quarter mile or the 0–60 km/h split inside a 0–200 km/h run.
struct Split: Codable, Hashable, Identifiable {
    var label: String
    var time: TimeInterval
    /// Speed at the marker, m/s. Set for distance markers (trap speed).
    var speed: Double?
    /// Distance at the marker, m. Set for speed markers.
    var distance: Double?

    var id: String { label }
}

enum ElevationSource: String, Codable {
    case gps
    case barometer
    case fused

    var description: String {
        switch self {
        case .gps: return "GPS altitude"
        case .barometer: return "Barometer"
        case .fused: return "GPS + barometer"
        }
    }
}

struct ElevationSummary: Codable, Hashable {
    var start: Double = 0
    var end: Double = 0
    var minimum: Double = 0
    var maximum: Double = 0
    var source: ElevationSource = .gps

    var change: Double { end - start }
}

struct AccuracySummary: Codable, Hashable {
    var average: Double = -1
    var best: Double = -1
    var worst: Double = -1
    var sampleCount: Int = 0
    /// Samples per second actually received during the measured window.
    var sampleRate: Double = 0
}

/// Everything the engine worked out about one completed measurement.
///
/// This is the hand-off between the pure performance core and the rest of the
/// app: the UI renders it, and `RunStore` maps it onto a persisted `Run`.
struct PerformanceResult: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var modeID: String
    var modeTitle: String
    var target: RunTarget

    /// Measured time between the start and finish conditions.
    var duration: TimeInterval
    /// Distance covered between start and finish, metres.
    var distance: Double
    var startSpeed: Double
    var endSpeed: Double
    var maxSpeed: Double

    var maxAccelerationG: Double = 0
    var maxBrakingG: Double = 0
    var maxLateralG: Double = 0
    var maxCombinedG: Double = 0

    var elevation = ElevationSummary()
    var accuracy = AccuracySummary()
    var quality: GPSQuality = .good
    var isValid = true
    var warnings: [String] = []
    var splits: [Split] = []

    var startCoordinate: Coordinate?
    var endCoordinate: Coordinate?

    /// The measured window plus a short lead-in, so charts show the launch.
    var samples: [TelemetryPoint] = []

    /// Mean acceleration over the measured window, m/s².
    var averageAcceleration: Double {
        guard duration > 0 else { return 0 }
        return (endSpeed - startSpeed) / duration
    }

    /// Mean acceleration expressed in G.
    var averageAccelerationG: Double {
        averageAcceleration / UnitConversion.standardGravity
    }

    /// Speed at the finish line, which for a distance run is the trap speed.
    var trapSpeed: Double? {
        if case .distance = target { return endSpeed }
        return nil
    }

    var isDistanceTarget: Bool {
        if case .distance = target { return true }
        return false
    }
}
