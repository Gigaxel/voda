import XCTest
@testable import Aqualume

private final class TestClock: @unchecked Sendable {
    var current: Date

    init(current: Date) {
        self.current = current
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

    func testUnitFormatting() {
        XCTAssertEqual(HydrationAmountFormatter.amount(250, unitSystem: .metric), "250 ml")
        XCTAssertEqual(HydrationAmountFormatter.amount(2_000, unitSystem: .metric), "2 L")
        XCTAssertEqual(HydrationAmountFormatter.milliliters(fromOunces: 8), 237)
    }

    func testSettingsValidation() {
        XCTAssertEqual(HydrationValidation.validatedGoal(100), 250)
        XCTAssertEqual(HydrationValidation.validatedGoal(20_000), 10_000)
        XCTAssertEqual(HydrationValidation.validatedDefaultAmount(1), 25)
        XCTAssertEqual(HydrationValidation.validatedDefaultAmount(4_000), 2_000)
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
}
