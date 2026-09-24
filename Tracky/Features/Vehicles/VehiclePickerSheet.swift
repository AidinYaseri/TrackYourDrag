import SwiftUI
import SwiftData

/// Pick the car before a run. One tap, then it closes.
struct VehiclePickerSheet: View {

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    let selectedID: UUID?
    let onSelect: (Vehicle?) -> Void

    @State private var showsEditor = false

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(vehicles) { vehicle in
                            row(for: vehicle)
                        }

                        Button {
                            onSelect(nil)
                            dismiss()
                        } label: {
                            HStack {
                                Text("No vehicle")
                                    .font(Theme.Typeface.body(15))
                                    .foregroundStyle(Theme.Palette.textSecondary)
                                Spacer()
                                if selectedID == nil {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Theme.Palette.accent)
                                }
                            }
                            .padding(16)
                            .frame(minHeight: Theme.Metrics.touchTarget)
                            .background(
                                RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                                    .fill(Theme.Palette.surface)
                            )
                        }
                        .buttonStyle(PressableButtonStyle())

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
                        .padding(.top, 6)
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .sheet(isPresented: $showsEditor) {
                VehicleEditorView()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func row(for vehicle: Vehicle) -> some View {
        Button {
            onSelect(vehicle)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(hexString: vehicle.colorHex))
                    .frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.name)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    if !vehicle.subtitle.isEmpty {
                        Text(vehicle.subtitle)
                            .font(Theme.Typeface.body(12))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                }
                Spacer(minLength: 0)
                if vehicle.id == selectedID {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .padding(16)
            .frame(minHeight: Theme.Metrics.touchTarget)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                    .fill(Theme.Palette.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                            .strokeBorder(
                                vehicle.id == selectedID ? Theme.Palette.accent.opacity(0.5) : Theme.Palette.stroke,
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(PressableButtonStyle())
    }
}
