import XCTest
@testable import Tracky

final class GeoMathTests: XCTestCase {

    func testOneDegreeOfLatitudeIsAboutOneHundredAndElevenKilometres() {
        let distance = GeoMath.distance(lat1: 45, lon1: -73, lat2: 46, lon2: -73)
        XCTAssertEqual(distance, 111_195, accuracy: 300)
    }

    func testDistanceIsZeroForTheSamePoint() {
        XCTAssertEqual(
            GeoMath.distance(lat1: 45.5, lon1: -73.5, lat2: 45.5, lon2: -73.5),
            0,
            accuracy: 1e-6
        )
    }

    func testLongitudeShrinksWithLatitude() {
        let atEquator = GeoMath.distance(lat1: 0, lon1: 0, lat2: 0, lon2: 1)
        let upNorth = GeoMath.distance(lat1: 60, lon1: 0, lat2: 60, lon2: 1)
        // cos(60 degrees) is a half.
        XCTAssertEqual(upNorth / atEquator, 0.5, accuracy: 0.01)
    }

    func testBearings() {
        XCTAssertEqual(GeoMath.bearing(lat1: 45, lon1: -73, lat2: 46, lon2: -73), 0, accuracy: 0.01)
        XCTAssertEqual(GeoMath.bearing(lat1: 45, lon1: -73, lat2: 45, lon2: -72), 90, accuracy: 0.5)
        XCTAssertEqual(GeoMath.bearing(lat1: 45, lon1: -73, lat2: 44, lon2: -73), 180, accuracy: 0.01)
    }

    func testProjectingAndMeasuringAgree() {
        let start = Coordinate(latitude: 45.5019, longitude: -73.5674)
        let end = GeoMath.destination(
            lat: start.latitude,
            lon: start.longitude,
            bearingDegrees: 42,
            distanceMeters: 402.336
        )
        XCTAssertEqual(GeoMath.distance(start, end), 402.336, accuracy: 0.5)
        XCTAssertEqual(
            GeoMath.bearing(lat1: start.latitude, lon1: start.longitude, lat2: end.latitude, lon2: end.longitude),
            42,
            accuracy: 0.1
        )
    }

    func testHeadingDeltaTakesTheShortWayRound() {
        XCTAssertEqual(GeoMath.headingDelta(from: 350, to: 10), 20, accuracy: 1e-9)
        XCTAssertEqual(GeoMath.headingDelta(from: 10, to: 350), -20, accuracy: 1e-9)
        XCTAssertEqual(GeoMath.headingDelta(from: 90, to: 180), 90, accuracy: 1e-9)
    }
}
