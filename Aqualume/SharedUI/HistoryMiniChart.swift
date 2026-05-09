import SwiftUI

struct HistoryMiniChart: View {
    let summaries: [DailyHydrationSummary]

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            ForEach(summaries) { summary in
                VStack(spacing: 6) {
                    GeometryReader { proxy in
                        let height = max(6, proxy.size.height * summary.progress)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.82), Color.teal.opacity(0.72)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: height)
                            .frame(maxHeight: .infinity, alignment: .bottom)
                            .accessibilityLabel(summary.dateKey)
                            .accessibilityValue("\(Int(summary.progress * 100)) percent")
                    }
                    .frame(maxWidth: .infinity)

                    Text(dayLabel(summary.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func dayLabel(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}
