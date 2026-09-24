import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

/// Create or edit a vehicle. Only the name matters; everything else is there
/// for people who want it. A run never waits on a spec sheet.
struct VehicleEditorView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    /// nil means "create a new one".
    var vehicle: Vehicle?

    @State private var name = ""
    @State private var year = ""
    @State private var make = ""
    @State private var model = ""
    @State private var trim = ""
    @State private var fuel = ""
    @State private var horsepower = ""
    @State private var weight = ""
    @State private var drivetrain: Drivetrain = .unspecified
    @State private var notes = ""
    @State private var colorHex = "#37E3FF"

    private let palette = ["#37E3FF", "#7C5CFF", "#3DDC97", "#FFB020", "#FF5A5F", "#F2F6FA"]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                field("Name", text: $name, placeholder: "2007 Mazdaspeed 3")
                                HStack(spacing: 12) {
                                    field("Year", text: $year, placeholder: "2007", keyboard: .numberPad)
                                    field("Make", text: $make, placeholder: "Mazda")
                                }
                                HStack(spacing: 12) {
                                    field("Model", text: $model, placeholder: "Mazdaspeed 3")
                                    field("Trim", text: $trim, placeholder: "Grand Touring")
                                }
                            }
                        }

                        SectionHeader(title: "Optional", subtitle: "None of this is required to record a run")
                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 12) {
                                    field("Power (hp)", text: $horsepower, placeholder: "300", keyboard: .numberPad)
                                    field("Weight (kg)", text: $weight, placeholder: "1450", keyboard: .numberPad)
                                }
                                field("Fuel", text: $fuel, placeholder: "91 octane")
                                VStack(alignment: .leading, spacing: 6) {
                                    MicroLabel(text: "Drivetrain", size: 10)
                                    Picker("Drivetrain", selection: $drivetrain) {
                                        ForEach(Drivetrain.allCases) { Text($0.title).tag($0) }
                                    }
                                    .pickerStyle(.segmented)
                                }
                                field("Notes", text: $notes, placeholder: "Mods, tyres, conditions")
                            }
                        }

                        SectionHeader(title: "Colour")
                        HStack(spacing: 10) {
                            ForEach(palette, id: \.self) { hex in
                                Button {
                                    Haptics.fire(.light)
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hexString: hex))
                                        .frame(width: 34, height: 34)
                                        .overlay(
                                            Circle().strokeBorder(
                                                colorHex == hex ? Color.white : Color.clear,
                                                lineWidth: 2
                                            )
                                        )
                                }
                            }
                        }

                        PrimaryActionButton(
                            title: vehicle == nil ? "Add Vehicle" : "Save Changes",
                            symbolName: "checkmark",
                            isEnabled: !name.trimmingCharacters(in: .whitespaces).isEmpty
                        ) {
                            commit()
                        }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle(vehicle == nil ? "New Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func field(
        _ title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MicroLabel(text: title, size: 10)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(Theme.Typeface.body(15))
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.Palette.surfaceRaised)
                )
        }
    }

    private func load() {
        guard let vehicle else { return }
        name = vehicle.name
        year = vehicle.year.map(String.init) ?? ""
        make = vehicle.make
        model = vehicle.model
        trim = vehicle.trim
        fuel = vehicle.fuel
        horsepower = vehicle.horsepower.map(String.init) ?? ""
        weight = vehicle.weightKg.map { String(Int($0.rounded())) } ?? ""
        drivetrain = Drivetrain(rawValue: vehicle.drivetrain) ?? .unspecified
        notes = vehicle.notes
        colorHex = vehicle.colorHex
    }

    private func commit() {
        let store = RunStore(context: context)
        if let vehicle {
            vehicle.name = name
            vehicle.year = Int(year)
            vehicle.make = make
            vehicle.model = model
            vehicle.trim = trim
            vehicle.fuel = fuel
            vehicle.horsepower = Int(horsepower)
            vehicle.weightKg = Double(weight)
            vehicle.drivetrain = drivetrain.rawValue
            vehicle.notes = notes
            vehicle.colorHex = colorHex
            store.commit()
        } else {
            store.addVehicle(
                Vehicle(
                    name: name,
                    year: Int(year),
                    make: make,
                    model: model,
                    trim: trim,
                    fuel: fuel,
                    horsepower: Int(horsepower),
                    weightKg: Double(weight),
                    drivetrain: drivetrain.rawValue,
                    notes: notes,
                    colorHex: colorHex
                )
            )
        }
        dismiss()
    }
}
