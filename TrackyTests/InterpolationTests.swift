import XCTest
@testable import Tracky

final class InterpolationTests: XCTestCase {

    func testLerp() {
        XCTAssertEqual(Interpolation.lerp(0, 10, 0.25), 2.5, accuracy: 1e-9)
        XCTAssertEqual(Interpolation.lerp(-4, 4, 0.5), 0, accuracy: 1e-9)
    }

    func testFractionBetweenBounds() {
        XCTAssertEqual(Interpolation.fraction(from: 0, to: 100, value: 25), 0.25, accuracy: 1e-9)
        XCTAssertEqual(Interpolation.fraction(from: 20, to: 40, value: 30), 0.5, accuracy: 1e-9)
    }

    func testFractionIsZeroForDegenerateRange() {
        XCTAssertEqual(Interpolation.fraction(from: 5, to: 5, value: 9), 0, accuracy: 1e-9)
    }

    func testCrossingFindsExactThresholdTime() {
        // Speed goes 24 -> 30 m/s between t = 1.0 and t = 1.1. It passes
        // 27.7778 m/s (100 km/h) 63% of the way through that interval.
        let crossing = Interpolation.crossing(x0: 1.0, y0: 24, x1: 1.1, y1: 30, target: 27.7778)
        XCTAssertNotNil(crossing)
        XCTAssertEqual(crossing!, 1.0 + 0.1 * (27.7778 - 24) / 6, accuracy: 1e-9)
    }

    func testCrossingProjectsBackwardsPastTheFirstSample() {
        // This is what launch detection relies on: the line through two moving
        // samples reaches zero speed *before* the first of them.
        let crossing = Interpolation.crossing(x0: 1.2, y0: 1.0, x1: 1.3, y1: 1.5, target: 0)
        XCTAssertNotNil(crossing)
        XCTAssertEqual(crossing!, 1.0, accuracy: 1e-9)
    }

    func testCrossingReturnsNilForAFlatLine() {
        XCTAssertNil(Interpolation.crossing(x0: 0, y0: 5, x1: 1, y1: 5, target: 10))
    }

    func testBracketedCrossingRejectsTargetsOutsideTheInterval() {
        XCTAssertNil(
            Interpolation.bracketedCrossing(x0: 0, y0: 10, x1: 1, y1: 20, target: 25)
        )
        XCTAssertNotNil(
            Interpolation.bracketedCrossing(x0: 0, y0: 10, x1: 1, y1: 20, target: 15)
        )
    }

    func testBracketedCrossingHandlesAFlatBracket() {
        let crossing = Interpolation.bracketedCrossing(x0: 2, y0: 7, x1: 3, y1: 7, target: 7)
        XCTAssertEqual(crossing, 2)
    }

    func testCompanionValueReadsASecondChannelAtTheCrossing() {
        // Distance at the moment the speed trace crossed its target: halfway
        // between the two samples, so halfway between 100 m and 140 m.
        let distance = Interpolation.companionValue(
            at: 1.5,
            x0: 1.0, x1: 2.0,
            v0: 100, v1: 140
        )
        XCTAssertEqual(distance, 120, accuracy: 1e-9)
    }

    func testCompanionValueFallsBackWhenTheIntervalIsDegenerate() {
        let value = Interpolation.companionValue(at: 1, x0: 1, x1: 1, v0: 5, v1: 9)
        XCTAssertEqual(value, 9, accuracy: 1e-9)
    }
}
