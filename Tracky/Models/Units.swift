import Foundation

// MARK: - Unit preferences

enum SpeedUnit: String, CaseIterable, Codable, Identifiable {
    case kmh
    case mph

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .kmh: return "km/h"
        case .mph: return "mph"
        }
    }

    /// Converts metres per second into this unit.
    func value(fromMetersPerSecond mps: Double) -> Double {
        switch self {
        case .kmh: return mps * UnitConversion.mpsToKmh
        case .mph: return mps * UnitConversion.mpsToMph
        }
    }

    /// Converts a value in this unit back into metres per second.
    func metersPerSecond(from value: Double) -> Double {
        switch self {
        case .kmh: return value / UnitConversion.mpsToKmh
        case .mph: return value / UnitConversion.mpsToMph
        }
    }
}

enum DistanceUnit: String, CaseIterable, Codable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var longSymbol: String { self == .metric ? "km" : "mi" }
    var shortSymbol: String { self == .metric ? "m" : "ft" }

    /// Large distances: kilometres or miles.
    func longValue(fromMeters meters: Double) -> Double {
        self == .metric ? meters / 1000 : meters / UnitConversion.metersPerMile
    }

    /// Short distances: metres or feet.
    func shortValue(fromMeters meters: Double) -> Double {
        self == .metric ? meters : meters * UnitConversion.feetPerMeter
    }
}

enum TemperatureUnit: String, CaseIterable, Codable, Identifiable {
    case celsius
    case fahrenheit

    var id: String { rawValue }
    var symbol: String { self == .celsius ? "°C" : "°F" }

    func value(fromCelsius celsius: Double) -> Double {
        self == .celsius ? celsius : celsius * 9 / 5 + 32
    }
}

// MARK: - Constants

enum UnitConversion {
    static let mpsToKmh = 3.6
    static let mpsToMph = 2.236936292054402
    static let metersPerMile = 1609.344
    static let metersPerKilometer = 1000.0
    static let feetPerMeter = 3.280839895013123
    /// Standard gravity, used everywhere a G value is produced.
    static let standardGravity = 9.80665

    static func kmh(_ mps: Double) -> Double { mps * mpsToKmh }
    static func mph(_ mps: Double) -> Double { mps * mpsToMph }
    static func mpsFromKmh(_ kmh: Double) -> Double { kmh / mpsToKmh }
    static func mpsFromMph(_ mph: Double) -> Double { mph / mpsToMph }
    static func meters(fromFeet feet: Double) -> Double { feet / feetPerMeter }
}
