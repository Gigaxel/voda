import Foundation

public struct HydrationCalculator: Sendable {
    public let calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 1970
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    public func isSameDay(_ lhs: Date, _ rhs: Date) -> Bool {
        calendar.isDate(lhs, inSameDayAs: rhs)
    }

    public func total(on day: Date, logs: [HydrationLog]) -> Int {
        logs
            .filter { isSameDay($0.loggedAt, day) }
            .reduce(0) { $0 + max(0, $1.amountML) }
    }

    public func progress(totalML: Int, goalML: Int) -> Double {
        guard goalML > 0 else { return 0 }
        return min(max(Double(totalML) / Double(goalML), 0), 1)
    }

    public func latestLog(on day: Date, logs: [HydrationLog]) -> HydrationLog? {
        logs
            .filter { isSameDay($0.loggedAt, day) }
            .sorted { $0.loggedAt > $1.loggedAt }
            .first
    }

    public func summaries(
        endingOn endDate: Date,
        days: Int,
        logs: [HydrationLog],
        goalML: Int,
        dailyGoalMLByDateKey: [String: Int] = [:]
    ) -> [DailyHydrationSummary] {
        guard days > 0 else { return [] }
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else {
                return nil
            }
            let dateKey = dateKey(for: date)
            return DailyHydrationSummary(
                dateKey: dateKey,
                date: date,
                totalML: total(on: date, logs: logs),
                goalML: dailyGoalMLByDateKey[dateKey] ?? goalML
            )
        }
    }

    public func summaries(
        endingOn endDate: Date,
        days: Int,
        dailyTotalsByDateKey: [String: Int],
        goalML: Int,
        dailyGoalMLByDateKey: [String: Int] = [:]
    ) -> [DailyHydrationSummary] {
        guard days > 0 else { return [] }
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else {
                return nil
            }
            let dateKey = dateKey(for: date)
            return DailyHydrationSummary(
                dateKey: dateKey,
                date: date,
                totalML: max(0, dailyTotalsByDateKey[dateKey] ?? 0),
                goalML: dailyGoalMLByDateKey[dateKey] ?? goalML
            )
        }
    }

    public func streakStatus(
        endingOn endDate: Date,
        logs: [HydrationLog],
        goalML: Int,
        dailyGoalMLByDateKey: [String: Int] = [:]
    ) -> HydrationStreakStatus {
        let today = calendar.startOfDay(for: endDate)
        let startDate = logs.map { calendar.startOfDay(for: $0.loggedAt) }.min() ?? today
        let dayCount = max(
            (calendar.dateComponents([.day], from: startDate, to: today).day ?? 0) + 1,
            1
        )
        let dailySummaries = summaries(
            endingOn: today,
            days: dayCount,
            logs: logs,
            goalML: goalML,
            dailyGoalMLByDateKey: dailyGoalMLByDateKey
        )

        return streakStatus(from: dailySummaries, endingOn: today)
    }

    public func streakStatus(
        endingOn endDate: Date,
        dailyTotalsByDateKey: [String: Int],
        goalML: Int,
        dailyGoalMLByDateKey: [String: Int] = [:]
    ) -> HydrationStreakStatus {
        let today = calendar.startOfDay(for: endDate)
        let earliestDate = dailyTotalsByDateKey.keys
            .compactMap(date(fromDateKey:))
            .min() ?? today
        let dayCount = max(
            (calendar.dateComponents([.day], from: earliestDate, to: today).day ?? 0) + 1,
            1
        )
        let dailySummaries = summaries(
            endingOn: today,
            days: dayCount,
            dailyTotalsByDateKey: dailyTotalsByDateKey,
            goalML: goalML,
            dailyGoalMLByDateKey: dailyGoalMLByDateKey
        )

        return streakStatus(from: dailySummaries, endingOn: today)
    }

    private func streakStatus(
        from dailySummaries: [DailyHydrationSummary],
        endingOn today: Date
    ) -> HydrationStreakStatus {
        var bestDays = 0
        var runDays = 0
        var goalDays = 0
        for summary in dailySummaries {
            if summary.reachedGoal {
                runDays += 1
                goalDays += 1
                bestDays = max(bestDays, runDays)
            } else {
                runDays = 0
            }
        }

        let achievedToday = dailySummaries.last?.reachedGoal ?? false
        var currentDays = achievedToday ? 1 : 0
        var index = dailySummaries.count - 2

        while index >= 0 {
            guard dailySummaries[index].reachedGoal else { break }
            currentDays += 1
            index -= 1
        }

        return HydrationStreakStatus(
            currentDays: currentDays,
            bestDays: bestDays,
            goalDays: goalDays,
            achievedToday: achievedToday,
            dateKey: dateKey(for: today)
        )
    }

    private func date(fromDateKey dateKey: String) -> Date? {
        let parts = dateKey.split(separator: "-")
        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }
}
