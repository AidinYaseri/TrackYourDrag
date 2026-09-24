import XCTest
@testable import Tracky

final class UnitsAndValidationTests: XCTestCase {

    // MARK: - Conversions

    func testSpeedConversions() {
        XCTAssertEqual(UnitConversion.kmh(27.7778), 100, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.mph(26.8224), 60, accuracy: 0.01)
        XCTAssertEqual(UnitConversion.mpsFromKmh(100), 27.7778, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.mpsFromMph(60), 26.8224, accuracy: 0.001)
    }

    func testSpeedConversionsRoundTrip() {
        for unit in SpeedUnit.allCases {
            let original = 31.5
            let converted = unit.value(fromMetersPerSecond: original)
            XCTAssertEqual(unit.metersPerSecond(from: converted), original, accuracy: 1e-9)
        }
    }

    func testDistanceConversions() {
        XCTAssertEqual(DistanceUnit.metric.longValue(fromMeters: 2500), 2.5, accuracy: 1e-9)
        XCTAssertEqual(DistanceUnit.imperial.longValue(fromMeters: 1609.344), 1, accuracy: 1e-9)
        XCTAssertEqual(DistanceUnit.imperial.shortValue(fromMeters: 1), 3.2808, accuracy: 0.001)
        XCTAssertEqual(UnitConversion.meters(fromFeet: 1), 0.3048, accuracy: 1e-6)
    }

    func testTemperatureConversion() {
        XCTAssertEqual(TemperatureUnit.fahrenheit.value(fromCelsius: 20), 68, accuracy: 1e-9)
        XCTAssertEqual(TemperatureUnit.celsius.value(fromCelsius: 20), 20, accuracy: 1e-9)
    }

    func testQuarterMileIsFourHundredAndTwoMetres() {
        XCTAssertEqual(RunMode.quarterMile.targetDistance ?? 0, 402.336, accuracy: 0.001)
        XCTAssertEqual(RunMode.eighthMile.targetDistance ?? 0, 201.168, accuracy: 0.001)
    }

    // MARK: - Run modes

    func testStandingStartDetection() {
        XCTAssertTrue(RunMode.zeroToHundredKmh.requiresStandingStart)
        XCTAssertTrue(RunMode.quarterMile.requiresStandingStart)
        XCTAssertFalse(RunMode.sixtyToOneThirtyMph.requiresStandingStart)
    }

    func testCustomModesCarryTheUnitTheyWereBuiltIn() {
        let metric = RunMode.acceleration(fromKmh: 50, toKmh: 100, isCustom: true)
        XCTAssertEqual(metric.speedUnitHint, .kmh)
        XCTAssertEqual(metric.title, "50 – 100 km/h")
        XCTAssertTrue(metric.isCustom)
        XCTAssertEqual(metric.category, .custom)

        let imperial = RunMode.acceleration(fromMph: 60, toMph: 130)
        XCTAssertEqual(imperial.speedUnitHint, .mph)
        XCTAssertEqual(imperial.speedBounds?.from ?? 0, UnitConversion.mpsFromMph(60), accuracy: 1e-9)
    }

    // MARK: - Formatting

    func testTimeFormatting() {
        XCTAssertEqual(Format.time(4.8213), "4.82")
        XCTAssertEqual(Format.time(12.0), "12.00")
        XCTAssertEqual(Format.signedTime(-0.214), "-0.21")
        XCTAssertEqual(Format.signedTime(0.214), "+0.21")
        XCTAssertEqual(Format.signedTime(0.0), "0.00")
    }

    func testSpeedFormatting() {
        XCTAssertEqual(Format.speed(27.7778, unit: .kmh), "100")
        XCTAssertEqual(Format.speed(26.8224, unit: .mph), "60")
        XCTAssertEqual(Format.speed(-5, unit: .kmh), "0")
    }

    func testAccuracyFormatting() {
        XCTAssertEqual(Format.accuracy(1.83), "±1.8 m")
        XCTAssertEqual(Format.accuracy(18.3), "±18 m")
        XCTAssertEqual(Format.accuracy(-1), "--")
    }

    func testElevationFormatting() {
        XCTAssertEqual(Format.signedElevation(3.2, unit: .metric), "+3 m")
        XCTAssertEqual(Format.signedElevation(-3.2, unit: .metric), "-3 m")
    }

    // MARK: - GPS quality

    func testQualityThresholds() {
        XCTAssertEqual(GPSQuality.from(horizontalAccuracy: 3), .excellent)
        XCTAssertEqual(GPSQuality.from(horizontalAccuracy: 8), .good)
        XCTAssertEqual(GPSQuality.from(horizontalAccuracy: 18), .fair)
        XCTAssertEqual(GPSQuality.from(horizontalAccuracy: 40), .poor)
        XCTAssertEqual(GPSQuality.from(horizontalAccuracy: -1), .poor)
    }

    func testQualityOrdering() {
        XCTAssertTrue(GPSQuality.excellent > GPSQuality.good)
        XCTAssertTrue(GPSQuality.good > GPSQuality.fair)
        XCTAssertTrue(GPSQuality.fair > GPSQuality.poor)
    }

    // MARK: - Run validation

    private func accuracy(
        average: Double,
        worst: Double,
        rate: Double,
        count: Int = 50
    ) -> AccuracySummary {
        AccuracySummary(average: average, best: average, worst: worst, sampleCount: count, sampleRate: rate)
    }

    func testCleanSignalIsExcellent() {
        let verdict = RunValidator.evaluate(
            accuracy: accuracy(average: 3, worst: 6, rate: 10),
            rejectedFixes: 0,
            duration: 5,
            gforceSource: .deviceMotion
        )
        XCTAssertEqual(verdict.quality, .excellent)
        XCTAssertTrue(verdict.isValid)
        XCTAssertTrue(verdict.warnings.isEmpty)
    }

    func testWeakSignalIsPoorAndInvalid() {
        let verdict = RunValidator.evaluate(
            accuracy: accuracy(average: 40, worst: 60, rate: 10),
            rejectedFixes: 0,
            duration: 5,
            gforceSource: .deviceMotion
        )
        XCTAssertEqual(verdict.quality, .poor)
        XCTAssertFalse(verdict.isValid)
        XCTAssertFalse(verdict.warnings.isEmpty)
    }

    func testALowFixRateIsCalledOut() {
        let verdict = RunValidator.evaluate(
            accuracy: accuracy(average: 4, worst: 8, rate: 1.5),
            rejectedFixes: 0,
            duration: 5,
            gforceSource: .deviceMotion
        )
        XCTAssertTrue(verdict.warnings.contains { $0.contains("fixes per second") })
    }

    func testDiscardedFixesAreReported() {
        let verdict = RunValidator.evaluate(
            accuracy: accuracy(average: 4, worst: 8, rate: 10),
            rejectedFixes: 3,
            duration: 5,
            gforceSource: .deviceMotion
        )
        XCTAssertTrue(verdict.warnings.contains { $0.contains("discarded") })
    }

    func testMissingMotionIsReported() {
        let verdict = RunValidator.evaluate(
            accuracy: accuracy(average: 4, worst: 8, rate: 10),
            rejectedFixes: 0,
            duration: 5,
            gforceSource: .gpsOnly
        )
        XCTAssertTrue(verdict.warnings.contains { $0.contains("Motion data") })
    }

    // MARK: - Telemetry series

    func testDownsamplingKeepsTheEnds() {
        let points = (0..<1000).map {
            TelemetryPoint(t: Double($0) * 0.02, speed: Double($0) * 0.05)
        }
        let reduced = points.downsampled(to: 100)
        XCTAssertEqual(reduced.count, 100)
        XCTAssertEqual(reduced.first?.t, points.first?.t)
        XCTAssertEqual(reduced.last?.t, points.last?.t)
    }

    func testDownsamplingLeavesShortSeriesAlone() {
        let points = (0..<10).map { TelemetryPoint(t: Double($0), speed: 1) }
        XCTAssertEqual(points.downsampled(to: 100).count, 10)
    }

    func testSpeedLookupInterpolatesBetweenSamples() {
        let points = [
            TelemetryPoint(t: 0, speed: 0),
            TelemetryPoint(t: 1, speed: 10),
            TelemetryPoint(t: 2, speed: 20)
        ]
        XCTAssertEqual(points.speed(at: 0.5) ?? 0, 5, accuracy: 1e-9)
        XCTAssertEqual(points.speed(at: 1.5) ?? 0, 15, accuracy: 1e-9)
        XCTAssertEqual(points.speed(at: -5) ?? 0, 0, accuracy: 1e-9)
        XCTAssertEqual(points.speed(at: 99) ?? 0, 20, accuracy: 1e-9)
    }

    func testCombinedGIsTheVectorMagnitude() {
        let point = TelemetryPoint(t: 0, speed: 0, longitudinalG: 0.3, lateralG: 0.4)
        XCTAssertEqual(point.combinedG, 0.5, accuracy: 1e-9)
    }
}
