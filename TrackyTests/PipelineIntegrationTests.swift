import XCTest
@testable import Tracky

/// End-to-end checks: synthetic sensor data goes in one end (raw GPS fixes and
/// device motion) and a finished result comes out the other, through the real
/// `TelemetryProcessor` and `PerformanceEngine`.
///
/// This is the same path the demo data uses, so a break here breaks the app in
/// the Simulator too.
final class PipelineIntegrationTests: XCTestCase {

    private func recipe(
        mode: RunMode,
        factor: Double = 1.0,
        accuracy: Double = 3.5,
        seed: UInt64 = 4242
    ) -> SampleDataGenerator.Recipe {
        SampleDataGenerator.Recipe(
            mode: mode,
            model: .scaled(byFactor: factor),
            date: Date(),
            accuracyBase: accuracy,
            lateralAmplitude: 1.2,
            seed: seed
        )
    }

    func testAFullRunCompletesThroughTheRealPipeline() {
        let result = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh))
        XCTAssertNotNil(result)
        guard let result else { return }

        // The model is a warm hatchback, not a dragster or a milk float.
        XCTAssertGreaterThan(result.duration, 3.0)
        XCTAssertLessThan(result.duration, 9.0)
        XCTAssertEqual(result.startSpeed, 0, accuracy: 0.5)
        XCTAssertEqual(result.endSpeed, UnitConversion.mpsFromKmh(100), accuracy: 0.1)
        XCTAssertFalse(result.samples.isEmpty)
    }

    func testAQuickerCarRecordsAQuickerTime() {
        let slow = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh, factor: 0.75))
        let quick = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh, factor: 1.3))

        XCTAssertNotNil(slow)
        XCTAssertNotNil(quick)
        XCTAssertLessThan(quick!.duration, slow!.duration)
    }

    func testDistanceCoveredIsConsistentWithTheTimeAndSpeed() {
        let result = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh))
        XCTAssertNotNil(result)
        guard let result else { return }

        // Average speed over the run has to sit between zero and the finish
        // speed, so distance must land inside that envelope.
        let upperBound = result.endSpeed * result.duration
        XCTAssertGreaterThan(result.distance, upperBound * 0.25)
        XCTAssertLessThan(result.distance, upperBound)
    }

    func testTheRunIsGradedOnItsSignalQuality() {
        let clean = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh, accuracy: 3))
        let messy = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh, accuracy: 15))

        XCTAssertEqual(clean?.quality, .excellent)
        XCTAssertTrue(clean?.isValid ?? false)
        XCTAssertEqual(messy?.quality, .fair)
    }

    func testBrakingAfterTheFinishLineIsCaptured() {
        // The generator brakes once the run finishes, which is exactly the
        // window the engine keeps recording for.
        let result = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh))
        XCTAssertNotNil(result)
        XCTAssertLessThan(result?.maxBrakingG ?? 0, -0.3)
        XCTAssertGreaterThan(result?.maxAccelerationG ?? 0, 0.3)
    }

    func testCorneringShowsUpOnTheLateralAxis() {
        let result = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh))
        XCTAssertGreaterThan(abs(result?.maxLateralG ?? 0), 0.02)
    }

    func testAQuarterMileRunProducesSplitsAndATrapSpeed() {
        let result = SampleDataGenerator.makeResult(recipe(mode: .quarterMile))
        XCTAssertNotNil(result)
        guard let result else { return }

        XCTAssertEqual(result.splits.map(\.label), ["60 ft", "330 ft", "1/8 mile", "1000 ft"])
        XCTAssertNotNil(result.trapSpeed)
        XCTAssertGreaterThan(result.trapSpeed ?? 0, UnitConversion.mpsFromKmh(120))
        XCTAssertEqual(result.distance, UnitConversion.metersPerMile / 4, accuracy: 2)
    }

    func testTheRouteIsRecordedWithTheRun() {
        let result = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh))
        XCTAssertNotNil(result?.startCoordinate)
        XCTAssertNotNil(result?.endCoordinate)

        let moved = GeoMath.distance(result!.startCoordinate!, result!.endCoordinate!)
        // The straight-line distance cannot exceed the distance actually driven.
        XCTAssertGreaterThan(moved, 10)
        XCTAssertLessThanOrEqual(moved, result!.distance + 5)
    }

    func testElevationUsesTheBarometerWhenItIsAvailable() {
        let result = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh))
        XCTAssertEqual(result?.elevation.source, .fused)
    }

    func testTheSameSeedProducesTheSameRun() {
        let first = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh, seed: 77))
        let second = SampleDataGenerator.makeResult(recipe(mode: .zeroToHundredKmh, seed: 77))
        XCTAssertEqual(first?.duration ?? 0, second?.duration ?? -1, accuracy: 1e-9)
    }
}
