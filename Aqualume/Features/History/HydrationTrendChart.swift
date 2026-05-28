import Charts
import SwiftUI

struct HydrationTrendChart: View {
    let summaries: [DailyHydrationSummary]
    let unitSystem: HydrationUnitSystem

    @State private var selectedDate: Date?
    @State private var revealProgress = 0.0

    private let brightCyan = Color(red: 0.23, green: 0.86, blue: 0.96)

    private var selectedSummary: DailyHydrationSummary? {
        guard let selectedDate else { return nil }
        return summaries.min {
            abs($0.date.timeIntervalSince(selectedDate)) < abs($1.date.timeIntervalSince(selectedDate))
        }
    }

    var body: some View {
        Chart {
            goalLine
            amountArea
            amountGlow
            amountLine
            currentGoalLabel
            reachedGoalDots

            if let latestSummary {
                latestPoint(latestSummary)
            }

            if let selectedSummary {
                selectionMarks(selectedSummary)
            }
        }
        .chartXSelection(value: $selectedDate)
        .chartYScale(domain: 0...yDomainUpper)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine().foregroundStyle(.secondary.opacity(0.12))
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
        .onAppear {
            replayRevealAnimation()
        }
        .onChange(of: summarySnapshots) { _, _ in
            selectedDate = nil
            replayRevealAnimation()
        }
    }

    private var summarySnapshots: [SummarySnapshot] {
        summaries.map { summary in
            SummarySnapshot(
                dateKey: summary.dateKey,
                totalML: summary.totalML,
                goalML: summary.goalML
            )
        }
    }

    @ChartContentBuilder
    private var goalLine: some ChartContent {
        ForEach(summaries) { summary in
            LineMark(
                x: .value("Day", summary.date, unit: .day),
                y: .value("Goal", summary.goalML),
                series: .value("Series", "goal")
            )
            .interpolationMethod(.stepCenter)
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(Color.teal.opacity(0.4))
        }
    }

    @ChartContentBuilder
    private var amountArea: some ChartContent {
        ForEach(summaries) { summary in
            AreaMark(
                x: .value("Day", summary.date, unit: .day),
                y: .value("Amount", animatedAmount(for: summary))
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(
                LinearGradient(
                    colors: [
                        brightCyan.opacity(0.30),
                        Color.teal.opacity(0.10),
                        Color.teal.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .opacity(revealProgress)
        }
    }

    @ChartContentBuilder
    private var amountGlow: some ChartContent {
        ForEach(summaries) { summary in
            LineMark(
                x: .value("Day", summary.date, unit: .day),
                y: .value("Amount", animatedAmount(for: summary)),
                series: .value("Series", "amountGlow")
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 7, lineCap: .round, lineJoin: .round))
            .foregroundStyle(brightCyan.opacity(0.18))
            .opacity(revealProgress)
        }
    }

    @ChartContentBuilder
    private var amountLine: some ChartContent {
        ForEach(summaries) { summary in
            LineMark(
                x: .value("Day", summary.date, unit: .day),
                y: .value("Amount", animatedAmount(for: summary)),
                series: .value("Series", "amount")
            )
            .interpolationMethod(.catmullRom)
            .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            .foregroundStyle(
                LinearGradient(
                    colors: [brightCyan, Color.teal],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .opacity(revealProgress)
        }
    }

    @ChartContentBuilder
    private var reachedGoalDots: some ChartContent {
        if summaries.count <= 31 {
            ForEach(summaries.filter(\.reachedGoal)) { summary in
                PointMark(
                    x: .value("Day", summary.date, unit: .day),
                    y: .value("Amount", animatedAmount(for: summary))
                )
                .symbolSize(26)
                .foregroundStyle(brightCyan)
                .opacity(revealProgress)
            }
        }
    }

    @ChartContentBuilder
    private var currentGoalLabel: some ChartContent {
        if let latestSummary {
            PointMark(
                x: .value("Day", latestSummary.date, unit: .day),
                y: .value("Goal", latestSummary.goalML)
            )
            .symbolSize(1)
            .foregroundStyle(Color.clear)
            .annotation(position: .trailing, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                Text("Goal")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.teal)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.teal.opacity(0.12), in: Capsule())
            }
        }
    }

    @ChartContentBuilder
    private func latestPoint(_ summary: DailyHydrationSummary) -> some ChartContent {
        PointMark(
            x: .value("Day", summary.date, unit: .day),
            y: .value("Amount", animatedAmount(for: summary))
        )
        .symbolSize(190)
        .foregroundStyle(brightCyan.opacity(0.18))
        .opacity(revealProgress)

        PointMark(
            x: .value("Day", summary.date, unit: .day),
            y: .value("Amount", animatedAmount(for: summary))
        )
        .symbolSize(58)
        .foregroundStyle(Color.teal)
        .opacity(revealProgress)
    }

    @ChartContentBuilder
    private func selectionMarks(_ summary: DailyHydrationSummary) -> some ChartContent {
        RuleMark(x: .value("Day", summary.date, unit: .day))
            .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
            .foregroundStyle(.secondary.opacity(0.4))

        PointMark(
            x: .value("Day", summary.date, unit: .day),
            y: .value("Amount", summary.totalML)
        )
        .symbolSize(220)
        .foregroundStyle((summary.reachedGoal ? brightCyan : Color.teal).opacity(0.18))

        PointMark(
            x: .value("Day", summary.date, unit: .day),
            y: .value("Amount", summary.totalML)
        )
        .symbolSize(90)
        .foregroundStyle(summary.reachedGoal ? brightCyan : Color.teal)
        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
            selectionCallout(summary)
        }
    }

    private var latestSummary: DailyHydrationSummary? {
        summaries.last
    }

    private var yDomainUpper: Double {
        let maxValue = summaries.reduce(0) { partialResult, summary in
            max(partialResult, max(summary.totalML, summary.goalML))
        }
        return max(Double(maxValue) * 1.16, 500)
    }

    private func animatedAmount(for summary: DailyHydrationSummary) -> Double {
        Double(summary.totalML) * revealProgress
    }

    private func replayRevealAnimation() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            revealProgress = 0
        }

        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.7)) {
                revealProgress = 1
            }
        }
    }

    private func selectionCallout(_ summary: DailyHydrationSummary) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(summary.date, format: .dateTime.weekday(.abbreviated).month().day())
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(HydrationAmountFormatter.amount(summary.totalML, unitSystem: unitSystem))
                .font(.system(.callout, design: .rounded, weight: .semibold))
            HStack(spacing: 4) {
                if summary.reachedGoal {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(Color.teal)
                }
                Text("of \(HydrationAmountFormatter.amount(summary.goalML, unitSystem: unitSystem)) goal")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private struct SummarySnapshot: Equatable {
        let dateKey: String
        let totalML: Int
        let goalML: Int
    }
}
