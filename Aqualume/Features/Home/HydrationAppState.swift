import Combine
import Foundation
#if os(iOS)
import WidgetKit
#endif

@MainActor
public final class HydrationAppState: ObservableObject {
    @Published public private(set) var logs: [HydrationLog] = []
    @Published public private(set) var settings: UserHydrationSettings = UserHydrationSettings()
    @Published public private(set) var latestAddedAmountML: Int?
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var healthKitState: HealthKitAuthorizationState = .notDetermined
    @Published public private(set) var currentDateKey: String = HydrationCalculator().dateKey(for: Date())
    @Published public private(set) var dailyGoalSnapshots: [String: Int] = [:]

    private let hydrationRepository: HydrationRepository
    private let settingsRepository: SettingsRepository
    private let dailyGoalRepository: DailyGoalRepository?
    private let healthKit: HealthKitWaterWriting
    private let reminders: ReminderScheduling
    private let sync: HydrationSyncing
    private let calculator: HydrationCalculator
    private let now: @Sendable () -> Date
    private var lastStreakNotificationDateKey: String?

    public init(
        hydrationRepository: HydrationRepository,
        settingsRepository: SettingsRepository,
        dailyGoalRepository: DailyGoalRepository? = nil,
        healthKit: HealthKitWaterWriting = NoOpHealthKitService(),
        reminders: ReminderScheduling = NoOpReminderScheduler(),
        sync: HydrationSyncing = NoOpHydrationSyncService(),
        calculator: HydrationCalculator = HydrationCalculator(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.hydrationRepository = hydrationRepository
        self.settingsRepository = settingsRepository
        self.dailyGoalRepository = dailyGoalRepository
            ?? hydrationRepository as? DailyGoalRepository
            ?? settingsRepository as? DailyGoalRepository
        self.healthKit = healthKit
        self.reminders = reminders
        self.sync = sync
        self.calculator = calculator
        self.now = now
        self.currentDateKey = calculator.dateKey(for: now())
    }

    public var todayTotalML: Int {
        calculator.total(on: now(), logs: logs)
    }

    public var progress: Double {
        calculator.progress(totalML: todayTotalML, goalML: settings.dailyGoalML)
    }

    public var hasReachedGoal: Bool {
        todayTotalML >= settings.dailyGoalML
    }

    public var streakStatus: HydrationStreakStatus {
        calculator.streakStatus(
            endingOn: now(),
            logs: logs,
            goalML: settings.dailyGoalML,
            dailyGoalMLByDateKey: dailyGoalSnapshotsIncludingToday
        )
    }

    public var canUndo: Bool {
        calculator.latestLog(on: now(), logs: logs) != nil
    }

    public var quickAmountsML: [Int] {
        HydrationValidation.quickAmountsML
    }

    public var sevenDaySummaries: [DailyHydrationSummary] {
        summaries(days: 7)
    }

    public func summaries(days: Int) -> [DailyHydrationSummary] {
        calculator.summaries(
            endingOn: now(),
            days: days,
            logs: logs,
            goalML: settings.dailyGoalML,
            dailyGoalMLByDateKey: dailyGoalSnapshotsIncludingToday
        )
    }

    public func refreshForCurrentDate() {
        currentDateKey = calculator.dateKey(for: now())
    }

    public func load() async {
        do {
            refreshForCurrentDate()
            logs = try await hydrationRepository.loadLogs()
            settings = try await settingsRepository.loadSettings()
            dailyGoalSnapshots = (try await dailyGoalRepository?.loadDailyGoalSnapshots()) ?? [:]
            try await saveCurrentGoalSnapshotIfNeeded()
            healthKitState = await healthKit.authorizationState()
            await sync.activate()
            await refreshStreakReminder()
        } catch {
            statusMessage = "Unable to load hydration data."
        }
    }

    public func logDefaultAmount(source: HydrationLogSource = .iPhone) async {
        await log(amountML: settings.defaultAmountML, source: source)
    }

    public func log(amountML: Int, source: HydrationLogSource = .iPhone) async {
        refreshForCurrentDate()
        let safeAmount = HydrationValidation.validatedDefaultAmount(amountML)
        let hadReachedGoal = hasReachedGoal
        var log = HydrationLog(amountML: safeAmount, loggedAt: now(), source: source)

        do {
            try await saveCurrentGoalSnapshotIfNeeded()
            try await hydrationRepository.appendLog(log)
            if settings.healthKitEnabled {
                do {
                    log.healthKitSampleIdentifier = try await healthKit.writeWater(amountML: safeAmount, date: log.loggedAt)
                    try await hydrationRepository.removeLog(id: log.id)
                    try await hydrationRepository.appendLog(log)
                } catch {
                    statusMessage = "Saved locally. Health write unavailable."
                }
            }
            logs = try await hydrationRepository.loadLogs()
            latestAddedAmountML = safeAmount
            await sync.sendLog(log)
            if !hadReachedGoal && hasReachedGoal {
                await notifyStreakGoalReachedIfNeeded()
            }
            await refreshStreakReminder()
            reloadWidgets()
        } catch {
            statusMessage = "Unable to save water."
        }
    }

    public func undoLatest() async {
        refreshForCurrentDate()
        guard let latest = calculator.latestLog(on: now(), logs: logs) else { return }
        do {
            try await hydrationRepository.removeLog(id: latest.id)
            if let identifier = latest.healthKitSampleIdentifier {
                try? await healthKit.deleteWaterSample(identifier: identifier)
            }
            logs = try await hydrationRepository.loadLogs()
            latestAddedAmountML = nil
            await refreshStreakReminder()
            reloadWidgets()
        } catch {
            statusMessage = "Unable to undo latest log."
        }
    }

    public func updateSettings(_ update: (inout UserHydrationSettings) -> Void) async {
        refreshForCurrentDate()
        var next = settings
        update(&next)
        next.dailyGoalML = HydrationValidation.validatedGoal(next.dailyGoalML)
        next.defaultAmountML = HydrationValidation.validatedDefaultAmount(next.defaultAmountML)
        do {
            try await settingsRepository.saveSettings(next)
            settings = try await settingsRepository.loadSettings()
            try await saveCurrentGoalSnapshotIfNeeded()
            if settings.remindersEnabled {
                try await reminders.scheduleReminders(settings: settings)
            } else {
                await reminders.cancelReminders()
            }
            await refreshStreakReminder()
            await sync.sendSettings(settings)
            reloadWidgets()
        } catch {
            statusMessage = "Unable to update settings."
        }
    }

    public func requestHealthKitAuthorization() async {
        do {
            healthKitState = try await healthKit.requestAuthorization()
            await updateSettings { settings in
                settings.healthKitEnabled = healthKitState == .sharingAuthorized
            }
        } catch {
            statusMessage = "Health permission unavailable."
        }
    }

    private func reloadWidgets() {
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private var dailyGoalSnapshotsIncludingToday: [String: Int] {
        var snapshots = dailyGoalSnapshots
        snapshots[calculator.dateKey(for: now())] = settings.dailyGoalML
        return snapshots
    }

    private func saveCurrentGoalSnapshotIfNeeded() async throws {
        let dateKey = calculator.dateKey(for: now())
        let goalML = settings.dailyGoalML
        guard dailyGoalSnapshots[dateKey] != goalML else { return }
        try await dailyGoalRepository?.saveDailyGoalSnapshot(dateKey: dateKey, goalML: goalML)
        dailyGoalSnapshots[dateKey] = goalML
    }

    private func refreshStreakReminder() async {
        do {
            if settings.streakNotificationsEnabled {
                try await reminders.scheduleStreakReminder(settings: settings, status: streakStatus, date: now())
            } else {
                await reminders.cancelStreakNotifications()
            }
        } catch {
            statusMessage = "Unable to update streak notifications."
        }
    }

    private func notifyStreakGoalReachedIfNeeded() async {
        let status = streakStatus
        guard lastStreakNotificationDateKey != status.dateKey else { return }
        do {
            try await reminders.notifyStreakGoalReached(settings: settings, status: status)
            lastStreakNotificationDateKey = status.dateKey
        } catch {
            statusMessage = "Unable to send streak notification."
        }
    }
}
