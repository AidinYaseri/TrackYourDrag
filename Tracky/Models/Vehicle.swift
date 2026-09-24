import Foundation
import SwiftData

/// A car the user measures. Every field except the name is optional: you can
/// record a run with nothing but "My car" typed in.
@Model
final class Vehicle {
    @Attribute(.unique) var id: UUID
    var name: String
    var year: Int?
    var make: String
    var model: String
    var trim: String
    /// Free text, e.g. "91 octane" or "E85".
    var fuel: String
    var horsepower: Int?
    var weightKg: Double?
    var drivetrain: String
    var notes: String
    /// `#RRGGBB` accent used on run cards so vehicles are easy to tell apart.
    var colorHex: String
    var isDefault: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \Run.vehicle)
    var runs: [Run] = []

    init(
        id: UUID = UUID(),
        name: String,
        year: Int? = nil,
        make: String = "",
        model: String = "",
        trim: String = "",
        fuel: String = "",
        horsepower: Int? = nil,
        weightKg: Double? = nil,
        drivetrain: String = "",
        notes: String = "",
        colorHex: String = "#37E3FF",
        isDefault: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.year = year
        self.make = make
        self.model = model
        self.trim = trim
        self.fuel = fuel
        self.horsepower = horsepower
        self.weightKg = weightKg
        self.drivetrain = drivetrain
        self.notes = notes
        self.colorHex = colorHex
        self.isDefault = isDefault
        self.createdAt = createdAt
    }

    /// "2007 Mazdaspeed 3" style line built from whatever the user filled in.
    var subtitle: String {
        var parts: [String] = []
        if let horsepower { parts.append("\(horsepower) hp") }
        if let weightKg { parts.append("\(Int(weightKg.rounded())) kg") }
        if !drivetrain.isEmpty { parts.append(drivetrain) }
        if !fuel.isEmpty { parts.append(fuel) }
        return parts.joined(separator: " · ")
    }

    /// Power-to-weight in hp per tonne, when both numbers are known.
    var powerToWeight: Double? {
        guard let horsepower, let weightKg, weightKg > 0 else { return nil }
        return Double(horsepower) / (weightKg / 1000)
    }
}

enum Drivetrain: String, CaseIterable, Identifiable {
    case unspecified = ""
    case fwd = "FWD"
    case rwd = "RWD"
    case awd = "AWD"
    case fourWD = "4WD"

    var id: String { rawValue }
    var title: String { rawValue.isEmpty ? "Not set" : rawValue }
}
