import SwiftUI
import SwiftData

@main
struct TrackyApp: App {

    @State private var settings: SettingsStore
    @State private var runManager: RunManager
    private let container: ModelContainer

    init() {
        let settings = SettingsStore()
        _settings = State(initialValue: settings)
        _runManager = State(initialValue: RunManager(settings: settings))
        container = TrackyApp.makeContainer()
        TrackyAppearance.apply()
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(settings)
                .environment(runManager)
                .preferredColorScheme(settings.appearance.colorScheme)
                .tint(Theme.Palette.accent)
        }
        .modelContainer(container)
    }

    /// Falls back to an in-memory store rather than crashing: losing history is
    /// bad, but an app that will not launch is worse.
    private static func makeContainer() -> ModelContainer {
        let schema = Schema([Run.self, Vehicle.self])
        do {
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema)]
            )
        } catch {
            assertionFailure("Tracky could not open its store: \(error)")
            return try! ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)]
            )
        }
    }
}
