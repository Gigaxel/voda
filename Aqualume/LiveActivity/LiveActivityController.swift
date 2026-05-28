import ActivityKit
import Foundation

/// iOS-only Live Activity lifecycle manager. Starts the activity on the first
/// drink of the day, updates it on every change, and ends it when the day
/// resets or the user opts out. Gated by a UserDefaults flag the Settings
/// toggle writes.
public actor LiveActivityController: LiveActivityControlling {
    private var dayBoundaryEndTask: Task<Void, Never>?

    public init() {}

    private var isEnabled: Bool {
        LiveActivityPreference.isEnabled
    }

    public func refresh(totalML: Int, goalML: Int, unitSystem: HydrationUnitSystem, defaultAmountML: Int) async {
        guard isEnabled, totalML > 0, ActivityAuthorizationInfo().areActivitiesEnabled else {
            await end()
            return
        }

        let state = HydrationActivityAttributes.ContentState(
            totalML: totalML,
            goalML: goalML,
            unitSystem: unitSystem,
            defaultAmountML: defaultAmountML
        )
        let staleDate = HydrationActivityAttributes.staleDate()
        let content = ActivityContent(state: state, staleDate: staleDate)

        if let activity = Activity<HydrationActivityAttributes>.activities.first {
            await activity.update(content)
        } else {
            _ = try? Activity.request(
                attributes: HydrationActivityAttributes(),
                content: content
            )
        }
        scheduleEndAtDayBoundary(staleDate)
    }

    public func end() async {
        dayBoundaryEndTask?.cancel()
        dayBoundaryEndTask = nil
        for activity in Activity<HydrationActivityAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func scheduleEndAtDayBoundary(_ date: Date) {
        dayBoundaryEndTask?.cancel()
        let interval = max(0, date.timeIntervalSinceNow)
        let nanoseconds = UInt64(interval * 1_000_000_000)
        dayBoundaryEndTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard !Task.isCancelled else { return }
            await self?.end()
        }
    }
}
