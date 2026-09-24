import SwiftUI
import SwiftData

/// The garage, reached from Settings. Shows how each car has been doing.
struct VehicleListView: View {

    @Environment(\.modelContext) private var context
    @Environment(SettingsStore.self) private var settings
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]
    @Query private var runs: [Run]

    @State private var showsEditor = false
    @State private var editing: Vehicle?

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView {
                VStack(spacing: 12) {
                    if vehicles.isEmpty {
                        EmptyStateView(
                            symbolName: "car.2.fill",
                            title: "No vehicles yet",
                            message: "Add a car so runs can be grouped and compared. Nothing about it is required."
                        )
                    }

                    ForEach(vehicles) { vehicle in
                        card(for: vehicle)
                    }

                    Button {
                        Haptics.fire(.light)
                        showsEditor = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                            Text("Add a vehicle")
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Theme.Palette.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: Theme.Metrics.touchTarget)
                        .background(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                                .fill(Theme.Palette.accent.opacity(0.1))
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                .padding(Theme.Metrics.screenPadding)
            }
        }
        .navigationTitle("Vehicles")
        .sheet(isPresented: $showsEditor) { VehicleEditorView() }
        .sheet(item: $editing) { vehicle in VehicleEditorView(vehicle: vehicle) }
    }

    private func card(for vehicle: Vehicle) -> some View {
        let vehicleRuns = runs.filter { $0.vehicle?.id == vehicle.id }
        let best = PersonalBestCalculator.bests(from: vehicleRuns.summaries).first

        return GlassCard(highlight: vehicle.id == settings.selectedVehicleID ? Color(hexString: vehicle.colorHex) : nil) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hexString: vehicle.colorHex))
                        .frame(width: 4, height: 38)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(vehicle.name)
                            .font(Theme.Typeface.title(18))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        if !vehicle.subtitle.isEmpty {
                            Text(vehicle.subtitle)
                                .font(Theme.Typeface.body(12))
                                .foregroundStyle(Theme.Palette.textTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                    Menu {
                        Button("Use for next run", systemImage: "checkmark.circle") {
                            settings.selectedVehicleID = vehicle.id
                        }
                        Button("Edit", systemImage: "pencil") { editing = vehicle }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            RunStore(context: context).delete(vehicle: vehicle)
                            if settings.selectedVehicleID == vehicle.id {
                                settings.selectedVehicleID = nil
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundStyle(Theme.Palette.textTertiary)
                            .frame(width: 44, height: 44)
                    }
                }

                HStack(spacing: 18) {
                    stat("Runs", "\(vehicleRuns.count)")
                    if let best {
                        stat(best.modeTitle, "\(Format.time(best.duration)) s")
                    }
                    if let ratio = vehicle.powerToWeight {
                        stat("hp / tonne", String(format: "%.0f", ratio))
                    }
                }

                if !vehicle.notes.isEmpty {
                    Text(vehicle.notes)
                        .font(Theme.Typeface.body(12))
                        .foregroundStyle(Theme.Palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(text: label, size: 9)
            Text(value)
                .font(Theme.Typeface.value(16))
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }
}
