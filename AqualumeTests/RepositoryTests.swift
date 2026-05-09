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
        try await repository.saveSettings(settings)

        let logs = try await repository.loadLogs()
        let loadedSettings = try await repository.loadSettings()
        XCTAssertEqual(logs, [log])
        XCTAssertEqual(loadedSettings.dailyGoalML, 2_500)
        XCTAssertEqual(loadedSettings.unitSystem, .imperial)
    }

    func testJSONRepositoryAvoidsDuplicateLogIDs() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repository = JSONHydrationRepository(directory: directory)
        let log = HydrationLog(id: UUID(), amountML: 330, source: .watch)

        try await repository.appendLog(log)
        try await repository.appendLog(log)

        let logs = try await repository.loadLogs()
        XCTAssertEqual(logs.count, 1)
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
    }
}
