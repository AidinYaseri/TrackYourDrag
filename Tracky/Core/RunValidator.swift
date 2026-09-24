import Foundation

/// Decides how much to trust a finished run and produces the warnings shown on
/// the result screen.
///
/// None of this claims a measurement uncertainty in seconds. A phone's answer
/// depends on satellite geometry, the mount, the road and the handset, so the
/// honest thing to report is signal quality plus anything odd that happened.
enum RunValidator {

    struct Verdict {
        var quality: GPSQuality
        var isValid: Bool
        var warnings: [String]
    }

    /// Fixes per second below which interpolation starts to matter a lot.
    static let minimumUsefulFixRate: Double = 3

    static func evaluate(
        accuracy: AccuracySummary,
        rejectedFixes: Int,
        duration: TimeInterval,
        gforceSource: GForceSource
    ) -> Verdict {
        var warnings: [String] = []
        let average = accuracy.average
        let worst = accuracy.worst
        let rate = accuracy.sampleRate

        let quality: GPSQuality
        if average >= 0 && average < 5 && worst < 10 && rate >= 5 {
            quality = .excellent
        } else if average >= 0 && average < 10 && worst < 25 && rate >= minimumUsefulFixRate {
            quality = .good
        } else if average >= 0 && average < 25 {
            quality = .fair
        } else {
            quality = .poor
        }

        if quality == .poor {
            warnings.append("GPS accuracy was weak for this run. The time may be off.")
        } else if quality == .fair {
            warnings.append("GPS accuracy wandered during this run.")
        }

        if rate > 0 && rate < minimumUsefulFixRate {
            warnings.append(String(
                format: "Only %.1f GPS fixes per second were received, so more of the time was interpolated than usual.",
                rate
            ))
        }

        if rejectedFixes > 0 {
            warnings.append("\(rejectedFixes) GPS fix\(rejectedFixes == 1 ? "" : "es") were discarded as unrealistic.")
        }

        if accuracy.sampleCount < 8 {
            warnings.append("Very few GPS fixes were recorded for this run.")
        }

        if duration < 0.5 {
            warnings.append("The measured window was extremely short.")
        }

        switch gforceSource {
        case .gpsOnly:
            warnings.append("Motion data was unavailable, so G-force was estimated from GPS speed only.")
        case .deviceMotionAssisted:
            warnings.append("Compass-referenced motion was unavailable, so lateral G is an estimate.")
        case .deviceMotion, .unavailable:
            break
        }

        let isValid = quality > .poor && accuracy.sampleCount >= 5 && duration >= 0.3
        return Verdict(quality: quality, isValid: isValid, warnings: warnings)
    }
}
