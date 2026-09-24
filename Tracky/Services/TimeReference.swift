import Foundation

/// Core Location stamps fixes with a `Date`; Core Motion stamps updates with
/// seconds since the device booted. Mixing the two would make every dt wrong,
/// so both are converted to the same reference-date timeline here.
enum TimeReference {
    /// Reference-date time that corresponds to device uptime zero. Captured
    /// once at launch; good enough because the two clocks only drift by
    /// microseconds over a run.
    static let bootTime: TimeInterval =
        Date().timeIntervalSinceReferenceDate - ProcessInfo.processInfo.systemUptime

    /// Converts a Core Motion timestamp (seconds since boot) to the shared clock.
    static func fromUptime(_ uptime: TimeInterval) -> TimeInterval {
        bootTime + uptime
    }

    /// Converts a Core Location timestamp to the shared clock.
    static func fromDate(_ date: Date) -> TimeInterval {
        date.timeIntervalSinceReferenceDate
    }

    /// Current time on the shared clock.
    static var now: TimeInterval {
        Date().timeIntervalSinceReferenceDate
    }
}
