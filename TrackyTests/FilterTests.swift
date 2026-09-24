import XCTest
@testable import Tracky

final class FilterTests: XCTestCase {

    // MARK: - Low pass

    func testLowPassAdoptsTheFirstValue() {
        var filter = LowPassFilter(timeConstant: 1)
        XCTAssertEqual(filter.update(10, dt: 0.1), 10, accuracy: 1e-9)
    }

    func testLowPassConvergesOnASteadyInput() {
        var filter = LowPassFilter(timeConstant: 0.5)
        filter.update(0, dt: 0.1)
        for _ in 0..<200 { filter.update(42, dt: 0.1) }
        XCTAssertEqual(filter.value ?? 0, 42, accuracy: 0.01)
    }

    func testLowPassSmoothingIsIndependentOfSampleRate() {
        // The same elapsed time should produce the same amount of smoothing,
        // whether it arrived in a few big steps or many small ones.
        var coarse = LowPassFilter(timeConstant: 1)
        coarse.update(0, dt: 0.1)
        for _ in 0..<10 { coarse.update(1, dt: 0.1) }

        var fine = LowPassFilter(timeConstant: 1)
        fine.update(0, dt: 0.01)
        for _ in 0..<100 { fine.update(1, dt: 0.01) }

        XCTAssertEqual(coarse.value ?? 0, fine.value ?? 0, accuracy: 0.02)
    }

    // MARK: - Speed Kalman

    func testKalmanAdoptsTheFirstFixOutright() {
        var filter = SpeedKalmanFilter()
        filter.update(measurement: 12, accuracy: 0.3)
        XCTAssertEqual(filter.speed, 12, accuracy: 1e-9)
        XCTAssertTrue(filter.hasFix)
    }

    func testKalmanConvergesOnANoisyConstantSpeed() {
        var filter = SpeedKalmanFilter()
        var generator = SeededGenerator(seed: 99)
        filter.update(measurement: 20, accuracy: 0.3)
        for _ in 0..<200 {
            filter.predict(dt: 0.1, acceleration: 0)
            let noise = (generator.nextUnit() - 0.5) * 0.8
            filter.update(measurement: 20 + noise, accuracy: 0.3)
        }
        XCTAssertEqual(filter.speed, 20, accuracy: 0.25)
    }

    func testKalmanFollowsAccelerationBetweenFixes() {
        var filter = SpeedKalmanFilter()
        filter.update(measurement: 10, accuracy: 0.3)
        filter.predict(dt: 0.5, acceleration: 4)
        XCTAssertEqual(filter.speed, 12, accuracy: 1e-9)
    }

    func testKalmanNeverReportsNegativeSpeed() {
        var filter = SpeedKalmanFilter()
        filter.update(measurement: 1, accuracy: 0.3)
        filter.predict(dt: 1, acceleration: -20)
        XCTAssertGreaterThanOrEqual(filter.speed, 0)
    }

    func testAPreciseFixMovesTheEstimateMoreThanAVagueOne() {
        var precise = SpeedKalmanFilter()
        precise.update(measurement: 10, accuracy: 0.2)
        precise.predict(dt: 0.1, acceleration: 0)
        precise.update(measurement: 20, accuracy: 0.2)

        var vague = SpeedKalmanFilter()
        vague.update(measurement: 10, accuracy: 0.2)
        vague.predict(dt: 0.1, acceleration: 0)
        vague.update(measurement: 20, accuracy: 8)

        XCTAssertGreaterThan(precise.speed, vague.speed)
    }

    // MARK: - Outlier rejection

    func testAccurateFixesAreAccepted() {
        var rejector = OutlierRejector()
        XCTAssertEqual(
            rejector.evaluate(speed: 10, timestamp: 0, horizontalAccuracy: 4),
            .accept
        )
    }

    func testInaccurateFixesAreRejected() {
        var rejector = OutlierRejector(accuracyLimit: 35)
        XCTAssertEqual(
            rejector.evaluate(speed: 10, timestamp: 0, horizontalAccuracy: 90),
            .rejectAccuracy(90)
        )
    }

    func testInvalidFixesAreRejected() {
        var rejector = OutlierRejector()
        XCTAssertEqual(
            rejector.evaluate(speed: 10, timestamp: 0, horizontalAccuracy: -1),
            .rejectAccuracy(-1)
        )
    }

    func testPhysicallyImpossibleJumpsAreRejected() {
        var rejector = OutlierRejector()
        XCTAssertEqual(rejector.evaluate(speed: 10, timestamp: 0, horizontalAccuracy: 4), .accept)
        // 10 -> 40 m/s in a tenth of a second is about 30 G.
        guard case .rejectImpossibleAcceleration = rejector.evaluate(
            speed: 40,
            timestamp: 0.1,
            horizontalAccuracy: 4
        ) else {
            return XCTFail("A 30 G jump should have been rejected")
        }
    }

    func testHardButPossibleAccelerationIsAccepted() {
        var rejector = OutlierRejector()
        XCTAssertEqual(rejector.evaluate(speed: 10, timestamp: 0, horizontalAccuracy: 4), .accept)
        // About 1 G.
        XCTAssertEqual(rejector.evaluate(speed: 11, timestamp: 0.1, horizontalAccuracy: 4), .accept)
    }

    func testStaleTimestampsAreRejected() {
        var rejector = OutlierRejector()
        XCTAssertEqual(rejector.evaluate(speed: 10, timestamp: 5, horizontalAccuracy: 4), .accept)
        XCTAssertEqual(
            rejector.evaluate(speed: 10, timestamp: 4.9, horizontalAccuracy: 4),
            .rejectStaleTimestamp
        )
    }

    // MARK: - Altitude

    func testAltitudeFusionSmoothsNoisyGPS() {
        var fusion = AltitudeFusion()
        var generator = SeededGenerator(seed: 7)
        for _ in 0..<300 {
            let noise = (generator.nextUnit() - 0.5) * 30
            fusion.ingestGPS(altitude: 100 + noise, verticalAccuracy: 8, dt: 0.1)
        }
        XCTAssertEqual(fusion.altitude, 100, accuracy: 4)
        XCTAssertEqual(fusion.source, .gps)
    }

    func testAltitudeIgnoresUnusableVerticalAccuracy() {
        var fusion = AltitudeFusion()
        fusion.ingestGPS(altitude: 500, verticalAccuracy: -1, dt: 0.1)
        XCTAssertFalse(fusion.hasValue)
    }

    func testBarometerTakesOverTheDetail() {
        var fusion = AltitudeFusion()
        for _ in 0..<200 {
            fusion.ingestGPS(altitude: 100, verticalAccuracy: 6, dt: 0.1)
        }
        fusion.ingestBarometricRelative(0)
        fusion.ingestGPS(altitude: 100, verticalAccuracy: 6, dt: 0.1)
        XCTAssertEqual(fusion.source, .fused)

        // A 5 m climb picked up by the barometer shows up straight away, without
        // waiting for the heavily smoothed GPS reference to catch up.
        fusion.ingestBarometricRelative(5)
        fusion.refreshFromBarometer()
        XCTAssertEqual(fusion.altitude, 105, accuracy: 0.5)
    }
}
