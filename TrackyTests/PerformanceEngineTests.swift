import XCTest
@testable import Tracky

/// The engine is checked against constant-acceleration physics, where every
/// answer can be worked out on paper: a speed `v` is reached at `v / a` and a
/// distance `d` at `sqrt(2d / a)`.
final class PerformanceEngineTests: XCTestCase {

    // MARK: - Speed thresholds

    func testZeroToHundredKmhMatchesThePhysics() {
        let acceleration = 5.0
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()

        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(acceleration)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        let expected = UnitConversion.mpsFromKmh(100) / acceleration
        XCTAssertEqual(result!.duration, expected, accuracy: 0.02)
    }

    func testTimeIsInterpolatedRatherThanRoundedToTheNextSample() {
        // With a = 5 m/s² the car passes 100 km/h at 5.5556 s, which lands
        // between the 5.5 s and 5.6 s fixes. Waiting for a sample would give
        // 5.6; interpolating gives the real number.
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(5.0, interval: 0.1)
        )
        let duration = SyntheticDrive.finishedResult(in: events)?.duration

        XCTAssertNotNil(duration)
        XCTAssertLessThan(duration!, 5.59)
        XCTAssertGreaterThan(duration!, 5.52)
    }

    func testResultIsStableAcrossSampleRates() {
        // A 10 Hz stream and a 5 Hz stream of the same drive should agree, which
        // is only true if the crossings are interpolated.
        let fast = measuredDuration(interval: 0.1)
        let slow = measuredDuration(interval: 0.2)
        XCTAssertEqual(fast, slow, accuracy: 0.05)
    }

    private func measuredDuration(interval: TimeInterval) -> Double {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(5.0, interval: interval)
        )
        return SyntheticDrive.finishedResult(in: events)?.duration ?? -1
    }

    func testRollingStartMeasuresFromTheStartSpeed() {
        let acceleration = 3.0
        let engine = PerformanceEngine(mode: .sixtyToOneThirtyMph)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(acceleration, duration: 40)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        let from = UnitConversion.mpsFromMph(60)
        let to = UnitConversion.mpsFromMph(130)
        XCTAssertEqual(result!.duration, (to - from) / acceleration, accuracy: 0.02)
        XCTAssertEqual(result!.startSpeed, from, accuracy: 0.01)
        XCTAssertEqual(result!.endSpeed, to, accuracy: 0.01)
    }

    // MARK: - Distance thresholds

    func testQuarterMileMatchesThePhysics() {
        let acceleration = 4.0
        let engine = PerformanceEngine(mode: .quarterMile)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(acceleration, duration: 40)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        let target = UnitConversion.metersPerMile / 4
        let expected = (2 * target / acceleration).squareRoot()
        XCTAssertEqual(result!.duration, expected, accuracy: 0.05)
        XCTAssertEqual(result!.distance, target, accuracy: 0.5)
    }

    func testTrapSpeedIsReadOffAtTheFinishLine() {
        let acceleration = 4.0
        let engine = PerformanceEngine(mode: .quarterMile)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(acceleration, duration: 40)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        let target = UnitConversion.metersPerMile / 4
        let expectedTime = (2 * target / acceleration).squareRoot()
        XCTAssertEqual(result!.trapSpeed ?? 0, acceleration * expectedTime, accuracy: 0.3)
    }

    func testRolloutStartsTheClockAfterTheFirstFoot() {
        let acceleration = 4.0
        var configuration = PerformanceEngine.Configuration.default
        configuration.rolloutMeters = UnitConversion.meters(fromFeet: 1)

        let engine = PerformanceEngine(mode: .quarterMile, configuration: configuration)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(acceleration, duration: 40)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        let rollout = configuration.rolloutMeters
        let target = UnitConversion.metersPerMile / 4
        let startTime = (2 * rollout / acceleration).squareRoot()
        let finishTime = (2 * (target + rollout) / acceleration).squareRoot()
        XCTAssertEqual(result!.duration, finishTime - startTime, accuracy: 0.06)
    }

    func testRolloutProducesAQuickerTimeThanNoRollout() {
        let acceleration = 4.0
        var configuration = PerformanceEngine.Configuration.default
        configuration.rolloutMeters = UnitConversion.meters(fromFeet: 1)

        let withRollout = PerformanceEngine(mode: .quarterMile, configuration: configuration)
        withRollout.arm()
        let rolloutEvents = SyntheticDrive.run(
            withRollout,
            with: SyntheticDrive.constantAcceleration(acceleration, duration: 40)
        )

        let plain = PerformanceEngine(mode: .quarterMile)
        plain.arm()
        let plainEvents = SyntheticDrive.run(
            plain,
            with: SyntheticDrive.constantAcceleration(acceleration, duration: 40)
        )

        let rolloutDuration = SyntheticDrive.finishedResult(in: rolloutEvents)?.duration ?? 0
        let plainDuration = SyntheticDrive.finishedResult(in: plainEvents)?.duration ?? 0
        XCTAssertLessThan(rolloutDuration, plainDuration)
    }

    // MARK: - Splits

    func testQuarterMileRecordsTheUsualMarkers() {
        let acceleration = 4.0
        let engine = PerformanceEngine(mode: .quarterMile)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(acceleration, duration: 40)
        )
        let splits = SyntheticDrive.splits(in: events)

        XCTAssertEqual(splits.map(\.label), ["60 ft", "330 ft", "1/8 mile", "1000 ft"])

        // Each marker should land where the physics says it does.
        let sixtyFeet = UnitConversion.meters(fromFeet: 60)
        XCTAssertEqual(splits[0].time, (2 * sixtyFeet / acceleration).squareRoot(), accuracy: 0.05)

        // And they must be in order.
        XCTAssertEqual(splits.map(\.time), splits.map(\.time).sorted())
    }

    func testSpeedRunRecordsIntermediateSpeedSplits() {
        let engine = PerformanceEngine(mode: .zeroToTwoHundredKmh)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(4.0, duration: 40)
        )
        let splits = SyntheticDrive.splits(in: events)
        XCTAssertEqual(splits.map(\.label), ["60 km/h", "100 km/h", "150 km/h"])
    }

    // MARK: - Run completion and aborts

    func testEngineFinishesAndSettles() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        XCTAssertEqual(engine.state, .armed)

        SyntheticDrive.run(engine, with: SyntheticDrive.constantAcceleration(5.0, duration: 20))
        XCTAssertEqual(engine.state, .finished)
    }

    func testResultIsPublishedBeforeTheSettlingWindowCloses() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()

        var finishedAt: TimeInterval?
        var refinedAt: TimeInterval?
        for sample in SyntheticDrive.constantAcceleration(5.0, duration: 20) {
            for event in engine.ingest(sample) {
                if case .finished = event, finishedAt == nil { finishedAt = sample.t }
                if case .resultRefined = event, refinedAt == nil { refinedAt = sample.t }
            }
        }

        XCTAssertNotNil(finishedAt)
        XCTAssertNotNil(refinedAt)
        XCTAssertGreaterThan(refinedAt!, finishedAt!)
        XCTAssertEqual(refinedAt! - finishedAt!, 3, accuracy: 0.25)
    }

    func testRunAbortsWhenTheDriverLifts() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.acceleratePlateauBrake(
                acceleration: 5,
                holdSpeed: 20,
                holdFor: 0.5,
                deceleration: 5
            )
        )

        XCTAssertNil(SyntheticDrive.finishedResult(in: events))
        XCTAssertNotNil(SyntheticDrive.abortReason(in: events))
    }

    func testNothingIsMeasuredUntilTheEngineIsArmed() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(5.0)
        )
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(engine.state, .idle)
    }

    func testStandingStartWaitsForTheCarToStop() {
        // The stream never contains a stationary sample, so a standing-start run
        // must refuse to launch.
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        var samples: [TelemetrySample] = []
        var t = 0.0
        var speed = 12.0
        var distance = 0.0
        while t < 10 {
            samples.append(
                SyntheticDrive.sample(t: t, speed: speed, distance: distance, acceleration: 2)
            )
            speed += 2 * 0.1
            distance += speed * 0.1
            t += 0.1
        }
        let events = SyntheticDrive.run(engine, with: samples)
        XCTAssertNil(SyntheticDrive.finishedResult(in: events))
        XCTAssertEqual(engine.state, .armed)
    }

    // MARK: - Progress

    func testProgressTracksTowardsASpeedTarget() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        for sample in SyntheticDrive.constantAcceleration(5.0, duration: 3) {
            engine.ingest(sample)
        }
        let progress = engine.progress
        XCTAssertNotNil(progress)
        XCTAssertFalse(progress!.isDistance)
        XCTAssertGreaterThan(progress!.fraction, 0.4)
        XCTAssertLessThan(progress!.fraction, 0.7)
    }

    // MARK: - Telemetry captured with the result

    func testResultCarriesTelemetryRebasedOnTheStartLine() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(5.0, duration: 20)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        XCTAssertFalse(result!.samples.isEmpty)
        // Lead-in samples sit before the start line and so carry negative times.
        XCTAssertLessThan(result!.samples.first!.t, 0.001)
        XCTAssertGreaterThan(result!.samples.last!.t, result!.duration - 0.2)
        // Distance is measured from the start line.
        XCTAssertEqual(result!.samples.first!.distance, 0, accuracy: 0.5)
    }

    func testPoorAccuracyMarksTheRunAsUnreliable() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(5.0, duration: 20, accuracy: 32)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        XCTAssertEqual(result!.quality, .poor)
        XCTAssertFalse(result!.isValid)
        XCTAssertFalse(result!.warnings.isEmpty)
    }

    func testCleanSignalProducesAValidRun() {
        let engine = PerformanceEngine(mode: .zeroToHundredKmh)
        engine.arm()
        let events = SyntheticDrive.run(
            engine,
            with: SyntheticDrive.constantAcceleration(5.0, duration: 20, accuracy: 3)
        )
        let result = SyntheticDrive.finishedResult(in: events)

        XCTAssertNotNil(result)
        XCTAssertTrue(result!.isValid)
        XCTAssertEqual(result!.quality, .excellent)
    }
}
