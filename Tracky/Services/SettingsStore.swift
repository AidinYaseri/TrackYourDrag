import Foundation
import SwiftUI
import Observation

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case dark
    case light
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dark: return "Dark"
        case .light: return "Light"
        case .system: return "System"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

/// How hard the app pushes the sensors.
///
/// iOS does not expose a GPS update rate: you ask for an accuracy and the
/// system decides. What this setting really controls is the motion sampling
/// rate and how strict the accuracy gate is, which together decide how much
/// battery a session costs.
enum SensorProfile: String, CaseIterable, Identifiable, Codable {
    case maximum
    case balanced
    case economy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .maximum: return "Maximum"
        case .balanced: return "Balanced"
        case .economy: return "Battery saver"
        }
    }

    var detail: String {
        switch self {
        case .maximum: return "100 Hz motion, strictest accuracy gate. Best for timing."
        case .balanced: return "50 Hz motion. The right choice for almost everyone."
        case .economy: return "25 Hz motion, looser accuracy gate. Longest battery life."
        }
    }

    /// Device-motion updates per second.
    var motionFrequency: Double {
        switch self {
        case .maximum: return 100
        case .balanced: return 50
        case .economy: return 25
        }
    }

    /// Worst horizontal accuracy still accepted, metres.
    var accuracyLimit: Double {
        switch self {
        case .maximum: return 20
        case .balanced: return 35
        case .economy: return 50
        }
    }
}

/// App preferences, backed by `UserDefaults` and observable by SwiftUI.
@Observable
final class SettingsStore {

    private enum Key {
        static let speedUnit = "settings.speedUnit"
        static let distanceUnit = "settings.distanceUnit"
        static let temperatureUnit = "settings.temperatureUnit"
        static let appearance = "settings.appearance"
        static let sensorProfile = "settings.sensorProfile"
        static let rolloutEnabled = "settings.rolloutEnabled"
        static let storeRoute = "settings.storeRoute"
        static let haptics = "settings.haptics"
        static let keepAwake = "settings.keepAwake"
        static let demoMode = "settings.demoMode"
        static let backgroundTracking = "settings.backgroundTracking"
        static let selectedVehicle = "settings.selectedVehicleID"
        static let selectedMode = "settings.selectedModeID"
        static let customModes = "settings.customModes"
        static let seededSampleData = "settings.seededSampleData"
        static let acceptedDisclaimer = "settings.acceptedDisclaimer"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var speedUnit: SpeedUnit { didSet { defaults.set(speedUnit.rawValue, forKey: Key.speedUnit) } }
    var distanceUnit: DistanceUnit { didSet { defaults.set(distanceUnit.rawValue, forKey: Key.distanceUnit) } }
    var temperatureUnit: TemperatureUnit { didSet { defaults.set(temperatureUnit.rawValue, forKey: Key.temperatureUnit) } }
    var appearance: AppAppearance { didSet { defaults.set(appearance.rawValue, forKey: Key.appearance) } }
    var sensorProfile: SensorProfile { didSet { defaults.set(sensorProfile.rawValue, forKey: Key.sensorProfile) } }

    /// Drag-strip one-foot rollout on distance runs.
    var rolloutEnabled: Bool { didSet { defaults.set(rolloutEnabled, forKey: Key.rolloutEnabled) } }
    /// Whether new runs keep their GPS route.
    var storeRouteData: Bool { didSet { defaults.set(storeRouteData, forKey: Key.storeRoute) } }
    var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: Key.haptics)
            Haptics.isEnabled = hapticsEnabled
        }
    }
    var keepScreenAwake: Bool { didSet { defaults.set(keepScreenAwake, forKey: Key.keepAwake) } }
    /// Generates data instead of reading the sensors. Always on in the Simulator.
    var demoMode: Bool { didSet { defaults.set(demoMode, forKey: Key.demoMode) } }
    var backgroundTracking: Bool { didSet { defaults.set(backgroundTracking, forKey: Key.backgroundTracking) } }

    var selectedVehicleID: UUID? {
        didSet { defaults.set(selectedVehicleID?.uuidString, forKey: Key.selectedVehicle) }
    }
    var selectedModeID: String { didSet { defaults.set(selectedModeID, forKey: Key.selectedMode) } }
    var customModes: [RunMode] {
        didSet {
            if let data = try? JSONEncoder().encode(customModes) {
                defaults.set(data, forKey: Key.customModes)
            }
        }
    }
    var hasSeededSampleData: Bool { didSet { defaults.set(hasSeededSampleData, forKey: Key.seededSampleData) } }
    var acceptedDisclaimer: Bool { didSet { defaults.set(acceptedDisclaimer, forKey: Key.acceptedDisclaimer) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        speedUnit = SpeedUnit(rawValue: defaults.string(forKey: Key.speedUnit) ?? "") ?? .kmh
        distanceUnit = DistanceUnit(rawValue: defaults.string(forKey: Key.distanceUnit) ?? "") ?? .metric
        temperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: Key.temperatureUnit) ?? "") ?? .celsius
        appearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .dark
        sensorProfile = SensorProfile(rawValue: defaults.string(forKey: Key.sensorProfile) ?? "") ?? .balanced

        rolloutEnabled = defaults.object(forKey: Key.rolloutEnabled) as? Bool ?? false
        storeRouteData = defaults.object(forKey: Key.storeRoute) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        keepScreenAwake = defaults.object(forKey: Key.keepAwake) as? Bool ?? true
        demoMode = defaults.object(forKey: Key.demoMode) as? Bool ?? false
        backgroundTracking = defaults.object(forKey: Key.backgroundTracking) as? Bool ?? true

        if let stored = defaults.string(forKey: Key.selectedVehicle) {
            selectedVehicleID = UUID(uuidString: stored)
        } else {
            selectedVehicleID = nil
        }
        selectedModeID = defaults.string(forKey: Key.selectedMode) ?? RunMode.zeroToHundredKmh.id

        if let data = defaults.data(forKey: Key.customModes),
           let decoded = try? JSONDecoder().decode([RunMode].self, from: data) {
            customModes = decoded
        } else {
            customModes = []
        }

        hasSeededSampleData = defaults.bool(forKey: Key.seededSampleData)
        acceptedDisclaimer = defaults.bool(forKey: Key.acceptedDisclaimer)

        Haptics.isEnabled = hapticsEnabled
    }

    // MARK: - Derived

    /// Every mode the picker can offer, presets plus whatever the user built.
    var availableModes: [RunMode] {
        RunMode.allPresets + customModes
    }

    func mode(withID id: String) -> RunMode? {
        availableModes.first { $0.id == id }
    }

    var selectedMode: RunMode {
        mode(withID: selectedModeID) ?? .zeroToHundredKmh
    }

    func addCustomMode(_ mode: RunMode) {
        guard !customModes.contains(where: { $0.id == mode.id }) else { return }
        customModes.append(mode)
    }

    func removeCustomMode(id: String) {
        customModes.removeAll { $0.id == id }
        if selectedModeID == id {
            selectedModeID = RunMode.zeroToHundredKmh.id
        }
    }

    var processorConfiguration: TelemetryProcessor.Configuration {
        var configuration = TelemetryProcessor.Configuration.default
        configuration.accuracyLimit = sensorProfile.accuracyLimit
        return configuration
    }

    func engineConfiguration(for mode: RunMode) -> PerformanceEngine.Configuration {
        var configuration = PerformanceEngine.Configuration.default
        // One foot, the drag-racing convention.
        configuration.rolloutMeters = (rolloutEnabled && mode.targetDistance != nil)
            ? UnitConversion.meters(fromFeet: 1)
            : 0
        return configuration
    }
}
