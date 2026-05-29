import XCTest
@testable import Aqualume

final class RepositoryTests: XCTestCase {
    func testInMemoryRepositoryPersistsLogsAndSettings() async throws {
        let repository = InMemoryHydrationRepository()
        let log = HydrationLog(amountML: 250, source: .iPhone)

        try await repository.appendLog(log)
        var settings = UserHydrationSettings()
        settings.dailyGoalML = 2_500
        settings.unitSystem = .imperial
        settings.profileGender = .male
        settings.profileWeightKG = 82
        settings.hasCompletedOnboarding = true
        settings.reminderSchedule = ReminderSchedule(startHour: 8, startMinute: 30, endHour: 20, endMinute: 45)
        settings.streakNotificationsEnabled = true
        settings.streakReminderHour = 19
        settings.streakReminderMinute = 15
        try await repository.saveSettings(settings)

        let logs = try await repository.loadLogs()
        let loadedSettings = try await repository.loadSettings()
        XCTAssertEqual(logs, [log])
        XCTAssertEqual(loadedSettings.dailyGoalML, 2_500)
        XCTAssertEqual(loadedSettings.unitSystem, .imperial)
        XCTAssertEqual(loadedSettings.profileGender, .male)
        XCTAssertEqual(loadedSettings.profileWeightKG, 82)
        XCTAssertTrue(loadedSettings.hasCompletedOnboarding)
        XCTAssertEqual(loadedSettings.reminderSchedule.startMinute, 30)
        XCTAssertEqual(loadedSettings.reminderSchedule.endMinute, 45)
        XCTAssertTrue(loadedSettings.streakNotificationsEnabled)
        XCTAssertEqual(loadedSettings.streakReminderHour, 19)
        XCTAssertEqual(loadedSettings.streakReminderMinute, 15)
    }

    func testSQLiteRepositoryAvoidsDuplicateLogIDs() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = SQLiteHydrationRepository(directory: directory)
        let log = HydrationLog(id: UUID(), amountML: 330, source: .watch)

        try await repository.appendLog(log)
        try await repository.appendLog(log)

        let logs = try await repository.loadLogs()
        XCTAssertEqual(logs.count, 1)
    }

    func testSQLiteRepositoryPersistsAcrossInstances() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let firstRepository = SQLiteHydrationRepository(directory: directory)
        let log = HydrationLog(
            id: UUID(),
            amountML: 500,
            loggedAt: Date(timeIntervalSince1970: 1_000_000),
            source: .widget
        )
        var settings = UserHydrationSettings()
        settings.dailyGoalML = 2_750
        settings.defaultAmountML = 330
        settings.profileGender = .female
        settings.profileWeightKG = 64
        settings.hasCompletedOnboarding = true
        settings.reminderSchedule = ReminderSchedule(startHour: 7, startMinute: 10, endHour: 22, endMinute: 35)
        settings.streakNotificationsEnabled = true
        settings.streakReminderHour = 20
        settings.streakReminderMinute = 5

        try await firstRepository.appendLog(log)
        try await firstRepository.saveSettings(settings)

        let secondRepository = SQLiteHydrationRepository(directory: directory)
        let loadedLogs = try await secondRepository.loadLogs()
        let loadedSettings = try await secondRepository.loadSettings()
        XCTAssertEqual(loadedLogs, [log])
        XCTAssertEqual(loadedSettings, settings)
    }

    func testSQLiteRepositoryPersistsDailyGoalSnapshots() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let firstRepository = SQLiteHydrationRepository(directory: directory)

        try await firstRepository.saveDailyGoalSnapshot(dateKey: "2026-05-10", goalML: 1_500)
        try await firstRepository.saveDailyGoalSnapshot(dateKey: "2026-05-11", goalML: 3_000)

        let secondRepository = SQLiteHydrationRepository(directory: directory)
        let snapshots = try await secondRepository.loadDailyGoalSnapshots()
        XCTAssertEqual(snapshots["2026-05-10"], 1_500)
        XCTAssertEqual(snapshots["2026-05-11"], 3_000)
    }

    func testSQLiteSnapshotReaderLoadsDatabaseStore() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = SQLiteHydrationRepository(directory: directory)
        let log = HydrationLog(
            id: UUID(),
            amountML: 250,
            loggedAt: Date(timeIntervalSince1970: 1_000_000),
            source: .iPhone
        )
        var settings = UserHydrationSettings()
        settings.dailyGoalML = 1_500

        try await repository.appendLog(log)
        try await repository.saveSettings(settings)

        let snapshot = HydrationSnapshotReader.load(directory: directory)
        XCTAssertEqual(snapshot.logs, [log])
        XCTAssertEqual(snapshot.settings.dailyGoalML, 1_500)
    }

}
