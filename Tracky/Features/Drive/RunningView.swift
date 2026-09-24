import SwiftUI

/// Shown while the clock is running. Three things matter here: speed, how far
/// through the run you are, and the G trace. Everything else gets out of the way.
struct RunningView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(RunManager.self) private var manager

    var body: some View {
        VStack(spacing: 16) {
            header

            Spacer(minLength: 0)

            SpeedReadout(speed: manager.speed, unit: settings.speedUnit, size: 132, showsUnit: true)

            HStack(alignment: .center, spacing: 16) {
                GForceMeter(reading: manager.gforce, trace: manager.gTrace, showsLabels: false)
                    .frame(width: 112, height: 112)

                VStack(alignment: .leading, spacing: 8) {
                    MicroLabel(text: "Live G")
                    Text(Format.gForce(manager.gforce.combined))
                        .font(Theme.Typeface.readout(44))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .contentTransition(.numericText())
                    HStack(spacing: 10) {
                        axisValue("LONG", manager.gforce.longitudinal, Theme.Palette.accent)
                        axisValue("LAT", manager.gforce.lateral, Theme.Palette.gLateral)
                    }
                }
                Spacer(minLength: 0)
            }

            GForceTraceView(trace: manager.gTrace)
                .frame(height: 64)

            Spacer(minLength: 0)

            if let progress = manager.progress {
                RunProgressView(
                    title: manager.selectedMode.title,
                    currentText: currentText(progress),
                    targetText: targetText(progress),
                    unitText: unitText(progress),
                    fraction: progress.fraction
                )
            }

            if let split = manager.latestSplit {
                splitBanner(split)
            }

            PrimaryActionButton(title: "Cancel Run", style: .danger) {
                manager.cancelRun()
            }
        }
        .padding(.horizontal, Theme.Metrics.screenPadding)
        .padding(.bottom, 6)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 7) {
                Circle()
                    .fill(Theme.Palette.danger)
                    .frame(width: 9, height: 9)
                MicroLabel(text: "Recording", color: Theme.Palette.danger, size: 11)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Format.time(manager.elapsed))
                    .font(Theme.Typeface.value(26))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .contentTransition(.numericText())
                MicroLabel(text: "sec", size: 10)
            }
        }
        .padding(.top, 6)
    }

    private func axisValue(_ label: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            MicroLabel(text: label, size: 9)
            Text(Format.gForce(value))
                .font(Theme.Typeface.value(16))
                .foregroundStyle(color)
                .contentTransition(.numericText())
        }
    }

    private func splitBanner(_ split: Split) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "flag.fill")
                .font(.system(size: 11, weight: .bold))
            Text("\(split.label) · \(Format.time(split.time)) s")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.Palette.accent)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Palette.accent.opacity(0.12))
        )
        .transition(.opacity)
        .id(split.label)
    }

    // MARK: - Progress formatting

    private func currentText(_ progress: PerformanceEngine.Progress) -> String {
        progress.isDistance
            ? String(Int(settings.distanceUnit.shortValue(fromMeters: progress.current).rounded()))
            : Format.speed(progress.current, unit: settings.speedUnit)
    }

    private func targetText(_ progress: PerformanceEngine.Progress) -> String {
        progress.isDistance
            ? String(Int(settings.distanceUnit.shortValue(fromMeters: progress.target).rounded()))
            : Format.speed(progress.target, unit: settings.speedUnit)
    }

    private func unitText(_ progress: PerformanceEngine.Progress) -> String {
        progress.isDistance ? settings.distanceUnit.shortSymbol : settings.speedUnit.symbol
    }
}
