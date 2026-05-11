import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var state: HydrationAppState
    @State private var selectedRange: HistoryRange = .ninetyDays

    private var summaries: [DailyHydrationSummary] {
        state.summaries(days: selectedRange.days)
    }

    var body: some View {
        List {
            Section {
                Picker("History range", selection: $selectedRange) {
                    ForEach(HistoryRange.allCases) { range in
                        Text(range.title).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section {
                HistoryStatsGrid(
                    summaries: summaries,
                    unitSystem: state.settings.unitSystem
                )
            }

            Section {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HistoryCalendarHeatmap(
                            summaries: summaries,
                            unitSystem: state.settings.unitSystem
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        scrollToToday(proxy)
                    }
                    .onChange(of: selectedRange) { _, _ in
                        scrollToToday(proxy)
                    }
                }
                .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
            }

            Section("Daily Totals") {
                ForEach(summaries.reversed()) { summary in
                    HistorySummaryRow(summary: summary, unitSystem: state.settings.unitSystem)
                }
            }
        }
        .navigationTitle("History")
    }

    private func scrollToToday(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            proxy.scrollTo(HistoryCalendarHeatmap.todayID, anchor: .trailing)
        }
    }
}

private enum HistoryRange: String, CaseIterable, Identifiable {
    case thirtyDays
    case ninetyDays
    case oneYear

    var id: String { rawValue }

    var title: String {
        switch self {
        case .thirtyDays: "30D"
        case .ninetyDays: "90D"
        case .oneYear: "1Y"
        }
    }

    var days: Int {
        switch self {
        case .thirtyDays: 30
        case .ninetyDays: 90
        case .oneYear: 365
        }
    }
}

private struct HistoryStatsGrid: View {
    let summaries: [DailyHydrationSummary]
    let unitSystem: HydrationUnitSystem

    var body: some View {
        Grid(horizontalSpacing: 18, verticalSpacing: 8) {
            GridRow {
                HistoryMetric(title: "Average", value: averageText)
                HistoryMetric(title: "Goal days", value: "\(goalDays)")
                HistoryMetric(title: "Best", value: bestText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
    }

    private var averageText: String {
        guard !summaries.isEmpty else {
            return HydrationAmountFormatter.amount(0, unitSystem: unitSystem)
        }
        let total = summaries.reduce(0) { $0 + $1.totalML }
        return HydrationAmountFormatter.amount(total / summaries.count, unitSystem: unitSystem)
    }

    private var goalDays: Int {
        summaries.filter { $0.totalML >= $0.goalML }.count
    }

    private var bestText: String {
        let best = summaries.map(\.totalML).max() ?? 0
        return HydrationAmountFormatter.amount(best, unitSystem: unitSystem)
    }
}

private struct HistoryMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct HistoryCalendarHeatmap: View {
    static let todayID = "history-calendar-today"

    let summaries: [DailyHydrationSummary]
    let unitSystem: HydrationUnitSystem

    private let calendar = Calendar.current

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                weekdayLabels

                HStack(alignment: .top, spacing: spacing) {
                    ForEach(weeks) { week in
                        VStack(spacing: 6) {
                            ZStack(alignment: .leading) {
                                Color.clear
                                    .frame(width: cellSize, height: 12)
                                Text(week.monthLabel)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                            }

                            VStack(spacing: spacing) {
                                ForEach(week.days) { day in
                                    heatmapCell(day)
                                }
                            }
                        }
                    }
                }
            }

            legend
        }
        .frame(maxWidth: .infinity, alignment: summaries.count <= 100 ? .center : .leading)
    }

    private var weekdayLabels: some View {
        VStack(spacing: spacing) {
            Color.clear.frame(width: 22, height: 12)

            ForEach(weekdaySymbols, id: \.self) { label in
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: cellSize)
            }
        }
    }

    private var legend: some View {
        HStack(spacing: 5) {
            Text("Less")
                .font(.caption2)
                .foregroundStyle(.secondary)

            ForEach(0..<5, id: \.self) { level in
                RoundedRectangle(cornerRadius: 3)
                    .fill(color(forProgressLevel: level))
                    .frame(width: 13, height: 13)
            }

            Text("More")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: summaries.count <= 100 ? .center : .leading)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func heatmapCell(_ day: HistoryHeatmapDay) -> some View {
        if let summary = day.summary {
            RoundedRectangle(cornerRadius: cellCornerRadius)
                .fill(color(for: summary))
                .frame(width: cellSize, height: cellSize)
                .overlay {
                    if day.isToday {
                        RoundedRectangle(cornerRadius: cellCornerRadius)
                            .stroke(Color.primary.opacity(0.78), lineWidth: 2)
                    }
                }
                .id(day.isToday ? Self.todayID : day.id)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(summary.date, format: .dateTime.weekday().month().day().year()))
                .accessibilityValue(accessibilityValue(for: summary))
        } else {
            Color.clear
                .frame(width: cellSize, height: cellSize)
                .accessibilityHidden(true)
        }
    }

    private var weeks: [HistoryHeatmapWeek] {
        let orderedSummaries = summaries.sorted { $0.date < $1.date }
        guard let first = orderedSummaries.first else { return [] }

        var days: [HistoryHeatmapDay] = []
        let leadingBlankCount = weekdayOffset(for: first.date)
        for index in 0..<leadingBlankCount {
            days.append(HistoryHeatmapDay(id: "leading-\(index)", summary: nil, isToday: false))
        }

        for summary in orderedSummaries {
            days.append(
                HistoryHeatmapDay(
                    id: summary.id,
                    summary: summary,
                    isToday: calendar.isDateInToday(summary.date)
                )
            )
        }

        let trailingBlankCount = (7 - days.count % 7) % 7
        if trailingBlankCount > 0 {
            for index in 0..<trailingBlankCount {
                days.append(HistoryHeatmapDay(id: "trailing-\(index)", summary: nil, isToday: false))
            }
        }

        let rawWeeks = stride(from: 0, to: days.count, by: 7).map { start in
            Array(days[start..<min(start + 7, days.count)])
        }

        return rawWeeks.enumerated().map { index, days in
            HistoryHeatmapWeek(
                id: "week-\(index)",
                monthLabel: monthLabel(for: days, previousDays: index > 0 ? rawWeeks[index - 1] : []),
                days: days
            )
        }
    }

    private var cellSize: CGFloat {
        if summaries.count <= 31 { return 28 }
        if summaries.count <= 100 { return 17 }
        return 11
    }

    private var spacing: CGFloat {
        if summaries.count <= 31 { return 5 }
        if summaries.count <= 100 { return 4 }
        return 3
    }

    private var cellCornerRadius: CGFloat {
        summaries.count <= 100 ? 4 : 3
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let startIndex = calendar.firstWeekday - 1
        return Array(symbols[startIndex...] + symbols[..<startIndex])
    }

    private func weekdayOffset(for date: Date) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func monthLabel(for days: [HistoryHeatmapDay], previousDays: [HistoryHeatmapDay]) -> String {
        guard let firstDate = days.compactMap({ $0.summary?.date }).first else { return "" }
        let previousDate = previousDays.compactMap { $0.summary?.date }.first
        guard previousDate == nil || !calendar.isDate(firstDate, equalTo: previousDate!, toGranularity: .month) else {
            return ""
        }
        return firstDate.formatted(.dateTime.month(.abbreviated))
    }

    private func color(for summary: DailyHydrationSummary) -> Color {
        if summary.totalML == 0 { return color(forProgressLevel: 0) }
        if summary.progress < 0.25 { return color(forProgressLevel: 1) }
        if summary.progress < 0.50 { return color(forProgressLevel: 2) }
        if summary.progress < 0.75 { return color(forProgressLevel: 3) }
        return color(forProgressLevel: 4)
    }

    private func color(forProgressLevel level: Int) -> Color {
        switch level {
        case 0:
            Color.secondary.opacity(0.14)
        case 1:
            Color.cyan.opacity(0.24)
        case 2:
            Color.cyan.opacity(0.44)
        case 3:
            Color.teal.opacity(0.64)
        default:
            Color.teal.opacity(0.88)
        }
    }

    private func accessibilityValue(for summary: DailyHydrationSummary) -> String {
        let amount = HydrationAmountFormatter.amount(summary.totalML, unitSystem: unitSystem)
        return "\(amount), \(Int(summary.progress * 100)) percent of goal"
    }
}

private struct HistoryHeatmapWeek: Identifiable {
    let id: String
    let monthLabel: String
    let days: [HistoryHeatmapDay]
}

private struct HistoryHeatmapDay: Identifiable {
    let id: String
    let summary: DailyHydrationSummary?
    let isToday: Bool
}

private struct HistorySummaryRow: View {
    let summary: DailyHydrationSummary
    let unitSystem: HydrationUnitSystem

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(summary.date, format: .dateTime.weekday(.wide).month().day())
                    .font(.headline)
                Text("\(Int(summary.progress * 100))% of goal")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(HydrationAmountFormatter.amount(summary.totalML, unitSystem: unitSystem))
                .font(.system(.title3, design: .rounded, weight: .semibold))
        }
        .padding(.vertical, 6)
    }
}
