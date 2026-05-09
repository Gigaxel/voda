import AppIntents
import SwiftUI
import WidgetKit

struct AqualumeWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: HydrationSnapshot
}

struct AqualumeTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AqualumeWidgetEntry {
        AqualumeWidgetEntry(date: Date(), snapshot: HydrationSnapshot(logs: [], settings: UserHydrationSettings()))
    }

    func getSnapshot(in context: Context, completion: @escaping (AqualumeWidgetEntry) -> Void) {
        completion(AqualumeWidgetEntry(date: Date(), snapshot: HydrationSnapshotReader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AqualumeWidgetEntry>) -> Void) {
        let entry = AqualumeWidgetEntry(date: Date(), snapshot: HydrationSnapshotReader.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct AqualumeProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "AqualumeProgressWidget", provider: AqualumeTimelineProvider()) { entry in
            AqualumeWidgetView(entry: entry)
        }
        .configurationDisplayName("Aqualume")
        .description("See today's water progress and add a glass.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct AqualumeWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: AqualumeWidgetEntry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.90, green: 0.99, blue: 1.0), Color(red: 0.08, green: 0.55, blue: 0.66)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .overlay {
                Image(family == .systemSmall ? "WidgetBackgroundSmall" : "WidgetBackgroundMedium")
                    .resizable()
                    .scaledToFill()
                    .opacity(0.44)
            }

            HStack(spacing: family == .systemSmall ? 8 : 16) {
                WidgetGlass(progress: entry.snapshot.progress)
                    .frame(width: family == .systemSmall ? 48 : 62, height: family == .systemSmall ? 68 : 84)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Aqualume")
                        .font(.headline)
                    Text(HydrationAmountFormatter.amount(entry.snapshot.todayTotalML, unitSystem: entry.snapshot.settings.unitSystem))
                        .font(.system(.title3, design: .rounded, weight: .semibold))
                        .minimumScaleFactor(0.75)
                    Text("of \(HydrationAmountFormatter.amount(entry.snapshot.settings.dailyGoalML, unitSystem: entry.snapshot.settings.unitSystem))")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if #available(iOSApplicationExtension 17.0, *) {
                        Button(intent: QuickAddWaterIntent(amountML: entry.snapshot.settings.defaultAmountML)) {
                            Label("Add", systemImage: "plus")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.cyan)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
        }
        .containerBackground(for: .widget) {
            Color.clear
        }
    }
}

struct WidgetGlass: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let rect = CGRect(origin: .zero, size: proxy.size)
            let fillHeight = rect.height * progress
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.8), lineWidth: 2)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.86), .teal.opacity(0.84)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: max(4, fillHeight))
                    .padding(4)
            }
        }
    }
}

struct QuickAddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Water"
    static let description = IntentDescription("Add water to Aqualume.")

    @Parameter(title: "Amount in ml")
    var amountML: Int

    init() {
        self.amountML = 250
    }

    init(amountML: Int) {
        self.amountML = amountML
    }

    func perform() async throws -> some IntentResult {
        let repository = JSONHydrationRepository()
        let amount = HydrationValidation.validatedDefaultAmount(amountML)
        try await repository.appendLog(HydrationLog(amountML: amount, source: .appIntent))
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
