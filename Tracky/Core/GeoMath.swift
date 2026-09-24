import Foundation

/// Spherical geometry used for distance between GPS fixes.
enum GeoMath {
    /// IUGG mean Earth radius, metres.
    static let earthRadius = 6_371_008.8

    static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }

    /// Great-circle distance in metres.
    ///
    /// Haversine is used rather than the flat-earth shortcut because it stays
    /// well conditioned near the poles and at the antimeridian, and the cost is
    /// irrelevant at ten samples a second.
    static func distance(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let phi1 = radians(lat1)
        let phi2 = radians(lat2)
        let deltaPhi = radians(lat2 - lat1)
        let deltaLambda = radians(lon2 - lon1)

        let sinLat = sin(deltaPhi / 2)
        let sinLon = sin(deltaLambda / 2)
        let a = sinLat * sinLat + cos(phi1) * cos(phi2) * sinLon * sinLon
        let c = 2 * atan2(a.squareRoot(), (1 - a).squareRoot())
        return earthRadius * c
    }

    static func distance(_ a: Coordinate, _ b: Coordinate) -> Double {
        distance(lat1: a.latitude, lon1: a.longitude, lat2: b.latitude, lon2: b.longitude)
    }

    /// Initial bearing from a to b, degrees clockwise from true north (0..<360).
    static func bearing(
        lat1: Double, lon1: Double,
        lat2: Double, lon2: Double
    ) -> Double {
        let phi1 = radians(lat1)
        let phi2 = radians(lat2)
        let deltaLambda = radians(lon2 - lon1)
        let y = sin(deltaLambda) * cos(phi2)
        let x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(deltaLambda)
        let result = degrees(atan2(y, x))
        return (result + 360).truncatingRemainder(dividingBy: 360)
    }

    /// Projects a coordinate `distance` metres along `bearing`.
    /// Used by the simulator to lay out a believable route.
    static func destination(
        lat: Double, lon: Double,
        bearingDegrees: Double,
        distanceMeters: Double
    ) -> Coordinate {
        let angular = distanceMeters / earthRadius
        let theta = radians(bearingDegrees)
        let phi1 = radians(lat)
        let lambda1 = radians(lon)

        let phi2 = asin(sin(phi1) * cos(angular) + cos(phi1) * sin(angular) * cos(theta))
        let lambda2 = lambda1 + atan2(
            sin(theta) * sin(angular) * cos(phi1),
            cos(angular) - sin(phi1) * sin(phi2)
        )
        return Coordinate(latitude: degrees(phi2), longitude: degrees(lambda2))
    }

    /// Smallest signed difference between two headings, in degrees (-180...180).
    static func headingDelta(from: Double, to: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return delta
    }
}
