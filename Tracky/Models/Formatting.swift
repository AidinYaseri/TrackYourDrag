import Foundation

/// Every number the user sees goes through here, so units and decimal places
/// stay consistent between the live dashboard, the history list and exports.
enum Format {

    // MARK: - Speed

    /// Whole-number speed for the big readout.
    static func speed(_ mps: Double, unit: SpeedUnit) -> String {
        let value = unit.value(fromMetersPerSecond: max(0, mps))
        return String(Int(value.rounded()))
    }

    static func speedDecimal(_ mps: Double, unit: SpeedUnit, decimals: Int = 1) -> String {
        let value = unit.value(fromMetersPerSecond: max(0, mps))
        return String(format: "%.\(decimals)f", value)
    }

    static func speedWithUnit(_ mps: Double, unit: SpeedUnit) -> String {
        "\(speed(mps, unit: unit)) \(unit.symbol)"
    }

    // MARK: - Time

    /// Run times: two decimals, the convention for acceleration timing.
    static func time(_ seconds: TimeInterval, decimals: Int = 2) -> String {
        guard seconds.isFinite else { return "--" }
        return String(format: "%.\(decimals)f", seconds)
    }

    static func timeWithUnit(_ seconds: TimeInterval) -> String {
        "\(time(seconds)) s"
    }

    /// Clock-style duration for long sessions, e.g. "12:04".
    static func clock(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Signed delta used in run comparison, e.g. "-0.21".
    static func signedTime(_ seconds: TimeInterval, decimals: Int = 2) -> String {
        let formatted = String(format: "%.\(decimals)f", abs(seconds))
        if abs(seconds) < 0.005 { return "0.00" }
        return (seconds < 0 ? "-" : "+") + formatted
    }

    // MARK: - G

    static func gForce(_ value: Double, decimals: Int = 2) -> String {
        String(format: "%.\(decimals)f", value)
    }

    static func gForceWithUnit(_ value: Double) -> String {
        "\(gForce(value)) G"
    }

    // MARK: - Distance

    /// Short distances (a run's rollout, the length of an acceleration run).
    static func shortDistance(_ meters: Double, unit: DistanceUnit, decimals: Int = 0) -> String {
        let value = unit.shortValue(fromMeters: meters)
        return "\(String(format: "%.\(decimals)f", value)) \(unit.shortSymbol)"
    }

    /// Long distances (odometer totals).
    static func longDistance(_ meters: Double, unit: DistanceUnit, decimals: Int = 2) -> String {
        let value = unit.longValue(fromMeters: meters)
        return "\(String(format: "%.\(decimals)f", value)) \(unit.longSymbol)"
    }

    /// Picks metres/feet under a kilometre and km/miles above it.
    static func adaptiveDistance(_ meters: Double, unit: DistanceUnit) -> String {
        let threshold = unit == .metric ? 1000.0 : UnitConversion.metersPerMile
        return meters < threshold
            ? shortDistance(meters, unit: unit)
            : longDistance(meters, unit: unit)
    }

    // MARK: - Elevation

    static func elevation(_ meters: Double, unit: DistanceUnit) -> String {
        let value = unit.shortValue(fromMeters: meters)
        return "\(Int(value.rounded())) \(unit.shortSymbol)"
    }

    static func signedElevation(_ meters: Double, unit: DistanceUnit) -> String {
        let value = unit.shortValue(fromMeters: meters)
        let rounded = Int(value.rounded())
        let sign = rounded > 0 ? "+" : ""
        return "\(sign)\(rounded) \(unit.shortSymbol)"
    }

    // MARK: - Accuracy

    static func accuracy(_ meters: Double) -> String {
        guard meters >= 0 else { return "--" }
        return meters < 10
            ? String(format: "±%.1f m", meters)
            : String(format: "±%.0f m", meters)
    }

    // MARK: - Dates

    static let runDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }()

    static let runDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    static let compactDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter
    }()

    static let isoTimestamp: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    /// Thousands-separated integer, e.g. "1,284".
    static func grouped(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? String(Int(value))
    }
}
