import SwiftUI

/// Mode selection, built for speed: one tap picks a mode and closes the sheet.
struct RunModePickerSheet: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(\.dismiss) private var dismiss

    let selected: RunMode
    let onSelect: (RunMode) -> Void

    @State private var showsEditor = false

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        group(
                            title: "Acceleration",
                            subtitle: "Time between two speeds",
                            modes: RunMode.accelerationPresets
                        )
                        group(
                            title: "Distance",
                            subtitle: "Time to cover a distance from a standing start",
                            modes: RunMode.distancePresets
                        )
                        customSection
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Run Mode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.Palette.accent)
                }
            }
            .sheet(isPresented: $showsEditor) {
                CustomModeEditor { mode in
                    settings.addCustomMode(mode)
                    pick(mode)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func group(title: String, subtitle: String, modes: [RunMode]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title, subtitle: subtitle)
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(modes) { mode in
                    ModeChip(
                        title: mode.shortTitle,
                        subtitle: subtitleText(for: mode),
                        isSelected: mode.id == selected.id
                    ) {
                        pick(mode)
                    }
                }
            }
        }
    }

    private var customSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Custom", subtitle: "Your own tests")

            if settings.customModes.isEmpty {
                Text("Build something specific: 50–100 km/h for a roll race, 100–200 km/h for a top-end pull, or any distance you like.")
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(settings.customModes) { mode in
                        ModeChip(
                            title: mode.shortTitle,
                            subtitle: subtitleText(for: mode),
                            isSelected: mode.id == selected.id
                        ) {
                            pick(mode)
                        }
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                settings.removeCustomMode(id: mode.id)
                            }
                        }
                    }
                }
            }

            Button {
                Haptics.fire(.light)
                showsEditor = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                    Text("New custom test")
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

            quickSuggestions
        }
    }

    private var quickSuggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            MicroLabel(text: "Quick add", size: 10)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RunMode.customSuggestions) { mode in
                        Button {
                            settings.addCustomMode(mode)
                            pick(mode)
                        } label: {
                            Text(mode.title)
                                .font(Theme.Typeface.label(12))
                                .foregroundStyle(Theme.Palette.textSecondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    Capsule().fill(Theme.Palette.surfaceRaised)
                                )
                        }
                    }
                }
            }
        }
    }

    private func subtitleText(for mode: RunMode) -> String? {
        switch mode.target {
        case .speed:
            return (mode.speedUnitHint ?? .kmh).symbol
        case .distance(let meters):
            return meters >= 1000 ? nil : "\(Int(meters.rounded())) m"
        }
    }

    private func pick(_ mode: RunMode) {
        onSelect(mode)
        dismiss()
    }
}

#Preview {
    RunModePickerSheet(selected: .zeroToHundredKmh) { _ in }
        .environment(SettingsStore(defaults: UserDefaults(suiteName: "preview") ?? .standard))
}
