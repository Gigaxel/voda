import XCTest
@testable import Aqualume

private final class TestClock: @unchecked Sendable {
    var current: Date

    init(current: Date) {
        self.current = current
    }
}

private final class RecordingReminderScheduler: ReminderScheduling, @unchecked Sendable {
    var scheduledReminderIncludesToday: [Bool] = []
    var scheduledStreakStatuses: [HydrationStreakStatus] = []
    var notifiedStreakStatuses: [HydrationStreakStatus] = []
    var cancelledReminders = 0
    var cancelledStreakNotifications = 0

    func authorizationStatus() async -> Bool { true }
    func requestAuthorization() async throws -> Bool { true }
    func scheduleReminders(settings: UserHydrationSettings) async throws {
        try await scheduleReminders(settings: settings, includingToday: true)
    }
    func scheduleReminders(settings: UserHydrationSettings, includingToday: Bool) async throws {
        scheduledReminderIncludesToday.append(includingToday)
    }
    func cancelReminders() async {
        cancelledReminders += 1
    }

    func scheduleStreakReminder(
        settings: UserHydrationSettings,
        status: HydrationStreakStatus,
        date: Date
    ) async throws {
        scheduledStreakStatuses.append(status)
    }

    func notifyStreakGoalReached(settings: UserHydrationSettings, status: HydrationStreakStatus) async throws {
        notifiedStreakStatuses.append(status)
    }

    func cancelStreakNotifications() async {
        cancelledStreakNotifications += 1
    }
}

final class HydrationLogicTests: XCTestCase {
    func testQuickAmountsMatchMVP() {
        XCTAssertEqual(HydrationValidation.quickAmountsML, [100, 250, 330, 500])
    }

    func testAddLogAndDailyTotal() {
        let calendar = Calendar(identifier: .gregorian)
        let calculator = HydrationCalculator(calendar: calendar)
        let day = Date(timeIntervalSince1970: 1_000_000)
        let logs = [
            HydrationLog(amountML: 250, loggedAt: day, source: .iPhone),
            HydrationLog(amountML: 330, loggedAt: day.addingTimeInterval(60), source: .watch)
        ]

        XCTAssertEqual(calculator.total(on: day, logs: logs), 580)
    }

    func testNewDayStartsEmptyWithoutDeletingHistory() {
        let calendar = Calendar(identifier: .gregorian)
        let calculator = HydrationCalculator(calendar: calendar)
        let firstDay = Date(timeIntervalSince1970: 1_000_000)
        let secondDay = firstDay.addingTimeInterval(86_400)
        let logs = [HydrationLog(amountML: 500, loggedAt: firstDay, source: .iPhone)]

        XCTAssertEqual(calculator.total(on: firstDay, logs: logs), 500)
        XCTAssertEqual(calculator.total(on: secondDay, logs: logs), 0)
        XCTAssertEqual(logs.count, 1)
    }

    func testProgressClampsAtGoal() {
        let calculator = HydrationCalculator()

        XCTAssertEqual(calculator.progress(totalML: 0, goalML: 2_000), 0)
        XCTAssertEqual(calculator.progress(totalML: 1_000, goalML: 2_000), 0.5)
        XCTAssertEqual(calculator.progress(totalML: 2_000, goalML: 2_000), 1)
        XCTAssertEqual(calculator.progress(totalML: 2_500, goalML: 2_000), 1)
    }

    func testLatestLogForUndoUsesCurrentDayOnly() {
        let calendar = Calendar(identifier: .gregorian)
        let calculator = HydrationCalculator(calendar: calendar)
        let day = Date(timeIntervalSince1970: 1_000_000)
        let yesterday = day.addingTimeInterval(-86_400)
        let old = HydrationLog(amountML: 500, loggedAt: yesterday, source: .iPhone)
        let first = HydrationLog(amountML: 100, loggedAt: day, source: .iPhone)
        let second = HydrationLog(amountML: 250, loggedAt: day.addingTimeInterval(90), source: .iPhone)

        XCTAssertEqual(calculator.latestLog(on: day, logs: [old, second, first]), second)
    }

    func testStreakCarriesUntilTodayIsMissed() {
        let calendar = Calendar(identifier: .gregorian)
        let calculator = HydrationCalculator(calendar: calendar)
        let today = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let yesterday = date(year: 2026, month: 5, day: 10, calendar: calendar)
        let twoDaysAgo = date(year: 2026, month: 5, day: 9, calendar: calendar)
        let logs = [
            HydrationLog(amountML: 2_000, loggedAt: twoDaysAgo, source: .iPhone),
            HydrationLog(amountML: 2_000, loggedAt: yesterday, source: .iPhone)
        ]

        let status = calculator.streakStatus(endingOn: today, logs: logs, goalML: 2_000)

        XCTAssertEqual(status.currentDays, 2)
        XCTAssertEqual(status.bestDays, 2)
        XCTAssertFalse(status.achievedToday)
    }

    func testStreakIncludesTodayAfterGoalReached() {
        let calendar = Calendar(identifier: .gregorian)
        let calculator = HydrationCalculator(calendar: calendar)
        let today = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let yesterday = date(year: 2026, month: 5, day: 10, calendar: calendar)
        let logs = [
            HydrationLog(amountML: 2_000, loggedAt: yesterday, source: .iPhone),
            HydrationLog(amountML: 2_000, loggedAt: today, source: .iPhone)
        ]

        let status = calculator.streakStatus(endingOn: today, logs: logs, goalML: 2_000)

        XCTAssertEqual(status.currentDays, 2)
        XCTAssertEqual(status.bestDays, 2)
        XCTAssertTrue(status.achievedToday)
    }

    func testStreakResetsAfterMissedCompletedDay() {
        let calendar = Calendar(identifier: .gregorian)
        let calculator = HydrationCalculator(calendar: calendar)
        let today = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let threeDaysAgo = date(year: 2026, month: 5, day: 8, calendar: calendar)
        let logs = [
            HydrationLog(amountML: 2_000, loggedAt: threeDaysAgo, source: .iPhone)
        ]

        let status = calculator.streakStatus(endingOn: today, logs: logs, goalML: 2_000)

        XCTAssertEqual(status.currentDays, 0)
        XCTAssertEqual(status.bestDays, 1)
    }

    func testUnitFormatting() {
        XCTAssertEqual(HydrationAmountFormatter.amount(250, unitSystem: .metric), "250 ml")
        XCTAssertEqual(HydrationAmountFormatter.amount(2_000, unitSystem: .metric), "2.00 L")
        XCTAssertEqual(HydrationAmountFormatter.amount(3_250, unitSystem: .metric), "3.25 L")
        XCTAssertEqual(HydrationAmountFormatter.milliliters(fromOunces: 8), 237)
    }

    func testDailySummariesUseGoalSnapshotForEachDay() {
        let calendar = Calendar(identifier: .gregorian)
        let calculator = HydrationCalculator(calendar: calendar)
        let firstDay = date(year: 2026, month: 5, day: 10, calendar: calendar)
        let secondDay = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let logs = [
            HydrationLog(amountML: 1_500, loggedAt: firstDay, source: .iPhone),
            HydrationLog(amountML: 1_500, loggedAt: secondDay, source: .iPhone)
        ]
        let snapshots = [
            calculator.dateKey(for: firstDay): 1_500,
            calculator.dateKey(for: secondDay): 3_000
        ]

        let summaries = calculator.summaries(
            endingOn: secondDay,
            days: 2,
            logs: logs,
            goalML: 2_000,
            dailyGoalMLByDateKey: snapshots
        )

        XCTAssertEqual(summaries.map(\.goalML), [1_500, 3_000])
        XCTAssertEqual(summaries.map(\.progress), [1, 0.5])
    }

    func testGoalRecommendationUsesWeightAndGender() {
        XCTAssertEqual(
            HydrationGoalRecommender.dailyGoalML(weightKG: 70, gender: .female),
            2_150
        )
        XCTAssertEqual(
            HydrationGoalRecommender.dailyGoalML(weightKG: 70, gender: .male),
            2_450
        )
        XCTAssertEqual(
            HydrationGoalRecommender.dailyGoalML(weightKG: 70, gender: .preferNotToSay),
            2_300
        )
    }

    func testSettingsValidation() {
        XCTAssertEqual(HydrationValidation.validatedGoal(100), 250)
        XCTAssertEqual(HydrationValidation.validatedGoal(20_000), 10_000)
        XCTAssertEqual(HydrationValidation.validatedDefaultAmount(1), 25)
        XCTAssertEqual(HydrationValidation.validatedDefaultAmount(4_000), 2_000)
        XCTAssertEqual(HydrationValidation.validatedProfileWeightKG(10), 30)
        XCTAssertEqual(HydrationValidation.validatedProfileWeightKG(400), 250)
    }

    func testStreakReminderDefaultsToSixPM() {
        XCTAssertEqual(HydrationReminderDefaults.streakReminderHour, 18)
    }

    func testHydrationReminderMessagePoolUsesTenShortFacts() {
        let messages = HydrationReminderDefaults.hydrationReminderMessages

        XCTAssertEqual(messages.count, 10)
        XCTAssertEqual(Set(messages).count, 10)
        XCTAssertTrue(messages.allSatisfy { !$0.isEmpty && $0.count <= 70 })
    }

    @MainActor
    func testStreakNotificationIsSentOnceWhenGoalIsReached() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let clock = TestClock(current: today)
        let settings = UserHydrationSettings(
            dailyGoalML: 500,
            streakNotificationsEnabled: true
        )
        let repository = InMemoryHydrationRepository(settings: settings)
        let reminders = RecordingReminderScheduler()
        let state = HydrationAppState(
            hydrationRepository: repository,
            settingsRepository: repository,
            reminders: reminders,
            calculator: HydrationCalculator(calendar: calendar),
            now: { clock.current }
        )

        await state.load()
        await state.log(amountML: 500)
        await state.log(amountML: 100)

        XCTAssertEqual(reminders.notifiedStreakStatuses.map(\.currentDays), [1])
    }

    @MainActor
    func testHydrationRemindersSkipRestOfTodayAfterGoalIsReached() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let settings = UserHydrationSettings(
            dailyGoalML: 500,
            remindersEnabled: true
        )
        let repository = InMemoryHydrationRepository(settings: settings)
        let reminders = RecordingReminderScheduler()
        let state = HydrationAppState(
            hydrationRepository: repository,
            settingsRepository: repository,
            reminders: reminders,
            calculator: HydrationCalculator(calendar: calendar),
            now: { today }
        )

        await state.load()
        await state.log(amountML: 250)
        await state.log(amountML: 250)

        XCTAssertEqual(reminders.scheduledReminderIncludesToday, [true, false])
    }

    @MainActor
    func testHydrationRemindersResumeTodayAfterUndoDropsBelowGoal() async throws {
        let calendar = Calendar(identifier: .gregorian)
        let today = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let settings = UserHydrationSettings(
            dailyGoalML: 500,
            remindersEnabled: true
        )
        let repository = InMemoryHydrationRepository(settings: settings)
        let reminders = RecordingReminderScheduler()
        let state = HydrationAppState(
            hydrationRepository: repository,
            settingsRepository: repository,
            reminders: reminders,
            calculator: HydrationCalculator(calendar: calendar),
            now: { today }
        )

        await state.load()
        await state.log(amountML: 500)
        await state.undoLatest()

        XCTAssertEqual(reminders.scheduledReminderIncludesToday, [true, false, true])
    }

    @MainActor
    func testLoadRefreshesCurrentDateKeyAfterDayChanges() async {
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = Date(timeIntervalSince1970: 1_000_000)
        let secondDay = firstDay.addingTimeInterval(86_400)
        let clock = TestClock(current: firstDay)
        let repository = InMemoryHydrationRepository()
        let state = HydrationAppState(
            hydrationRepository: repository,
            settingsRepository: repository,
            calculator: HydrationCalculator(calendar: calendar),
            now: { clock.current }
        )

        XCTAssertEqual(state.currentDateKey, HydrationCalculator(calendar: calendar).dateKey(for: firstDay))

        clock.current = secondDay
        await state.load()

        XCTAssertEqual(state.currentDateKey, HydrationCalculator(calendar: calendar).dateKey(for: secondDay))
    }

    @MainActor
    func testAppStateSnapshotsDailyGoalsForHistory() async {
        let calendar = Calendar(identifier: .gregorian)
        let firstDay = date(year: 2026, month: 5, day: 10, calendar: calendar)
        let secondDay = date(year: 2026, month: 5, day: 11, calendar: calendar)
        let clock = TestClock(current: firstDay)
        let settings = UserHydrationSettings(dailyGoalML: 1_500)
        let repository = InMemoryHydrationRepository(settings: settings)
        let state = HydrationAppState(
            hydrationRepository: repository,
            settingsRepository: repository,
            calculator: HydrationCalculator(calendar: calendar),
            now: { clock.current }
        )

        await state.load()
        await state.log(amountML: 1_500)

        clock.current = secondDay
        await state.updateSettings { $0.dailyGoalML = 3_000 }
        await state.log(amountML: 1_500)

        let summaries = state.summaries(days: 2)
        XCTAssertEqual(summaries.map(\.goalML), [1_500, 3_000])
        XCTAssertEqual(summaries.map(\.progress), [1, 0.5])
    }

    @MainActor
    func testDevelopmentOnboardingReplayOnlyClearsCompletionFlag() async {
        let settings = UserHydrationSettings(
            dailyGoalML: 2_850,
            profileGender: .male,
            profileWeightKG: 82,
            hasCompletedOnboarding: true
        )
        let repository = InMemoryHydrationRepository(settings: settings)
        let state = HydrationAppState(
            hydrationRepository: repository,
            settingsRepository: repository
        )

        await state.load()
        await state.replayOnboardingForDevelopment()

        XCTAssertFalse(state.settings.hasCompletedOnboarding)
        XCTAssertEqual(state.settings.dailyGoalML, 2_850)
        XCTAssertEqual(state.settings.profileGender, .male)
        XCTAssertEqual(state.settings.profileWeightKG, 82)
    }

    private func date(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
