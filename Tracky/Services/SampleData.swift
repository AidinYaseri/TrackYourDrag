import Foundation
import SwiftData

/// Builds demo runs by pushing synthetic sensor data through the *real*
/// pipeline — `TelemetryProcessor` then `PerformanceEngine` — rather than
/// hand-writing plausible numbers.
///
/// Two reasons for doing it the hard way: the charts, splits, quality verdicts
/// and maps in the demo data are then genuinely consistent with each other, and
/// the act of generating them exercises the whole measurement path every time
/// the app runs in the Simulator.
enum SampleDataGenerator {

    struct Recipe {
        var mode: RunMode
        var model: VehicleModel = .default
        var date: Date
        /// Typical horizontal accuracy for the run, metres.
        var accuracyBase: Double = 3.6
        /// Peak cornering acceleration mixed in, m/s².
        var lateralAmplitude: Double = 1.4
        var seed: UInt64 = 0xC0FFEE
        var startCoordinate = Coordinate(latitude: 45.5019, longitude: -73.5674)
        var baseAltitude: Double = 42
        /// Seconds the car sits still before launching.
        var stationaryLeadIn: TimeInterval = 1.6
        var heading: Double = 42
    }

    static func makeResult(_ recipe: Recipe) -> PerformanceResult? {
        let processor = TelemetryProcessor(configuration: .default)
        let engine = PerformanceEngine(mode: recipe.mode)
        engine.arm()

        var generator = SeededGenerator(seed: recipe.seed)
        func noise(_ magnitude: Double) -> Double {
            (generator.nextUnit() - 0.5) * 2 * magnitude
        }

        var t: TimeInterval = 0
        let dt = 0.02
        var speed: Double = 0
        var distance: Double = 0
        var coordinate = recipe.startCoordinate
        var heading = recipe.heading
        var braking = false
        var finished: PerformanceResult?
        var refined: PerformanceResult?
        var finishedAt: TimeInterval?
        var tick = 0

        func handle(_ events: [PerformanceEngine.Event]) {
            for event in events {
                switch event {
                case .finished(let result):
                    finished = result
                    finishedAt = t
                    braking = true
                case .resultRefined(let result):
                    refined = result
                case .aborted:
                    finishedAt = t
                default:
                    break
                }
            }
        }

        while t < 120 {
            let sinceLaunch = t - recipe.stationaryLeadIn
            var longitudinal: Double = 0
            if braking {
                longitudinal = speed > 0 ? -recipe.model.brakingDeceleration : 0
            } else if sinceLaunch > 0 {
                longitudinal = recipe.model.acceleration(atSpeed: speed, secondsSinceLaunch: sinceLaunch)
            }
            let lateral = speed > 3 ? recipe.lateralAmplitude * sin(t * 0.8) : 0

            speed = max(0, speed + longitudinal * dt)
            distance += speed * dt
            if speed > 0.2 {
                heading += (lateral / max(speed, 4)) * dt * 180 / .pi
                coordinate = GeoMath.destination(
                    lat: coordinate.latitude,
                    lon: coordinate.longitude,
                    bearingDegrees: heading,
                    distanceMeters: speed * dt
                )
            }

            let terrain = sin(distance / 900) * 14
            processor.ingestBarometer(relativeAltitude: terrain)

            if tick % 5 == 0 {
                let accuracy = recipe.accuracyBase + abs(noise(1.0))
                let location = LocationSample(
                    timestamp: t,
                    latitude: coordinate.latitude,
                    longitude: coordinate.longitude,
                    altitude: recipe.baseAltitude + terrain + noise(2.5),
                    speed: max(0, speed + noise(0.09)),
                    course: speed > 0.5 ? heading : -1,
                    horizontalAccuracy: accuracy,
                    verticalAccuracy: accuracy * 1.6,
                    speedAccuracy: 0.28
                )
                if let sample = processor.process(location: location) {
                    handle(engine.ingest(sample))
                }
            }

            let theta = GeoMath.radians(heading)
            let g = UnitConversion.standardGravity
            let north = longitudinal * cos(theta) - lateral * sin(theta)
            let west = -longitudinal * sin(theta) - lateral * cos(theta)
            let motion = MotionSample(
                timestamp: t,
                userAcceleration: Vector3(x: north / g, y: west / g, z: noise(0.1) / g),
                gravity: Vector3(x: 0, y: 0, z: -1),
                rotationRate: Vector3(x: 0, y: 0, z: -lateral / max(speed, 1)),
                rotationMatrix: .identity,
                isNorthReferenced: true
            )
            if let sample = processor.process(motion: motion) {
                handle(engine.ingest(sample))
            }

            t += dt
            tick += 1
            if let finishedAt, t > finishedAt + 4.5 { break }
        }

        guard var result = refined ?? finished else { return nil }
        result.date = recipe.date
        return result
    }
}

/// Puts a believable garage and history in place the first time the app runs,
/// so every screen has something to show in the Simulator.
@MainActor
enum SampleDataSeeder {

    static func seedIfNeeded(context: ModelContext, settings: SettingsStore) {
        guard !settings.hasSeededSampleData else { return }

        let existing = (try? context.fetch(FetchDescriptor<Run>())) ?? []
        guard existing.isEmpty else {
            settings.hasSeededSampleData = true
            return
        }

        seed(context: context, settings: settings)
        settings.hasSeededSampleData = true
    }

    static func seed(context: ModelContext, settings: SettingsStore) {
        let daily = Vehicle(
            name: "2007 Mazdaspeed 3",
            year: 2007,
            make: "Mazda",
            model: "Mazdaspeed 3",
            trim: "Grand Touring",
            fuel: "91 octane",
            horsepower: 300,
            weightKg: 1450,
            drivetrain: Drivetrain.fwd.rawValue,
            notes: "Catback, intake, stage 2 tune.",
            colorHex: "#37E3FF",
            isDefault: true
        )
        let weekend = Vehicle(
            name: "1999 Miata",
            year: 1999,
            make: "Mazda",
            model: "MX-5",
            trim: "Base",
            fuel: "91 octane",
            horsepower: 140,
            weightKg: 1065,
            drivetrain: Drivetrain.rwd.rawValue,
            notes: "Coilovers and sticky tyres. Slow in a straight line, quick everywhere else.",
            colorHex: "#7C5CFF"
        )
        context.insert(daily)
        context.insert(weekend)

        struct Plan {
            var mode: RunMode
            var vehicle: Vehicle
            var factor: Double
            var daysAgo: Double
            var accuracy: Double
            var lateral: Double
            var seed: UInt64
        }

        let plans: [Plan] = [
            Plan(mode: .zeroToHundredKmh, vehicle: daily, factor: 1.00, daysAgo: 1.2, accuracy: 3.2, lateral: 1.1, seed: 11),
            Plan(mode: .zeroToHundredKmh, vehicle: daily, factor: 0.94, daysAgo: 9.4, accuracy: 4.4, lateral: 1.6, seed: 12),
            Plan(mode: .zeroToHundredKmh, vehicle: daily, factor: 0.90, daysAgo: 24.1, accuracy: 6.8, lateral: 2.2, seed: 13),
            Plan(mode: .zeroToSixtyMph, vehicle: daily, factor: 1.02, daysAgo: 2.4, accuracy: 3.0, lateral: 0.9, seed: 14),
            Plan(mode: .zeroToSixtyMph, vehicle: daily, factor: 0.96, daysAgo: 16.8, accuracy: 3.9, lateral: 1.3, seed: 15),
            Plan(mode: .quarterMile, vehicle: daily, factor: 1.00, daysAgo: 3.6, accuracy: 3.4, lateral: 0.8, seed: 16),
            Plan(mode: .quarterMile, vehicle: daily, factor: 0.93, daysAgo: 31.2, accuracy: 5.1, lateral: 1.0, seed: 17),
            Plan(mode: .eighthMile, vehicle: daily, factor: 0.98, daysAgo: 6.1, accuracy: 3.3, lateral: 0.9, seed: 18),
            Plan(mode: .zeroToHundredMph, vehicle: daily, factor: 0.97, daysAgo: 12.5, accuracy: 4.1, lateral: 1.2, seed: 19),
            Plan(mode: .sixtyToOneThirtyMph, vehicle: daily, factor: 0.99, daysAgo: 19.3, accuracy: 4.6, lateral: 1.4, seed: 20),
            Plan(mode: .zeroToHundredKmh, vehicle: weekend, factor: 0.70, daysAgo: 5.2, accuracy: 3.5, lateral: 2.8, seed: 21),
            Plan(mode: .zeroToSixtyMph, vehicle: weekend, factor: 0.71, daysAgo: 5.3, accuracy: 3.7, lateral: 3.1, seed: 22),
            Plan(mode: .quarterMile, vehicle: weekend, factor: 0.72, daysAgo: 27.7, accuracy: 4.2, lateral: 2.6, seed: 23)
        ]

        for plan in plans {
            let recipe = SampleDataGenerator.Recipe(
                mode: plan.mode,
                model: .scaled(byFactor: plan.factor),
                date: Date().addingTimeInterval(-plan.daysAgo * 86_400),
                accuracyBase: plan.accuracy,
                lateralAmplitude: plan.lateral,
                seed: plan.seed,
                startCoordinate: Coordinate(
                    latitude: 45.5019 + Double(plan.seed % 7) * 0.004,
                    longitude: -73.5674 - Double(plan.seed % 5) * 0.006
                ),
                baseAltitude: 38 + Double(plan.seed % 11)
            )
            guard let result = SampleDataGenerator.makeResult(recipe) else { continue }
            let run = Run(
                result: result,
                category: plan.mode.category,
                vehicle: plan.vehicle,
                storeRoute: true
            )
            context.insert(run)
        }

        settings.selectedVehicleID = daily.id
        try? context.save()
    }
}
