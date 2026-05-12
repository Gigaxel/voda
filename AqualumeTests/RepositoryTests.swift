import XCTest
import SQLite3
@testable import Aqualume

final class RepositoryTests: XCTestCase {
    func testInMemoryRepositoryPersistsLogsAndSettings() async throws {
        let repository = InMemoryHydrationRepository()
        let log = HydrationLog(amountML: 250, source: .iPhone)

        try await repository.appendLog(log)
        var settings = UserHydrationSettings()
        settings.dailyGoalML = 2_500
        settings.unitSystem = .imperial
        settings.streakNotificationsEnabled = true
        try await repository.saveSettings(settings)

        let logs = try await repository.loadLogs()
        let loadedSettings = try await repository.loadSettings()
        XCTAssertEqual(logs, [log])
        XCTAssertEqual(loadedSettings.dailyGoalML, 2_500)
        XCTAssertEqual(loadedSettings.unitSystem, .imperial)
        XCTAssertTrue(loadedSettings.streakNotificationsEnabled)
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
        settings.glassDesign = .prism
        settings.streakNotificationsEnabled = true

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

    func testSQLiteRepositoryMigratesStreakNotificationSetting() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("hydration-store.sqlite")

        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(fileURL.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }

        try executeSQLite(
            """
            CREATE TABLE settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                daily_goal_ml INTEGER NOT NULL,
                default_amount_ml INTEGER NOT NULL,
                unit_system TEXT NOT NULL,
                glass_design TEXT NOT NULL,
                reminders_enabled INTEGER NOT NULL,
                reminder_start_hour INTEGER NOT NULL,
                reminder_end_hour INTEGER NOT NULL,
                reminder_interval_minutes INTEGER NOT NULL,
                healthkit_enabled INTEGER NOT NULL
            );
            """,
            database: database
        )
        try executeSQLite(
            """
            INSERT INTO settings (
                id,
                daily_goal_ml,
                default_amount_ml,
                unit_system,
                glass_design,
                reminders_enabled,
                reminder_start_hour,
                reminder_end_hour,
                reminder_interval_minutes,
                healthkit_enabled
            )
            VALUES (1, 2200, 250, 'metric', 'tumbler', 0, 9, 21, 120, 0);
            """,
            database: database
        )
        sqlite3_close(database)
        database = nil

        let repository = SQLiteHydrationRepository(directory: directory)
        var settings = try await repository.loadSettings()
        XCTAssertFalse(settings.streakNotificationsEnabled)

        settings.streakNotificationsEnabled = true
        try await repository.saveSettings(settings)

        let migratedSettings = try await repository.loadSettings()
        XCTAssertTrue(migratedSettings.streakNotificationsEnabled)
    }

    func testSettingsDecodeDefaultsLegacyGlassDesignToTumbler() throws {
        let data = """
        {
          "dailyGoalML": 2200,
          "defaultAmountML": 250,
          "unitSystem": "metric",
          "remindersEnabled": false,
          "reminderSchedule": {
            "startHour": 9,
            "endHour": 21,
            "intervalMinutes": 120
          },
          "healthKitEnabled": false
        }
        """.data(using: .utf8)!

        let settings = try JSONDecoder().decode(UserHydrationSettings.self, from: data)
        XCTAssertEqual(settings.glassDesign, .tumbler)
        XCTAssertFalse(settings.streakNotificationsEnabled)
    }

    private func executeSQLite(_ sql: String, database: OpaquePointer?) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(database, sql, nil, nil, &errorMessage)
        if result != SQLITE_OK {
            let message = errorMessage.map { String(cString: $0) } ?? "Unknown SQLite error"
            sqlite3_free(errorMessage)
            XCTFail(message)
        }
    }
}
