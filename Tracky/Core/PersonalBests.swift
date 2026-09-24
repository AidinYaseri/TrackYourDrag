import Foundation

/// One record: the quickest time recorded for a given mode.
struct PersonalBest: Identifiable, Hashable {
    var modeID: String
    var modeTitle: String
    var duration: TimeInterval
    var runID: UUID
    var date: Date
    var vehicleName: String?
    /// How much quicker this is than the previous best for the same mode.
    var improvementOverPrevious: TimeInterval?

    var id: String { modeID }
}

/// Everything the Stats screen shows.
struct StatsSummary {
    var bests: [PersonalBest] = []
    var maxAccelerationG: Double = 0
    var maxBrakingG: Double = 0
    var maxLateralG: Double = 0
    var totalDistance: Double = 0
    var totalRuns: Int = 0
    var validRuns: Int = 0
    var totalDriveTime: TimeInterval = 0
    var fastestRunID: UUID?
    var highestSpeed: Double = 0

    func best(forModeID modeID: String) -> PersonalBest? {
        bests.first { $0.modeID == modeID }
    }
}

/// A point on a "how am I improving" chart.
struct TrendPoint: Identifiable, Hashable {
    var date: Date
    var duration: TimeInterval
    var runID: UUID
    var isRecord: Bool

    var id: UUID { runID }
}

enum PersonalBestCalculator {

    /// Fastest valid run per mode, ordered with the presets first so the Stats
    /// screen reads the same way every time.
    static func bests(from runs: [RunSummary]) -> [PersonalBest] {
        let eligible = runs.filter(\.countsTowardsRecords)
        var grouped: [String: [RunSummary]] = [:]
        for run in eligible {
            grouped[run.modeID, default: []].append(run)
        }

        var results: [PersonalBest] = []
        for (modeID, group) in grouped {
            let sorted = group.sorted { $0.duration < $1.duration }
            guard let fastest = sorted.first else { continue }
            // "Improvement" compares the record against the next best time, so
            // a new record shows how much was gained.
            let runnerUp = sorted.dropFirst().first
            results.append(
                PersonalBest(
                    modeID: modeID,
                    modeTitle: fastest.modeTitle,
                    duration: fastest.duration,
                    runID: fastest.id,
                    date: fastest.date,
                    vehicleName: fastest.vehicleName,
                    improvementOverPrevious: runnerUp.map { $0.duration - fastest.duration }
                )
            )
        }

        let order = RunMode.allPresets.map(\.id)
        return results.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs.modeID) ?? Int.max
            let right = order.firstIndex(of: rhs.modeID) ?? Int.max
            if left != right { return left < right }
            return lhs.modeTitle < rhs.modeTitle
        }
    }

    static func summary(from runs: [RunSummary]) -> StatsSummary {
        var summary = StatsSummary()
        summary.bests = bests(from: runs)
        summary.totalRuns = runs.count
        summary.validRuns = runs.filter(\.countsTowardsRecords).count
        summary.totalDistance = runs.reduce(0) { $0 + max(0, $1.distance) }
        summary.totalDriveTime = runs.reduce(0) { $0 + max(0, $1.duration) }

        // G records come from every recorded run, valid or not: a big braking
        // number is still a real measurement even if the run was cut short.
        for run in runs {
            summary.maxAccelerationG = max(summary.maxAccelerationG, run.maxAccelerationG)
            summary.maxBrakingG = min(summary.maxBrakingG, run.maxBrakingG)
            if abs(run.maxLateralG) > abs(summary.maxLateralG) {
                summary.maxLateralG = run.maxLateralG
            }
            summary.highestSpeed = max(summary.highestSpeed, run.maxSpeed)
        }

        summary.fastestRunID = runs
            .filter(\.countsTowardsRecords)
            .min { $0.duration < $1.duration }?
            .id
        return summary
    }

    /// Chronological times for one mode, flagging each run that set a new record
    /// at the time it was recorded.
    static func trend(for modeID: String, in runs: [RunSummary]) -> [TrendPoint] {
        let ordered = runs
            .filter { $0.modeID == modeID && $0.countsTowardsRecords }
            .sorted { $0.date < $1.date }

        var best = Double.greatestFiniteMagnitude
        return ordered.map { run in
            let isRecord = run.duration < best
            if isRecord { best = run.duration }
            return TrendPoint(date: run.date, duration: run.duration, runID: run.id, isRecord: isRecord)
        }
    }

    /// True when `candidate` would become the record for its mode.
    static func isPersonalBest(_ candidate: RunSummary, among runs: [RunSummary]) -> Bool {
        guard candidate.countsTowardsRecords else { return false }
        let others = runs.filter { $0.modeID == candidate.modeID && $0.id != candidate.id && $0.countsTowardsRecords }
        guard let bestOther = others.map(\.duration).min() else { return true }
        return candidate.duration < bestOther
    }
}
