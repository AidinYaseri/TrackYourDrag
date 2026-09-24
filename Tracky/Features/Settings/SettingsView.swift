import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(RunManager.self) private var manager
    @Environment(\.modelContext) private var context
    @Query private var runs: [Run]

    @State private var confirmation: DestructiveAction?

    enum DestructiveAction: String, Identifiable {
        case deleteRuns
        case deleteEverything
        case stripLocations

        var id: String { rawValue }

        var title: String {
            switch self {
            case .deleteRuns: return "Delete every run?"
            case .deleteEverything: return "Delete all Tracky data?"
            case .stripLocations: return "Remove location data from every run?"
            }
        }

        var message: String {
            switch self {
            case .deleteRuns: return "Your vehicles stay. Every recorded run and its telemetry is removed. This cannot be undone."
            case .deleteEverything: return "Runs, telemetry and vehicles are all removed. This cannot be undone."
            case .stripLocations: return "Times, speeds and G-forces are kept. Every stored coordinate is removed. This cannot be undone."
            }
        }

        var confirmTitle: String {
            switch self {
            case .deleteRuns: return "Delete runs"
            case .deleteEverything: return "Delete everything"
            case .stripLocations: return "Remove locations"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(spacing: 18) {
                        unitsSection
                        measurementSection
                        gpsSection
                        vehiclesSection
                        appearanceSection
                        feedbackSection
                        dataSection
                        aboutSection
                        footer
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Settings")
            .confirmationDialog(
                confirmation?.title ?? "",
                isPresented: Binding(
                    get: { confirmation != nil },
                    set: { if !$0 { confirmation = nil } }
                ),
                titleVisibility: .visible,
                presenting: confirmation
            ) { action in
                Button(action.confirmTitle, role: .destructive) { perform(action) }
                Button("Cancel", role: .cancel) {}
            } message: { action in
                Text(action.message)
            }
        }
    }

    // MARK: - Units

    private var unitsSection: some View {
        section(title: "Units") {
            VStack(spacing: 14) {
                picker(label: "Speed", selection: Binding(
                    get: { settings.speedUnit },
                    set: { settings.speedUnit = $0 }
                )) { unit in Text(unit.symbol) }

                picker(label: "Distance", selection: Binding(
                    get: { settings.distanceUnit },
                    set: { settings.distanceUnit = $0 }
                )) { unit in Text(unit == .metric ? "km / m" : "mi / ft") }

                picker(label: "Temperature", selection: Binding(
                    get: { settings.temperatureUnit },
                    set: { settings.temperatureUnit = $0 }
                )) { unit in Text(unit.symbol) }
            }
        }
    }

    // MARK: - Measurement

    private var measurementSection: some View {
        section(title: "Measurement") {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    MicroLabel(text: "Sensor rate", size: 10)
                    Picker("Sensor rate", selection: Binding(
                        get: { settings.sensorProfile },
                        set: {
                            settings.sensorProfile = $0
                            manager.applySettings()
                        }
                    )) {
                        ForEach(SensorProfile.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text(settings.sensorProfile.detail)
                        .font(Theme.Typeface.body(12))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().overlay(Theme.Palette.stroke)

                toggle(
                    label: "One-foot rollout",
                    detail: "Drag-strip convention: on distance runs the clock starts once the car has moved one foot, not the instant it moves.",
                    isOn: Binding(
                        get: { settings.rolloutEnabled },
                        set: {
                            settings.rolloutEnabled = $0
                            manager.applySettings()
                        }
                    )
                )

                Divider().overlay(Theme.Palette.stroke)

                toggle(
                    label: "Keep recording in the background",
                    detail: "Lets a session started in the driveway survive the drive out. Needs Always location access.",
                    isOn: Binding(
                        get: { settings.backgroundTracking },
                        set: {
                            settings.backgroundTracking = $0
                            manager.applySettings()
                        }
                    )
                )
            }
        }
    }

    // MARK: - GPS

    private var gpsSection: some View {
        section(title: "GPS") {
            VStack(alignment: .leading, spacing: 12) {
                StatRow(
                    label: "Current accuracy",
                    value: Format.accuracy(manager.horizontalAccuracy),
                    detail: manager.gpsQuality.title,
                    accent: Theme.Palette.quality(manager.gpsQuality)
                )
                Divider().overlay(Theme.Palette.stroke)
                StatRow(
                    label: "Fixes received",
                    value: "\(manager.statistics.accuracySummary.sampleCount)",
                    detail: String(format: "%.1f per second", manager.statistics.fixRate)
                )
                Divider().overlay(Theme.Palette.stroke)
                StatRow(
                    label: "Elevation source",
                    value: manager.hasBarometer ? manager.elevationSource.description : "GPS altitude",
                    detail: manager.hasBarometer
                        ? "Barometer detail on a GPS reference"
                        : "This device has no barometer"
                )
                Divider().overlay(Theme.Palette.stroke)
                StatRow(
                    label: "Motion reference",
                    value: manager.isNorthReferenced ? "True north" : "Vertical only",
                    detail: manager.isNorthReferenced
                        ? "Full longitudinal and lateral split"
                        : "Lateral G is estimated"
                )

                NavigationLink {
                    AccuracyInfoView()
                } label: {
                    HStack {
                        Text("What affects accuracy")
                            .font(Theme.Typeface.body(14))
                            .foregroundStyle(Theme.Palette.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    .frame(height: 44)
                }
            }
        }
    }

    // MARK: - Vehicles

    private var vehiclesSection: some View {
        section(title: "Vehicle") {
            NavigationLink {
                VehicleListView()
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Manage vehicles")
                            .font(Theme.Typeface.body(15))
                            .foregroundStyle(Theme.Palette.textPrimary)
                        Text("Add, edit or remove cars")
                            .font(Theme.Typeface.body(12))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .frame(minHeight: Theme.Metrics.touchTarget)
            }
        }
    }

    // MARK: - Appearance

    private var appearanceSection: some View {
        section(title: "Appearance") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Appearance", selection: Binding(
                    get: { settings.appearance },
                    set: { settings.appearance = $0 }
                )) {
                    ForEach(AppAppearance.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                Text("Tracky is built for the dark. Light mode is there if you need it in bright sun.")
                    .font(Theme.Typeface.body(12))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var feedbackSection: some View {
        section(title: "Feedback") {
            VStack(alignment: .leading, spacing: 14) {
                toggle(
                    label: "Haptics",
                    detail: "A tap on launch, on each split and when a run finishes, so you do not need to look.",
                    isOn: Binding(
                        get: { settings.hapticsEnabled },
                        set: { settings.hapticsEnabled = $0 }
                    )
                )
                Divider().overlay(Theme.Palette.stroke)
                toggle(
                    label: "Keep the screen on during a session",
                    detail: nil,
                    isOn: Binding(
                        get: { settings.keepScreenAwake },
                        set: {
                            settings.keepScreenAwake = $0
                            manager.applySettings()
                        }
                    )
                )
                #if !targetEnvironment(simulator)
                Divider().overlay(Theme.Palette.stroke)
                toggle(
                    label: "Demo mode",
                    detail: "Generates a drive instead of reading the sensors. Useful for showing the app to someone while parked.",
                    isOn: Binding(
                        get: { settings.demoMode },
                        set: {
                            settings.demoMode = $0
                            manager.rebuildSource()
                        }
                    )
                )
                #endif
            }
        }
    }

    // MARK: - Data

    private var dataSection: some View {
        section(title: "Data") {
            VStack(alignment: .leading, spacing: 14) {
                toggle(
                    label: "Record the route",
                    detail: "Stores the GPS track with each new run so it can be shown on a map. Stored on this device only, never uploaded.",
                    isOn: Binding(
                        get: { settings.storeRouteData },
                        set: { settings.storeRouteData = $0 }
                    )
                )

                Divider().overlay(Theme.Palette.stroke)

                destructiveRow(
                    title: "Remove all location data",
                    detail: "\(runs.filter(\.hasRoute).count) run\(runs.filter(\.hasRoute).count == 1 ? "" : "s") currently store a route",
                    tint: Theme.Palette.warning
                ) { confirmation = .stripLocations }

                destructiveRow(
                    title: "Delete all runs",
                    detail: "\(runs.count) saved",
                    tint: Theme.Palette.danger
                ) { confirmation = .deleteRuns }

                destructiveRow(
                    title: "Delete all data",
                    detail: "Runs and vehicles",
                    tint: Theme.Palette.danger
                ) { confirmation = .deleteEverything }
            }
        }
    }

    private var aboutSection: some View {
        section(title: "About") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tracky is a telemetry and performance measurement tool. Always use it responsibly and only perform performance testing where it is legal and safe to do so.")
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationLink {
                    MethodologyView()
                } label: {
                    HStack {
                        Text("How Tracky measures")
                            .font(Theme.Typeface.body(14))
                            .foregroundStyle(Theme.Palette.accent)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.Palette.textTertiary)
                    }
                    .frame(height: 44)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 8) {
            TrackyWordmark(size: 17, showsTagline: true)
            Text("Version \(Bundle.main.appVersion) (\(Bundle.main.appBuild))")
                .font(Theme.Typeface.body(11))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
        .padding(.top, 8)
        .padding(.bottom, 20)
    }

    // MARK: - Building blocks

    private func section<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: title)
            GlassCard { content().frame(maxWidth: .infinity, alignment: .leading) }
        }
    }

    private func picker<Value: Hashable & Identifiable & CaseIterable, Label: View>(
        label: String,
        selection: Binding<Value>,
        @ViewBuilder content: @escaping (Value) -> Label
    ) -> some View where Value.AllCases: RandomAccessCollection {
        VStack(alignment: .leading, spacing: 8) {
            MicroLabel(text: label, size: 10)
            Picker(label, selection: selection) {
                ForEach(Value.allCases) { value in
                    content(value).tag(value)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private func toggle(label: String, detail: String?, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(Theme.Typeface.body(15))
                    .foregroundStyle(Theme.Palette.textPrimary)
                if let detail {
                    Text(detail)
                        .font(Theme.Typeface.body(12))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.Palette.accent)
    }

    private func destructiveRow(
        title: String,
        detail: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typeface.body(15))
                        .foregroundStyle(tint)
                    Text(detail)
                        .font(Theme.Typeface.body(12))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                Spacer()
            }
            .frame(minHeight: Theme.Metrics.touchTarget - 8)
        }
    }

    private func perform(_ action: DestructiveAction) {
        let store = RunStore(context: context)
        switch action {
        case .deleteRuns:
            store.deleteAllRuns()
        case .deleteEverything:
            store.deleteEverything()
            settings.selectedVehicleID = nil
        case .stripLocations:
            store.stripAllLocationData()
        }
        Haptics.fire(.warning)
    }
}

extension Bundle {
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var appBuild: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}
