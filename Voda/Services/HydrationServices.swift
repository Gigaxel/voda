import Foundation

public enum HealthKitAuthorizationState: Equatable, Sendable {
    case unavailable
    case notDetermined
    case sharingDenied
    case sharingAuthorized
}

public protocol HealthKitWaterWriting: Sendable {
    func authorizationState() async -> HealthKitAuthorizationState
    func requestAuthorization() async throws -> HealthKitAuthorizationState
    func writeWater(amountML: Int, date: Date) async throws -> String?
    func deleteWaterSample(identifier: String) async throws
}

public struct NoOpHealthKitService: HealthKitWaterWriting {
    public init() {}

    public func authorizationState() async -> HealthKitAuthorizationState {
        .unavailable
    }

    public func requestAuthorization() async throws -> HealthKitAuthorizationState {
        .unavailable
    }

    public func writeWater(amountML: Int, date: Date) async throws -> String? {
        nil
    }

    public func deleteWaterSample(identifier: String) async throws {}
}

public protocol ReminderScheduling: Sendable {
    func requestAuthorization() async throws -> Bool
    func scheduleReminders(settings: UserHydrationSettings, includingToday: Bool) async throws
    func cancelReminders() async
    func scheduleStreakReminder(
        settings: UserHydrationSettings,
        status: HydrationStreakStatus,
        date: Date
    ) async throws
    func notifyStreakGoalReached(settings: UserHydrationSettings, status: HydrationStreakStatus) async throws
    func cancelStreakNotifications() async
}

public struct NoOpReminderScheduler: ReminderScheduling {
    public init() {}

    public func requestAuthorization() async throws -> Bool { false }
    public func scheduleReminders(settings: UserHydrationSettings, includingToday: Bool) async throws {}
    public func cancelReminders() async {}
    public func scheduleStreakReminder(
        settings: UserHydrationSettings,
        status: HydrationStreakStatus,
        date: Date
    ) async throws {}
    public func notifyStreakGoalReached(settings: UserHydrationSettings, status: HydrationStreakStatus) async throws {}
    public func cancelStreakNotifications() async {}
}

public protocol HydrationSyncing: Sendable {
    func activate() async
    func sendLog(_ log: HydrationLog) async
    func sendSettings(_ settings: UserHydrationSettings) async
}

public struct NoOpHydrationSyncService: HydrationSyncing {
    public init() {}

    public func activate() async {}
    public func sendLog(_ log: HydrationLog) async {}
    public func sendSettings(_ settings: UserHydrationSettings) async {}
}

/// Drives the Lock Screen / Dynamic Island Live Activity. Defined here (free of
/// ActivityKit) so non-iOS targets can use the no-op without importing it.
public protocol LiveActivityControlling: Sendable {
    func refresh(totalML: Int, goalML: Int, unitSystem: HydrationUnitSystem, defaultAmountML: Int) async
}

public struct NoOpLiveActivityController: LiveActivityControlling {
    public init() {}

    public func refresh(totalML: Int, goalML: Int, unitSystem: HydrationUnitSystem, defaultAmountML: Int) async {}
}
