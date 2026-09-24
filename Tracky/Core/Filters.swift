import Foundation

/// First-order low-pass filter with a time constant expressed in seconds, so
/// the amount of smoothing does not change when the sample rate changes.
struct LowPassFilter {
    /// Seconds for the output to cover ~63% of a step change.
    var timeConstant: Double
    private(set) var value: Double?

    init(timeConstant: Double, initialValue: Double? = nil) {
        self.timeConstant = timeConstant
        self.value = initialValue
    }

    @discardableResult
    mutating func update(_ measurement: Double, dt: Double) -> Double {
        guard let current = value else {
            value = measurement
            return measurement
        }
        guard dt > 0, timeConstant > 0 else {
            value = measurement
            return measurement
        }
        let alpha = 1 - exp(-dt / timeConstant)
        let next = current + alpha * (measurement - current)
        value = next
        return next
    }

    mutating func reset(to newValue: Double? = nil) {
        value = newValue
    }
}

/// Scalar Kalman filter fusing GPS ground speed with accelerometer-derived
/// acceleration.
///
/// Why bother: Core Location gives a speed roughly ten times a second and each
/// reading carries its own noise. Between fixes the accelerometer knows how the
/// car is accelerating, so the filter propagates the speed forward with that
/// and corrects it whenever a fix lands. The result is a smooth, low-latency
/// speed estimate — which matters, because every threshold time in the app is
/// read off this signal.
///
/// State is the single value `speed`; `variance` is its uncertainty.
struct SpeedKalmanFilter {
    /// Best estimate of ground speed, m/s.
    private(set) var speed: Double = 0
    /// Estimate variance, (m/s)².
    private(set) var variance: Double = 1

    /// How much the acceleration input is trusted, m/s² of standard deviation
    /// per second of prediction. Cars rarely exceed ~1.2 G of longitudinal
    /// change, and the accelerometer adds bias on top.
    var processNoise: Double = 1.2
    /// Floor on measurement noise so a wildly optimistic accuracy reading
    /// cannot make the filter ignore its own prediction.
    var minimumMeasurementNoise: Double = 0.15

    private(set) var hasFix = false

    init() {}

    mutating func reset() {
        speed = 0
        variance = 1
        hasFix = false
    }

    /// Propagates the estimate forward by `dt` seconds using measured
    /// longitudinal acceleration in m/s² (pass 0 when motion is unavailable).
    mutating func predict(dt: Double, acceleration: Double) {
        guard dt > 0 else { return }
        speed = max(0, speed + acceleration * dt)
        let sigma = processNoise * dt
        variance += sigma * sigma
    }

    /// Folds in a GPS speed reading. `accuracy` is the speed accuracy in m/s
    /// reported by Core Location; pass a negative number when it is unknown.
    mutating func update(measurement: Double, accuracy: Double) {
        let noise = max(minimumMeasurementNoise, accuracy >= 0 ? accuracy : 1.0)
        let measurementVariance = noise * noise

        guard hasFix else {
            // First fix: adopt it outright instead of dragging up from zero.
            speed = max(0, measurement)
            variance = measurementVariance
            hasFix = true
            return
        }

        let gain = variance / (variance + measurementVariance)
        speed = max(0, speed + gain * (measurement - speed))
        variance *= (1 - gain)
    }
}

/// Smooths altitude and, when a barometer is present, uses it for the shape of
/// the curve while GPS supplies the absolute reference.
///
/// Methodology: GPS altitude is accurate to tens of metres but unbiased over
/// time; a barometer resolves centimetres of *change* but knows nothing about
/// sea level and drifts with the weather. So Tracky low-passes GPS altitude
/// hard to get a stable datum, then adds the barometer's relative altitude on
/// top of that datum. The offset between the two is itself low-passed with a
/// long time constant, which keeps short-term detail from the barometer and
/// long-term truth from GPS.
struct AltitudeFusion {
    private var gpsFilter = LowPassFilter(timeConstant: 12)
    private var offsetFilter = LowPassFilter(timeConstant: 60)
    private var barometricRelative: Double?
    private(set) var source: ElevationSource = .gps
    private(set) var altitude: Double = 0
    private(set) var hasValue = false

    init() {}

    mutating func reset() {
        gpsFilter.reset()
        offsetFilter.reset()
        barometricRelative = nil
        source = .gps
        altitude = 0
        hasValue = false
    }

    /// Relative altitude in metres since the barometer started, from CMAltimeter.
    mutating func ingestBarometricRelative(_ relative: Double) {
        barometricRelative = relative
        if source == .gps && hasValue {
            source = .fused
        } else if !hasValue {
            source = .barometer
        }
    }

    /// GPS altitude in metres. `verticalAccuracy` below zero means unusable.
    @discardableResult
    mutating func ingestGPS(altitude rawAltitude: Double, verticalAccuracy: Double, dt: Double) -> Double {
        guard verticalAccuracy >= 0 else { return altitude }
        let smoothedGPS = gpsFilter.update(rawAltitude, dt: max(dt, 0.01))
        hasValue = true

        if let relative = barometricRelative {
            let offset = offsetFilter.update(smoothedGPS - relative, dt: max(dt, 0.01))
            altitude = relative + offset
            source = .fused
        } else {
            altitude = smoothedGPS
            source = .gps
        }
        return altitude
    }

    /// Recomputes the output between GPS fixes using the latest barometer value.
    mutating func refreshFromBarometer() {
        guard let relative = barometricRelative, let offset = offsetFilter.value else { return }
        altitude = relative + offset
    }
}

/// Rejects GPS fixes that cannot be true.
///
/// Two things get thrown away: fixes whose reported horizontal accuracy is
/// worse than the configured limit, and fixes that imply an acceleration no car
/// can produce. The second check catches the speed spikes you get when the
/// receiver re-acquires satellites after a bridge or a tunnel.
struct OutlierRejector {
    /// Worst horizontal accuracy still accepted, metres.
    var accuracyLimit: Double = 35
    /// Largest believable longitudinal acceleration, in G. 2.2 G is already
    /// beyond a road car on street tyres.
    var maximumAccelerationG: Double = 2.2

    private var lastSpeed: Double?
    private var lastTimestamp: TimeInterval?

    init(accuracyLimit: Double = 35, maximumAccelerationG: Double = 2.2) {
        self.accuracyLimit = accuracyLimit
        self.maximumAccelerationG = maximumAccelerationG
    }

    enum Decision: Equatable {
        case accept
        case rejectAccuracy(Double)
        case rejectImpossibleAcceleration(Double)
        case rejectStaleTimestamp
    }

    mutating func reset() {
        lastSpeed = nil
        lastTimestamp = nil
    }

    mutating func evaluate(speed: Double, timestamp: TimeInterval, horizontalAccuracy: Double) -> Decision {
        guard horizontalAccuracy >= 0, horizontalAccuracy <= accuracyLimit else {
            return .rejectAccuracy(horizontalAccuracy)
        }
        if let previousTime = lastTimestamp, timestamp <= previousTime {
            return .rejectStaleTimestamp
        }
        if let previousSpeed = lastSpeed, let previousTime = lastTimestamp {
            let dt = timestamp - previousTime
            // Only judge gaps short enough for the comparison to mean anything.
            if dt > 0, dt < 2 {
                let impliedG = abs(speed - previousSpeed) / dt / UnitConversion.standardGravity
                if impliedG > maximumAccelerationG {
                    return .rejectImpossibleAcceleration(impliedG)
                }
            }
        }
        lastSpeed = speed
        lastTimestamp = timestamp
        return .accept
    }

    /// Call after a rejected fix so the next comparison uses a fresh baseline
    /// once the receiver settles down.
    mutating func noteRejection(timestamp: TimeInterval) {
        lastTimestamp = timestamp
    }
}
