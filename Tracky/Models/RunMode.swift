import Foundation

/// What a run is measuring.
enum RunTarget: Codable, Hashable {
    /// Time between two ground speeds, both in metres per second.
    /// `from == 0` means a standing start.
    case speed(from: Double, to: Double)
    /// Time to cover a distance from a standing start, in metres.
    case distance(meters: Double)
}

enum RunModeCategory: String, Codable, CaseIterable, Identifiable {
    case acceleration
    case distance
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .acceleration: return "Acceleration"
        case .distance: return "Distance"
        case .custom: return "Custom"
        }
    }

    var symbolName: String {
        switch self {
        case .acceleration: return "gauge.with.dots.needle.67percent"
        case .distance: return "flag.checkered"
        case .custom: return "slider.horizontal.3"
        }
    }
}

/// A selectable measurement. Modes are values, not managed objects, so the
/// engine and the tests can build one without touching the database.
struct RunMode: Identifiable, Codable, Hashable {
    var id: String
    /// Full label, e.g. "0 – 100 km/h".
    var title: String
    /// Compact label for chips and cards, e.g. "0–100".
    var shortTitle: String
    var category: RunModeCategory
    var target: RunTarget
    var isCustom: Bool
    /// Which unit the mode was defined in. Used to pick sensible intermediate
    /// splits (a 0–200 km/h run splits at 60/100/150 km/h, a 0–100 mph run at
    /// 30/60 mph) and to label the run the way the driver asked for it, even if
    /// the app is currently showing the other unit. Optional so older stored
    /// custom modes still decode.
    var speedUnitHint: SpeedUnit?

    init(
        id: String,
        title: String,
        shortTitle: String,
        category: RunModeCategory,
        target: RunTarget,
        isCustom: Bool = false,
        speedUnitHint: SpeedUnit? = nil
    ) {
        self.id = id
        self.title = title
        self.shortTitle = shortTitle
        self.category = category
        self.target = target
        self.isCustom = isCustom
        self.speedUnitHint = speedUnitHint
    }

    /// True when the car has to be stopped before the run can begin.
    var requiresStandingStart: Bool {
        switch target {
        case .speed(let from, _): return from <= 0.001
        case .distance: return true
        }
    }

    /// Target distance in metres, for distance modes.
    var targetDistance: Double? {
        if case .distance(let meters) = target { return meters }
        return nil
    }

    /// Start and finish speeds in m/s, for speed modes.
    var speedBounds: (from: Double, to: Double)? {
        if case .speed(let from, let to) = target { return (from, to) }
        return nil
    }

    // MARK: - Builders

    static func acceleration(fromKmh: Double, toKmh: Double, isCustom: Bool = false) -> RunMode {
        let from = UnitConversion.mpsFromKmh(fromKmh)
        let to = UnitConversion.mpsFromKmh(toKmh)
        return RunMode(
            id: "kmh-\(Self.trim(fromKmh))-\(Self.trim(toKmh))",
            title: "\(Self.trim(fromKmh)) – \(Self.trim(toKmh)) km/h",
            shortTitle: "\(Self.trim(fromKmh))–\(Self.trim(toKmh))",
            category: isCustom ? .custom : .acceleration,
            target: .speed(from: from, to: to),
            isCustom: isCustom,
            speedUnitHint: .kmh
        )
    }

    static func acceleration(fromMph: Double, toMph: Double, isCustom: Bool = false) -> RunMode {
        let from = UnitConversion.mpsFromMph(fromMph)
        let to = UnitConversion.mpsFromMph(toMph)
        return RunMode(
            id: "mph-\(Self.trim(fromMph))-\(Self.trim(toMph))",
            title: "\(Self.trim(fromMph)) – \(Self.trim(toMph)) mph",
            shortTitle: "\(Self.trim(fromMph))–\(Self.trim(toMph))",
            category: isCustom ? .custom : .acceleration,
            target: .speed(from: from, to: to),
            isCustom: isCustom,
            speedUnitHint: .mph
        )
    }

    static func distance(
        meters: Double,
        id: String? = nil,
        title: String? = nil,
        shortTitle: String? = nil,
        isCustom: Bool = false
    ) -> RunMode {
        let resolvedTitle = title ?? "\(Self.trim(meters)) m"
        return RunMode(
            id: id ?? "dist-\(Self.trim(meters))",
            title: resolvedTitle,
            shortTitle: shortTitle ?? resolvedTitle,
            category: isCustom ? .custom : .distance,
            target: .distance(meters: meters),
            isCustom: isCustom,
            speedUnitHint: nil
        )
    }

    private static func trim(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value.rounded())) : String(format: "%.1f", value)
    }
}

// MARK: - Presets

extension RunMode {
    static let zeroToSixtyMph = RunMode.acceleration(fromMph: 0, toMph: 60)
    static let zeroToHundredKmh = RunMode.acceleration(fromKmh: 0, toKmh: 100)
    static let zeroToHundredMph = RunMode.acceleration(fromMph: 0, toMph: 100)
    static let zeroToTwoHundredKmh = RunMode.acceleration(fromKmh: 0, toKmh: 200)
    static let sixtyToOneThirtyMph = RunMode.acceleration(fromMph: 60, toMph: 130)

    static let eighthMile = RunMode.distance(
        meters: UnitConversion.metersPerMile / 8,
        id: "eighth-mile",
        title: "1/8 mile",
        shortTitle: "1/8 mi"
    )
    static let quarterMile = RunMode.distance(
        meters: UnitConversion.metersPerMile / 4,
        id: "quarter-mile",
        title: "1/4 mile",
        shortTitle: "1/4 mi"
    )
    static let halfMile = RunMode.distance(
        meters: UnitConversion.metersPerMile / 2,
        id: "half-mile",
        title: "1/2 mile",
        shortTitle: "1/2 mi"
    )
    static let oneKilometer = RunMode.distance(
        meters: 1000,
        id: "one-km",
        title: "1 km",
        shortTitle: "1 km"
    )

    static let accelerationPresets: [RunMode] = [
        .zeroToSixtyMph,
        .zeroToHundredKmh,
        .zeroToHundredMph,
        .zeroToTwoHundredKmh,
        .sixtyToOneThirtyMph
    ]

    static let distancePresets: [RunMode] = [
        .eighthMile,
        .quarterMile,
        .halfMile,
        .oneKilometer
    ]

    /// Offered as one-tap starting points in the custom sheet.
    static let customSuggestions: [RunMode] = [
        .acceleration(fromKmh: 0, toKmh: 80, isCustom: true),
        .acceleration(fromKmh: 50, toKmh: 100, isCustom: true),
        .acceleration(fromKmh: 100, toKmh: 200, isCustom: true),
        .acceleration(fromKmh: 80, toKmh: 120, isCustom: true)
    ]

    static let allPresets: [RunMode] = accelerationPresets + distancePresets

    static func preset(id: String) -> RunMode? {
        allPresets.first { $0.id == id }
    }
}
