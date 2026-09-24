import SwiftUI

/// Builds a custom speed-interval or distance test.
struct CustomModeEditor: View {

    private enum Kind: String, CaseIterable, Identifiable {
        case speed
        case distance

        var id: String { rawValue }
        var title: String { self == .speed ? "Speed interval" : "Distance" }
    }

    private enum DistanceInput: String, CaseIterable, Identifiable {
        case meters
        case feet
        case kilometers
        case miles

        var id: String { rawValue }

        var title: String {
            switch self {
            case .meters: return "m"
            case .feet: return "ft"
            case .kilometers: return "km"
            case .miles: return "mi"
            }
        }

        func meters(from value: Double) -> Double {
            switch self {
            case .meters: return value
            case .feet: return UnitConversion.meters(fromFeet: value)
            case .kilometers: return value * 1000
            case .miles: return value * UnitConversion.metersPerMile
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    let onCreate: (RunMode) -> Void

    @State private var kind: Kind = .speed
    @State private var speedUnit: SpeedUnit = .kmh
    @State private var fromSpeed = "0"
    @State private var toSpeed = "80"
    @State private var distanceValue = "500"
    @State private var distanceUnit: DistanceInput = .meters

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Picker("Kind", selection: $kind) {
                            ForEach(Kind.allCases) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        if kind == .speed {
                            speedEditor
                        } else {
                            distanceEditor
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 6) {
                                MicroLabel(text: "Preview")
                                Text(previewMode?.title ?? "Enter values")
                                    .font(Theme.Typeface.title(22))
                                    .foregroundStyle(Theme.Palette.textPrimary)
                                if let message = validationMessage {
                                    Text(message)
                                        .font(Theme.Typeface.body(12))
                                        .foregroundStyle(Theme.Palette.warning)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        PrimaryActionButton(
                            title: "Create test",
                            symbolName: "checkmark",
                            isEnabled: previewMode != nil
                        ) {
                            if let mode = previewMode {
                                onCreate(mode)
                                dismiss()
                            }
                        }
                    }
                    .padding(Theme.Metrics.screenPadding)
                }
            }
            .navigationTitle("Custom Test")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.Palette.textSecondary)
                }
            }
        }
    }

    private var speedEditor: some View {
        GlassCard {
            VStack(spacing: 16) {
                Picker("Unit", selection: $speedUnit) {
                    ForEach(SpeedUnit.allCases) { Text($0.symbol).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 12) {
                    numberField(title: "From", text: $fromSpeed)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                    numberField(title: "To", text: $toSpeed)
                }
            }
        }
    }

    private var distanceEditor: some View {
        GlassCard {
            VStack(spacing: 16) {
                Picker("Unit", selection: $distanceUnit) {
                    ForEach(DistanceInput.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                numberField(title: "Distance", text: $distanceValue)
            }
        }
    }

    private func numberField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            MicroLabel(text: title, size: 10)
            TextField("", text: text)
                .keyboardType(.decimalPad)
                .font(Theme.Typeface.value(26))
                .foregroundStyle(Theme.Palette.textPrimary)
                .padding(.horizontal, 12)
                .frame(height: Theme.Metrics.touchTarget)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Metrics.controlRadius, style: .continuous)
                        .fill(Theme.Palette.surfaceRaised)
                )
        }
    }

    // MARK: - Validation

    private var previewMode: RunMode? {
        switch kind {
        case .speed:
            guard let from = Double(fromSpeed.replacingOccurrences(of: ",", with: ".")),
                  let to = Double(toSpeed.replacingOccurrences(of: ",", with: ".")),
                  from >= 0, to > from, to <= 500 else { return nil }
            return speedUnit == .kmh
                ? .acceleration(fromKmh: from, toKmh: to, isCustom: true)
                : .acceleration(fromMph: from, toMph: to, isCustom: true)
        case .distance:
            guard let value = Double(distanceValue.replacingOccurrences(of: ",", with: ".")),
                  value > 0 else { return nil }
            let meters = distanceUnit.meters(from: value)
            guard meters >= 20, meters <= 20_000 else { return nil }
            let label = "\(Format.grouped(value)) \(distanceUnit.title)"
            return .distance(
                meters: meters,
                id: "custom-dist-\(Int(meters.rounded()))",
                title: label,
                shortTitle: label,
                isCustom: true
            )
        }
    }

    private var validationMessage: String? {
        guard previewMode == nil else { return nil }
        switch kind {
        case .speed:
            return "The finish speed has to be higher than the start speed."
        case .distance:
            return "Pick a distance between 20 m and 20 km."
        }
    }
}

#Preview {
    CustomModeEditor { _ in }
}
