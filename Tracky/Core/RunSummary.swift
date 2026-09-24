import Foundation

/// A flat, value-type view of a saved run.
///
/// Statistics work on these rather than on SwiftData objects so the personal
/// best and trend maths can be tested without a database.
struct RunSummary: Identifiable, Hashable {
    var id: UUID
    var date: Date
    var modeID: String
    var modeTitle: String
    var category: RunModeCategory
    var duration: TimeInterval
    var distance: Double
    var startSpeed: Double
    var endSpeed: Double
    var maxSpeed: Double
    var maxAccelerationG: Double
    var maxBrakingG: Double
    var maxLateralG: Double
    var elevationChange: Double
    var quality: GPSQuality
    var isValid: Bool
    var vehicleID: UUID?
    var vehicleName: String?

    /// Only runs that actually completed with a usable signal are eligible for
    /// a personal best.
    var countsTowardsRecords: Bool { isValid && quality > .poor && duration > 0 }
}
