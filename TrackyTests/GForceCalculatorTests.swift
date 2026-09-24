import XCTest
@testable import Tracky

/// The G maths is checked with hand-built vectors: an identity attitude means
/// the device frame *is* the world frame (x north, y west, z up), so the
/// expected longitudinal and lateral values can be reasoned about directly.
final class GForceCalculatorTests: XCTestCase {

    private func motion(north: Double, west: Double, up: Double = 0, yaw: Double = 0) -> MotionSample {
        MotionSample(
            timestamp: 0,
            userAcceleration: Vector3(x: north, y: west, z: up),
            gravity: Vector3(x: 0, y: 0, z: -1),
            rotationRate: Vector3(x: 0, y: 0, z: yaw),
            rotationMatrix: .identity,
            isNorthReferenced: true
        )
    }

    func testAccelerationDueNorthWhileHeadingNorthIsPurelyLongitudinal() {
        let reading = GForceCalculator.resolve(
            motion: motion(north: 0.5, west: 0),
            courseDegrees: 0,
            speed: 20,
            gpsLongitudinalG: 0
        )
        XCTAssertEqual(reading.longitudinal, 0.5, accuracy: 1e-9)
        XCTAssertEqual(reading.lateral, 0, accuracy: 1e-9)
        XCTAssertEqual(reading.source, .deviceMotion)
    }

    func testBrakingIsNegativeLongitudinal() {
        let reading = GForceCalculator.resolve(
            motion: motion(north: -0.9, west: 0),
            courseDegrees: 0,
            speed: 20,
            gpsLongitudinalG: 0
        )
        XCTAssertEqual(reading.longitudinal, -0.9, accuracy: 1e-9)
    }

    func testTurningRightGivesPositiveLateral() {
        // Heading north, accelerating east: the car is being pushed to its right.
        // East is negative west in this frame.
        let reading = GForceCalculator.resolve(
            motion: motion(north: 0, west: -0.6),
            courseDegrees: 0,
            speed: 20,
            gpsLongitudinalG: 0
        )
        XCTAssertEqual(reading.lateral, 0.6, accuracy: 1e-9)
        XCTAssertEqual(reading.longitudinal, 0, accuracy: 1e-9)
    }

    func testTurningLeftGivesNegativeLateral() {
        let reading = GForceCalculator.resolve(
            motion: motion(north: 0, west: 0.6),
            courseDegrees: 0,
            speed: 20,
            gpsLongitudinalG: 0
        )
        XCTAssertEqual(reading.lateral, -0.6, accuracy: 1e-9)
    }

    func testTheSplitFollowsTheCarsHeading() {
        // Heading east. Acceleration due east is now longitudinal, not lateral.
        let reading = GForceCalculator.resolve(
            motion: motion(north: 0, west: -0.4),
            courseDegrees: 90,
            speed: 20,
            gpsLongitudinalG: 0
        )
        XCTAssertEqual(reading.longitudinal, 0.4, accuracy: 1e-9)
        XCTAssertEqual(reading.lateral, 0, accuracy: 1e-9)
    }

    func testCombinedIsTheVectorMagnitude() {
        let reading = GForceCalculator.resolve(
            motion: motion(north: 0.3, west: -0.4),
            courseDegrees: 0,
            speed: 20,
            gpsLongitudinalG: 0
        )
        XCTAssertEqual(reading.combined, 0.5, accuracy: 1e-9)
    }

    func testVerticalIsReportedSeparately() {
        let reading = GForceCalculator.resolve(
            motion: motion(north: 0, west: 0, up: 0.25),
            courseDegrees: 0,
            speed: 20,
            gpsLongitudinalG: 0
        )
        XCTAssertEqual(reading.vertical, 0.25, accuracy: 1e-9)
    }

    func testWithoutANorthReferenceLongitudinalComesFromGPS() {
        var sample = motion(north: 0.5, west: 0)
        sample.isNorthReferenced = false
        let reading = GForceCalculator.resolve(
            motion: sample,
            courseDegrees: 0,
            speed: 20,
            gpsLongitudinalG: 0.31
        )
        XCTAssertEqual(reading.longitudinal, 0.31, accuracy: 1e-9)
        XCTAssertEqual(reading.source, .deviceMotionAssisted)
    }

    func testBelowWalkingPaceThereIsNoHeadingSoNoLateralSplit() {
        let reading = GForceCalculator.resolve(
            motion: motion(north: 0, west: -0.6),
            courseDegrees: 0,
            speed: 0.2,
            gpsLongitudinalG: 0.05
        )
        XCTAssertEqual(reading.lateral, 0, accuracy: 1e-9)
        XCTAssertEqual(reading.longitudinal, 0.05, accuracy: 1e-9)
    }

    func testNoMotionAtAllFallsBackToGPSOnly() {
        var calculator = GForceCalculator()
        let reading = calculator.reading(
            motion: nil,
            courseDegrees: 0,
            speed: 20,
            gpsAcceleration: UnitConversion.standardGravity * 0.4,
            dt: 1
        )
        XCTAssertEqual(reading.source, .gpsOnly)
        XCTAssertGreaterThan(reading.longitudinal, 0)
    }

    // MARK: - Accumulator

    func testAccumulatorTracksSeparatePeaks() {
        var accumulator = GForceAccumulator()
        accumulator.ingest(GForceReading(longitudinal: 0.8, lateral: 0.2, vertical: 0))
        accumulator.ingest(GForceReading(longitudinal: -1.1, lateral: -0.9, vertical: 0))
        accumulator.ingest(GForceReading(longitudinal: 0.4, lateral: 0.5, vertical: 0))

        XCTAssertEqual(accumulator.maxAcceleration, 0.8, accuracy: 1e-9)
        XCTAssertEqual(accumulator.maxBraking, -1.1, accuracy: 1e-9)
        // Lateral keeps the largest magnitude with its sign.
        XCTAssertEqual(accumulator.maxLateral, -0.9, accuracy: 1e-9)
        XCTAssertEqual(accumulator.maxCombined, (1.1 * 1.1 + 0.9 * 0.9).squareRoot(), accuracy: 1e-9)
    }
}
