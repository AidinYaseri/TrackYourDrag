import Foundation

/// Turns raw GPS fixes and device-motion updates into a single, clean stream of
/// `TelemetrySample`s.
///
/// Responsibilities, in order:
/// 1. Reject fixes that are too inaccurate or physically impossible.
/// 2. Fuse GPS speed with accelerometer data in a Kalman filter.
/// 3. Integrate speed over time to get distance.
/// 4. Fuse GPS altitude with the barometer.
/// 5. Resolve device motion into car-frame G-forces.
///
/// Nothing in here touches Core Location, Core Motion, SwiftUI or SwiftData,
/// which is what makes the whole measurement path unit testable.
final class TelemetryProcessor {

    struct Configuration {
        /// Worst horizontal accuracy still accepted, metres.
        var accuracyLimit: Double = 35
        /// Largest believable longitudinal acceleration, in G.
        var maximumAccelerationG: Double = 2.2
        /// Speed below which the car is treated as stopped, m/s (~1.1 km/h).
        var stationarySpeed: Double = 0.3

        static let `default` = Configuration()
    }

    private(set) var configuration: Configuration
    private(set) var statistics = SessionStatistics()
    private(set) var lastSample: TelemetrySample?
    private(set) var lastRejection: OutlierRejector.Decision?

    private var sessionStart: TimeInterval?
    private var speedFilter = SpeedKalmanFilter()
    private var altitude = AltitudeFusion()
    private var rejector: OutlierRejector
    private var gforce = GForceCalculator()

    private var lastMotion: MotionSample?
    private var lastPredictTime: TimeInterval?
    private var lastIntegrationTime: TimeInterval?
    private var lastIntegratedSpeed: Double = 0
    private var cumulativeDistance: Double = 0

    private var lastRawSpeed: Double?
    private var lastRawSpeedTime: TimeInterval?
    private var lastGPSAcceleration: Double = 0
    private var lastCoordinate: Coordinate?
    private var lastCourse: Double = -1
    private var lastAccuracy: Double = -1

    init(configuration: Configuration = .default) {
        self.configuration = configuration
        self.rejector = OutlierRejector(
            accuracyLimit: configuration.accuracyLimit,
            maximumAccelerationG: configuration.maximumAccelerationG
        )
    }

    func reset() {
        statistics.reset()
        lastSample = nil
        lastRejection = nil
        sessionStart = nil
        speedFilter.reset()
        altitude.reset()
        rejector.reset()
        gforce.reset()
        lastMotion = nil
        lastPredictTime = nil
        lastIntegrationTime = nil
        lastIntegratedSpeed = 0
        cumulativeDistance = 0
        lastRawSpeed = nil
        lastRawSpeedTime = nil
        lastGPSAcceleration = 0
        lastCoordinate = nil
        lastCourse = -1
        lastAccuracy = -1
    }

    func apply(configuration newConfiguration: Configuration) {
        configuration = newConfiguration
        rejector.accuracyLimit = newConfiguration.accuracyLimit
        rejector.maximumAccelerationG = newConfiguration.maximumAccelerationG
    }

    // MARK: - Inputs

    /// Relative altitude in metres since the barometer started, from CMAltimeter.
    func ingestBarometer(relativeAltitude: Double) {
        altitude.ingestBarometricRelative(relativeAltitude)
        altitude.refreshFromBarometer()
    }

    /// Feeds a device-motion update. Returns a sample when there is already a
    /// session to extend, so the UI can run at motion rate between GPS fixes.
    @discardableResult
    func process(motion: MotionSample) -> TelemetrySample? {
        lastMotion = motion
        guard let sessionStart else { return nil }

        let t = motion.timestamp - sessionStart
        guard t >= 0 else { return nil }

        let dt = lastPredictTime.map { t - $0 } ?? 0
        guard dt >= 0 else { return nil }

        // Only push the filter forward with the accelerometer when the reading
        // is a genuine 3-axis solution. In the fallback modes the longitudinal
        // value is itself derived from GPS, and feeding it back in would make
        // the filter chase its own tail.
        let reading = gforce.reading(
            motion: motion,
            courseDegrees: lastCourse,
            speed: speedFilter.speed,
            gpsAcceleration: lastGPSAcceleration,
            dt: dt > 0 ? dt : 0.01
        )
        let accelerationInput = reading.source == .deviceMotion
            ? reading.longitudinal * UnitConversion.standardGravity
            : 0

        if dt > 0 {
            speedFilter.predict(dt: dt, acceleration: accelerationInput)
        }
        lastPredictTime = t

        guard speedFilter.hasFix else { return nil }

        let sample = makeSample(t: t, reading: reading, isGPSUpdate: false)
        lastSample = sample
        statistics.ingest(sample)
        return sample
    }

    /// Feeds a GPS fix. Returns nil when the fix was rejected as an outlier.
    @discardableResult
    func process(location: LocationSample) -> TelemetrySample? {
        if sessionStart == nil {
            sessionStart = location.timestamp
            lastPredictTime = 0
        }
        guard let sessionStart else { return nil }
        let t = location.timestamp - sessionStart

        // Core Location reports a negative speed when it cannot work one out.
        // Fall back to differentiating position, which is poor but better than
        // dropping the fix entirely.
        var rawSpeed = location.speed
        if rawSpeed < 0 {
            if let previous = lastCoordinate, let previousTime = lastRawSpeedTime, t > previousTime {
                let moved = GeoMath.distance(previous, location.coordinate)
                rawSpeed = moved / (t - previousTime)
            } else {
                rawSpeed = 0
            }
        }

        switch rejector.evaluate(
            speed: rawSpeed,
            timestamp: t,
            horizontalAccuracy: location.horizontalAccuracy
        ) {
        case .accept:
            break
        case .rejectStaleTimestamp:
            lastRejection = .rejectStaleTimestamp
            statistics.noteRejectedFix()
            return nil
        case .rejectAccuracy(let value):
            lastRejection = .rejectAccuracy(value)
            rejector.noteRejection(timestamp: t)
            statistics.noteRejectedFix()
            lastAccuracy = location.horizontalAccuracy
            return nil
        case .rejectImpossibleAcceleration(let value):
            lastRejection = .rejectImpossibleAcceleration(value)
            rejector.noteRejection(timestamp: t)
            statistics.noteRejectedFix()
            return nil
        }
        lastRejection = nil

        // Advance the filter to this fix before folding the fix in, carrying
        // the previous interval's acceleration forward. Predicting with zero
        // acceleration would make the estimate lag behind a car that is still
        // pulling — about 0.8 m/s behind at 0.4 G with no motion data, which is
        // a sixth of a second of error at the 100 km/h mark.
        //
        // When device motion is available the motion updates have already
        // advanced the filter, so this residual step covers only the few
        // milliseconds since the last one.
        let predictDelta = lastPredictTime.map { t - $0 } ?? 0
        if predictDelta > 0 {
            speedFilter.predict(dt: predictDelta, acceleration: lastGPSAcceleration)
        }

        // Acceleration straight off the GPS speed trace. Used to drive the next
        // prediction, as a cross-check, and as the longitudinal source when
        // device motion is unavailable.
        if let previousSpeed = lastRawSpeed, let previousTime = lastRawSpeedTime, t > previousTime {
            lastGPSAcceleration = (rawSpeed - previousSpeed) / (t - previousTime)
        }
        lastRawSpeed = rawSpeed
        lastRawSpeedTime = t

        speedFilter.update(measurement: rawSpeed, accuracy: location.speedAccuracy)
        lastPredictTime = t

        let gpsDelta = lastIntegrationTime.map { t - $0 } ?? 0.1
        altitude.ingestGPS(
            altitude: location.altitude,
            verticalAccuracy: location.verticalAccuracy,
            dt: gpsDelta
        )

        lastCourse = location.course
        lastAccuracy = location.horizontalAccuracy
        lastCoordinate = location.coordinate

        let reading = gforce.reading(
            motion: lastMotion,
            courseDegrees: location.course,
            speed: speedFilter.speed,
            gpsAcceleration: lastGPSAcceleration,
            dt: max(gpsDelta, 0.01)
        )

        let sample = makeSample(t: t, reading: reading, isGPSUpdate: true)
        lastSample = sample
        statistics.ingest(sample)
        return sample
    }

    // MARK: - Helpers

    /// Distance comes from integrating filtered speed rather than from summing
    /// the gaps between fixes. Core Location derives speed from Doppler shift,
    /// which is good to a fraction of a metre per second, while consecutive
    /// positions can wander by several metres — over a 12 second quarter mile
    /// that position noise would swamp the answer.
    private func advanceDistance(to t: TimeInterval, speed: Double) {
        if let last = lastIntegrationTime, t > last {
            let dt = t - last
            cumulativeDistance += (lastIntegratedSpeed + speed) / 2 * dt
        }
        lastIntegrationTime = t
        lastIntegratedSpeed = speed
    }

    private func makeSample(t: TimeInterval, reading: GForceReading, isGPSUpdate: Bool) -> TelemetrySample {
        let speed = speedFilter.speed
        advanceDistance(to: t, speed: speed)
        altitude.refreshFromBarometer()

        return TelemetrySample(
            t: t,
            speed: speed,
            rawSpeed: lastRawSpeed ?? speed,
            distance: cumulativeDistance,
            altitude: altitude.altitude,
            elevationSource: altitude.source,
            gforce: reading,
            coordinate: lastCoordinate,
            horizontalAccuracy: lastAccuracy,
            course: lastCourse,
            gpsAcceleration: lastGPSAcceleration,
            isGPSUpdate: isGPSUpdate
        )
    }

    // MARK: - Derived state

    var isStationary: Bool {
        (lastSample?.speed ?? 0) <= configuration.stationarySpeed
    }

    var currentQuality: GPSQuality {
        GPSQuality.from(horizontalAccuracy: lastAccuracy)
    }
}
