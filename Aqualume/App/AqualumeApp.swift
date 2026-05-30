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
        let liveActivity: LiveActivityControlling = LiveActivityController()
        func refreshLiveActivity(settings: UserHydrationSettings) async {
            let totalML = (try? await repository.total(on: Date(), calendar: .current)) ?? 0
            await liveActivity.refresh(
                totalML: totalML,
                goalML: settings.dailyGoalML,
                unitSystem: settings.unitSystem,
                defaultAmountML: settings.defaultAmountML
            )
        }
        let sync: HydrationSyncing = WatchConnectivityHydrationSyncService(
            onLog: { log in
                Task {
                    let settings = (try? await repository.loadSettings()) ?? UserHydrationSettings()
                    try? await repository.saveDailyGoalSnapshot(
                        dateKey: HydrationCalculator().dateKey(for: log.loggedAt),
                        goalML: settings.dailyGoalML
                    )
                    try? await repository.appendLog(log)
                    await refreshLiveActivity(settings: settings)
                }
            },
            onSettings: { settings in
                Task {
                    try? await repository.saveSettings(settings)
                    try? await repository.saveDailyGoalSnapshot(
                        dateKey: HydrationCalculator().dateKey(for: Date()),
                        goalML: settings.dailyGoalML
                    )
                    await refreshLiveActivity(settings: settings)
                }
            }
        )
        #else
        let healthKit: HealthKitWaterWriting = NoOpHealthKitService()
        let reminders: ReminderScheduling = NoOpReminderScheduler()
        let sync: HydrationSyncing = NoOpHydrationSyncService()
        let liveActivity: LiveActivityControlling = NoOpLiveActivityController()
        #endif
        _state = StateObject(
            wrappedValue: HydrationAppState(
                hydrationRepository: repository,
                settingsRepository: repository,
                healthKit: healthKit,
                reminders: reminders,
                sync: sync,
                liveActivity: liveActivity
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
