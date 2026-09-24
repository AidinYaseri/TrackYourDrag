import Foundation
import CoreLocation
import Observation

/// Wraps `CLLocationManager` and hands out plain `LocationSample` values.
///
/// Configured for vehicle use: best-for-navigation accuracy, no distance
/// filter, and the automotive activity type so iOS keeps the receiver awake
/// instead of trying to save power between fixes.
///
/// Main-thread bound. The underlying manager is created on the main thread, so
/// its delegate callbacks land there too and the observable properties are only
/// ever mutated from the main thread.
@Observable
final class LocationManager: NSObject {

    enum Availability {
        case unknown
        case denied
        case authorizedWhenInUse
        case authorizedAlways
        case servicesDisabled
    }

    private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined
    private(set) var latestSample: LocationSample?
    private(set) var isTracking = false
    private(set) var lastErrorMessage: String?
    /// Horizontal accuracy of the most recent fix, metres. -1 means no fix yet.
    private(set) var horizontalAccuracy: Double = -1
    /// Seconds since the last fix arrived, used to show "searching" again if
    /// the signal drops.
    private(set) var lastFixTime: TimeInterval?

    @ObservationIgnored
    var onSample: ((LocationSample) -> Void)?

    @ObservationIgnored
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        authorizationStatus = manager.authorizationStatus
    }

    // MARK: - Authorisation

    var availability: Availability {
        switch authorizationStatus {
        case .notDetermined: return .unknown
        case .restricted, .denied: return .denied
        case .authorizedWhenInUse: return .authorizedWhenInUse
        case .authorizedAlways: return .authorizedAlways
        @unknown default: return .unknown
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    func requestAuthorization() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            // Only asked for once a session is actually running, so the prompt
            // makes sense to the user.
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    // MARK: - Updates

    func start() {
        guard !isTracking else { return }
        guard isAuthorized else {
            requestAuthorization()
            return
        }
        isTracking = true
        manager.startUpdatingLocation()
        manager.startUpdatingHeading()
    }

    func stop() {
        guard isTracking else { return }
        isTracking = false
        manager.stopUpdatingLocation()
        manager.stopUpdatingHeading()
        setBackgroundUpdates(false)
    }

    /// Keeps the receiver running with the screen off so a session started in
    /// the driveway survives the drive to the test road.
    func setBackgroundUpdates(_ enabled: Bool) {
        guard authorizationStatus == .authorizedAlways else {
            manager.allowsBackgroundLocationUpdates = false
            return
        }
        manager.allowsBackgroundLocationUpdates = enabled
        manager.showsBackgroundLocationIndicator = enabled
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if isAuthorized && isTracking {
            manager.startUpdatingLocation()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        for location in locations {
            // A negative horizontal accuracy means the fix is not valid at all.
            guard location.horizontalAccuracy >= 0 else { continue }

            let sample = LocationSample(
                timestamp: TimeReference.fromDate(location.timestamp),
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                altitude: location.altitude,
                speed: location.speed,
                course: location.course,
                horizontalAccuracy: location.horizontalAccuracy,
                verticalAccuracy: location.verticalAccuracy,
                speedAccuracy: location.speedAccuracy
            )
            latestSample = sample
            horizontalAccuracy = location.horizontalAccuracy
            lastFixTime = sample.timestamp
            lastErrorMessage = nil
            onSample?(sample)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError, clError.code == .locationUnknown {
            // Transient: the receiver is still looking. Not worth surfacing.
            return
        }
        lastErrorMessage = error.localizedDescription
    }
}
