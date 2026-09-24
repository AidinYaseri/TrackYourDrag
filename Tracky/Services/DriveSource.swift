import Foundation

enum DriveAuthorization: Equatable {
    case notDetermined
    case denied
    case whenInUse
    case always
    /// No real sensors; data is being generated.
    case simulated

    var isUsable: Bool {
        switch self {
        case .whenInUse, .always, .simulated: return true
        case .notDetermined, .denied: return false
        }
    }
}

/// Everything the app needs from "the sensors", so the live hardware and the
/// simulator can be swapped without the rest of the app noticing.
protocol DriveSource: AnyObject {
    var onLocation: ((LocationSample) -> Void)? { get set }
    var onMotion: ((MotionSample) -> Void)? { get set }
    var onBarometer: ((Double) -> Void)? { get set }

    var isSimulated: Bool { get }
    var authorization: DriveAuthorization { get }
    var hasBarometer: Bool { get }
    var hasDeviceMotion: Bool { get }
    /// True when the attitude is north-referenced, which is what a full
    /// longitudinal/lateral G split needs.
    var isNorthReferenced: Bool { get }
    var isRunning: Bool { get }

    func requestAuthorization()
    func start()
    func stop()
    func setBackgroundUpdates(_ enabled: Bool)
    /// Motion updates per second.
    func setMotionFrequency(_ frequency: Double)
}

/// A source that can be told to act out a run, used in the simulator and in
/// the in-app demo mode.
protocol ScriptableDriveSource: DriveSource {
    func simulateLaunch()
    func simulateBraking()
    func simulateStop()
}

/// The real thing: Core Location plus Core Motion.
final class LiveDriveSource: DriveSource {

    let location = LocationManager()
    let motion = MotionManager()

    var onLocation: ((LocationSample) -> Void)?
    var onMotion: ((MotionSample) -> Void)?
    var onBarometer: ((Double) -> Void)?

    private var motionFrequency: Double = 50
    private(set) var isRunning = false

    init() {
        location.onSample = { [weak self] sample in self?.onLocation?(sample) }
        motion.onMotion = { [weak self] sample in self?.onMotion?(sample) }
        motion.onBarometer = { [weak self] relative in self?.onBarometer?(relative) }
    }

    var isSimulated: Bool { false }
    var hasBarometer: Bool { motion.isBarometerAvailable }
    var hasDeviceMotion: Bool { motion.isDeviceMotionAvailable }
    var isNorthReferenced: Bool { motion.isNorthReferenced }

    var authorization: DriveAuthorization {
        switch location.availability {
        case .unknown: return .notDetermined
        case .denied, .servicesDisabled: return .denied
        case .authorizedWhenInUse: return .whenInUse
        case .authorizedAlways: return .always
        }
    }

    func requestAuthorization() {
        location.requestAuthorization()
    }

    func start() {
        isRunning = true
        location.start()
        motion.start(frequency: motionFrequency)
    }

    func stop() {
        isRunning = false
        location.stop()
        motion.stop()
    }

    func setBackgroundUpdates(_ enabled: Bool) {
        location.setBackgroundUpdates(enabled)
    }

    func setMotionFrequency(_ frequency: Double) {
        motionFrequency = frequency
        guard isRunning else { return }
        motion.stop()
        motion.start(frequency: frequency)
    }
}
