import Foundation
@testable import Tracky

/// Builders for synthetic drives whose answers can be worked out on paper, so
/// the tests check the engine against physics rather than against itself.
enum SyntheticDrive {

    static func sample(
        t: TimeInterval,
        speed: Double,
        distance: Double,
        acceleration: Double = 0,
        lateral: Double = 0,
        accuracy: Double = 3,
        isGPSUpdate: Bool = true
    ) -> TelemetrySample {
        TelemetrySample(
            t: t,
            speed: speed,
            rawSpeed: speed,
            distance: distance,
            altitude: 40,
            elevationSource: .gps,
            gforce: GForceReading(
                longitudinal: acceleration / UnitConversion.standardGravity,
                lateral: lateral / UnitConversion.standardGravity,
                vertical: 0,
                source: .deviceMotion
            ),
            coordinate: Coordinate(latitude: 45.5, longitude: -73.56),
            horizontalAccuracy: accuracy,
            course: 42,
            gpsAcceleration: acceleration,
            isGPSUpdate: isGPSUpdate
        )
    }

    /// Stationary for `stationaryLeadIn`, then constant acceleration from rest.
    ///
    /// With constant acceleration the answers are exact: a speed `v` is reached
    /// at `v / a`, and a distance `d` at `sqrt(2d / a)`.
    static func constantAcceleration(
        _ acceleration: Double,
        duration: TimeInterval = 30,
        interval: TimeInterval = 0.1,
        stationaryLeadIn: TimeInterval = 1.0,
        accuracy: Double = 3
    ) -> [TelemetrySample] {
        var samples: [TelemetrySample] = []
        var t: TimeInterval = 0
        while t <= stationaryLeadIn + duration + 1e-9 {
            let since = t - stationaryLeadIn
            let speed = since > 0 ? acceleration * since : 0
            let distance = since > 0 ? 0.5 * acceleration * since * since : 0
            samples.append(
                sample(
                    t: t,
                    speed: speed,
                    distance: distance,
                    acceleration: since > 0 ? acceleration : 0,
                    accuracy: accuracy
                )
            )
            t += interval
        }
        return samples
    }

    /// Accelerates to `holdSpeed`, holds it, then decelerates to a stop.
    static func acceleratePlateauBrake(
        acceleration: Double,
        holdSpeed: Double,
        holdFor: TimeInterval,
        deceleration: Double,
        interval: TimeInterval = 0.1,
        stationaryLeadIn: TimeInterval = 1.0
    ) -> [TelemetrySample] {
        var samples: [TelemetrySample] = []
        var t: TimeInterval = 0
        var speed: Double = 0
        var distance: Double = 0
        let accelerationEnd = stationaryLeadIn + holdSpeed / acceleration
        let holdEnd = accelerationEnd + holdFor

        while speed > 0.001 || t <= holdEnd {
            let current: Double
            if t <= stationaryLeadIn {
                current = 0
            } else if t <= accelerationEnd {
                current = acceleration
            } else if t <= holdEnd {
                current = 0
            } else {
                current = -deceleration
            }
            samples.append(
                sample(t: t, speed: speed, distance: distance, acceleration: current)
            )
            speed = max(0, speed + current * interval)
            distance += speed * interval
            t += interval
            if t > stationaryLeadIn + 600 { break }
        }
        return samples
    }

    /// Runs a whole sample stream through an armed engine and returns every
    /// event it produced.
    @discardableResult
    static func run(_ engine: PerformanceEngine, with samples: [TelemetrySample]) -> [PerformanceEngine.Event] {
        var events: [PerformanceEngine.Event] = []
        for sample in samples {
            events.append(contentsOf: engine.ingest(sample))
        }
        return events
    }

    static func finishedResult(in events: [PerformanceEngine.Event]) -> PerformanceResult? {
        var latest: PerformanceResult?
        for event in events {
            switch event {
            case .finished(let result), .resultRefined(let result):
                latest = result
            default:
                break
            }
        }
        return latest
    }

    static func abortReason(in events: [PerformanceEngine.Event]) -> PerformanceEngine.AbortReason? {
        for event in events {
            if case .aborted(let reason) = event { return reason }
        }
        return nil
    }

    static func splits(in events: [PerformanceEngine.Event]) -> [Split] {
        events.compactMap { event in
            if case .split(let split) = event { return split }
            return nil
        }
    }
}

extension RunSummary {
    /// Compact builder for the personal-best tests.
    static func make(
        modeID: String = RunMode.zeroToHundredKmh.id,
        duration: TimeInterval,
        daysAgo: Double = 0,
        quality: GPSQuality = .good,
        isValid: Bool = true,
        vehicleName: String? = nil,
        maxAccelerationG: Double = 0.8,
        maxBrakingG: Double = -0.9,
        maxLateralG: Double = 0.5,
        distance: Double = 150
    ) -> RunSummary {
        RunSummary(
            id: UUID(),
            date: Date().addingTimeInterval(-daysAgo * 86_400),
            modeID: modeID,
            modeTitle: modeID,
            category: .acceleration,
            duration: duration,
            distance: distance,
            startSpeed: 0,
            endSpeed: 27.78,
            maxSpeed: 27.78,
            maxAccelerationG: maxAccelerationG,
            maxBrakingG: maxBrakingG,
            maxLateralG: maxLateralG,
            elevationChange: 0,
            quality: quality,
            isValid: isValid,
            vehicleID: nil,
            vehicleName: vehicleName
        )
    }
}
