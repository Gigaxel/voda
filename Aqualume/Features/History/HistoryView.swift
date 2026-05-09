import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var state: HydrationAppState

    var body: some View {
        List {
            ForEach(state.sevenDaySummaries.reversed()) { summary in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(summary.date, format: .dateTime.weekday(.wide).month().day())
                            .font(.headline)
                        Text("\(Int(summary.progress * 100))% of goal")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(HydrationAmountFormatter.amount(summary.totalML, unitSystem: state.settings.unitSystem))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                }
                .padding(.vertical, 6)
            }
        }
        .navigationTitle("7-Day History")
    }
}
