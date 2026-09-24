import Foundation

/// A GPS fix, stripped of Core Location so the core can be tested anywhere.
struct LocationSample: Equatable {
    /// Seconds on a monotonic clock (Core Location's timestamp converted once
    /// at the boundary).
    var timestamp: TimeInterval
    var latitude: Double
    var longitude: Double
    /// Metres above sea level as reported by the receiver.
    var altitude: Double
    /// Ground speed in m/s. Negative means the receiver has no valid speed.
    var speed: Double
    /// Course over ground in degrees clockwise from true north. Negative means
    /// unknown (typically when stationary).
    var course: Double
    /// Metres. Negative means the fix is invalid.
    var horizontalAccuracy: Double
    /// Metres. Negative means the altitude is unusable.
    var verticalAccuracy: Double
    /// Speed accuracy in m/s. Negative when unknown.
    var speedAccuracy: Double

    init(
        timestamp: TimeInterval,
        latitude: Double = 0,
        longitude: Double = 0,
        altitude: Double = 0,
        speed: Double,
        course: Double = -1,
        horizontalAccuracy: Double = 5,
        verticalAccuracy: Double = 8,
        speedAccuracy: Double = 0.4
    ) {
        self.timestamp = timestamp
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.speed = speed
        self.course = course
        self.horizontalAccuracy = horizontalAccuracy
        self.verticalAccuracy = verticalAccuracy
        self.speedAccuracy = speedAccuracy
    }

    var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    var hasValidFix: Bool { horizontalAccuracy >= 0 }
}

/// One device-motion update. Acceleration values are in G, matching
/// `CMDeviceMotion`.
struct MotionSample: Equatable {
    var timestamp: TimeInterval
    /// Acceleration caused by the user/vehicle, gravity already removed, in G.
    var userAcceleration: Vector3
    /// Gravity direction in the device frame, in G (points down, magnitude ~1).
    var gravity: Vector3
    /// Rotation rate in radians per second, device frame.
    var rotationRate: Vector3
    /// Attitude as a rotation from the device frame into the reference frame.
    var rotationMatrix: Matrix3?
    /// True when the reference frame's X axis points at north, which is what
    /// makes a full longitudinal/lateral split possible.
    var isNorthReferenced: Bool

    init(
        timestamp: TimeInterval,
        userAcceleration: Vector3 = .zero,
        gravity: Vector3 = Vector3(x: 0, y: 0, z: -1),
        rotationRate: Vector3 = .zero,
        rotationMatrix: Matrix3? = nil,
        isNorthReferenced: Bool = false
    ) {
        self.timestamp = timestamp
        self.userAcceleration = userAcceleration
        self.gravity = gravity
        self.rotationRate = rotationRate
        self.rotationMatrix = rotationMatrix
        self.isNorthReferenced = isNorthReferenced
    }
}

/// A fully processed instant of the drive: what the UI draws and what the
/// performance engine measures against.
struct TelemetrySample: Equatable {
    /// Seconds since the telemetry processor was started.
    var t: TimeInterval
    /// Filtered ground speed, m/s.
    var speed: Double
    /// Unfiltered GPS speed, m/s, kept for diagnostics and the chart's raw trace.
    var rawSpeed: Double
    /// Cumulative distance since the processor started, m.
    var distance: Double
    var altitude: Double
    var elevationSource: ElevationSource
    var gforce: GForceReading
    var coordinate: Coordinate?
    var horizontalAccuracy: Double
    var course: Double
    /// Longitudinal acceleration differentiated from GPS speed, m/s².
    var gpsAcceleration: Double
    /// True when this sample was produced by a fresh GPS fix rather than by a
    /// motion-only prediction between fixes.
    var isGPSUpdate: Bool

    init(
        t: TimeInterval,
        speed: Double,
        rawSpeed: Double = 0,
        distance: Double = 0,
        altitude: Double = 0,
        elevationSource: ElevationSource = .gps,
        gforce: GForceReading = GForceReading(),
        coordinate: Coordinate? = nil,
        horizontalAccuracy: Double = 5,
        course: Double = -1,
        gpsAcceleration: Double = 0,
        isGPSUpdate: Bool = true
    ) {
        self.t = t
        self.speed = speed
        self.rawSpeed = rawSpeed
        self.distance = distance
        self.altitude = altitude
        self.elevationSource = elevationSource
        self.gforce = gforce
        self.coordinate = coordinate
        self.horizontalAccuracy = horizontalAccuracy
        self.course = course
        self.gpsAcceleration = gpsAcceleration
        self.isGPSUpdate = isGPSUpdate
    }

    var quality: GPSQuality { GPSQuality.from(horizontalAccuracy: horizontalAccuracy) }

    var point: TelemetryPoint {
        TelemetryPoint(
            t: t,
            speed: speed,
            distance: distance,
            altitude: altitude,
            longitudinalG: gforce.longitudinal,
            lateralG: gforce.lateral,
            verticalG: gforce.vertical,
            latitude: coordinate?.latitude ?? 0,
            longitude: coordinate?.longitude ?? 0,
            horizontalAccuracy: horizontalAccuracy
        )
    }
}
