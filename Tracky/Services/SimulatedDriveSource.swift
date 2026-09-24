import Foundation

/// Generates believable GPS and motion data so the whole app — arming, launch
/// detection, interpolation, charts, maps, saving — can be exercised in the
/// iOS Simulator, where Core Location gives nothing useful and Core Motion
/// gives nothing at all.
///
/// The vehicle model is deliberately simple but physically sensible:
/// acceleration falls off exponentially with speed, limited by traction at
/// launch, which produces the familiar tapering speed curve of a real car.
final class SimulatedDriveSource: ScriptableDriveSource {

    enum Phase: Equatable {
        case idle
        case launching
        case cruising
        case braking
    }

    var onLocation: ((LocationSample) -> Void)?
    var onMotion: ((MotionSample) -> Void)?
    var onBarometer: ((Double) -> Void)?

    var isSimulated: Bool { true }
    var authorization: DriveAuthorization { .simulated }
    var hasBarometer: Bool { true }
    var hasDeviceMotion: Bool { true }
    var isNorthReferenced: Bool { true }
    private(set) var isRunning = false

    // MARK: - Vehicle model

    var vehicleModel = VehicleModel.default
    /// Speed at which the simulated driver lifts, m/s (~230 km/h).
    var topSpeed: Double = 64

    // MARK: - State

    private(set) var phase: Phase = .idle
    private var speed: Double = 0
    private var distance: Double = 0
    private var heading: Double = 42
    private var coordinate = Coordinate(latitude: 45.5019, longitude: -73.5674)
    private var baseAltitude: Double = 42
    private var barometricRelative: Double = 0
    private var longitudinalAcceleration: Double = 0
    private var lateralAcceleration: Double = 0
    private var launchTimer: TimeInterval = 0

    private var motionTimer: Timer?
    private var locationTimer: Timer?
    private var motionFrequency: Double = 50
    private var clock: TimeInterval = 0
    private var generator = SeededGenerator(seed: 0x5EED)

    // MARK: - Lifecycle

    func requestAuthorization() {}

    func start() {
        guard !isRunning else { return }
        isRunning = true
        clock = TimeReference.now
        scheduleTimers()
    }

    func stop() {
        isRunning = false
        motionTimer?.invalidate()
        locationTimer?.invalidate()
        motionTimer = nil
        locationTimer = nil
    }

    func setBackgroundUpdates(_ enabled: Bool) {}

    func setMotionFrequency(_ frequency: Double) {
        motionFrequency = max(10, frequency)
        guard isRunning else { return }
        motionTimer?.invalidate()
        locationTimer?.invalidate()
        scheduleTimers()
    }

    private func scheduleTimers() {
        let motionInterval = 1.0 / motionFrequency
        let motionTimer = Timer(timeInterval: motionInterval, repeats: true) { [weak self] _ in
            self?.stepMotion(dt: motionInterval)
        }
        // 10 Hz, which is what a modern iPhone realistically delivers.
        let locationTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.emitLocation()
        }
        RunLoop.main.add(motionTimer, forMode: .common)
        RunLoop.main.add(locationTimer, forMode: .common)
        self.motionTimer = motionTimer
        self.locationTimer = locationTimer
    }

    // MARK: - Scripted behaviour

    func simulateLaunch() {
        phase = .launching
        launchTimer = 0
    }

    func simulateBraking() {
        phase = .braking
    }

    func simulateStop() {
        phase = .idle
        speed = 0
        longitudinalAcceleration = 0
        lateralAcceleration = 0
    }

    // MARK: - Integration

    private func stepMotion(dt: Double) {
        clock += dt
        updateVehicle(dt: dt)

        // Build the acceleration in the world frame (x = north, y = west,
        // z = up) and hand it over with an identity attitude, which is exactly
        // what a phone perfectly aligned with the world would report.
        let theta = GeoMath.radians(heading)
        let aLong = longitudinalAcceleration + noise(0.25)
        let aLat = lateralAcceleration + noise(0.2)
        let north = aLong * cos(theta) - aLat * sin(theta)
        let west = -aLong * sin(theta) - aLat * cos(theta)
        let g = UnitConversion.standardGravity

        let sample = MotionSample(
            timestamp: clock,
            userAcceleration: Vector3(x: north / g, y: west / g, z: noise(0.12) / g),
            gravity: Vector3(x: 0, y: 0, z: -1),
            rotationRate: Vector3(x: 0, y: 0, z: -lateralAcceleration / max(speed, 1)),
            rotationMatrix: .identity,
            isNorthReferenced: true
        )
        onMotion?(sample)

        barometricRelative += (altitudeProfile() - baseAltitude - barometricRelative) * min(1, dt * 2)
        onBarometer?(barometricRelative)
    }

    private func updateVehicle(dt: Double) {
        switch phase {
        case .idle:
            longitudinalAcceleration = speed > 0 ? -3.0 : 0
            speed = max(0, speed + longitudinalAcceleration * dt)
            if speed == 0 { longitudinalAcceleration = 0 }
            lateralAcceleration = 0

        case .launching:
            launchTimer += dt
            longitudinalAcceleration = vehicleModel.acceleration(
                atSpeed: speed,
                secondsSinceLaunch: launchTimer
            )
            speed += longitudinalAcceleration * dt
            lateralAcceleration = noise(0.05)
            if speed >= topSpeed { phase = .braking }

        case .cruising:
            longitudinalAcceleration = noise(0.3)
            speed = max(0, speed + longitudinalAcceleration * dt)
            // A gentle sweeping bend so the lateral axis has something to show.
            lateralAcceleration = 2.4 * sin(clock / 6)
            heading += (lateralAcceleration / max(speed, 4)) * dt * 180 / .pi

        case .braking:
            longitudinalAcceleration = -vehicleModel.brakingDeceleration
            speed = max(0, speed + longitudinalAcceleration * dt)
            lateralAcceleration = 0
            if speed <= 0.01 {
                phase = .idle
                longitudinalAcceleration = 0
            }
        }

        distance += speed * dt
        if speed > 0.2 {
            coordinate = GeoMath.destination(
                lat: coordinate.latitude,
                lon: coordinate.longitude,
                bearingDegrees: heading,
                distanceMeters: speed * dt
            )
        }
    }

    /// Gentle rise and fall so the elevation display has something to track.
    private func altitudeProfile() -> Double {
        baseAltitude + sin(distance / 900) * 14
    }

    private func emitLocation() {
        let accuracy = 3.4 + abs(noise(1.1))
        let sample = LocationSample(
            timestamp: clock,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            altitude: altitudeProfile() + noise(2.5),
            speed: max(0, speed + noise(0.09)),
            course: speed > 0.5 ? heading : -1,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy * 1.6,
            speedAccuracy: 0.28
        )
        onLocation?(sample)
    }

    private func noise(_ magnitude: Double) -> Double {
        (generator.nextUnit() - 0.5) * 2 * magnitude
    }
}

/// Small deterministic generator so simulated runs are repeatable, which makes
/// the simulator useful for checking UI changes side by side.
struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 0x9E3779B97F4A7C15 : seed
    }

    mutating func next() -> UInt64 {
        // xorshift64*
        state ^= state >> 12
        state ^= state << 25
        state ^= state >> 27
        return state &* 2685821657736338717
    }

    /// Uniform value in 0..<1.
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }
}
