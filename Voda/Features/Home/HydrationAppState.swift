import Combine
import Foundation
#if os(iOS)
import WidgetKit
#endif

@MainActor
public final class HydrationAppState: ObservableObject {
    @Published public private(set) var todayLogs: [HydrationLog] = []
    @Published public private(set) var settings: UserHydrationSettings = UserHydrationSettings()
    @Published public private(set) var latestAddedAmountML: Int?
    @Published public private(set) var statusMessage: String?
    @Published public private(set) var healthKitState: HealthKitAuthorizationState = .notDetermined
    @Published public private(set) var currentDateKey: String = HydrationCalculator().dateKey(for: Date())
    @Published public private(set) var dailyGoalSnapshots: [String: Int] = [:]
    @Published public private(set) var historySummaries: [DailyHydrationSummary] = []
    @Published public private(set) var isLoadingHistory = false
    @Published public private(set) var hasLoadedHistory = false
    @Published public private(set) var streakStatus = HydrationStreakStatus(
        currentDays: 0,
        bestDays: 0,
        goalDays: 0,
        achievedToday: false,
        dateKey: HydrationCalculator().dateKey(for: Date())
    )
    @Published public private(set) var hasLoaded = false

    private let hydrationRepository: HydrationRepository
    private let settingsRepository: SettingsRepository
    private let dailyGoalRepository: DailyGoalRepository?
    private let healthKit: HealthKitWaterWriting
    private let reminders: ReminderScheduling
    private let sync: HydrationSyncing
    private let liveActivity: LiveActivityControlling
    private let calculator: HydrationCalculator
    private let now: @Sendable () -> Date
    private var lastStreakNotificationDateKey: String?
    private var historyLoadedDays = 0
    private var pendingOptimisticLogIDs: Set<UUID> = []

    public init(
        hydrationRepository: HydrationRepository,
        settingsRepository: SettingsRepository,
        dailyGoalRepository: DailyGoalRepository? = nil,
        healthKit: HealthKitWaterWriting = NoOpHealthKitService(),
        reminders: ReminderScheduling = NoOpReminderScheduler(),
        sync: HydrationSyncing = NoOpHydrationSyncService(),
        liveActivity: LiveActivityControlling = NoOpLiveActivityController(),
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
        self.liveActivity = liveActivity
        self.calculator = calculator
        self.now = now
        self.currentDateKey = calculator.dateKey(for: now())
        self.streakStatus = emptyStreakStatus(for: now())
    }

    public var todayTotalML: Int {
        calculator.total(on: now(), logs: todayLogs)
    }

    public var progress: Double {
        calculator.progress(totalML: todayTotalML, goalML: settings.dailyGoalML)
    }

    public var hasReachedGoal: Bool {
        todayTotalML >= settings.dailyGoalML
    }

    public var canUndo: Bool {
        guard let latest = calculator.latestLog(on: now(), logs: todayLogs) else {
            return false
        }
        return !pendingOptimisticLogIDs.contains(latest.id)
    }

    public var quickAmountsML: [Int] {
        HydrationValidation.quickAmountsML
    }

    public func summaries(days: Int) -> [DailyHydrationSummary] {
        guard days > 0 else { return [] }
        guard historySummaries.count > days else { return historySummaries }
        return Array(historySummaries.suffix(days))
    }

    public func refreshForCurrentDate() {
        let nextDateKey = calculator.dateKey(for: now())
        guard currentDateKey != nextDateKey else { return }
        currentDateKey = nextDateKey
        todayLogs = []
        latestAddedAmountML = nil
        historySummaries = []
        hasLoadedHistory = false
        historyLoadedDays = 0
        pendingOptimisticLogIDs = []
        streakStatus = emptyStreakStatus(for: now())
    }

    public func refreshLiveActivity() async {
        await liveActivity.refresh(
            totalML: todayTotalML,
            goalML: settings.dailyGoalML,
            unitSystem: settings.unitSystem,
            defaultAmountML: settings.defaultAmountML
        )
    }

    public func load() async {
        do {
            refreshForCurrentDate()
            let loadedTodayLogs = try await hydrationRepository.loadLogs(on: now(), calendar: calculator.calendar)
            mergeTodayLogsWithPending(loadedTodayLogs)
            settings = try await settingsRepository.loadSettings()
            dailyGoalSnapshots = (try await dailyGoalRepository?.loadDailyGoalSnapshots(
                from: currentDateKey,
                through: currentDateKey
            )) ?? [:]
            try await saveCurrentGoalSnapshotIfNeeded()
            healthKitState = await healthKit.authorizationState()
            await sync.activate()
            await refreshHydrationReminders()
            await refreshStreakReminder()
            await refreshLiveActivity()
            hasLoaded = true
        } catch {
            statusMessage = "Unable to load hydration data."
            hasLoaded = true
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
        todayLogs.append(log)
        pendingOptimisticLogIDs.insert(log.id)
        latestAddedAmountML = safeAmount

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
            pendingOptimisticLogIDs.remove(log.id)
            let loadedTodayLogs = try await hydrationRepository.loadLogs(on: now(), calendar: calculator.calendar)
            mergeTodayLogsWithPending(loadedTodayLogs)
            await sync.sendLog(log)
            if !hadReachedGoal && hasReachedGoal {
                await notifyStreakGoalReachedIfNeeded()
            }
            if hadReachedGoal != hasReachedGoal {
                await refreshHydrationReminders()
            }
            await refreshStreakReminder()
            await refreshLoadedHistoryIfNeeded()
            reloadWidgets()
            await refreshLiveActivity()
        } catch {
            pendingOptimisticLogIDs.remove(log.id)
            todayLogs.removeAll { $0.id == log.id }
            latestAddedAmountML = nil
            statusMessage = "Unable to save water."
        }
    }

    public func undoLatest() async {
        refreshForCurrentDate()
        guard let latest = calculator.latestLog(on: now(), logs: todayLogs),
              !pendingOptimisticLogIDs.contains(latest.id)
        else {
            return
        }
        let hadReachedGoal = hasReachedGoal
        todayLogs.removeAll { $0.id == latest.id }
        latestAddedAmountML = nil
        do {
            try await hydrationRepository.removeLog(id: latest.id)
            if let identifier = latest.healthKitSampleIdentifier {
                try? await healthKit.deleteWaterSample(identifier: identifier)
            }
            let loadedTodayLogs = try await hydrationRepository.loadLogs(on: now(), calendar: calculator.calendar)
            mergeTodayLogsWithPending(loadedTodayLogs)
            if hadReachedGoal != hasReachedGoal {
                await refreshHydrationReminders()
            }
            await refreshStreakReminder()
            await refreshLoadedHistoryIfNeeded()
            reloadWidgets()
            await refreshLiveActivity()
        } catch {
            todayLogs.append(latest)
            todayLogs.sort { $0.loggedAt < $1.loggedAt }
            statusMessage = "Unable to undo latest log."
        }
    }

    public func updateSettings(_ update: (inout UserHydrationSettings) -> Void) async {
        refreshForCurrentDate()
        var next = settings
        update(&next)
        next.dailyGoalML = HydrationValidation.validatedGoal(next.dailyGoalML)
        next.defaultAmountML = HydrationValidation.validatedDefaultAmount(next.defaultAmountML)
        next.reminderSchedule = HydrationValidation.validatedReminderSchedule(next.reminderSchedule)
        next.streakReminderHour = HydrationValidation.validatedHour(next.streakReminderHour)
        next.streakReminderMinute = HydrationValidation.validatedMinute(next.streakReminderMinute)
        if let weightKG = next.profileWeightKG {
            next.profileWeightKG = HydrationValidation.validatedProfileWeightKG(weightKG)
        }
        do {
            try await settingsRepository.saveSettings(next)
            settings = try await settingsRepository.loadSettings()
            try await saveCurrentGoalSnapshotIfNeeded()
            await refreshHydrationReminders()
            await refreshStreakReminder()
            await refreshLoadedHistoryIfNeeded()
            await sync.sendSettings(settings)
            reloadWidgets()
            await refreshLiveActivity()
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

    public func loadHistory(days: Int = 365, force: Bool = false) async {
        guard days > 0 else { return }
        guard force || !hasLoadedHistory || days > historyLoadedDays else { return }
        guard !isLoadingHistory else { return }

        isLoadingHistory = true
        defer { isLoadingHistory = false }

        do {
            refreshForCurrentDate()
            let endDate = now()
            let startDate = calculator.calendar.date(byAdding: .day, value: -(days - 1), to: endDate) ?? endDate
            let startDateKey = calculator.dateKey(for: startDate)
            let endDateKey = calculator.dateKey(for: endDate)
            let dailyTotals = try await hydrationRepository.loadDailyTotals(
                from: startDate,
                through: endDate,
                calendar: calculator.calendar
            )
            let snapshots = (try await dailyGoalRepository?.loadDailyGoalSnapshots(
                from: startDateKey,
                through: endDateKey
            )) ?? [:]
            mergeDailyGoalSnapshots(snapshots)

            historySummaries = calculator.summaries(
                endingOn: endDate,
                days: days,
                dailyTotalsByDateKey: dailyTotals,
                goalML: settings.dailyGoalML,
                dailyGoalMLByDateKey: snapshotsIncludingToday(snapshots)
            )
            historyLoadedDays = days
            hasLoadedHistory = true
            do {
                try await refreshStreakStatus()
            } catch {
                statusMessage = "Unable to load streak."
            }
        } catch {
            statusMessage = "Unable to load history."
        }
    }

    public func loadStreakStatus() async {
        do {
            try await refreshStreakStatus()
        } catch {
            statusMessage = "Unable to load streak."
        }
    }

    public func replayOnboardingForDevelopment() async {
        await updateSettings { settings in
            settings.hasCompletedOnboarding = false
        }
    }

    private func reloadWidgets() {
        #if os(iOS)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }

    private func saveCurrentGoalSnapshotIfNeeded() async throws {
        let dateKey = calculator.dateKey(for: now())
        let goalML = settings.dailyGoalML
        guard dailyGoalSnapshots[dateKey] != goalML else { return }
        try await dailyGoalRepository?.saveDailyGoalSnapshot(dateKey: dateKey, goalML: goalML)
        dailyGoalSnapshots[dateKey] = goalML
    }

    private func snapshotsIncludingToday(_ snapshots: [String: Int]) -> [String: Int] {
        var snapshots = snapshots
        snapshots[calculator.dateKey(for: now())] = settings.dailyGoalML
        return snapshots
    }

    private func mergeDailyGoalSnapshots(_ snapshots: [String: Int]) {
        for (dateKey, goalML) in snapshots {
            dailyGoalSnapshots[dateKey] = goalML
        }
    }

    private func mergeTodayLogsWithPending(_ loadedTodayLogs: [HydrationLog]) {
        guard !pendingOptimisticLogIDs.isEmpty else {
            todayLogs = loadedTodayLogs
            return
        }

        let loadedIDs = Set(loadedTodayLogs.map(\.id))
        let pendingLogs = todayLogs.filter { log in
            pendingOptimisticLogIDs.contains(log.id)
                && !loadedIDs.contains(log.id)
                && calculator.isSameDay(log.loggedAt, now())
        }
        todayLogs = (loadedTodayLogs + pendingLogs).sorted { $0.loggedAt < $1.loggedAt }
    }

    private func refreshLoadedHistoryIfNeeded() async {
        guard hasLoadedHistory else { return }
        await loadHistory(days: historyLoadedDays > 0 ? historyLoadedDays : 365, force: true)
    }

    private func refreshStreakStatus() async throws {
        let endDate = now()
        let endDateKey = calculator.dateKey(for: endDate)
        let dailyTotals = try await hydrationRepository.loadDailyTotals(
            from: nil,
            through: endDate,
            calendar: calculator.calendar
        )
        let snapshots = (try await dailyGoalRepository?.loadDailyGoalSnapshots(
            from: nil,
            through: endDateKey
        )) ?? [:]
        mergeDailyGoalSnapshots(snapshots)
        streakStatus = calculator.streakStatus(
            endingOn: endDate,
            dailyTotalsByDateKey: dailyTotals,
            goalML: settings.dailyGoalML,
            dailyGoalMLByDateKey: snapshotsIncludingToday(snapshots)
        )
    }

    private func emptyStreakStatus(for date: Date) -> HydrationStreakStatus {
        HydrationStreakStatus(
            currentDays: 0,
            bestDays: 0,
            goalDays: 0,
            achievedToday: false,
            dateKey: calculator.dateKey(for: date)
        )
    }

    private func refreshHydrationReminders() async {
        do {
            if settings.remindersEnabled {
                try await reminders.scheduleReminders(settings: settings, includingToday: !hasReachedGoal)
            } else {
                await reminders.cancelReminders()
            }
        } catch {
            statusMessage = "Unable to update reminders."
        }
    }

    private func refreshStreakReminder() async {
        do {
            if settings.streakNotificationsEnabled {
                try await refreshStreakStatus()
                try await reminders.scheduleStreakReminder(settings: settings, status: streakStatus, date: now())
            } else {
                await reminders.cancelStreakNotifications()
            }
        } catch {
            statusMessage = "Unable to update streak notifications."
        }
    }

    private func notifyStreakGoalReachedIfNeeded() async {
        guard settings.streakNotificationsEnabled else { return }
        do {
            try await refreshStreakStatus()
            let status = streakStatus
            guard lastStreakNotificationDateKey != status.dateKey else { return }
            try await reminders.notifyStreakGoalReached(settings: settings, status: status)
            lastStreakNotificationDateKey = status.dateKey
        } catch {
            statusMessage = "Unable to send streak notification."
        }
    }
}
