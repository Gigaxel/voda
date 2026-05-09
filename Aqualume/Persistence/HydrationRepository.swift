import Foundation

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

public actor JSONHydrationRepository: HydrationRepository, SettingsRepository {
    private struct Store: Codable, Sendable {
        var logs: [HydrationLog] = []
        var settings: UserHydrationSettings = UserHydrationSettings()
    }

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL = RepositoryLocation.sharedDirectory()) {
        self.fileURL = directory.appendingPathComponent("hydration-store.json")
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    public func loadLogs() async throws -> [HydrationLog] {
        try loadStore().logs
    }

    public func saveLogs(_ logs: [HydrationLog]) async throws {
        var store = try loadStore()
        store.logs = logs.sorted { $0.loggedAt < $1.loggedAt }
        try saveStore(store)
    }

    public func appendLog(_ log: HydrationLog) async throws {
        var store = try loadStore()
        guard !store.logs.contains(where: { $0.id == log.id }) else { return }
        store.logs.append(log)
        store.logs.sort { $0.loggedAt < $1.loggedAt }
        try saveStore(store)
    }

    public func removeLog(id: UUID) async throws {
        var store = try loadStore()
        store.logs.removeAll { $0.id == id }
        try saveStore(store)
    }

    public func loadSettings() async throws -> UserHydrationSettings {
        try loadStore().settings
    }

    public func saveSettings(_ settings: UserHydrationSettings) async throws {
        var normalized = settings
        normalized.dailyGoalML = HydrationValidation.validatedGoal(settings.dailyGoalML)
        normalized.defaultAmountML = HydrationValidation.validatedDefaultAmount(settings.defaultAmountML)

        var store = try loadStore()
        store.settings = normalized
        try saveStore(store)
    }

    private func loadStore() throws -> Store {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return Store()
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(Store.self, from: data)
    }

    private func saveStore(_ store: Store) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(store)
        try data.write(to: fileURL, options: [.atomic])
    }
}

public actor InMemoryHydrationRepository: HydrationRepository, SettingsRepository {
    private var logs: [HydrationLog]
    private var settings: UserHydrationSettings

    public init(logs: [HydrationLog] = [], settings: UserHydrationSettings = UserHydrationSettings()) {
        self.logs = logs
        self.settings = settings
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
        self.settings = normalized
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
    private struct Store: Codable {
        var logs: [HydrationLog] = []
        var settings: UserHydrationSettings = UserHydrationSettings()
    }

    public static func load(directory: URL = RepositoryLocation.sharedDirectory()) -> HydrationSnapshot {
        let fileURL = directory.appendingPathComponent("hydration-store.json")
        guard let data = try? Data(contentsOf: fileURL) else {
            return HydrationSnapshot(logs: [], settings: UserHydrationSettings())
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let store = (try? decoder.decode(Store.self, from: data)) ?? Store()
        return HydrationSnapshot(logs: store.logs, settings: store.settings)
    }
}
