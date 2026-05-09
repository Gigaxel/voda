import Foundation

public struct HydrationCalculator: Sendable {
    private let calendar: Calendar

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
        goalML: Int
    ) -> [DailyHydrationSummary] {
        guard days > 0 else { return [] }
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: endDate) else {
                return nil
            }
            return DailyHydrationSummary(
                dateKey: dateKey(for: date),
                date: date,
                totalML: total(on: date, logs: logs),
                goalML: goalML
            )
        }
    }
}
