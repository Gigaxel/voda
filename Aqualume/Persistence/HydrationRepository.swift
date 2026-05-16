import Foundation
import SQLite3

public protocol HydrationRepository: Sendable {
    func loadLogs() async throws -> [HydrationLog]
    func saveLogs(_ logs: [HydrationLog]) async throws
    func appendLog(_ log: HydrationLog) async throws
    func removeLog(id: UUID) async throws
}

public protocol SettingsRepository: Sendable {
    func loadSettings() async throws -> UserHydrationSettings
    func saveSettings(_ settings: UserHydrationSettings) async throws
}

public protocol DailyGoalRepository: Sendable {
    func loadDailyGoalSnapshots() async throws -> [String: Int]
    func saveDailyGoalSnapshot(dateKey: String, goalML: Int) async throws
}

public enum RepositoryLocation {
    public static let appGroupID = "group.com.gigaxel.aqualume"

    public static func sharedDirectory(appGroupID: String = appGroupID) -> URL {
        if let container = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
            return container
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Aqualume", isDirectory: true)
    }
}

public actor SQLiteHydrationRepository: HydrationRepository, SettingsRepository, DailyGoalRepository {
    private let fileURL: URL

    public init(directory: URL = RepositoryLocation.sharedDirectory()) {
        self.fileURL = SQLiteHydrationStore.fileURL(directory: directory)
    }

    public func loadLogs() async throws -> [HydrationLog] {
        let database = try SQLiteDatabase(fileURL: fileURL)
        return try SQLiteHydrationStore.loadLogs(from: database)
    }

    public func saveLogs(_ logs: [HydrationLog]) async throws {
        let database = try SQLiteDatabase(fileURL: fileURL)
        try database.transaction {
            try database.execute("DELETE FROM hydration_logs;")
            for log in logs.sorted(by: { $0.loggedAt < $1.loggedAt }) {
                try SQLiteHydrationStore.insertLog(log, into: database)
            }
        }
    }

    public func appendLog(_ log: HydrationLog) async throws {
        let database = try SQLiteDatabase(fileURL: fileURL)
        try SQLiteHydrationStore.insertLog(log, into: database)
    }

    public func removeLog(id: UUID) async throws {
        let database = try SQLiteDatabase(fileURL: fileURL)
        let statement = try database.prepare("DELETE FROM hydration_logs WHERE id = ?;")
        defer { sqlite3_finalize(statement) }
        try database.bind(id.uuidString, at: 1, in: statement)
        try database.stepDone(statement, sql: "DELETE FROM hydration_logs WHERE id = ?;")
    }

    public func loadSettings() async throws -> UserHydrationSettings {
        let database = try SQLiteDatabase(fileURL: fileURL)
        return try SQLiteHydrationStore.loadSettings(from: database)
    }

    public func saveSettings(_ settings: UserHydrationSettings) async throws {
        var normalized = settings
        normalized.dailyGoalML = HydrationValidation.validatedGoal(settings.dailyGoalML)
        normalized.defaultAmountML = HydrationValidation.validatedDefaultAmount(settings.defaultAmountML)
        normalized.reminderSchedule = HydrationValidation.validatedReminderSchedule(settings.reminderSchedule)
        normalized.streakReminderHour = HydrationValidation.validatedHour(settings.streakReminderHour)
        normalized.streakReminderMinute = HydrationValidation.validatedMinute(settings.streakReminderMinute)
        if let weightKG = settings.profileWeightKG {
            normalized.profileWeightKG = HydrationValidation.validatedProfileWeightKG(weightKG)
        }

        let database = try SQLiteDatabase(fileURL: fileURL)
        try SQLiteHydrationStore.saveSettings(normalized, into: database)
    }

    public func loadDailyGoalSnapshots() async throws -> [String: Int] {
        let database = try SQLiteDatabase(fileURL: fileURL)
        return try SQLiteHydrationStore.loadDailyGoalSnapshots(from: database)
    }

    public func saveDailyGoalSnapshot(dateKey: String, goalML: Int) async throws {
        let database = try SQLiteDatabase(fileURL: fileURL)
        try SQLiteHydrationStore.saveDailyGoalSnapshot(
            dateKey: dateKey,
            goalML: HydrationValidation.validatedGoal(goalML),
            into: database
        )
    }
}

public actor InMemoryHydrationRepository: HydrationRepository, SettingsRepository, DailyGoalRepository {
    private var logs: [HydrationLog]
    private var settings: UserHydrationSettings
    private var dailyGoalSnapshots: [String: Int]

    public init(
        logs: [HydrationLog] = [],
        settings: UserHydrationSettings = UserHydrationSettings(),
        dailyGoalSnapshots: [String: Int] = [:]
    ) {
        self.logs = logs
        self.settings = settings
        self.dailyGoalSnapshots = dailyGoalSnapshots
    }

    public func loadLogs() async throws -> [HydrationLog] {
        logs
    }

    public func saveLogs(_ logs: [HydrationLog]) async throws {
        self.logs = logs
    }

    public func appendLog(_ log: HydrationLog) async throws {
        guard !logs.contains(where: { $0.id == log.id }) else { return }
        logs.append(log)
    }

    public func removeLog(id: UUID) async throws {
        logs.removeAll { $0.id == id }
    }

    public func loadSettings() async throws -> UserHydrationSettings {
        settings
    }

    public func saveSettings(_ settings: UserHydrationSettings) async throws {
        var normalized = settings
        normalized.dailyGoalML = HydrationValidation.validatedGoal(settings.dailyGoalML)
        normalized.defaultAmountML = HydrationValidation.validatedDefaultAmount(settings.defaultAmountML)
        if let weightKG = settings.profileWeightKG {
            normalized.profileWeightKG = HydrationValidation.validatedProfileWeightKG(weightKG)
        }
        self.settings = normalized
    }

    public func loadDailyGoalSnapshots() async throws -> [String: Int] {
        dailyGoalSnapshots
    }

    public func saveDailyGoalSnapshot(dateKey: String, goalML: Int) async throws {
        dailyGoalSnapshots[dateKey] = HydrationValidation.validatedGoal(goalML)
    }
}

public struct HydrationSnapshot: Sendable {
    public var logs: [HydrationLog]
    public var settings: UserHydrationSettings

    public var todayTotalML: Int {
        HydrationCalculator().total(on: Date(), logs: logs)
    }

    public var progress: Double {
        HydrationCalculator().progress(totalML: todayTotalML, goalML: settings.dailyGoalML)
    }
}

public enum HydrationSnapshotReader {
    public static func load(directory: URL = RepositoryLocation.sharedDirectory()) -> HydrationSnapshot {
        guard let database = try? SQLiteDatabase(fileURL: SQLiteHydrationStore.fileURL(directory: directory)) else {
            return HydrationSnapshot(logs: [], settings: UserHydrationSettings())
        }
        let logs = (try? SQLiteHydrationStore.loadLogs(from: database)) ?? []
        let settings = (try? SQLiteHydrationStore.loadSettings(from: database)) ?? UserHydrationSettings()
        return HydrationSnapshot(logs: logs, settings: settings)
    }
}

private final class SQLiteDatabase {
    private let handle: OpaquePointer?

    var errorMessage: String {
        SQLiteDatabase.message(from: handle)
    }

    init(fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var openedHandle: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(fileURL.path, &openedHandle, flags, nil) == SQLITE_OK else {
            let message = SQLiteDatabase.message(from: openedHandle)
            if let openedHandle {
                sqlite3_close(openedHandle)
            }
            throw SQLiteHydrationStoreError.open(path: fileURL.path, message: message)
        }

        handle = openedHandle
        try configure()
    }

    deinit {
        sqlite3_close(handle)
    }

    func execute(_ sql: String) throws {
        var errorMessage: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(handle, sql, nil, nil, &errorMessage)
        guard result == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? SQLiteDatabase.message(from: handle)
            sqlite3_free(errorMessage)
            throw SQLiteHydrationStoreError.execute(sql: sql, message: message)
        }
    }

    func prepare(_ sql: String) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(handle, sql, -1, &statement, nil) == SQLITE_OK else {
            throw SQLiteHydrationStoreError.prepare(sql: sql, message: SQLiteDatabase.message(from: handle))
        }
        return statement
    }

    func stepDone(_ statement: OpaquePointer?, sql: String) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw SQLiteHydrationStoreError.step(sql: sql, message: SQLiteDatabase.message(from: handle))
        }
    }

    func bind(_ value: String, at index: Int32, in statement: OpaquePointer?) throws {
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        guard sqlite3_bind_text(statement, index, value, -1, transient) == SQLITE_OK else {
            throw SQLiteHydrationStoreError.bind(message: SQLiteDatabase.message(from: handle))
        }
    }

    func bind(_ value: String?, at index: Int32, in statement: OpaquePointer?) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteHydrationStoreError.bind(message: SQLiteDatabase.message(from: handle))
            }
            return
        }
        try bind(value, at: index, in: statement)
    }

    func bind(_ value: Int, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_int64(statement, index, sqlite3_int64(value)) == SQLITE_OK else {
            throw SQLiteHydrationStoreError.bind(message: SQLiteDatabase.message(from: handle))
        }
    }

    func bind(_ value: Bool, at index: Int32, in statement: OpaquePointer?) throws {
        try bind(value ? 1 : 0, at: index, in: statement)
    }

    func bind(_ value: Double, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_double(statement, index, value) == SQLITE_OK else {
            throw SQLiteHydrationStoreError.bind(message: SQLiteDatabase.message(from: handle))
        }
    }

    func bind(_ value: Double?, at index: Int32, in statement: OpaquePointer?) throws {
        guard let value else {
            guard sqlite3_bind_null(statement, index) == SQLITE_OK else {
                throw SQLiteHydrationStoreError.bind(message: SQLiteDatabase.message(from: handle))
            }
            return
        }
        try bind(value, at: index, in: statement)
    }

    func bind(_ value: Date, at index: Int32, in statement: OpaquePointer?) throws {
        guard sqlite3_bind_double(statement, index, value.timeIntervalSince1970) == SQLITE_OK else {
            throw SQLiteHydrationStoreError.bind(message: SQLiteDatabase.message(from: handle))
        }
    }

    func transaction(_ work: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try work()
            try execute("COMMIT TRANSACTION;")
        } catch {
            try? execute("ROLLBACK TRANSACTION;")
            throw error
        }
    }

    private func configure() throws {
        try execute("PRAGMA journal_mode = WAL;")
        try execute("PRAGMA foreign_keys = ON;")
        try SQLiteHydrationStore.createSchema(in: self)
    }

    private static func message(from handle: OpaquePointer?) -> String {
        guard let handle, let error = sqlite3_errmsg(handle) else {
            return "Unknown SQLite error."
        }
        return String(cString: error)
    }
}

private enum SQLiteHydrationStore {
    static func fileURL(directory: URL) -> URL {
        directory.appendingPathComponent("hydration-store.sqlite")
    }

    static func createSchema(in database: SQLiteDatabase) throws {
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS hydration_logs (
                id TEXT PRIMARY KEY NOT NULL,
                amount_ml INTEGER NOT NULL,
                logged_at REAL NOT NULL,
                source TEXT NOT NULL,
                healthkit_sample_identifier TEXT
            );
            """
        )
        try database.execute(
            """
            CREATE INDEX IF NOT EXISTS hydration_logs_logged_at_index
            ON hydration_logs(logged_at);
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS settings (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                daily_goal_ml INTEGER NOT NULL,
                default_amount_ml INTEGER NOT NULL,
                unit_system TEXT NOT NULL,
                glass_design TEXT NOT NULL,
                profile_gender TEXT,
                profile_weight_kg REAL,
                has_completed_onboarding INTEGER NOT NULL DEFAULT 0,
                reminders_enabled INTEGER NOT NULL,
                reminder_start_hour INTEGER NOT NULL,
                reminder_start_minute INTEGER NOT NULL DEFAULT 0,
                reminder_end_hour INTEGER NOT NULL,
                reminder_end_minute INTEGER NOT NULL DEFAULT 0,
                reminder_interval_minutes INTEGER NOT NULL,
                streak_notifications_enabled INTEGER NOT NULL DEFAULT 0,
                streak_reminder_hour INTEGER NOT NULL DEFAULT 18,
                streak_reminder_minute INTEGER NOT NULL DEFAULT 0,
                healthkit_enabled INTEGER NOT NULL
            );
            """
        )
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS daily_goal_snapshots (
                date_key TEXT PRIMARY KEY NOT NULL,
                goal_ml INTEGER NOT NULL
            );
            """
        )
        if try !settingsTableHasColumn("streak_notifications_enabled", in: database) {
            try database.execute(
                "ALTER TABLE settings ADD COLUMN streak_notifications_enabled INTEGER NOT NULL DEFAULT 0;"
            )
        }
        if try !settingsTableHasColumn("profile_gender", in: database) {
            try database.execute("ALTER TABLE settings ADD COLUMN profile_gender TEXT;")
        }
        if try !settingsTableHasColumn("profile_weight_kg", in: database) {
            try database.execute("ALTER TABLE settings ADD COLUMN profile_weight_kg REAL;")
        }
        if try !settingsTableHasColumn("has_completed_onboarding", in: database) {
            try database.execute(
                "ALTER TABLE settings ADD COLUMN has_completed_onboarding INTEGER NOT NULL DEFAULT 0;"
            )
        }
        if try !settingsTableHasColumn("reminder_start_minute", in: database) {
            try database.execute("ALTER TABLE settings ADD COLUMN reminder_start_minute INTEGER NOT NULL DEFAULT 0;")
        }
        if try !settingsTableHasColumn("reminder_end_minute", in: database) {
            try database.execute("ALTER TABLE settings ADD COLUMN reminder_end_minute INTEGER NOT NULL DEFAULT 0;")
        }
        if try !settingsTableHasColumn("streak_reminder_hour", in: database) {
            try database.execute("ALTER TABLE settings ADD COLUMN streak_reminder_hour INTEGER NOT NULL DEFAULT 18;")
        }
        if try !settingsTableHasColumn("streak_reminder_minute", in: database) {
            try database.execute("ALTER TABLE settings ADD COLUMN streak_reminder_minute INTEGER NOT NULL DEFAULT 0;")
        }
        try database.execute("PRAGMA user_version = 5;")
    }

    static func loadLogs(from database: SQLiteDatabase) throws -> [HydrationLog] {
        let sql = """
        SELECT id, amount_ml, logged_at, source, healthkit_sample_identifier
        FROM hydration_logs
        ORDER BY logged_at ASC;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        var logs: [HydrationLog] = []
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            guard
                let id = columnString(statement, 0).flatMap(UUID.init(uuidString:)),
                let sourceRawValue = columnString(statement, 3),
                let source = HydrationLogSource(rawValue: sourceRawValue)
            else {
                result = sqlite3_step(statement)
                continue
            }
            logs.append(
                HydrationLog(
                    id: id,
                    amountML: Int(sqlite3_column_int64(statement, 1)),
                    loggedAt: Date(timeIntervalSince1970: sqlite3_column_double(statement, 2)),
                    source: source,
                    healthKitSampleIdentifier: columnString(statement, 4)
                )
            )
            result = sqlite3_step(statement)
        }

        guard result == SQLITE_DONE else {
            throw SQLiteHydrationStoreError.step(sql: sql, message: database.errorMessage)
        }

        return logs
    }

    static func insertLog(_ log: HydrationLog, into database: SQLiteDatabase) throws {
        let sql = """
        INSERT OR IGNORE INTO hydration_logs (
            id,
            amount_ml,
            logged_at,
            source,
            healthkit_sample_identifier
        )
        VALUES (?, ?, ?, ?, ?);
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        try database.bind(log.id.uuidString, at: 1, in: statement)
        try database.bind(log.amountML, at: 2, in: statement)
        try database.bind(log.loggedAt, at: 3, in: statement)
        try database.bind(log.source.rawValue, at: 4, in: statement)
        try database.bind(log.healthKitSampleIdentifier, at: 5, in: statement)
        try database.stepDone(statement, sql: sql)
    }

    static func loadSettings(from database: SQLiteDatabase) throws -> UserHydrationSettings {
        let sql = """
        SELECT daily_goal_ml,
               default_amount_ml,
               unit_system,
               glass_design,
               profile_gender,
               profile_weight_kg,
               has_completed_onboarding,
               reminders_enabled,
               reminder_start_hour,
               reminder_start_minute,
               reminder_end_hour,
               reminder_end_minute,
               reminder_interval_minutes,
               streak_notifications_enabled,
               streak_reminder_hour,
               streak_reminder_minute,
               healthkit_enabled
        FROM settings
        WHERE id = 1;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        let result = sqlite3_step(statement)
        guard result == SQLITE_ROW else {
            guard result == SQLITE_DONE else {
                throw SQLiteHydrationStoreError.step(sql: sql, message: database.errorMessage)
            }
            return UserHydrationSettings()
        }

        let unitSystem = columnString(statement, 2)
            .flatMap(HydrationUnitSystem.init(rawValue:)) ?? .metric
        let glassDesign = columnString(statement, 3)
            .flatMap(HydrationGlassDesign.init(rawValue:)) ?? .tumbler
        let profileGender = columnString(statement, 4)
            .flatMap(HydrationProfileGender.init(rawValue:))
        let profileWeightKG = sqlite3_column_type(statement, 5) == SQLITE_NULL
            ? nil
            : sqlite3_column_double(statement, 5)
        let reminderSchedule = ReminderSchedule(
            startHour: Int(sqlite3_column_int64(statement, 8)),
            startMinute: Int(sqlite3_column_int64(statement, 9)),
            endHour: Int(sqlite3_column_int64(statement, 10)),
            endMinute: Int(sqlite3_column_int64(statement, 11)),
            intervalMinutes: Int(sqlite3_column_int64(statement, 12))
        )

        return UserHydrationSettings(
            dailyGoalML: Int(sqlite3_column_int64(statement, 0)),
            defaultAmountML: Int(sqlite3_column_int64(statement, 1)),
            unitSystem: unitSystem,
            glassDesign: glassDesign,
            profileGender: profileGender,
            profileWeightKG: profileWeightKG,
            hasCompletedOnboarding: sqlite3_column_int64(statement, 6) == 1,
            remindersEnabled: sqlite3_column_int64(statement, 7) == 1,
            reminderSchedule: reminderSchedule,
            streakNotificationsEnabled: sqlite3_column_int64(statement, 13) == 1,
            streakReminderHour: Int(sqlite3_column_int64(statement, 14)),
            streakReminderMinute: Int(sqlite3_column_int64(statement, 15)),
            healthKitEnabled: sqlite3_column_int64(statement, 16) == 1
        )
    }

    static func saveSettings(_ settings: UserHydrationSettings, into database: SQLiteDatabase) throws {
        let sql = """
        INSERT INTO settings (
            id,
            daily_goal_ml,
            default_amount_ml,
            unit_system,
            glass_design,
            profile_gender,
            profile_weight_kg,
            has_completed_onboarding,
            reminders_enabled,
            reminder_start_hour,
            reminder_start_minute,
            reminder_end_hour,
            reminder_end_minute,
            reminder_interval_minutes,
            streak_notifications_enabled,
            streak_reminder_hour,
            streak_reminder_minute,
            healthkit_enabled
        )
        VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            daily_goal_ml = excluded.daily_goal_ml,
            default_amount_ml = excluded.default_amount_ml,
            unit_system = excluded.unit_system,
            glass_design = excluded.glass_design,
            profile_gender = excluded.profile_gender,
            profile_weight_kg = excluded.profile_weight_kg,
            has_completed_onboarding = excluded.has_completed_onboarding,
            reminders_enabled = excluded.reminders_enabled,
            reminder_start_hour = excluded.reminder_start_hour,
            reminder_start_minute = excluded.reminder_start_minute,
            reminder_end_hour = excluded.reminder_end_hour,
            reminder_end_minute = excluded.reminder_end_minute,
            reminder_interval_minutes = excluded.reminder_interval_minutes,
            streak_notifications_enabled = excluded.streak_notifications_enabled,
            streak_reminder_hour = excluded.streak_reminder_hour,
            streak_reminder_minute = excluded.streak_reminder_minute,
            healthkit_enabled = excluded.healthkit_enabled;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        try database.bind(settings.dailyGoalML, at: 1, in: statement)
        try database.bind(settings.defaultAmountML, at: 2, in: statement)
        try database.bind(settings.unitSystem.rawValue, at: 3, in: statement)
        try database.bind(settings.glassDesign.rawValue, at: 4, in: statement)
        try database.bind(settings.profileGender?.rawValue, at: 5, in: statement)
        try database.bind(settings.profileWeightKG, at: 6, in: statement)
        try database.bind(settings.hasCompletedOnboarding, at: 7, in: statement)
        try database.bind(settings.remindersEnabled, at: 8, in: statement)
        try database.bind(settings.reminderSchedule.startHour, at: 9, in: statement)
        try database.bind(settings.reminderSchedule.startMinute, at: 10, in: statement)
        try database.bind(settings.reminderSchedule.endHour, at: 11, in: statement)
        try database.bind(settings.reminderSchedule.endMinute, at: 12, in: statement)
        try database.bind(settings.reminderSchedule.intervalMinutes, at: 13, in: statement)
        try database.bind(settings.streakNotificationsEnabled, at: 14, in: statement)
        try database.bind(settings.streakReminderHour, at: 15, in: statement)
        try database.bind(settings.streakReminderMinute, at: 16, in: statement)
        try database.bind(settings.healthKitEnabled, at: 17, in: statement)
        try database.stepDone(statement, sql: sql)
    }

    static func loadDailyGoalSnapshots(from database: SQLiteDatabase) throws -> [String: Int] {
        let sql = """
        SELECT date_key, goal_ml
        FROM daily_goal_snapshots;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        var snapshots: [String: Int] = [:]
        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            if let dateKey = columnString(statement, 0) {
                snapshots[dateKey] = Int(sqlite3_column_int64(statement, 1))
            }
            result = sqlite3_step(statement)
        }

        guard result == SQLITE_DONE else {
            throw SQLiteHydrationStoreError.step(sql: sql, message: database.errorMessage)
        }

        return snapshots
    }

    static func saveDailyGoalSnapshot(dateKey: String, goalML: Int, into database: SQLiteDatabase) throws {
        let sql = """
        INSERT INTO daily_goal_snapshots (
            date_key,
            goal_ml
        )
        VALUES (?, ?)
        ON CONFLICT(date_key) DO UPDATE SET
            goal_ml = excluded.goal_ml;
        """
        let statement = try database.prepare(sql)
        defer { sqlite3_finalize(statement) }

        try database.bind(dateKey, at: 1, in: statement)
        try database.bind(goalML, at: 2, in: statement)
        try database.stepDone(statement, sql: sql)
    }

    private static func settingsTableHasColumn(_ column: String, in database: SQLiteDatabase) throws -> Bool {
        let statement = try database.prepare("PRAGMA table_info(settings);")
        defer { sqlite3_finalize(statement) }

        var result = sqlite3_step(statement)
        while result == SQLITE_ROW {
            if columnString(statement, 1) == column {
                return true
            }
            result = sqlite3_step(statement)
        }

        guard result == SQLITE_DONE else {
            throw SQLiteHydrationStoreError.step(sql: "PRAGMA table_info(settings);", message: database.errorMessage)
        }
        return false
    }

    private static func columnString(_ statement: OpaquePointer?, _ index: Int32) -> String? {
        guard let value = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: value)
    }
}

private enum SQLiteHydrationStoreError: Error, Equatable {
    case open(path: String, message: String)
    case execute(sql: String, message: String)
    case prepare(sql: String, message: String)
    case step(sql: String, message: String)
    case bind(message: String)
}
