import SwiftUI
import SwiftData

/// The primary screen: a dashboard you can read at a glance, with one big
/// button. Everything needed to record a run is reachable without scrolling.
struct DriveView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(RunManager.self) private var manager
    @Environment(\.modelContext) private var context

    @Query private var vehicles: [Vehicle]
    @Query(sort: \Run.date, order: .reverse) private var runs: [Run]

    @State private var showsModePicker = false
    @State private var showsVehiclePicker = false

    private var selectedVehicle: Vehicle? {
        vehicles.first { $0.id == settings.selectedVehicleID } ?? vehicles.first { $0.isDefault }
    }

    var body: some View {
        ZStack {
            ScreenBackground()

            switch manager.stage {
            case .idle, .armed:
                dashboard
                    .transition(.opacity)
            case .running:
                RunningView()
                    .transition(.opacity.combined(with: .scale(scale: 1.03)))
            case .result:
                if let result = manager.latestResult {
                    RunResultView(
                        result: result,
                        mode: manager.selectedMode,
                        vehicle: selectedVehicle,
                        existingRuns: runs.summaries,
                        onSave: save,
                        onDiscard: { manager.clearResult() },
                        onRunAgain: { manager.rearm() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(Theme.Motion.stage, value: manager.stage)
        .task {
            manager.applySettings()
            manager.startSession()
        }
        .sheet(isPresented: $showsModePicker) {
            RunModePickerSheet(selected: manager.selectedMode) { mode in
                manager.selectedMode = mode
            }
        }
        .sheet(isPresented: $showsVehiclePicker) {
            VehiclePickerSheet(selectedID: settings.selectedVehicleID) { vehicle in
                settings.selectedVehicleID = vehicle?.id
            }
        }
    }

    // MARK: - Dashboard

    private var dashboard: some View {
        VStack(spacing: 14) {
            header

            if manager.authorization == .denied || manager.authorization == .notDetermined {
                permissionCard
            }

            modeBar

            Spacer(minLength: 4)

            speedBlock

            Spacer(minLength: 4)

            GForceTraceView(trace: manager.gTrace)
                .frame(height: 54)
                .padding(.horizontal, 4)

            telemetry

            if let message = manager.statusMessage {
                statusBanner(message)
            }

            footer
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack {
            TrackyWordmark(size: 19)
            Spacer()
            GPSStatusPill(status: gpsStatus)
        }
        .padding(.top, 4)
    }

    private var gpsStatus: GPSStatusPill.Status {
        if manager.isSimulated { return .simulated }
        switch manager.authorization {
        case .notDetermined, .denied:
            return .notAuthorized
        case .whenInUse, .always, .simulated:
            guard manager.hasFix, manager.horizontalAccuracy >= 0 else { return .searching }
            return .ready(accuracy: manager.horizontalAccuracy, quality: manager.gpsQuality)
        }
    }

    private var permissionCard: some View {
        GlassCard(highlight: Theme.Palette.warning) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Location access is needed")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("Tracky measures speed, distance and elevation from GPS. Nothing is uploaded and no location leaves your phone.")
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Allow location access") {
                    manager.requestAuthorization()
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.Palette.accent)
            }
        }
    }

    private var modeBar: some View {
        HStack(spacing: 10) {
            Button {
                Haptics.fire(.light)
                showsModePicker = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: manager.selectedMode.category.symbolName)
                        .font(.system(size: 13, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        MicroLabel(text: "Mode", size: 9)
                        Text(manager.selectedMode.title)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, 14)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                        .fill(Theme.Palette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                                .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PressableButtonStyle())

            Button {
                Haptics.fire(.light)
                showsVehiclePicker = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "car.fill")
                        .font(.system(size: 14, weight: .semibold))
                    Text(selectedVehicle?.name.components(separatedBy: " ").last ?? "Add")
                        .font(Theme.Typeface.label(9))
                        .lineLimit(1)
                }
                .foregroundStyle(selectedVehicle == nil ? Theme.Palette.textTertiary : Theme.Palette.accent)
                .frame(width: 66, height: 54)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                        .fill(Theme.Palette.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                                .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PressableButtonStyle())
        }
    }

    private var speedBlock: some View {
        VStack(spacing: 10) {
            SpeedReadout(speed: manager.speed, unit: settings.speedUnit, size: 108, showsUnit: false)
            unitToggle
        }
    }

    private var unitToggle: some View {
        HStack(spacing: 0) {
            ForEach(SpeedUnit.allCases) { unit in
                Button {
                    Haptics.fire(.light)
                    withAnimation(Theme.Motion.standard) { settings.speedUnit = unit }
                } label: {
                    Text(unit.symbol.uppercased())
                        .font(Theme.Typeface.label(12))
                        .kerning(1)
                        .foregroundStyle(
                            settings.speedUnit == unit ? Theme.Palette.base : Theme.Palette.textSecondary
                        )
                        .frame(width: 66, height: 34)
                        .background(
                            Capsule().fill(
                                settings.speedUnit == unit
                                    ? AnyShapeStyle(Theme.Gradients.accent)
                                    : AnyShapeStyle(Color.clear)
                            )
                        )
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(3)
        .background(
            Capsule().fill(Theme.Palette.surface)
                .overlay(Capsule().strokeBorder(Theme.Palette.stroke, lineWidth: 1))
        )
    }

    private var telemetry: some View {
        TelemetryGrid {
            TelemetryTile(
                label: "G-Force",
                value: Format.gForce(manager.gforce.combined),
                unit: "G",
                accent: manager.gforce.longitudinal < -0.05
                    ? Theme.Palette.gBrake
                    : Theme.Palette.gAccel,
                symbolName: "arrow.up.and.down.and.arrow.left.and.right"
            )
            TelemetryTile(
                label: "Elevation",
                value: Format.elevation(manager.altitude, unit: settings.distanceUnit),
                unit: nil,
                symbolName: "mountain.2.fill"
            )
            TelemetryTile(
                label: "Distance",
                value: Format.longDistance(
                    manager.sessionDistance,
                    unit: settings.distanceUnit
                ),
                unit: nil,
                symbolName: "point.topleft.down.to.point.bottomright.curvepath"
            )
            TelemetryTile(
                label: "GPS Accuracy",
                value: Format.accuracy(manager.horizontalAccuracy),
                unit: nil,
                accent: Theme.Palette.quality(manager.gpsQuality),
                symbolName: "antenna.radiowaves.left.and.right"
            )
        }
    }

    private func statusBanner(_ message: String) -> some View {
        Text(message)
            .font(Theme.Typeface.body(13))
            .foregroundStyle(Theme.Palette.warning)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.Palette.warning.opacity(0.12))
            )
            .transition(.opacity)
    }

    private var footer: some View {
        Group {
            if manager.stage == .armed {
                VStack(spacing: 10) {
                    ArmedBanner(mode: manager.selectedMode, isSimulated: manager.isSimulated)
                    PrimaryActionButton(title: "Cancel", style: .danger) {
                        manager.cancelRun()
                    }
                }
            } else {
                PrimaryActionButton(
                    title: "Start Run",
                    subtitle: manager.selectedMode.title,
                    symbolName: "bolt.fill",
                    isEnabled: manager.authorization.isUsable
                ) {
                    manager.arm()
                }
            }
        }
    }

    // MARK: - Saving

    private func save(_ result: PerformanceResult) {
        let store = RunStore(context: context)
        store.save(
            result: result,
            category: manager.selectedMode.category,
            vehicle: selectedVehicle,
            storeRoute: settings.storeRouteData
        )
        manager.clearResult()
    }
}

/// The "waiting for launch" state. Big, calm, and readable from the driver's
/// seat without touching anything.
struct ArmedBanner: View {
    let mode: RunMode
    var isSimulated = false
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Theme.Palette.accent)
                .frame(width: 10, height: 10)
                .scaleEffect(isPulsing ? 1.5 : 1)
                .opacity(isPulsing ? 0.35 : 1)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isPulsing)
            VStack(alignment: .leading, spacing: 2) {
                Text("ARMED · WAITING FOR LAUNCH")
                    .font(Theme.Typeface.label(12))
                    .kerning(1.1)
                    .foregroundStyle(Theme.Palette.accent)
                Text(isSimulated
                     ? "Simulated launch in a moment."
                     : "Come to a stop, then accelerate. Tracky starts the clock itself.")
                    .font(Theme.Typeface.body(12))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                .fill(Theme.Palette.accent.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Metrics.cardRadius, style: .continuous)
                        .strokeBorder(Theme.Palette.accent.opacity(0.35), lineWidth: 1)
                )
        )
        .onAppear { isPulsing = true }
    }
}
