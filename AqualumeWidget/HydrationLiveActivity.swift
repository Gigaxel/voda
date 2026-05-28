import ActivityKit
import SwiftUI
import WidgetKit

struct HydrationLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: HydrationActivityAttributes.self) { context in
            LiveActivityLockScreen(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color(red: 0.93, green: 0.99, blue: 1.0))
                .activitySystemActionForegroundColor(WidgetPalette.water)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label {
                        Text(amount(context.state))
                            .font(.system(.callout, design: .rounded, weight: .semibold))
                    } icon: {
                        Image(systemName: "drop.fill")
                            .foregroundStyle(WidgetPalette.water)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.percent)%")
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(context.state.reachedGoal ? WidgetPalette.deepWater : WidgetPalette.water)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack(spacing: 12) {
                        LiveActivityBar(progress: context.state.progress, reachedGoal: context.state.reachedGoal)
                        Button(intent: QuickAddWaterIntent(amountML: context.state.defaultAmountML)) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .tint(WidgetPalette.water)
                    }
                }
            } compactLeading: {
                Image(systemName: "drop.fill")
                    .foregroundStyle(WidgetPalette.water)
            } compactTrailing: {
                Text("\(context.state.percent)%")
                    .foregroundStyle(context.state.reachedGoal ? WidgetPalette.deepWater : WidgetPalette.water)
            } minimal: {
                Image(systemName: context.state.reachedGoal ? "checkmark" : "drop.fill")
                    .foregroundStyle(context.state.reachedGoal ? WidgetPalette.deepWater : WidgetPalette.water)
            }
            .keylineTint(WidgetPalette.water)
        }
    }

    private func amount(_ state: HydrationActivityAttributes.ContentState) -> String {
        HydrationAmountFormatter.amount(state.totalML, unitSystem: state.unitSystem)
    }
}

private struct LiveActivityLockScreen: View {
    let state: HydrationActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 16) {
            WidgetGlass(progress: state.progress)
                .frame(width: 44, height: 60)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(HydrationAmountFormatter.amount(state.totalML, unitSystem: state.unitSystem))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .foregroundStyle(WidgetPalette.ink)
                    Spacer()
                    Text("\(state.percent)%")
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .foregroundStyle(state.reachedGoal ? WidgetPalette.deepWater : WidgetPalette.water)
                }
                LiveActivityBar(progress: state.progress, reachedGoal: state.reachedGoal)
                Text(state.reachedGoal
                     ? "Goal reached - nice work"
                     : "of \(HydrationAmountFormatter.amount(state.goalML, unitSystem: state.unitSystem))")
                    .font(.caption2)
                    .foregroundStyle(WidgetPalette.muted)
            }
        }
    }
}

private struct LiveActivityBar: View {
    let progress: Double
    let reachedGoal: Bool

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(WidgetPalette.water.opacity(0.18))
                Capsule()
                    .fill(reachedGoal ? WidgetPalette.deepWater : WidgetPalette.water)
                    .frame(width: max(6, proxy.size.width * min(1, max(0, progress))))
            }
        }
        .frame(height: 7)
    }
}
