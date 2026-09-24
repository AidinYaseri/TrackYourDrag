import Foundation
import Observation
#if canImport(UIKit)
import UIKit
#endif

/// One point on the live G-force trace.
struct GTracePoint: Identifiable, Equatable {
    let t: TimeInterval
    let longitudinal: Double
    let lateral: Double
    let combined: Double

    var id: TimeInterval { t }
}

/// Ties the sensors, the telemetry processor and the performance engine
/// together and exposes exactly what the UI needs.
///
/// Everything here runs on the main actor. The heavy lifting happens in the
/// core types; this class is deliberately thin so the measurement logic stays
/// testable on its own.
@MainActor
@Observable
final class RunManager {

    enum Stage: Equatable {
        /// A session may be recording, but no run is armed.
        case idle
        /// Waiting for the car to launch.
        case armed
        /// The clock is running.
        case running
        /// A run finished and is waiting to be saved or discarded.
        case result
    }

    // MARK: - Live telemetry

    private(set) var stage: Stage = .idle
    private(set) var isSessionActive = false

    private(set) var speed: Double = 0
    private(set) var gforce = GForceReading()
    private(set) var altitude: Double = 0
    private(set) var sessionDistance: Double = 0
    private(set) var horizontalAccuracy: Double = -1
    private(set) var hasFix = false
    private(set) var statistics = SessionStatistics()
    private(set) var gTrace: [GTracePoint] = []
    private(set) var progress: PerformanceEngine.Progress?
    private(set) var elapsed: TimeInterval = 0
    private(set) var latestSplit: Split?
    private(set) var latestResult: PerformanceResult?
    /// Short-lived message shown on the dashboard (aborts, signal problems).
    private(set) var statusMessage: String?

    var selectedMode: RunMode {
        didSet {
            settings.selectedModeID = selectedMode.id
            engine.update(mode: selectedMode)
            engine.update(configuration: settings.engineConfiguration(for: selectedMode))
            if stage == .armed { arm() }
        }
    }

    // MARK: - Dependencies

    @ObservationIgnored private let settings: SettingsStore
    @ObservationIgnored private var source: DriveSource
    @ObservationIgnored private let processor: TelemetryProcessor
    @ObservationIgnored private let engine: PerformanceEngine
    @ObservationIgnored private var lastPublish: TimeInterval = 0
    @ObservationIgnored private var statusClearTask: Task<Void, Never>?
    @ObservationIgnored private var scriptedLaunchTask: Task<Void, Never>?

    /// How often observable state is refreshed. Motion arrives up to 100 times
    /// a second; redrawing that often would burn battery for nothing.
    @ObservationIgnored private let publishInterval: TimeInterval = 1.0 / 20.0
    /// Seconds of G history kept for the live trace.
    @ObservationIgnored private let traceWindow: TimeInterval = 6

    init(settings: SettingsStore, source: DriveSource? = nil) {
        self.settings = settings
        self.source = source ?? RunManager.makeSource(settings: settings)
        self.processor = TelemetryProcessor(configuration: settings.processorConfiguration)
        let mode = settings.selectedMode
        self.selectedMode = mode
        self.engine = PerformanceEngine(
            mode: mode,
            configuration: settings.engineConfiguration(for: mode)
        )
        attach()
    }

    static func makeSource(settings: SettingsStore) -> DriveSource {
        #if targetEnvironment(simulator)
        // The Simulator gives no motion at all and only a fixed location, so
        // the app always generates its own data there.
        return SimulatedDriveSource()
        #else
        return settings.demoMode ? SimulatedDriveSource() : LiveDriveSource()
        #endif
    }

    private func attach() {
        source.onLocation = { [weak self] sample in self?.handle(location: sample) }
        source.onMotion = { [weak self] sample in self?.handle(motion: sample) }
        source.onBarometer = { [weak self] relative in self?.processor.ingestBarometer(relativeAltitude: relative) }
        source.setMotionFrequency(settings.sensorProfile.motionFrequency)
    }

    // MARK: - Source information

    var isSimulated: Bool { source.isSimulated }
    var authorization: DriveAuthorization { source.authorization }
    var hasBarometer: Bool { source.hasBarometer }
    var hasDeviceMotion: Bool { source.hasDeviceMotion }
    var isNorthReferenced: Bool { source.isNorthReferenced }
    var gpsQuality: GPSQuality { GPSQuality.from(horizontalAccuracy: horizontalAccuracy) }
    var elevationSource: ElevationSource { statistics.elevationSummary.source }

    /// Rebuilt when demo mode is toggled in Settings.
    func rebuildSource() {
        let wasActive = isSessionActive
        stopSession()
        source.onLocation = nil
        source.onMotion = nil
        source.onBarometer = nil
        source = RunManager.makeSource(settings: settings)
        attach()
        if wasActive { startSession() }
    }

    func applySettings() {
        processor.apply(configuration: settings.processorConfiguration)
        engine.update(configuration: settings.engineConfiguration(for: selectedMode))
        source.setMotionFrequency(settings.sensorProfile.motionFrequency)
        source.setBackgroundUpdates(settings.backgroundTracking && isSessionActive)
        setIdleTimerDisabled(settings.keepScreenAwake && isSessionActive)
    }

    // MARK: - Session

    func requestAuthorization() {
        source.requestAuthorization()
    }

    /// Starts reading the sensors. Deliberately separate from arming a run so
    /// the driver can get a fix in the driveway and then leave the phone alone.
    func startSession() {
        guard !isSessionActive else { return }
        guard authorization.isUsable else {
            requestAuthorization()
            return
        }
        isSessionActive = true
        processor.reset()
        statistics.reset()
        gTrace.removeAll()
        source.start()
        source.setBackgroundUpdates(settings.backgroundTracking)
        setIdleTimerDisabled(settings.keepScreenAwake)
    }

    func stopSession() {
        guard isSessionActive else { return }
        isSessionActive = false
        scriptedLaunchTask?.cancel()
        source.stop()
        engine.reset()
        stage = .idle
        progress = nil
        elapsed = 0
        setIdleTimerDisabled(false)
    }

    // MARK: - Runs

    /// Arms the selected mode. Nothing is timed until the car actually launches.
    func arm() {
        if !isSessionActive { startSession() }
        engine.update(configuration: settings.engineConfiguration(for: selectedMode))
        engine.arm()
        stage = .armed
        latestResult = nil
        latestSplit = nil
        progress = nil
        elapsed = 0
        Haptics.fire(.medium)
        scheduleScriptedLaunch()
    }

    func cancelRun() {
        scriptedLaunchTask?.cancel()
        engine.cancel()
        engine.reset()
        stage = .idle
        progress = nil
        elapsed = 0
        latestSplit = nil
        Haptics.fire(.light)
    }

    /// Called once the result has been saved or thrown away.
    func clearResult() {
        latestResult = nil
        stage = .idle
        engine.reset()
        progress = nil
        elapsed = 0
    }

    /// Discards the result and immediately arms the same mode again, so a
    /// second attempt needs one tap instead of four.
    func rearm() {
        latestResult = nil
        arm()
    }

    // MARK: - Sensor input

    private func handle(location sample: LocationSample) {
        guard let processed = processor.process(location: sample) else {
            // The fix was rejected. Tell the driver only if it keeps happening.
            if case .rejectAccuracy? = processor.lastRejection {
                horizontalAccuracy = sample.horizontalAccuracy
            }
            return
        }
        hasFix = true
        consume(processed, force: true)
    }

    private func handle(motion sample: MotionSample) {
        guard let processed = processor.process(motion: sample) else { return }
        consume(processed, force: false)
    }

    private func consume(_ sample: TelemetrySample, force: Bool) {
        let events = engine.ingest(sample)
        appendTrace(sample)

        let now = sample.t
        if force || now - lastPublish >= publishInterval {
            lastPublish = now
            publish(sample)
        }

        for event in events { handle(event: event) }
    }

    private func publish(_ sample: TelemetrySample) {
        speed = sample.speed
        gforce = sample.gforce
        altitude = sample.altitude
        sessionDistance = sample.distance
        horizontalAccuracy = sample.horizontalAccuracy
        statistics = processor.statistics
        if engine.isMeasuring {
            progress = engine.progress
            elapsed = engine.elapsed
        }
    }

    private func appendTrace(_ sample: TelemetrySample) {
        // The trace is drawn at roughly the publish rate, not at motion rate.
        if let last = gTrace.last, sample.t - last.t < publishInterval { return }
        gTrace.append(
            GTracePoint(
                t: sample.t,
                longitudinal: sample.gforce.longitudinal,
                lateral: sample.gforce.lateral,
                combined: sample.gforce.combined
            )
        )
        let cutoff = sample.t - traceWindow
        if let first = gTrace.first, first.t < cutoff {
            gTrace.removeAll { $0.t < cutoff }
        }
    }

    // MARK: - Engine events

    private func handle(event: PerformanceEngine.Event) {
        switch event {
        case .armed:
            stage = .armed

        case .launched:
            stage = .running
            statusMessage = nil
            Haptics.fire(.heavy)

        case .split(let split):
            latestSplit = split
            Haptics.fire(.light)

        case .finished(let result):
            latestResult = result
            stage = .result
            progress = nil
            Haptics.fire(.success)
            scheduleScriptedBraking()

        case .resultRefined(let result):
            // Only replace the displayed result if the user has not moved on.
            if latestResult?.id == result.id {
                latestResult = result
            }

        case .aborted(let reason):
            show(status: reason.message)
            Haptics.fire(.warning)
            // Re-arm straight away: the driver should be able to try again
            // without picking the phone up.
            if reason != .manual {
                engine.arm()
                stage = .armed
                progress = nil
                elapsed = 0
                scheduleScriptedLaunch()
            } else {
                stage = .idle
            }
        }
    }

    private func show(status message: String) {
        statusMessage = message
        statusClearTask?.cancel()
        statusClearTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.statusMessage = nil
        }
    }

    // MARK: - Scripted driving (Simulator / demo mode)

    private func scheduleScriptedLaunch() {
        guard let scriptable = source as? ScriptableDriveSource else { return }
        scriptedLaunchTask?.cancel()
        scriptable.simulateStop()
        scriptedLaunchTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled, self?.stage == .armed else { return }
            scriptable.simulateLaunch()
        }
    }

    private func scheduleScriptedBraking() {
        guard let scriptable = source as? ScriptableDriveSource else { return }
        Task {
            try? await Task.sleep(for: .milliseconds(900))
            scriptable.simulateBraking()
        }
    }

    // MARK: - Screen

    private func setIdleTimerDisabled(_ disabled: Bool) {
        #if canImport(UIKit) && !os(watchOS)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }
}
