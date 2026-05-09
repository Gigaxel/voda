import SwiftUI

struct WatchHydrationView: View {
    @EnvironmentObject private var state: HydrationAppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var rippleID = UUID()

    var body: some View {
        VStack(spacing: 8) {
            Text(HydrationAmountFormatter.amount(state.todayTotalML, unitSystem: state.settings.unitSystem))
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .minimumScaleFactor(0.7)

            HydrationGlassView(
                progress: state.progress,
                reachedGoal: state.hasReachedGoal,
                design: .tumbler,
                rippleID: rippleID,
                floatingAmount: nil,
                reduceMotion: reduceMotion
            ) {
                Task {
                    await state.logDefaultAmount(source: .watch)
                    rippleID = UUID()
                }
            }
            .frame(height: 112)

            HStack(spacing: 6) {
                ForEach([100, 250], id: \.self) { amount in
                    Button(HydrationAmountFormatter.compactAmount(amount, unitSystem: state.settings.unitSystem)) {
                        Task {
                            await state.log(amountML: amount, source: .watch)
                            rippleID = UUID()
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
            }
        }
        .padding(.horizontal, 4)
        .background(
            LinearGradient(
                colors: [Color(red: 0.02, green: 0.07, blue: 0.12), Color(red: 0.03, green: 0.18, blue: 0.24)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
