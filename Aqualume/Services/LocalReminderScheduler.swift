#if canImport(UserNotifications) && os(iOS)
import Foundation
import UserNotifications

public final class LocalReminderScheduler: ReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let reminderPrefix = "aqualume.reminder."
    private let streakReminderPrefix = "aqualume.streak.reminder."
    private let streakMilestonePrefix = "aqualume.streak.milestone."

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
                identifier: "\(reminderPrefix)\(hour)",
                content: content,
                trigger: trigger
            )
            try await center.add(request)
        }
    }

    public func cancelReminders() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(reminderPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    public func scheduleStreakReminder(
        settings: UserHydrationSettings,
        status: HydrationStreakStatus,
        date: Date
    ) async throws {
        await cancelPendingNotifications(prefix: streakReminderPrefix)
        guard settings.streakNotificationsEnabled, status.currentDays > 0, !status.achievedToday else { return }

        let granted = try await requestAuthorization()
        guard granted else { return }

        let calendar = Calendar.current
        let reminderHour = max(0, min(settings.reminderSchedule.endHour, 23))
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = reminderHour
        components.minute = 0

        guard let reminderDate = calendar.date(from: components), reminderDate > date else { return }

        let content = UNMutableNotificationContent()
        content.title = "Keep your streak alive"
        content.body = "Log your water before the day ends to keep your \(status.currentDays)-day streak."
        content.sound = .default

        let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(streakReminderPrefix)\(status.dateKey)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    public func notifyStreakGoalReached(settings: UserHydrationSettings, status: HydrationStreakStatus) async throws {
        await cancelPendingNotifications(prefix: streakReminderPrefix)
        guard settings.streakNotificationsEnabled, status.achievedToday, status.currentDays > 0 else { return }

        let granted = try await requestAuthorization()
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = status.currentDays == 1 ? "Streak started" : "\(status.currentDays)-day streak"
        content.body = status.currentDays == 1
            ? "You reached today's goal. Come back tomorrow to keep it going."
            : "You reached today's goal and kept your streak going."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(streakMilestonePrefix)\(status.dateKey)",
            content: content,
            trigger: trigger
        )
        try await center.add(request)
    }

    public func cancelStreakNotifications() async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter {
            $0.hasPrefix(streakReminderPrefix) || $0.hasPrefix(streakMilestonePrefix)
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func cancelPendingNotifications(prefix: String) async {
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
#endif
