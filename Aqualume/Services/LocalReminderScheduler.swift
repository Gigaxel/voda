#if canImport(UserNotifications) && os(iOS)
import Foundation
import UserNotifications

public final class LocalReminderScheduler: ReminderScheduling, @unchecked Sendable {
    private let center: UNUserNotificationCenter
    private let calendar: Calendar
    private let now: @Sendable () -> Date
    private let reminderPrefix = "aqualume.reminder."
    private let streakReminderPrefix = "aqualume.streak.reminder."
    private let streakMilestonePrefix = "aqualume.streak.milestone."
    private let maxScheduledReminderRequests = 60

    public init(
        center: UNUserNotificationCenter = .current(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.center = center
        self.calendar = calendar
        self.now = now
    }

    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    public func scheduleReminders(settings: UserHydrationSettings, includingToday: Bool) async throws {
        await cancelReminders()
        guard settings.remindersEnabled else { return }

        let granted = try await requestAuthorization()
        guard granted else { return }

        let reminderTimes = Self.reminderTimes(for: settings.reminderSchedule)
        guard !reminderTimes.isEmpty else { return }

        let scheduledDays = max(1, min(7, maxScheduledReminderRequests / reminderTimes.count))
        let todayOffset = includingToday ? 0 : 1
        let referenceDate = now()
        var scheduledRequestCount = 0

        for dayOffset in todayOffset..<(todayOffset + scheduledDays) {
            guard scheduledRequestCount < maxScheduledReminderRequests else { break }
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: referenceDate) else { continue }

            for reminderTime in reminderTimes {
                guard scheduledRequestCount < maxScheduledReminderRequests else { break }
                var components = calendar.dateComponents([.year, .month, .day], from: day)
                let hour = reminderTime / 60
                let minute = reminderTime % 60
                components.hour = hour
                components.minute = minute

                guard let reminderDate = calendar.date(from: components), reminderDate > referenceDate else { continue }

                let content = UNMutableNotificationContent()
                content.title = "Aqualume"
                content.body = hydrationReminderMessage()
                content.sound = .default

                let triggerComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminderDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
                let request = UNNotificationRequest(
                    identifier: "\(reminderPrefix)\(calendarIdentifier(for: reminderDate)).\(reminderTime)",
                    content: content,
                    trigger: trigger
                )
                try await center.add(request)
                scheduledRequestCount += 1
            }
        }
    }

    static func reminderTimes(for schedule: ReminderSchedule) -> [Int] {
        let schedule = HydrationValidation.validatedReminderSchedule(schedule)
        let intervalMinutes = HydrationValidation.validatedReminderIntervalMinutes(schedule.intervalMinutes)
        let start = schedule.startMinutesAfterMidnight
        let end = schedule.endMinutesAfterMidnight
        let endBoundary = end >= start ? end : end + 24 * 60

        return stride(from: start, through: endBoundary, by: intervalMinutes)
            .map { $0 % (24 * 60) }
            .sorted()
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

        let calendar = self.calendar
        let reminderHour = HydrationValidation.validatedHour(settings.streakReminderHour)
        let reminderMinute = HydrationValidation.validatedMinute(settings.streakReminderMinute)
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = reminderHour
        components.minute = reminderMinute

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

    private func calendarIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0
        return String(format: "%04d%02d%02d", year, month, day)
    }

    private func hydrationReminderMessage() -> String {
        HydrationReminderDefaults.hydrationReminderMessages.randomElement()
            ?? "Sip a glass bro"
    }
}
#endif
