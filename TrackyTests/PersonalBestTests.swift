import XCTest
@testable import Tracky

final class PersonalBestTests: XCTestCase {

    func testFastestRunPerModeBecomesTheRecord() {
        let runs = [
            RunSummary.make(duration: 5.2, daysAgo: 30),
            RunSummary.make(duration: 4.82, daysAgo: 10),
            RunSummary.make(duration: 5.0, daysAgo: 1)
        ]
        let bests = PersonalBestCalculator.bests(from: runs)
        XCTAssertEqual(bests.count, 1)
        XCTAssertEqual(bests[0].duration, 4.82, accuracy: 1e-9)
    }

    func testImprovementIsMeasuredAgainstTheNextBestTime() {
        let runs = [
            RunSummary.make(duration: 5.2),
            RunSummary.make(duration: 4.8),
            RunSummary.make(duration: 5.0)
        ]
        let best = PersonalBestCalculator.bests(from: runs).first
        XCTAssertEqual(best?.improvementOverPrevious ?? 0, 0.2, accuracy: 1e-9)
    }

    func testASingleRunHasNoImprovementFigure() {
        let best = PersonalBestCalculator.bests(from: [.make(duration: 5.0)]).first
        XCTAssertNil(best?.improvementOverPrevious)
    }

    func testRunsWithAPoorSignalDoNotSetRecords() {
        let runs = [
            RunSummary.make(duration: 4.0, quality: .poor),
            RunSummary.make(duration: 5.0, quality: .good)
        ]
        let best = PersonalBestCalculator.bests(from: runs).first
        XCTAssertEqual(best?.duration ?? 0, 5.0, accuracy: 1e-9)
    }

    func testInvalidRunsDoNotSetRecords() {
        let runs = [
            RunSummary.make(duration: 3.9, isValid: false),
            RunSummary.make(duration: 5.1)
        ]
        let best = PersonalBestCalculator.bests(from: runs).first
        XCTAssertEqual(best?.duration ?? 0, 5.1, accuracy: 1e-9)
    }

    func testRecordsAreGroupedPerMode() {
        let runs = [
            RunSummary.make(modeID: RunMode.zeroToHundredKmh.id, duration: 4.8),
            RunSummary.make(modeID: RunMode.quarterMile.id, duration: 12.9),
            RunSummary.make(modeID: RunMode.quarterMile.id, duration: 13.4)
        ]
        let bests = PersonalBestCalculator.bests(from: runs)
        XCTAssertEqual(bests.count, 2)
        XCTAssertEqual(bests.first { $0.modeID == RunMode.quarterMile.id }?.duration, 12.9)
    }

    func testRecordsComeBackInPresetOrder() {
        let runs = [
            RunSummary.make(modeID: RunMode.quarterMile.id, duration: 12.9),
            RunSummary.make(modeID: RunMode.zeroToSixtyMph.id, duration: 4.5)
        ]
        let bests = PersonalBestCalculator.bests(from: runs)
        // 0-60 mph is the first preset, the quarter mile comes later.
        XCTAssertEqual(bests.first?.modeID, RunMode.zeroToSixtyMph.id)
    }

    func testIsPersonalBestRecognisesANewRecord() {
        let history = [RunSummary.make(duration: 5.0), RunSummary.make(duration: 5.3)]
        let candidate = RunSummary.make(duration: 4.7)
        XCTAssertTrue(PersonalBestCalculator.isPersonalBest(candidate, among: history))
    }

    func testIsPersonalBestRejectsASlowerRun() {
        let history = [RunSummary.make(duration: 4.5)]
        let candidate = RunSummary.make(duration: 4.7)
        XCTAssertFalse(PersonalBestCalculator.isPersonalBest(candidate, among: history))
    }

    func testTheFirstRunOfAModeIsAlwaysARecord() {
        XCTAssertTrue(
            PersonalBestCalculator.isPersonalBest(RunSummary.make(duration: 9.9), among: [])
        )
    }

    func testAPoorQualityRunIsNeverAPersonalBest() {
        let candidate = RunSummary.make(duration: 1.0, quality: .poor)
        XCTAssertFalse(PersonalBestCalculator.isPersonalBest(candidate, among: []))
    }

    func testTrendIsChronologicalAndFlagsRecordsAsTheyHappened() {
        let runs = [
            RunSummary.make(duration: 5.4, daysAgo: 30),
            RunSummary.make(duration: 5.6, daysAgo: 20),
            RunSummary.make(duration: 5.1, daysAgo: 10),
            RunSummary.make(duration: 5.2, daysAgo: 1)
        ]
        let trend = PersonalBestCalculator.trend(for: RunMode.zeroToHundredKmh.id, in: runs)

        XCTAssertEqual(trend.map(\.duration), [5.4, 5.6, 5.1, 5.2])
        XCTAssertEqual(trend.map(\.isRecord), [true, false, true, false])
    }

    func testSummaryAddsUpTotalsAndPeaks() {
        let runs = [
            RunSummary.make(duration: 5.0, maxAccelerationG: 0.9, maxBrakingG: -1.1, maxLateralG: 0.6, distance: 120),
            RunSummary.make(duration: 5.5, maxAccelerationG: 1.04, maxBrakingG: -0.8, maxLateralG: -0.87, distance: 130)
        ]
        let summary = PersonalBestCalculator.summary(from: runs)

        XCTAssertEqual(summary.totalRuns, 2)
        XCTAssertEqual(summary.validRuns, 2)
        XCTAssertEqual(summary.totalDistance, 250, accuracy: 1e-9)
        XCTAssertEqual(summary.maxAccelerationG, 1.04, accuracy: 1e-9)
        XCTAssertEqual(summary.maxBrakingG, -1.1, accuracy: 1e-9)
        XCTAssertEqual(summary.maxLateralG, -0.87, accuracy: 1e-9)
    }

    func testGPeaksCountEvenFromRunsThatDoNotSetRecords() {
        let runs = [RunSummary.make(duration: 4.0, quality: .poor, maxBrakingG: -1.3)]
        let summary = PersonalBestCalculator.summary(from: runs)
        XCTAssertTrue(summary.bests.isEmpty)
        XCTAssertEqual(summary.maxBrakingG, -1.3, accuracy: 1e-9)
    }
}
