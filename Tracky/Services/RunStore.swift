import Foundation
import SwiftData

enum RunSortOption: String, CaseIterable, Identifiable {
    case date
    case fastest
    case distance
    case vehicle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .date: return "Date"
        case .fastest: return "Fastest"
        case .distance: return "Distance"
        case .vehicle: return "Vehicle"
        }
    }

    var symbolName: String {
        switch self {
        case .date: return "calendar"
        case .fastest: return "stopwatch"
        case .distance: return "ruler"
        case .vehicle: return "car.fill"
        }
    }
}

extension Run {
    /// Flat value-type view used by the statistics code.
    var summary: RunSummary {
        RunSummary(
            id: id,
            date: date,
            modeID: modeID,
            modeTitle: modeTitle,
            category: category,
            duration: duration,
            distance: distance,
            startSpeed: startSpeed,
            endSpeed: endSpeed,
            maxSpeed: maxSpeed,
            maxAccelerationG: maxAccelerationG,
            maxBrakingG: maxBrakingG,
            maxLateralG: maxLateralG,
            elevationChange: elevationChange,
            quality: quality,
            isValid: isValid,
            vehicleID: vehicle?.id,
            vehicleName: vehicle?.name
        )
    }
}

extension Array where Element == Run {
    func sorted(by option: RunSortOption) -> [Run] {
        switch option {
        case .date:
            return sorted { $0.date > $1.date }
        case .fastest:
            return sorted { $0.duration < $1.duration }
        case .distance:
            return sorted { $0.distance > $1.distance }
        case .vehicle:
            return sorted {
                let left = $0.vehicle?.name ?? "zzz"
                let right = $1.vehicle?.name ?? "zzz"
                if left == right { return $0.date > $1.date }
                return left.localizedCaseInsensitiveCompare(right) == .orderedAscending
            }
        }
    }

    var summaries: [RunSummary] { map(\.summary) }
}

/// All the writes. Reads in the UI go through `@Query` so views update
/// automatically; this exists for the operations that need to be explicit.
@MainActor
final class RunStore {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    // MARK: - Runs

    @discardableResult
    func save(
        result: PerformanceResult,
        category: RunModeCategory,
        vehicle: Vehicle?,
        storeRoute: Bool
    ) -> Run {
        let run = Run(result: result, category: category, vehicle: vehicle, storeRoute: storeRoute)
        context.insert(run)
        commit()
        return run
    }

    func delete(_ run: Run) {
        context.delete(run)
        commit()
    }

    func delete(_ runs: [Run]) {
        for run in runs { context.delete(run) }
        commit()
    }

    func deleteAllRuns() {
        let runs = (try? context.fetch(FetchDescriptor<Run>())) ?? []
        delete(runs)
    }

    /// Privacy control: keeps the timing, throws away every coordinate.
    func stripLocationData(from runs: [Run]) {
        for run in runs { run.stripLocationData() }
        commit()
    }

    func stripAllLocationData() {
        let runs = (try? context.fetch(FetchDescriptor<Run>())) ?? []
        stripLocationData(from: runs)
    }

    func allRuns(sortedBy option: RunSortOption = .date) -> [Run] {
        let runs = (try? context.fetch(FetchDescriptor<Run>())) ?? []
        return runs.sorted(by: option)
    }

    func run(withID id: UUID) -> Run? {
        var descriptor = FetchDescriptor<Run>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    // MARK: - Vehicles

    func allVehicles() -> [Vehicle] {
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        return vehicles.sorted { $0.createdAt < $1.createdAt }
    }

    func vehicle(withID id: UUID?) -> Vehicle? {
        guard let id else { return nil }
        return allVehicles().first { $0.id == id }
    }

    @discardableResult
    func addVehicle(_ vehicle: Vehicle) -> Vehicle {
        context.insert(vehicle)
        commit()
        return vehicle
    }

    /// Deleting a vehicle keeps its runs; they simply lose the association.
    func delete(vehicle: Vehicle) {
        context.delete(vehicle)
        commit()
    }

    func deleteEverything() {
        let runs = (try? context.fetch(FetchDescriptor<Run>())) ?? []
        for run in runs { context.delete(run) }
        let vehicles = (try? context.fetch(FetchDescriptor<Vehicle>())) ?? []
        for vehicle in vehicles { context.delete(vehicle) }
        commit()
    }

    // MARK: - Helpers

    func commit() {
        do {
            try context.save()
        } catch {
            // A failed save is worth knowing about but should never take the
            // app down mid-drive.
            assertionFailure("Tracky failed to save: \(error)")
        }
    }
}

extension PerformanceResult {
    /// Lets an unsaved result be compared against saved history, which is how a
    /// personal best can be flagged on the result screen before the run is even
    /// saved.
    func makeSummary(category: RunModeCategory, vehicle: Vehicle?) -> RunSummary {
        RunSummary(
            id: id,
            date: date,
            modeID: modeID,
            modeTitle: modeTitle,
            category: category,
            duration: duration,
            distance: distance,
            startSpeed: startSpeed,
            endSpeed: endSpeed,
            maxSpeed: maxSpeed,
            maxAccelerationG: maxAccelerationG,
            maxBrakingG: maxBrakingG,
            maxLateralG: maxLateralG,
            elevationChange: elevation.change,
            quality: quality,
            isValid: isValid,
            vehicleID: vehicle?.id,
            vehicleName: vehicle?.name
        )
    }
}
