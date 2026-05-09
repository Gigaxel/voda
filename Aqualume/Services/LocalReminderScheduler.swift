#if canImport(UserNotifications) && os(iOS)
import Foundation
import UserNotifications

public final class LocalReminderScheduler: ReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    public func authorizationStatus() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    public func scheduleReminders(settings: UserHydrationSettings) async throws {
        await cancelReminders()
        guard settings.remindersEnabled else { return }

        let granted = try await requestAuthorization()
        guard granted else { return }

        let start = max(0, min(settings.reminderSchedule.startHour, 23))
        let end = max(start, min(settings.reminderSchedule.endHour, 23))
        let intervalHours = max(1, settings.reminderSchedule.intervalMinutes / 60)

        for hour in stride(from: start, through: end, by: intervalHours) {
            var components = DateComponents()
            components.hour = hour
            components.minute = 0

            let content = UNMutableNotificationContent()
            content.title = "Aqualume"
            content.body = "A little more light in the glass."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(
                identifier: "aqualume.reminder.\(hour)",
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    public func cancelReminders() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix("aqualume.reminder.") }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
#endif
