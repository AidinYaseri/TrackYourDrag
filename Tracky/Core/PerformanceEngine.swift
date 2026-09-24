import Foundation

/// The measurement state machine.
///
/// Feed it processed telemetry and it works out when the run started, when it
/// finished, what happened in between, and whether the answer can be trusted.
/// It knows nothing about SwiftUI, Core Location or the database, so every
/// behaviour below is exercised directly in the unit tests.
///
/// ## How the timing works
///
/// GPS lands roughly ten times a second, so a car almost never gets sampled at
/// exactly 100 km/h or exactly 402 m. Waiting for a sample that matches would
/// add up to a tenth of a second of error, which is an eternity when the whole
/// number is under five seconds. Instead:
///
/// - **Finish** is the interpolated instant the speed (or distance) trace
///   crosses the target, taken from the two samples that straddle it.
/// - **Standing start** is back-extrapolated. The first two moving samples give
///   an acceleration; projecting that line back to zero speed estimates the
///   instant the car actually left the line, which is always somewhere between
///   the last stationary fix and the first moving one.
/// - **Rolling start** (60–130 mph and friends) is the interpolated instant the
///   speed trace crosses the start speed on the way up.
final class PerformanceEngine {

    // MARK: - Types

    struct Configuration: Equatable {
        /// Speed at or below which the car counts as stopped, m/s.
        var stationarySpeed: Double = 0.4
        /// Speed above which the car counts as moving, m/s (~1.8 km/h).
        var launchSpeedThreshold: Double = 0.5
        /// Acceleration needed to treat movement as a launch rather than a
        /// roll, m/s².
        var launchAcceleration: Double = 1.0
        /// A standing-start run requires the car to be stopped first.
        var requireStationaryBeforeLaunch = true
        /// Drop from the best speed so far that counts as the driver lifting, m/s.
        var abortSpeedDrop: Double = 2.8
        /// How long that drop has to persist before the run is thrown away.
        var abortAfterSeconds: TimeInterval = 1.5
        /// Safety net so an armed-and-forgotten run does not record forever.
        var maximumRunDuration: TimeInterval = 120
        /// Drag-strip style rollout: start the clock once the car has moved this
        /// far, rather than at the instant it moves. 0.3048 m is the classic
        /// one-foot rollout. Distance modes only.
        var rolloutMeters: Double = 0
        /// Telemetry kept before the start line so charts show the launch.
        var leadInSeconds: TimeInterval = 2
        /// Hard cap on buffered samples so a long armed session cannot grow
        /// without bound.
        var maximumBufferedSamples = 20_000

        static let `default` = Configuration()
    }

    enum AbortReason: String, Equatable {
        case decelerated
        case timedOut
        case manual
        case stopped

        var message: String {
            switch self {
            case .decelerated: return "Run cancelled — the car slowed down before the target."
            case .timedOut: return "Run cancelled — took too long to reach the target."
            case .manual: return "Run cancelled."
            case .stopped: return "Run cancelled — the car stopped."
            }
        }
    }

    enum State: Equatable {
        /// Not measuring anything.
        case idle
        /// Waiting for the start condition.
        case armed
        /// Moving, but the rollout distance has not been covered yet.
        case rollingOut
        /// The clock is running.
        case running
        case finished
        case aborted(AbortReason)
    }

    enum Event: Equatable {
        case armed
        case launched(at: TimeInterval)
        case split(Split)
        case finished(PerformanceResult)
        case aborted(AbortReason)
    }

    /// Live progress towards the target, for the running screen.
    struct Progress: Equatable {
        /// 0...1.
        var fraction: Double
        /// Current speed (m/s) or distance covered (m).
        var current: Double
        /// Target speed (m/s) or distance (m).
        var target: Double
        var isDistance: Bool
        /// Seconds since the clock started.
        var elapsed: TimeInterval
    }

    private struct SplitTarget {
        var label: String
        /// Distance past the start line, metres.
        var distance: Double?
        /// Absolute speed, m/s.
        var speed: Double?
    }

    // MARK: - Stored state

    private(set) var mode: RunMode
    private(set) var configuration: Configuration
    private(set) var state: State = .idle
    private(set) var splits: [Split] = []

    private var buffer: [TelemetrySample] = []
    private var lastEvaluated: TelemetrySample?

    private var sawStationary = false
    /// Last sample below the launch threshold.
    private var preLaunchSample: TelemetrySample?
    /// First sample above the launch threshold.
    private var firstMovingSample: TelemetrySample?

    private var launchTime: TimeInterval?
    private var launchDistance: Double = 0

    private var startTime: TimeInterval?
    private var startDistance: Double = 0
    private var startSpeed: Double = 0

    private var maxSpeedSinceStart: Double = 0
    private var decelerationSince: TimeInterval?
    private var pendingSplits: [SplitTarget] = []

    // MARK: - Init

    init(mode: RunMode, configuration: Configuration = .default) {
        self.mode = mode
        self.configuration = configuration
    }

    // MARK: - Control

    func update(mode newMode: RunMode) {
        mode = newMode
        reset()
    }

    func update(configuration newConfiguration: Configuration) {
        configuration = newConfiguration
    }

    func reset() {
        state = .idle
        buffer.removeAll(keepingCapacity: true)
        lastEvaluated = nil
        sawStationary = false
        preLaunchSample = nil
        firstMovingSample = nil
        launchTime = nil
        launchDistance = 0
        startTime = nil
        startDistance = 0
        startSpeed = 0
        maxSpeedSinceStart = 0
        decelerationSince = nil
        splits = []
        pendingSplits = []
    }

    /// Puts the engine into the waiting state. Nothing is timed until the start
    /// condition is met, so the driver can arm the run before setting off and
    /// never touch the phone again.
    @discardableResult
    func arm() -> Event {
        reset()
        state = .armed
        pendingSplits = Self.splitTargets(for: mode)
        return .armed
    }

    @discardableResult
    func cancel() -> Event? {
        switch state {
        case .running, .rollingOut, .armed:
            state = .aborted(.manual)
            return .aborted(.manual)
        case .idle, .finished, .aborted:
            return nil
        }
    }

    var isMeasuring: Bool {
        switch state {
        case .running, .rollingOut: return true
        default: return false
        }
    }

    // MARK: - Ingest

    /// Feeds one processed sample and returns whatever happened as a result.
    ///
    /// Every sample is buffered so charts and G maxima keep full resolution,
    /// but the start/finish decisions are only ever taken on samples backed by a
    /// real GPS fix. Motion-predicted samples smooth the display; they are not
    /// allowed to decide a time.
    @discardableResult
    func ingest(_ sample: TelemetrySample) -> [Event] {
        switch state {
        case .idle, .finished, .aborted:
            return []
        case .armed, .rollingOut, .running:
            break
        }

        record(sample)
        guard sample.isGPSUpdate else { return [] }
        defer { lastEvaluated = sample }

        var events: [Event] = []
        switch state {
        case .armed:
            events.append(contentsOf: detectStart(sample))
        case .rollingOut:
            events.append(contentsOf: advanceRollout(sample))
        case .running:
            events.append(contentsOf: advanceRun(sample))
        default:
            break
        }
        return events
    }

    private func record(_ sample: TelemetrySample) {
        buffer.append(sample)
        if buffer.count > configuration.maximumBufferedSamples {
            buffer.removeFirst(buffer.count - configuration.maximumBufferedSamples)
        }
        // While waiting there is no point holding more than the chart lead-in.
        if state == .armed {
            let cutoff = sample.t - (configuration.leadInSeconds + 5)
            if let first = buffer.first, first.t < cutoff {
                buffer.removeAll { $0.t < cutoff }
            }
        }
    }

    // MARK: - Start detection

    private func detectStart(_ sample: TelemetrySample) -> [Event] {
        if sample.speed <= configuration.stationarySpeed {
            sawStationary = true
            preLaunchSample = sample
            firstMovingSample = nil
            return []
        }

        switch mode.target {
        case .speed(let from, _) where from > 0.001:
            return detectRollingStart(sample, startSpeed: from)
        default:
            return detectStandingStart(sample)
        }
    }

    /// Standing start: wait for two consecutive moving samples, then project the
    /// speed line back to zero to find the instant the car left the line.
    private func detectStandingStart(_ sample: TelemetrySample) -> [Event] {
        if configuration.requireStationaryBeforeLaunch && !sawStationary {
            preLaunchSample = sample
            return []
        }

        guard sample.speed > configuration.launchSpeedThreshold else {
            preLaunchSample = sample
            return []
        }

        guard let first = firstMovingSample else {
            firstMovingSample = sample
            return []
        }

        let dt = sample.t - first.t
        guard dt > 0 else { return [] }
        let acceleration = (sample.speed - first.speed) / dt

        // Moving but not really launching (rolling in traffic, GPS drift):
        // drop the candidate and keep waiting.
        guard acceleration >= configuration.launchAcceleration else {
            if sample.speed <= configuration.launchSpeedThreshold {
                firstMovingSample = nil
                preLaunchSample = sample
            } else {
                firstMovingSample = sample
            }
            return []
        }

        // Back-extrapolate to v = 0.
        var t0 = first.t - first.speed / acceleration
        var d0 = first.distance - first.speed * first.speed / (2 * acceleration)

        // The launch cannot be earlier than the last stationary fix or later
        // than the first moving one.
        if let previous = preLaunchSample {
            t0 = min(max(t0, previous.t), first.t)
            d0 = min(max(d0, previous.distance), first.distance)
        } else {
            t0 = min(t0, first.t)
            d0 = min(d0, first.distance)
        }

        launchTime = t0
        launchDistance = d0
        maxSpeedSinceStart = sample.speed
        decelerationSince = nil

        var events: [Event] = [.launched(at: t0)]

        if configuration.rolloutMeters > 0, mode.targetDistance != nil {
            state = .rollingOut
            events.append(contentsOf: advanceRollout(sample))
        } else {
            startTime = t0
            startDistance = d0
            startSpeed = 0
            state = .running
            events.append(contentsOf: advanceRun(sample))
        }
        return events
    }

    /// Rolling start: the clock begins the instant the speed trace crosses the
    /// start speed going up.
    private func detectRollingStart(_ sample: TelemetrySample, startSpeed target: Double) -> [Event] {
        guard let previous = lastEvaluated else { return [] }
        guard previous.speed < target, sample.speed >= target else { return [] }

        guard let crossing = Interpolation.bracketedCrossing(
            x0: previous.t, y0: previous.speed,
            x1: sample.t, y1: sample.speed,
            target: target
        ) else { return [] }

        let distanceAtCrossing = Interpolation.companionValue(
            at: crossing,
            x0: previous.t, x1: sample.t,
            v0: previous.distance, v1: sample.distance
        )

        launchTime = crossing
        launchDistance = distanceAtCrossing
        startTime = crossing
        startDistance = distanceAtCrossing
        startSpeed = target
        maxSpeedSinceStart = sample.speed
        decelerationSince = nil
        state = .running

        var events: [Event] = [.launched(at: crossing)]
        events.append(contentsOf: advanceRun(sample))
        return events
    }

    /// Distance runs with rollout enabled: the car is moving but the clock has
    /// not started yet.
    private func advanceRollout(_ sample: TelemetrySample) -> [Event] {
        guard let previous = lastEvaluated, launchTime != nil else { return [] }
        let target = launchDistance + configuration.rolloutMeters
        guard sample.distance >= target else { return [] }

        let crossing = Interpolation.bracketedCrossing(
            x0: previous.t, y0: previous.distance,
            x1: sample.t, y1: sample.distance,
            target: target
        ) ?? sample.t

        startTime = crossing
        startDistance = target
        startSpeed = Interpolation.companionValue(
            at: crossing,
            x0: previous.t, x1: sample.t,
            v0: previous.speed, v1: sample.speed
        )
        state = .running
        return advanceRun(sample)
    }

    // MARK: - Run progression

    private func advanceRun(_ sample: TelemetrySample) -> [Event] {
        guard let startTime else { return [] }
        var events: [Event] = []

        if sample.speed > maxSpeedSinceStart { maxSpeedSinceStart = sample.speed }

        // Abort checks first: there is no point recording splits on a run the
        // driver already gave up on.
        if let abort = abortReason(for: sample, startTime: startTime) {
            state = .aborted(abort)
            return [.aborted(abort)]
        }

        events.append(contentsOf: checkSplits(sample))

        if let finish = finishCrossing(sample) {
            let result = buildResult(
                finishTime: finish.time,
                finishDistance: finish.distance,
                finishSpeed: finish.speed
            )
            state = .finished
            events.append(.finished(result))
        }
        return events
    }

    private func abortReason(for sample: TelemetrySample, startTime: TimeInterval) -> AbortReason? {
        if sample.t - startTime > configuration.maximumRunDuration {
            return .timedOut
        }
        if sample.speed <= configuration.stationarySpeed && maxSpeedSinceStart > 2 {
            return .stopped
        }
        if sample.speed < maxSpeedSinceStart - configuration.abortSpeedDrop {
            if let since = decelerationSince {
                if sample.t - since >= configuration.abortAfterSeconds { return .decelerated }
            } else {
                decelerationSince = sample.t
            }
        } else if sample.speed > maxSpeedSinceStart - configuration.abortSpeedDrop / 2 {
            decelerationSince = nil
        }
        return nil
    }

    private func checkSplits(_ sample: TelemetrySample) -> [Event] {
        guard let previous = lastEvaluated, let startTime, !pendingSplits.isEmpty else { return [] }
        var events: [Event] = []

        while let next = pendingSplits.first {
            var crossing: TimeInterval?
            var speedAt: Double?
            var distanceAt: Double?

            if let distanceTarget = next.distance {
                let absolute = startDistance + distanceTarget
                guard sample.distance >= absolute else { break }
                crossing = Interpolation.bracketedCrossing(
                    x0: previous.t, y0: previous.distance,
                    x1: sample.t, y1: sample.distance,
                    target: absolute
                ) ?? sample.t
                speedAt = Interpolation.companionValue(
                    at: crossing ?? sample.t,
                    x0: previous.t, x1: sample.t,
                    v0: previous.speed, v1: sample.speed
                )
                distanceAt = distanceTarget
            } else if let speedTarget = next.speed {
                guard sample.speed >= speedTarget else { break }
                crossing = Interpolation.bracketedCrossing(
                    x0: previous.t, y0: previous.speed,
                    x1: sample.t, y1: sample.speed,
                    target: speedTarget
                ) ?? sample.t
                speedAt = speedTarget
                distanceAt = Interpolation.companionValue(
                    at: crossing ?? sample.t,
                    x0: previous.t, x1: sample.t,
                    v0: previous.distance, v1: sample.distance
                ) - startDistance
            } else {
                pendingSplits.removeFirst()
                continue
            }

            guard let time = crossing else { break }
            let split = Split(
                label: next.label,
                time: max(0, time - startTime),
                speed: speedAt,
                distance: distanceAt
            )
            splits.append(split)
            events.append(.split(split))
            pendingSplits.removeFirst()
        }
        return events
    }

    private func finishCrossing(_ sample: TelemetrySample) -> (time: TimeInterval, distance: Double, speed: Double)? {
        guard let previous = lastEvaluated else { return nil }

        switch mode.target {
        case .speed(_, let target):
            guard sample.speed >= target else { return nil }
            let time = Interpolation.bracketedCrossing(
                x0: previous.t, y0: previous.speed,
                x1: sample.t, y1: sample.speed,
                target: target
            ) ?? sample.t
            let distance = Interpolation.companionValue(
                at: time,
                x0: previous.t, x1: sample.t,
                v0: previous.distance, v1: sample.distance
            )
            return (time, distance, target)

        case .distance(let meters):
            let absolute = startDistance + meters
            guard sample.distance >= absolute else { return nil }
            let time = Interpolation.bracketedCrossing(
                x0: previous.t, y0: previous.distance,
                x1: sample.t, y1: sample.distance,
                target: absolute
            ) ?? sample.t
            // Speed at the finish line is the trap speed.
            let speed = Interpolation.companionValue(
                at: time,
                x0: previous.t, x1: sample.t,
                v0: previous.speed, v1: sample.speed
            )
            return (time, absolute, speed)
        }
    }

    // MARK: - Progress

    var progress: Progress? {
        guard let startTime, let latest = buffer.last else { return nil }
        let elapsed = max(0, latest.t - startTime)

        switch mode.target {
        case .speed(let from, let to):
            let fraction = Interpolation.fraction(from: from, to: to, value: latest.speed)
            return Progress(
                fraction: min(max(fraction, 0), 1),
                current: latest.speed,
                target: to,
                isDistance: false,
                elapsed: elapsed
            )
        case .distance(let meters):
            let covered = max(0, latest.distance - startDistance)
            return Progress(
                fraction: min(max(covered / meters, 0), 1),
                current: covered,
                target: meters,
                isDistance: true,
                elapsed: elapsed
            )
        }
    }

    /// Seconds the clock has been running, for the live timer.
    var elapsed: TimeInterval {
        guard let startTime, let latest = buffer.last else { return 0 }
        return max(0, latest.t - startTime)
    }

    // MARK: - Result

    private func buildResult(
        finishTime: TimeInterval,
        finishDistance: Double,
        finishSpeed: Double
    ) -> PerformanceResult {
        let start = startTime ?? finishTime
        let leadIn = start - configuration.leadInSeconds
        let window = buffer.filter { $0.t >= leadIn && $0.t <= finishTime }
        let measured = window.filter { $0.t >= start }

        var gforce = GForceAccumulator()
        var maxSpeed = finishSpeed
        for sample in measured {
            gforce.ingest(sample.gforce)
            if sample.speed > maxSpeed { maxSpeed = sample.speed }
        }

        let gpsSamples = measured.filter { $0.isGPSUpdate && $0.horizontalAccuracy >= 0 }
        var accuracy = AccuracySummary()
        if !gpsSamples.isEmpty {
            let values = gpsSamples.map(\.horizontalAccuracy)
            accuracy.average = values.reduce(0, +) / Double(values.count)
            accuracy.best = values.min() ?? -1
            accuracy.worst = values.max() ?? -1
            accuracy.sampleCount = values.count
            let span = (gpsSamples.last?.t ?? start) - (gpsSamples.first?.t ?? start)
            accuracy.sampleRate = span > 0.2 ? Double(values.count - 1) / span : 0
        }

        var elevation = ElevationSummary()
        if let first = measured.first, let last = measured.last {
            let altitudes = measured.map(\.altitude)
            elevation = ElevationSummary(
                start: first.altitude,
                end: last.altitude,
                minimum: altitudes.min() ?? first.altitude,
                maximum: altitudes.max() ?? first.altitude,
                source: last.elevationSource
            )
        }

        let duration = max(0, finishTime - start)
        let verdict = RunValidator.evaluate(
            accuracy: accuracy,
            rejectedFixes: 0,
            duration: duration,
            gforceSource: measured.last?.gforce.source ?? .unavailable
        )

        // Telemetry is rebased so t = 0 is the start line and distance = 0 is
        // the start point. Lead-in samples therefore carry negative times,
        // which is exactly what the charts want.
        let points: [TelemetryPoint] = window.map { sample in
            var point = sample.point
            point.t = sample.t - start
            point.distance = sample.distance - startDistance
            return point
        }

        var result = PerformanceResult(
            date: Date(),
            modeID: mode.id,
            modeTitle: mode.title,
            target: mode.target,
            duration: duration,
            distance: max(0, finishDistance - startDistance),
            startSpeed: startSpeed,
            endSpeed: finishSpeed,
            maxSpeed: maxSpeed
        )
        result.maxAccelerationG = gforce.maxAcceleration
        result.maxBrakingG = gforce.maxBraking
        result.maxLateralG = gforce.maxLateral
        result.maxCombinedG = gforce.maxCombined
        result.elevation = elevation
        result.accuracy = accuracy
        result.quality = verdict.quality
        result.isValid = verdict.isValid
        result.warnings = verdict.warnings
        result.splits = splits
        result.startCoordinate = measured.first?.coordinate ?? window.first?.coordinate
        result.endCoordinate = measured.last?.coordinate
        result.samples = points
        return result
    }

    // MARK: - Splits

    /// Distance markers used on drag-strip style runs, in metres.
    private static let distanceMarkers: [(label: String, meters: Double)] = [
        ("60 ft", UnitConversion.meters(fromFeet: 60)),
        ("330 ft", UnitConversion.meters(fromFeet: 330)),
        ("1/8 mile", UnitConversion.metersPerMile / 8),
        ("1000 ft", UnitConversion.meters(fromFeet: 1000)),
        ("1/4 mile", UnitConversion.metersPerMile / 4),
        ("1/2 mile", UnitConversion.metersPerMile / 2)
    ]

    private static func splitTargets(for mode: RunMode) -> [SplitTarget] {
        switch mode.target {
        case .distance(let meters):
            return distanceMarkers
                .filter { $0.meters < meters - 0.5 }
                .map { SplitTarget(label: $0.label, distance: $0.meters, speed: nil) }

        case .speed(let from, let to):
            let unit = mode.speedUnitHint ?? .kmh
            let markers: [Double] = unit == .mph ? [30, 60, 100] : [60, 100, 150]
            return markers
                .map { (display: $0, mps: unit.metersPerSecond(from: $0)) }
                .filter { $0.mps > from + 0.5 && $0.mps < to - 0.5 }
                .map {
                    SplitTarget(
                        label: "\(Int($0.display)) \(unit.symbol)",
                        distance: nil,
                        speed: $0.mps
                    )
                }
        }
    }
}
