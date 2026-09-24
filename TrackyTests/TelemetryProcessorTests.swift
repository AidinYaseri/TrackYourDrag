import XCTest
@testable import Tracky

final class TelemetryProcessorTests: XCTestCase {

    private func location(
        t: TimeInterval,
        speed: Double,
        accuracy: Double = 4,
        latitude: Double = 45.5,
        longitude: Double = -73.56,
        altitude: Double = 40
    ) -> LocationSample {
        LocationSample(
            timestamp: t,
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            speed: speed,
            course: 42,
            horizontalAccuracy: accuracy,
            verticalAccuracy: accuracy * 1.5,
            speedAccuracy: 0.3
        )
    }

    func testDistanceIsIntegratedFromSpeed() {
        let processor = TelemetryProcessor()
        var t: TimeInterval = 0
        var last: TelemetrySample?
        while t <= 10.0001 {
            last = processor.process(location: location(t: t, speed: 10))
            t += 0.1
        }
        // Ten seconds at ten metres a second.
        XCTAssertEqual(last?.distance ?? 0, 100, accuracy: 0.5)
    }

    func testDistanceUnderConstantAccelerationMatchesThePhysics() {
        let processor = TelemetryProcessor()
        let acceleration = 4.0
        var t: TimeInterval = 0
        var last: TelemetrySample?
        while t <= 10.0001 {
            last = processor.process(location: location(t: t, speed: acceleration * t))
            t += 0.1
        }
        // s = ½at² = 200 m. Trapezoidal integration of a straight speed ramp is
        // exact, so this should be tight.
        XCTAssertEqual(last?.distance ?? 0, 200, accuracy: 1.0)
    }

    func testFirstFixIsAdoptedRatherThanFilteredUpFromZero() {
        let processor = TelemetryProcessor()
        let sample = processor.process(location: location(t: 0, speed: 25))
        XCTAssertEqual(sample?.speed ?? 0, 25, accuracy: 0.01)
    }

    func testInaccurateFixesAreDroppedAndCounted() {
        let processor = TelemetryProcessor()
        XCTAssertNotNil(processor.process(location: location(t: 0, speed: 10)))
        XCTAssertNil(processor.process(location: location(t: 0.1, speed: 10, accuracy: 120)))
        XCTAssertEqual(processor.statistics.rejectedFixes, 1)
        XCTAssertEqual(processor.statistics.accuracySummary.sampleCount, 1)
    }

    func testImpossibleSpeedSpikesAreDropped() {
        let processor = TelemetryProcessor()
        processor.process(location: location(t: 0, speed: 10))
        XCTAssertNil(processor.process(location: location(t: 0.1, speed: 60)))
        XCTAssertEqual(processor.statistics.rejectedFixes, 1)
    }

    func testSpeedIsDerivedFromPositionWhenTheReceiverHasNone() {
        let processor = TelemetryProcessor()
        // Core Location reports -1 when it cannot work a speed out.
        processor.process(location: location(t: 0, speed: -1, latitude: 45.5))
        let moved = GeoMath.destination(
            lat: 45.5,
            lon: -73.56,
            bearingDegrees: 0,
            distanceMeters: 0.1
        )
        let sample = processor.process(
            location: location(t: 0.1, speed: -1, latitude: moved.latitude, longitude: moved.longitude)
        )
        // A tenth of a metre in a tenth of a second is 1 m/s.
        XCTAssertEqual(sample?.rawSpeed ?? 0, 1, accuracy: 0.15)
    }

    func testStatisticsTrackSpeedAndElevationExtremes() {
        let processor = TelemetryProcessor()
        processor.process(location: location(t: 0, speed: 5, altitude: 40))
        processor.process(location: location(t: 1, speed: 12, altitude: 48))
        processor.process(location: location(t: 2, speed: 8, altitude: 36))

        XCTAssertGreaterThan(processor.statistics.maxSpeed, 10)
        XCTAssertGreaterThan(processor.statistics.maxAltitude, processor.statistics.minAltitude)
        XCTAssertEqual(processor.statistics.accuracySummary.sampleCount, 3)
    }

    func testFixRateIsMeasuredFromTheTimestamps() {
        let processor = TelemetryProcessor()
        var t: TimeInterval = 0
        while t <= 5.0001 {
            processor.process(location: location(t: t, speed: 10))
            t += 0.1
        }
        XCTAssertEqual(processor.statistics.fixRate, 10, accuracy: 0.5)
    }

    func testResetClearsEverything() {
        let processor = TelemetryProcessor()
        processor.process(location: location(t: 0, speed: 10))
        processor.process(location: location(t: 1, speed: 10))
        processor.reset()
        XCTAssertNil(processor.lastSample)
        XCTAssertEqual(processor.statistics.accuracySummary.sampleCount, 0)
    }

    func testStationaryDetection() {
        let processor = TelemetryProcessor()
        processor.process(location: location(t: 0, speed: 0.1))
        XCTAssertTrue(processor.isStationary)
        processor.process(location: location(t: 1, speed: 9))
        XCTAssertFalse(processor.isStationary)
    }
}
