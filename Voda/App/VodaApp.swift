import SwiftUI

@main
struct VodaApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var state: HydrationAppState

    init() {
        let repository = SQLiteHydrationRepository()
        #if os(iOS)
        let healthKit: HealthKitWaterWriting = AppleHealthKitService()
        let reminders: ReminderScheduling = LocalReminderScheduler()
        let liveActivity: LiveActivityControlling = LiveActivityController()
        let sync: HydrationSyncing = NoOpHydrationSyncService()
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
            VodaRootView()
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
