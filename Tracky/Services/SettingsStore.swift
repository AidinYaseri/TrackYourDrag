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

    // `@Observable` turns stored properties into computed ones, which rules out
    // `didSet`. So each preference is a tracked stored property with a plain
    // name prefixed by `stored`, wrapped in a computed property that writes the
    // new value through to `UserDefaults`. Reads and writes both go through the
    // tracked storage, so SwiftUI still sees every change.

    private var storedSpeedUnit: SpeedUnit
    var speedUnit: SpeedUnit {
        get { storedSpeedUnit }
        set {
            storedSpeedUnit = newValue
            defaults.set(newValue.rawValue, forKey: Key.speedUnit)
        }
    }

    private var storedDistanceUnit: DistanceUnit
    var distanceUnit: DistanceUnit {
        get { storedDistanceUnit }
        set {
            storedDistanceUnit = newValue
            defaults.set(newValue.rawValue, forKey: Key.distanceUnit)
        }
    }

    private var storedTemperatureUnit: TemperatureUnit
    var temperatureUnit: TemperatureUnit {
        get { storedTemperatureUnit }
        set {
            storedTemperatureUnit = newValue
            defaults.set(newValue.rawValue, forKey: Key.temperatureUnit)
        }
    }

    private var storedAppearance: AppAppearance
    var appearance: AppAppearance {
        get { storedAppearance }
        set {
            storedAppearance = newValue
            defaults.set(newValue.rawValue, forKey: Key.appearance)
        }
    }

    private var storedSensorProfile: SensorProfile
    var sensorProfile: SensorProfile {
        get { storedSensorProfile }
        set {
            storedSensorProfile = newValue
            defaults.set(newValue.rawValue, forKey: Key.sensorProfile)
        }
    }

    /// Drag-strip one-foot rollout on distance runs.
    private var storedRolloutEnabled: Bool
    var rolloutEnabled: Bool {
        get { storedRolloutEnabled }
        set {
            storedRolloutEnabled = newValue
            defaults.set(newValue, forKey: Key.rolloutEnabled)
        }
    }

    /// Whether new runs keep their GPS route.
    private var storedStoreRouteData: Bool
    var storeRouteData: Bool {
        get { storedStoreRouteData }
        set {
            storedStoreRouteData = newValue
            defaults.set(newValue, forKey: Key.storeRoute)
        }
    }

    private var storedHapticsEnabled: Bool
    var hapticsEnabled: Bool {
        get { storedHapticsEnabled }
        set {
            storedHapticsEnabled = newValue
            defaults.set(newValue, forKey: Key.haptics)
            Haptics.isEnabled = newValue
        }
    }

    private var storedKeepScreenAwake: Bool
    var keepScreenAwake: Bool {
        get { storedKeepScreenAwake }
        set {
            storedKeepScreenAwake = newValue
            defaults.set(newValue, forKey: Key.keepAwake)
        }
    }

    /// Generates data instead of reading the sensors. Always on in the Simulator.
    private var storedDemoMode: Bool
    var demoMode: Bool {
        get { storedDemoMode }
        set {
            storedDemoMode = newValue
            defaults.set(newValue, forKey: Key.demoMode)
        }
    }

    private var storedBackgroundTracking: Bool
    var backgroundTracking: Bool {
        get { storedBackgroundTracking }
        set {
            storedBackgroundTracking = newValue
            defaults.set(newValue, forKey: Key.backgroundTracking)
        }
    }

    private var storedSelectedVehicleID: UUID?
    var selectedVehicleID: UUID? {
        get { storedSelectedVehicleID }
        set {
            storedSelectedVehicleID = newValue
            defaults.set(newValue?.uuidString, forKey: Key.selectedVehicle)
        }
    }

    private var storedSelectedModeID: String
    var selectedModeID: String {
        get { storedSelectedModeID }
        set {
            storedSelectedModeID = newValue
            defaults.set(newValue, forKey: Key.selectedMode)
        }
    }

    private var storedCustomModes: [RunMode]
    var customModes: [RunMode] {
        get { storedCustomModes }
        set {
            storedCustomModes = newValue
            if let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: Key.customModes)
            }
        }
    }

    private var storedHasSeededSampleData: Bool
    var hasSeededSampleData: Bool {
        get { storedHasSeededSampleData }
        set {
            storedHasSeededSampleData = newValue
            defaults.set(newValue, forKey: Key.seededSampleData)
        }
    }

    private var storedAcceptedDisclaimer: Bool
    var acceptedDisclaimer: Bool {
        get { storedAcceptedDisclaimer }
        set {
            storedAcceptedDisclaimer = newValue
            defaults.set(newValue, forKey: Key.acceptedDisclaimer)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        storedSpeedUnit = SpeedUnit(rawValue: defaults.string(forKey: Key.speedUnit) ?? "") ?? .kmh
        storedDistanceUnit = DistanceUnit(rawValue: defaults.string(forKey: Key.distanceUnit) ?? "") ?? .metric
        storedTemperatureUnit = TemperatureUnit(rawValue: defaults.string(forKey: Key.temperatureUnit) ?? "") ?? .celsius
        storedAppearance = AppAppearance(rawValue: defaults.string(forKey: Key.appearance) ?? "") ?? .dark
        storedSensorProfile = SensorProfile(rawValue: defaults.string(forKey: Key.sensorProfile) ?? "") ?? .balanced

        storedRolloutEnabled = defaults.object(forKey: Key.rolloutEnabled) as? Bool ?? false
        storedStoreRouteData = defaults.object(forKey: Key.storeRoute) as? Bool ?? true
        storedHapticsEnabled = defaults.object(forKey: Key.haptics) as? Bool ?? true
        storedKeepScreenAwake = defaults.object(forKey: Key.keepAwake) as? Bool ?? true
        storedDemoMode = defaults.object(forKey: Key.demoMode) as? Bool ?? false
        storedBackgroundTracking = defaults.object(forKey: Key.backgroundTracking) as? Bool ?? true

        if let stored = defaults.string(forKey: Key.selectedVehicle) {
            storedSelectedVehicleID = UUID(uuidString: stored)
        } else {
            storedSelectedVehicleID = nil
        }
        storedSelectedModeID = defaults.string(forKey: Key.selectedMode) ?? RunMode.zeroToHundredKmh.id

        if let data = defaults.data(forKey: Key.customModes),
           let decoded = try? JSONDecoder().decode([RunMode].self, from: data) {
            storedCustomModes = decoded
        } else {
            storedCustomModes = []
        }

        storedHasSeededSampleData = defaults.bool(forKey: Key.seededSampleData)
        storedAcceptedDisclaimer = defaults.bool(forKey: Key.acceptedDisclaimer)

        Haptics.isEnabled = storedHapticsEnabled
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
