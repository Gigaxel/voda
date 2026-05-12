import SwiftUI

@main
struct AqualumeApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var state: HydrationAppState

    init() {
        let repository = SQLiteHydrationRepository()
        #if os(iOS)
        let healthKit: HealthKitWaterWriting = AppleHealthKitService()
        let reminders: ReminderScheduling = LocalReminderScheduler()
        let sync: HydrationSyncing = WatchConnectivityHydrationSyncService(
            onLog: { log in
                Task {
                    let settings = (try? await repository.loadSettings()) ?? UserHydrationSettings()
                    try? await repository.saveDailyGoalSnapshot(
                        dateKey: HydrationCalculator().dateKey(for: log.loggedAt),
                        goalML: settings.dailyGoalML
                    )
                    try? await repository.appendLog(log)
                }
            },
            onSettings: { settings in
                Task {
                    try? await repository.saveSettings(settings)
                    try? await repository.saveDailyGoalSnapshot(
                        dateKey: HydrationCalculator().dateKey(for: Date()),
                        goalML: settings.dailyGoalML
                    )
                }
            }
        )
        #else
        let healthKit: HealthKitWaterWriting = NoOpHealthKitService()
        let reminders: ReminderScheduling = NoOpReminderScheduler()
        let sync: HydrationSyncing = NoOpHydrationSyncService()
        #endif
        _state = StateObject(
            wrappedValue: HydrationAppState(
                hydrationRepository: repository,
                settingsRepository: repository,
                healthKit: healthKit,
                reminders: reminders,
                sync: sync
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            AqualumeRootView()
                .environmentObject(state)
                .task {
                    await state.load()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task {
                        await state.load()
                    }
                }
        }
    }
}
