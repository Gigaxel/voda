import SwiftUI

@main
struct AqualumeWatchApp: App {
    @StateObject private var state: HydrationAppState

    init() {
        let repository = SQLiteHydrationRepository()
        let sync = WatchConnectivityHydrationSyncService(
            onLog: { log in
                Task { try? await repository.appendLog(log) }
            },
            onSettings: { settings in
                Task { try? await repository.saveSettings(settings) }
            }
        )
        _state = StateObject(
            wrappedValue: HydrationAppState(
                hydrationRepository: repository,
                settingsRepository: repository,
                sync: sync
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            WatchHydrationView()
                .environmentObject(state)
                .task {
                    await state.load()
                }
        }
    }
}
