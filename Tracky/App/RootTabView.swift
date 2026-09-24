import SwiftUI
import SwiftData

struct RootTabView: View {

    enum Tab: Hashable {
        case drive, runs, stats, settings
    }

    @Environment(SettingsStore.self) private var settings
    @Environment(\.modelContext) private var context
    @State private var selection: Tab = .drive
    @State private var showsDisclaimer = false

    var body: some View {
        TabView(selection: $selection) {
            DriveView()
                .tabItem {
                    Label("Drive", systemImage: "gauge.with.dots.needle.67percent")
                }
                .tag(Tab.drive)

            RunsListView()
                .tabItem {
                    Label("Runs", systemImage: "list.bullet.rectangle")
                }
                .tag(Tab.runs)

            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(Tab.stats)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(Tab.settings)
        }
        .tint(Theme.Palette.accent)
        .task {
            SampleDataSeeder.seedIfNeeded(context: context, settings: settings)
            if !settings.acceptedDisclaimer { showsDisclaimer = true }
        }
        .sheet(isPresented: $showsDisclaimer) {
            WelcomeSheet {
                settings.acceptedDisclaimer = true
                showsDisclaimer = false
            }
            .interactiveDismissDisabled()
        }
    }
}

/// Shown once, on first launch. Sets expectations about accuracy and about
/// where performance testing belongs.
struct WelcomeSheet: View {
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            ScreenBackground()
            VStack(spacing: 0) {
                Spacer(minLength: 24)
                TrackyMark().frame(width: 92, height: 92)
                Text("TRACKY")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .kerning(5)
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(.top, 14)
                Text("Measure Your Drive.")
                    .font(Theme.Typeface.body(15))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: 16) {
                    row(
                        symbol: "hand.raised.fill",
                        title: "Test where it is legal and safe",
                        detail: "Tracky is a measurement tool, not a reason to speed. Use a closed course or a legal venue."
                    )
                    row(
                        symbol: "iphone.gen3",
                        title: "Mount the phone and leave it alone",
                        detail: "Arm a run before you set off. Tracky detects the launch and the finish on its own."
                    )
                    row(
                        symbol: "antenna.radiowaves.left.and.right",
                        title: "A phone is not a timing beam",
                        detail: "Results depend on GPS reception, the handset, the mount, the road and satellite visibility. Tracky shows the signal quality behind every run."
                    )
                }
                .padding(.top, 30)

                Spacer(minLength: 20)
                PrimaryActionButton(title: "Let's Drive", symbolName: "checkmark") {
                    onContinue()
                }
            }
            .padding(Theme.Metrics.screenPadding)
        }
    }

    private func row(symbol: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.Palette.accent)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(Theme.Typeface.body(13))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    WelcomeSheet {}
}
