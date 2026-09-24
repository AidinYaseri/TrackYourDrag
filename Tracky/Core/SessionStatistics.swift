import Foundation

/// Rolling totals for everything recorded since the processor started.
struct SessionStatistics {
    private(set) var distance: Double = 0
    private(set) var maxSpeed: Double = 0
    private(set) var gforce = GForceAccumulator()

    private(set) var startAltitude: Double = 0
    private(set) var currentAltitude: Double = 0
    private(set) var minAltitude: Double = 0
    private(set) var maxAltitude: Double = 0
    private(set) var elevationSource: ElevationSource = .gps
    private var hasAltitude = false

    private(set) var acceptedFixes = 0
    private(set) var rejectedFixes = 0
    private var accuracySum: Double = 0
    private(set) var bestAccuracy: Double = -1
    private(set) var worstAccuracy: Double = -1

    private(set) var firstSampleTime: TimeInterval?
    private(set) var lastSampleTime: TimeInterval?

    mutating func reset() {
        self = SessionStatistics()
    }

    mutating func ingest(_ sample: TelemetrySample) {
        if sample.speed > maxSpeed { maxSpeed = sample.speed }
        distance = sample.distance
        gforce.ingest(sample.gforce)

        if firstSampleTime == nil { firstSampleTime = sample.t }
        lastSampleTime = sample.t

        guard sample.isGPSUpdate else { return }

        acceptedFixes += 1
        if sample.horizontalAccuracy >= 0 {
            accuracySum += sample.horizontalAccuracy
            if bestAccuracy < 0 || sample.horizontalAccuracy < bestAccuracy {
                bestAccuracy = sample.horizontalAccuracy
            }
            if sample.horizontalAccuracy > worstAccuracy {
                worstAccuracy = sample.horizontalAccuracy
            }
        }

        elevationSource = sample.elevationSource
        currentAltitude = sample.altitude
        if !hasAltitude {
            hasAltitude = true
            startAltitude = sample.altitude
            minAltitude = sample.altitude
            maxAltitude = sample.altitude
        } else {
            minAltitude = Swift.min(minAltitude, sample.altitude)
            maxAltitude = Swift.max(maxAltitude, sample.altitude)
        }
    }

    mutating func noteRejectedFix() {
        rejectedFixes += 1
    }

    var averageAccuracy: Double {
        acceptedFixes > 0 ? accuracySum / Double(acceptedFixes) : -1
    }

    var elapsed: TimeInterval {
        guard let first = firstSampleTime, let last = lastSampleTime else { return 0 }
        return last - first
    }

    /// Fixes per second actually received.
    var fixRate: Double {
        guard elapsed > 0.5 else { return 0 }
        return Double(acceptedFixes) / elapsed
    }

    var elevationChange: Double { currentAltitude - startAltitude }

    var elevationSummary: ElevationSummary {
        ElevationSummary(
            start: startAltitude,
            end: currentAltitude,
            minimum: minAltitude,
            maximum: maxAltitude,
            source: elevationSource
        )
    }

    var accuracySummary: AccuracySummary {
        AccuracySummary(
            average: averageAccuracy,
            best: bestAccuracy,
            worst: worstAccuracy,
            sampleCount: acceptedFixes,
            sampleRate: fixRate
        )
    }
}
