import ActivityKit
import Foundation

/// Shared attributes for the hydration Live Activity (app + widget extension).
public struct HydrationActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var totalML: Int
        public var goalML: Int
        public var unitSystem: HydrationUnitSystem
        public var defaultAmountML: Int

        public init(
            totalML: Int,
            goalML: Int,
            unitSystem: HydrationUnitSystem,
            defaultAmountML: Int = 250
        ) {
            self.totalML = totalML
            self.goalML = goalML
            self.unitSystem = unitSystem
            self.defaultAmountML = defaultAmountML
        }

        public var progress: Double {
            guard goalML > 0 else { return 0 }
            return min(1, max(0, Double(totalML) / Double(goalML)))
        }

        public var percent: Int { Int((progress * 100).rounded()) }
        public var reachedGoal: Bool { totalML >= goalML }
    }

    public init() {}

    public static func staleDate(after date: Date = Date(), calendar: Calendar = .current) -> Date {
        let today = calendar.startOfDay(for: date)
        return calendar.date(byAdding: .day, value: 1, to: today)?.addingTimeInterval(1)
            ?? date.addingTimeInterval(86_400)
    }
}

public enum LiveActivityPreference {
    public static let enabledDefaultsKey = "liveActivityEnabled"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: RepositoryLocation.appGroupID) ?? .standard
    }

    public static var isEnabled: Bool {
        defaults.object(forKey: enabledDefaultsKey) as? Bool ?? true
    }

    public static func setEnabled(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: enabledDefaultsKey)
    }
}
