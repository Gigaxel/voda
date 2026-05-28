import Charts
import SwiftUI

struct HydrationTrendChart: View {
    let summaries: [DailyHydrationSummary]
    let unitSystem: HydrationUnitSystem

    @State private var selectedDate: Date?

    private var selectedSummary: DailyHydrationSummary? {
        guard let selectedDate else { return nil }
        return summaries.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            ForEach(summaries) { summary in
                LineMark(
                    x: .value("Day", summary.date, unit: .day),
                    y: .value("Goal", summary.goalML)
                )
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.teal.opacity(0.65))
            }

            ForEach(summaries) { summary in
                AreaMark(
                    x: .value("Day", summary.date, unit: .day),
                    y: .value("Amount", summary.totalML)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.28), Color.cyan.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Day", summary.date, unit: .day),
                    y: .value("Amount", summary.totalML)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.25, lineCap: .round))
                .foregroundStyle(Color.teal)
            }

            if let selectedSummary {
                RuleMark(x: .value("Day", selectedSummary.date, unit: .day))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .foregroundStyle(.secondary.opacity(0.45))

                PointMark(
                    x: .value("Day", selectedSummary.date, unit: .day),
                    y: .value("Amount", selectedSummary.totalML)
                )
                .symbolSize(80)
                .foregroundStyle(Color.teal)
                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                    selectionCallout(selectedSummary)
                }
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.18))
                if let ml = value.as(Double.self) {
                    AxisValueLabel {
                        Text(HydrationAmountFormatter.amount(Int(ml), unitSystem: unitSystem))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 200)
    }

    private func selectionCallout(_ summary: DailyHydrationSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.date, format: .dateTime.weekday(.abbreviated).month().day())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(HydrationAmountFormatter.amount(summary.totalML, unitSystem: unitSystem))
                .font(.callout.weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
