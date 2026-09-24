import SwiftUI
import SwiftData

/// Everything recorded, sortable and filterable, with a two-run comparison mode.
struct RunsListView: View {

    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context
    @Query private var runs: [Run]
    @Query(sort: \Vehicle.createdAt) private var vehicles: [Vehicle]

    @State private var sort: RunSortOption = .date
    @State private var vehicleFilter: UUID?
    @State private var modeFilter: String?
    @State private var isComparing = false
    @State private var selection: [Run] = []
    @State private var comparison: RunPair?

    private var filtered: [Run] {
        runs
            .filter { vehicleFilter == nil || $0.vehicle?.id == vehicleFilter }
            .filter { modeFilter == nil || $0.modeID == modeFilter }
            .sorted(by: sort)
    }

    private var recordIDs: Set<UUID> {
        Set(PersonalBestCalculator.bests(from: runs.summaries).map(\.runID))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                content
            }
            .navigationTitle("Runs")
            .toolbar { toolbar }
            .sheet(item: $comparison) { pair in
                RunComparisonView(runA: pair.a, runB: pair.b)
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 12) {
                filterBar

                if filtered.isEmpty {
                    EmptyStateView(
                        symbolName: "flag.checkered",
                        title: runs.isEmpty ? "No runs yet" : "Nothing matches",
                        message: runs.isEmpty
                            ? "Arm a run on the Drive tab. Tracky detects the launch and saves the result here."
                            : "Try a different filter."
                    )
                } else {
                    ForEach(filtered) { run in
                        if isComparing {
                            Button { toggle(run) } label: { card(for: run) }
                                .buttonStyle(PressableButtonStyle())
                        } else {
                            NavigationLink {
                                RunDetailView(run: run)
                            } label: {
                                card(for: run)
                            }
                            .buttonStyle(PressableButtonStyle())
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    RunStore(context: context).delete(run)
                                }
                            }
                        }
                    }
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    private func card(for run: Run) -> some View {
        RunCardView(
            run: run,
            speedUnit: settings.speedUnit,
            distanceUnit: settings.distanceUnit,
            isRecord: recordIDs.contains(run.id),
            isSelected: selection.contains { $0.id == run.id },
            selectionEnabled: isComparing
        )
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(RunSortOption.allCases) { option in
                    Button(option.title, systemImage: option.symbolName) { sort = option }
                }
            } label: {
                chip(label: "Sort", value: sort.title, symbol: "arrow.up.arrow.down")
            }

            Menu {
                Button("All vehicles") { vehicleFilter = nil }
                ForEach(vehicles) { vehicle in
                    Button(vehicle.name) { vehicleFilter = vehicle.id }
                }
            } label: {
                chip(
                    label: "Vehicle",
                    value: vehicles.first { $0.id == vehicleFilter }?.name ?? "All",
                    symbol: "car.fill"
                )
            }

            Menu {
                Button("All modes") { modeFilter = nil }
                ForEach(Array(Set(runs.map(\.modeID))).sorted(), id: \.self) { id in
                    Button(runs.first { $0.modeID == id }?.modeTitle ?? id) { modeFilter = id }
                }
            } label: {
                chip(
                    label: "Mode",
                    value: modeFilter.flatMap { id in runs.first { $0.modeID == id }?.shortModeTitle } ?? "All",
                    symbol: "gauge.with.dots.needle.67percent"
                )
            }
        }
    }

    private func chip(label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
            VStack(alignment: .leading, spacing: 1) {
                MicroLabel(text: label, size: 8)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .padding(.horizontal, 11)
        .frame(height: 44)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Theme.Palette.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Theme.Palette.stroke, lineWidth: 1)
                )
        )
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button(isComparing ? "Cancel" : "Compare") {
                withAnimation(Theme.Motion.standard) {
                    isComparing.toggle()
                    selection.removeAll()
                }
            }
            .foregroundStyle(Theme.Palette.accent)
            .disabled(runs.count < 2)
        }
    }

    private func toggle(_ run: Run) {
        Haptics.fire(.light)
        if let index = selection.firstIndex(where: { $0.id == run.id }) {
            selection.remove(at: index)
            return
        }
        selection.append(run)
        if selection.count == 2 {
            comparison = RunPair(a: selection[0], b: selection[1])
            selection.removeAll()
            isComparing = false
        }
    }
}

/// Two runs chosen for comparison.
struct RunPair: Identifiable {
    let a: Run
    let b: Run
    var id: String { "\(a.id)-\(b.id)" }
}

extension Run {
    /// Shorter label for filter chips.
    var shortModeTitle: String {
        modeTitle
            .replacingOccurrences(of: " km/h", with: "")
            .replacingOccurrences(of: " mph", with: "")
    }
}
