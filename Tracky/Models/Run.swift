import Foundation
import SwiftData

/// A saved measurement.
///
/// Scalar fields are stored as columns so lists, sorting and personal bests can
/// be queried without decoding anything. The full telemetry series is kept in a
/// single external blob because it is only needed when a chart or map is shown.
@Model
final class Run {
    @Attribute(.unique) var id: UUID
    var date: Date

    // What was measured
    var modeID: String
    var modeTitle: String
    var categoryRaw: String
    /// "speed" or "distance".
    var targetKind: String
    /// Start speed of a speed target, m/s.
    var targetFrom: Double
    /// Finish speed of a speed target, m/s.
    var targetTo: Double
    /// Target distance, m. Zero for speed targets.
    var targetDistanceMeters: Double

    // Result
    var duration: TimeInterval
    var distance: Double
    var startSpeed: Double
    var endSpeed: Double
    var maxSpeed: Double

    var maxAccelerationG: Double
    var maxBrakingG: Double
    var maxLateralG: Double
    var maxCombinedG: Double

    var startAltitude: Double
    var endAltitude: Double
    var minAltitude: Double
    var maxAltitude: Double
    var elevationSourceRaw: String

    var averageAccuracy: Double
    var bestAccuracy: Double
    var worstAccuracy: Double
    var sampleRate: Double
    var qualityRaw: String

    var isValid: Bool
    var warningsBlob: Data?
    var splitsBlob: Data?
    var notes: String

    var startLatitude: Double?
    var startLongitude: Double?
    var endLatitude: Double?
    var endLongitude: Double?

    /// JSON-encoded `[TelemetryPoint]`. Held outside the main store file so the
    /// database stays small and run lists load instantly.
    @Attribute(.externalStorage) var telemetryBlob: Data?
    /// False once the user strips location data from this run.
    var storesRoute: Bool

    var vehicle: Vehicle?

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        modeID: String,
        modeTitle: String,
        categoryRaw: String,
        targetKind: String,
        targetFrom: Double = 0,
        targetTo: Double = 0,
        targetDistanceMeters: Double = 0,
        duration: TimeInterval,
        distance: Double,
        startSpeed: Double,
        endSpeed: Double,
        maxSpeed: Double,
        maxAccelerationG: Double = 0,
        maxBrakingG: Double = 0,
        maxLateralG: Double = 0,
        maxCombinedG: Double = 0,
        startAltitude: Double = 0,
        endAltitude: Double = 0,
        minAltitude: Double = 0,
        maxAltitude: Double = 0,
        elevationSourceRaw: String = ElevationSource.gps.rawValue,
        averageAccuracy: Double = -1,
        bestAccuracy: Double = -1,
        worstAccuracy: Double = -1,
        sampleRate: Double = 0,
        qualityRaw: String = GPSQuality.good.rawValue,
        isValid: Bool = true,
        notes: String = "",
        storesRoute: Bool = true,
        vehicle: Vehicle? = nil
    ) {
        self.id = id
        self.date = date
        self.modeID = modeID
        self.modeTitle = modeTitle
        self.categoryRaw = categoryRaw
        self.targetKind = targetKind
        self.targetFrom = targetFrom
        self.targetTo = targetTo
        self.targetDistanceMeters = targetDistanceMeters
        self.duration = duration
        self.distance = distance
        self.startSpeed = startSpeed
        self.endSpeed = endSpeed
        self.maxSpeed = maxSpeed
        self.maxAccelerationG = maxAccelerationG
        self.maxBrakingG = maxBrakingG
        self.maxLateralG = maxLateralG
        self.maxCombinedG = maxCombinedG
        self.startAltitude = startAltitude
        self.endAltitude = endAltitude
        self.minAltitude = minAltitude
        self.maxAltitude = maxAltitude
        self.elevationSourceRaw = elevationSourceRaw
        self.averageAccuracy = averageAccuracy
        self.bestAccuracy = bestAccuracy
        self.worstAccuracy = worstAccuracy
        self.sampleRate = sampleRate
        self.qualityRaw = qualityRaw
        self.isValid = isValid
        self.notes = notes
        self.storesRoute = storesRoute
        self.vehicle = vehicle
    }
}

// MARK: - Derived values

extension Run {
    var quality: GPSQuality {
        GPSQuality(rawValue: qualityRaw) ?? .good
    }

    var category: RunModeCategory {
        RunModeCategory(rawValue: categoryRaw) ?? .acceleration
    }

    var elevationSource: ElevationSource {
        ElevationSource(rawValue: elevationSourceRaw) ?? .gps
    }

    var elevationChange: Double { endAltitude - startAltitude }

    var isDistanceRun: Bool { targetKind == "distance" }

    var target: RunTarget {
        isDistanceRun
            ? .distance(meters: targetDistanceMeters)
            : .speed(from: targetFrom, to: targetTo)
    }

    var warnings: [String] {
        guard let warningsBlob else { return [] }
        return (try? JSONDecoder().decode([String].self, from: warningsBlob)) ?? []
    }

    var splits: [Split] {
        guard let splitsBlob else { return [] }
        return (try? JSONDecoder().decode([Split].self, from: splitsBlob)) ?? []
    }

    /// Decoded telemetry. Decoding is deliberately lazy: nothing calls this
    /// until a chart, map or export actually needs the series.
    var telemetry: [TelemetryPoint] {
        guard let telemetryBlob else { return [] }
        return (try? JSONDecoder().decode([TelemetryPoint].self, from: telemetryBlob)) ?? []
    }

    var hasRoute: Bool {
        guard storesRoute else { return false }
        return startLatitude != nil && startLongitude != nil
    }

    /// Trap speed for distance runs, m/s.
    var trapSpeed: Double? { isDistanceRun ? endSpeed : nil }

    var averageAcceleration: Double {
        guard duration > 0 else { return 0 }
        return (endSpeed - startSpeed) / duration
    }
}

// MARK: - Mapping

extension Run {
    /// Builds a persistable run from an engine result.
    convenience init(result: PerformanceResult, category: RunModeCategory, vehicle: Vehicle?, storeRoute: Bool) {
        var targetKind = "speed"
        var from = 0.0
        var to = 0.0
        var targetDistance = 0.0
        switch result.target {
        case .speed(let start, let end):
            from = start
            to = end
        case .distance(let meters):
            targetKind = "distance"
            targetDistance = meters
        }

        self.init(
            id: result.id,
            date: result.date,
            modeID: result.modeID,
            modeTitle: result.modeTitle,
            categoryRaw: category.rawValue,
            targetKind: targetKind,
            targetFrom: from,
            targetTo: to,
            targetDistanceMeters: targetDistance,
            duration: result.duration,
            distance: result.distance,
            startSpeed: result.startSpeed,
            endSpeed: result.endSpeed,
            maxSpeed: result.maxSpeed,
            maxAccelerationG: result.maxAccelerationG,
            maxBrakingG: result.maxBrakingG,
            maxLateralG: result.maxLateralG,
            maxCombinedG: result.maxCombinedG,
            startAltitude: result.elevation.start,
            endAltitude: result.elevation.end,
            minAltitude: result.elevation.minimum,
            maxAltitude: result.elevation.maximum,
            elevationSourceRaw: result.elevation.source.rawValue,
            averageAccuracy: result.accuracy.average,
            bestAccuracy: result.accuracy.best,
            worstAccuracy: result.accuracy.worst,
            sampleRate: result.accuracy.sampleRate,
            qualityRaw: result.quality.rawValue,
            isValid: result.isValid,
            storesRoute: storeRoute,
            vehicle: vehicle
        )

        warningsBlob = try? JSONEncoder().encode(result.warnings)
        splitsBlob = try? JSONEncoder().encode(result.splits)

        let samples = storeRoute ? result.samples : result.samples.map { point in
            var stripped = point
            stripped.latitude = 0
            stripped.longitude = 0
            return stripped
        }
        telemetryBlob = try? JSONEncoder().encode(samples)

        if storeRoute {
            startLatitude = result.startCoordinate?.latitude
            startLongitude = result.startCoordinate?.longitude
            endLatitude = result.endCoordinate?.latitude
            endLongitude = result.endCoordinate?.longitude
        }
    }

    /// Removes every stored coordinate from this run while keeping the timing
    /// and telemetry. Used by the privacy controls in Settings.
    func stripLocationData() {
        storesRoute = false
        startLatitude = nil
        startLongitude = nil
        endLatitude = nil
        endLongitude = nil
        let stripped = telemetry.map { point -> TelemetryPoint in
            var copy = point
            copy.latitude = 0
            copy.longitude = 0
            return copy
        }
        telemetryBlob = try? JSONEncoder().encode(stripped)
    }
}
