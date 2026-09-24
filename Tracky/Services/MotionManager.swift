import Foundation
import CoreMotion
import Observation

/// Wraps Core Motion: device motion for G-force, and the barometer for
/// elevation.
///
/// Device motion is preferred over the raw accelerometer because Core Motion
/// has already separated gravity from vehicle acceleration and solved for the
/// device's attitude. A north-referenced attitude is requested when the
/// hardware can provide one, because that is what lets the G reading be split
/// into longitudinal and lateral in the car's frame.
@Observable
final class MotionManager {

    private(set) var isDeviceMotionAvailable = false
    private(set) var isBarometerAvailable = false
    private(set) var isRunning = false
    private(set) var latestSample: MotionSample?
    /// Metres of altitude change since the barometer started.
    private(set) var relativeAltitude: Double?
    private(set) var pressureKPa: Double?
    private(set) var isNorthReferenced = false

    @ObservationIgnored
    var onMotion: ((MotionSample) -> Void)?
    @ObservationIgnored
    var onBarometer: ((Double) -> Void)?

    @ObservationIgnored
    private let motion = CMMotionManager()
    @ObservationIgnored
    private let altimeter = CMAltimeter()
    @ObservationIgnored
    private lazy var queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.tracky.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInteractive
        return queue
    }()

    init() {
        isDeviceMotionAvailable = motion.isDeviceMotionAvailable
        isBarometerAvailable = CMAltimeter.isRelativeAltitudeAvailable()
    }

    /// - Parameter frequency: device motion updates per second. 50 Hz is
    ///   plenty for a G meter and costs far less battery than the 100 Hz
    ///   maximum.
    func start(frequency: Double = 50) {
        guard !isRunning else { return }
        isRunning = true
        startDeviceMotion(frequency: frequency)
        startBarometer()
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
        altimeter.stopRelativeAltitudeUpdates()
    }

    // MARK: - Device motion

    private func startDeviceMotion(frequency: Double) {
        guard motion.isDeviceMotionAvailable else { return }

        let frame = Self.bestAvailableReferenceFrame()
        isNorthReferenced = frame == .xTrueNorthZVertical || frame == .xMagneticNorthZVertical

        motion.deviceMotionUpdateInterval = 1.0 / max(1, frequency)
        motion.showsDeviceMovementDisplay = true

        let northReferenced = isNorthReferenced
        motion.startDeviceMotionUpdates(using: frame, to: queue) { [weak self] deviceMotion, _ in
            guard let self, let deviceMotion else { return }
            let sample = Self.makeSample(from: deviceMotion, isNorthReferenced: northReferenced)
            DispatchQueue.main.async {
                self.latestSample = sample
                self.onMotion?(sample)
            }
        }
    }

    /// True north is best because GPS course is also true-north based. Magnetic
    /// north is close enough to be useful, and the arbitrary frame still gives
    /// a correct vertical axis, which the G calculator handles as a fallback.
    private static func bestAvailableReferenceFrame() -> CMAttitudeReferenceFrame {
        let available = CMMotionManager.availableAttitudeReferenceFrames()
        if available.contains(.xTrueNorthZVertical) { return .xTrueNorthZVertical }
        if available.contains(.xMagneticNorthZVertical) { return .xMagneticNorthZVertical }
        return .xArbitraryZVertical
    }

    private static func makeSample(from deviceMotion: CMDeviceMotion, isNorthReferenced: Bool) -> MotionSample {
        let matrix = deviceMotion.attitude.rotationMatrix
        return MotionSample(
            timestamp: TimeReference.fromUptime(deviceMotion.timestamp),
            userAcceleration: Vector3(
                x: deviceMotion.userAcceleration.x,
                y: deviceMotion.userAcceleration.y,
                z: deviceMotion.userAcceleration.z
            ),
            gravity: Vector3(
                x: deviceMotion.gravity.x,
                y: deviceMotion.gravity.y,
                z: deviceMotion.gravity.z
            ),
            rotationRate: Vector3(
                x: deviceMotion.rotationRate.x,
                y: deviceMotion.rotationRate.y,
                z: deviceMotion.rotationRate.z
            ),
            rotationMatrix: Matrix3(
                m11: matrix.m11, m12: matrix.m12, m13: matrix.m13,
                m21: matrix.m21, m22: matrix.m22, m23: matrix.m23,
                m31: matrix.m31, m32: matrix.m32, m33: matrix.m33
            ),
            isNorthReferenced: isNorthReferenced
        )
    }

    // MARK: - Barometer

    private func startBarometer() {
        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data else { return }
            let relative = data.relativeAltitude.doubleValue
            let pressure = data.pressure.doubleValue
            DispatchQueue.main.async {
                self.relativeAltitude = relative
                self.pressureKPa = pressure
                self.onBarometer?(relative)
            }
        }
    }
}
