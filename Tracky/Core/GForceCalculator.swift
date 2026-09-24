import Foundation

/// Where a G reading came from, so the UI can be honest about it.
enum GForceSource: String, Codable {
    /// Full 3-axis solution: device motion resolved into the car's frame using
    /// a north-referenced attitude plus GPS course.
    case deviceMotion
    /// Attitude is vertical-referenced but not north-referenced, so the split
    /// between longitudinal and lateral comes from GPS acceleration.
    case deviceMotionAssisted
    /// No usable attitude: longitudinal only, differentiated from GPS speed.
    case gpsOnly
    case unavailable
}

struct GForceReading: Equatable {
    /// Along the direction of travel, in G. Positive accelerating, negative braking.
    var longitudinal: Double = 0
    /// Across the direction of travel, in G. Positive when turning right.
    var lateral: Double = 0
    /// Vertical, in G, with gravity already removed.
    var vertical: Double = 0
    var source: GForceSource = .unavailable

    /// Magnitude of the longitudinal + lateral vector, which is what a
    /// traction circle plots.
    var combined: Double {
        (longitudinal * longitudinal + lateral * lateral).squareRoot()
    }
}

/// Turns raw device motion into car-frame G-forces.
///
/// The hard part is that the phone is not bolted to the car in a known
/// orientation. The solution used here does not care how the phone is mounted:
///
/// 1. Core Motion already separates gravity from user acceleration, and with a
///    `xTrueNorthZVertical` reference frame it also gives an attitude that maps
///    the device frame onto a world frame whose Z axis is up and whose X axis
///    points at true north.
/// 2. Rotating the user acceleration by that attitude gives acceleration in
///    world terms — north, west and up — which is independent of the phone.
/// 3. GPS course says which way the car is pointing in that same world frame,
///    so projecting the world acceleration onto the direction of travel and
///    onto its perpendicular gives longitudinal and lateral G.
///
/// When the attitude is not north-referenced (no magnetometer, or the user
/// declined location) step 3 has no heading to work with, so the longitudinal
/// value falls back to differentiated GPS speed and the lateral value is
/// whatever horizontal acceleration is left over, signed by the yaw rate.
struct GForceCalculator {

    /// Below this ground speed the GPS course is mostly noise, so the car
    /// frame cannot be established and only vertical/aggregate values are used.
    var minimumSpeedForHeading: Double = 1.5

    /// Light smoothing to take out engine and road vibration without visibly
    /// lagging the meter.
    private var longitudinalFilter = LowPassFilter(timeConstant: 0.18)
    private var lateralFilter = LowPassFilter(timeConstant: 0.18)
    private var verticalFilter = LowPassFilter(timeConstant: 0.18)

    init() {}

    mutating func reset() {
        longitudinalFilter.reset()
        lateralFilter.reset()
        verticalFilter.reset()
    }

    /// - Parameters:
    ///   - motion: latest device motion, or nil when motion is unavailable.
    ///   - courseDegrees: GPS course over ground, clockwise from true north.
    ///     Negative means unknown.
    ///   - speed: current ground speed, m/s.
    ///   - gpsAcceleration: acceleration differentiated from GPS speed, m/s².
    ///   - dt: seconds since the previous reading.
    mutating func reading(
        motion: MotionSample?,
        courseDegrees: Double,
        speed: Double,
        gpsAcceleration: Double,
        dt: Double
    ) -> GForceReading {
        let gpsLongitudinal = gpsAcceleration / UnitConversion.standardGravity

        guard let motion else {
            // Simulator or motion denied: GPS is all there is.
            var reading = GForceReading()
            reading.longitudinal = longitudinalFilter.update(gpsLongitudinal, dt: dt)
            reading.lateral = lateralFilter.update(0, dt: dt)
            reading.vertical = verticalFilter.update(0, dt: dt)
            reading.source = .gpsOnly
            return reading
        }

        let raw = Self.resolve(
            motion: motion,
            courseDegrees: courseDegrees,
            speed: speed,
            gpsLongitudinalG: gpsLongitudinal,
            minimumSpeedForHeading: minimumSpeedForHeading
        )

        var reading = GForceReading()
        reading.longitudinal = longitudinalFilter.update(raw.longitudinal, dt: dt)
        reading.lateral = lateralFilter.update(raw.lateral, dt: dt)
        reading.vertical = verticalFilter.update(raw.vertical, dt: dt)
        reading.source = raw.source
        return reading
    }

    /// Unsmoothed resolution, exposed as a static function so it can be tested
    /// with hand-built vectors.
    static func resolve(
        motion: MotionSample,
        courseDegrees: Double,
        speed: Double,
        gpsLongitudinalG: Double,
        minimumSpeedForHeading: Double = 1.5
    ) -> GForceReading {
        var reading = GForceReading()
        let headingIsUsable = courseDegrees >= 0 && speed >= minimumSpeedForHeading

        if let matrix = motion.rotationMatrix, motion.isNorthReferenced, headingIsUsable {
            // World frame: x = true north, y = west, z = up.
            let world = matrix.rotate(motion.userAcceleration)
            let theta = GeoMath.radians(courseDegrees)
            let sinT = sin(theta)
            let cosT = cos(theta)

            // Direction of travel in (north, west): (cos θ, -sin θ).
            // To the car's right in (north, west): (-sin θ, -cos θ).
            reading.longitudinal = world.x * cosT + world.y * (-sinT)
            reading.lateral = world.x * (-sinT) + world.y * (-cosT)
            reading.vertical = world.z
            reading.source = .deviceMotion
            return reading
        }

        // No usable heading, but gravity still tells us which way is up, so the
        // vertical axis and the total horizontal magnitude are still valid.
        let up = (motion.gravity * -1).normalized
        let accel = motion.userAcceleration
        let vertical = up.magnitude > 0 ? accel.dot(up) : 0
        let horizontalVector = up.magnitude > 0 ? accel - up * vertical : accel
        let horizontalMagnitude = horizontalVector.magnitude

        reading.vertical = vertical

        if speed >= minimumSpeedForHeading {
            // Trust GPS for the longitudinal split and attribute whatever
            // horizontal acceleration is left to cornering.
            let longitudinal = gpsLongitudinalG
            let clamped = min(abs(longitudinal), horizontalMagnitude)
            let lateralMagnitude = (horizontalMagnitude * horizontalMagnitude - clamped * clamped)
                .clampedToZero
                .squareRoot()
            // Yaw rate about the vertical axis: positive is a left turn under
            // the right-hand rule, so a right turn is a positive lateral G.
            let yawRate = up.magnitude > 0 ? motion.rotationRate.dot(up) : 0
            reading.longitudinal = longitudinal
            reading.lateral = yawRate < 0 ? lateralMagnitude : -lateralMagnitude
            reading.source = .deviceMotionAssisted
        } else {
            reading.longitudinal = gpsLongitudinalG
            reading.lateral = 0
            reading.source = .deviceMotionAssisted
        }
        return reading
    }
}

private extension Double {
    /// Guards against tiny negative values from floating point error before a
    /// square root.
    var clampedToZero: Double { self < 0 ? 0 : self }
}

/// Running maxima over a run or a whole session.
struct GForceAccumulator {
    private(set) var maxAcceleration: Double = 0
    /// Stored as a negative number, the way a telemetry display shows braking.
    private(set) var maxBraking: Double = 0
    private(set) var maxLateral: Double = 0
    private(set) var maxCombined: Double = 0

    init() {}

    mutating func reset() {
        maxAcceleration = 0
        maxBraking = 0
        maxLateral = 0
        maxCombined = 0
    }

    mutating func ingest(_ reading: GForceReading) {
        if reading.longitudinal > maxAcceleration { maxAcceleration = reading.longitudinal }
        if reading.longitudinal < maxBraking { maxBraking = reading.longitudinal }
        if abs(reading.lateral) > abs(maxLateral) { maxLateral = reading.lateral }
        if reading.combined > maxCombined { maxCombined = reading.combined }
    }
}
