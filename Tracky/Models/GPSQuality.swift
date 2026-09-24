import Foundation

/// Coarse verdict on how much a recorded run can be trusted.
///
/// Derived from the horizontal accuracy reported by Core Location across the
/// run plus how consistently samples arrived. A phone is not a survey-grade
/// receiver, so this is a confidence hint rather than an error bound.
enum GPSQuality: String, Codable, CaseIterable, Identifiable, Comparable {
    case excellent
    case good
    case fair
    case poor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }

    var detail: String {
        switch self {
        case .excellent: return "Strong signal for the whole run."
        case .good: return "Solid signal. Times should be repeatable."
        case .fair: return "Signal wandered. Treat the time as indicative."
        case .poor: return "Weak or unstable signal. This run may be inaccurate."
        }
    }

    private var rank: Int {
        switch self {
        case .poor: return 0
        case .fair: return 1
        case .good: return 2
        case .excellent: return 3
        }
    }

    static func < (lhs: GPSQuality, rhs: GPSQuality) -> Bool { lhs.rank < rhs.rank }

    /// Classifies a live horizontal accuracy reading, in metres.
    /// A negative value means Core Location has no fix at all.
    static func from(horizontalAccuracy: Double) -> GPSQuality {
        guard horizontalAccuracy >= 0 else { return .poor }
        switch horizontalAccuracy {
        case ..<5: return .excellent
        case ..<10: return .good
        case ..<25: return .fair
        default: return .poor
        }
    }
}
