import AppIntents
import ActivityKit
import SwiftUI
import WidgetKit

private enum VodaWidgetKind {
    static let progress = "VodaProgressWidget"
}

struct VodaWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: HydrationSnapshot
}

struct VodaTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VodaWidgetEntry {
        VodaWidgetEntry(date: Date(), snapshot: HydrationSnapshot(logs: [], settings: UserHydrationSettings()))
    }

    func getSnapshot(in context: Context, completion: @escaping (VodaWidgetEntry) -> Void) {
        completion(VodaWidgetEntry(date: Date(), snapshot: HydrationSnapshotReader.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VodaWidgetEntry>) -> Void) {
        let entry = VodaWidgetEntry(date: Date(), snapshot: HydrationSnapshotReader.load())
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date().addingTimeInterval(1_800)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct VodaProgressWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: VodaWidgetKind.progress, provider: VodaTimelineProvider()) { entry in
            VodaWidgetView(entry: entry)
        }
        .configurationDisplayName("Voda")
        .description("See today's water progress and add a glass.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular,
            .accessoryInline
        ])
        .contentMarginsDisabled()
    }
}

struct VodaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: VodaWidgetEntry

    private var progress: Double { entry.snapshot.progress }
    private var percent: Int { Int((progress * 100).rounded()) }

    var body: some View {
        switch family {
        case .accessoryCircular:
            accessoryCircular
        case .accessoryRectangular:
            accessoryRectangular
        case .accessoryInline:
            Label("\(amountText) of \(goalText)", systemImage: "drop.fill")
        case .systemMedium:
            mediumLayout
                .containerBackground(for: .widget) { WidgetSurface() }
        default:
            smallLayout
                .containerBackground(for: .widget) { WidgetSurface() }
        }
    }

    private var amountText: String {
        HydrationAmountFormatter.amount(entry.snapshot.todayTotalML, unitSystem: entry.snapshot.settings.unitSystem)
    }

    private var goalText: String {
        HydrationAmountFormatter.amount(entry.snapshot.settings.dailyGoalML, unitSystem: entry.snapshot.settings.unitSystem)
    }

    private var smallLayout: some View {
        VStack(spacing: 7) {
            Spacer(minLength: 0)

            WidgetGlass(progress: progress)
                .frame(width: 72, height: 96)

            VStack(spacing: 1) {
                Text(amountText)
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("of \(goalText)")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetPalette.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var mediumLayout: some View {
        HStack(spacing: 18) {
            WidgetGlass(progress: progress)
                .frame(width: 82, height: 110)

            VStack(alignment: .leading, spacing: 4) {
                Text(amountText)
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.ink)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("drank today")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetPalette.muted)
                Text("goal \(goalText)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(WidgetPalette.soft)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }

            Spacer(minLength: 0)

            QuickAddButton(amountML: entry.snapshot.settings.defaultAmountML)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    private var accessoryCircular: some View {
        Gauge(value: progress) {
            Image(systemName: "drop.fill")
        } currentValueLabel: {
            Text("\(percent)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .gaugeStyle(.accessoryCircularCapacity)
        .tint(WidgetPalette.water)
        .containerBackground(.clear, for: .widget)
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Label(amountText, systemImage: "drop.fill")
                .font(.headline)
                .widgetAccentable()
            ProgressView(value: progress)
                .tint(WidgetPalette.water)
            Text("\(percent)% of \(goalText)")
                .font(.caption2)
        }
        .containerBackground(.clear, for: .widget)
    }
}

struct WidgetGlass: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let clampedProgress = min(max(progress, 0), 1)
            let fillHeight = size.height * clampedProgress
            let glassShape = WidgetGlassShape()
            let innerGlassShape = WidgetGlassShape(inset: 4)

            ZStack(alignment: .bottom) {
                glassShape
                    .fill(Color.white.opacity(0.72))
                    .shadow(color: WidgetPalette.water.opacity(0.13), radius: 10, y: 5)

                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [WidgetPalette.water, WidgetPalette.deepWater],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: fillHeight)
                }
                .frame(width: size.width, height: size.height, alignment: .bottom)
                .clipShape(innerGlassShape)

                glassShape
                    .stroke(WidgetPalette.stroke, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                Capsule()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: size.width * 0.55, height: 3)
                    .offset(y: -size.height * 0.83)
            }
            .accessibilityHidden(true)
            .animation(.easeOut(duration: 0.35), value: clampedProgress)
        }
    }
}

private struct WidgetGlassShape: InsettableShape {
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let rect = rect.insetBy(dx: inset, dy: inset)
        let topInset = rect.width * 0.10
        let bottomInset = rect.width * 0.23
        let topY = rect.height * 0.11
        let bottomY = rect.height * 0.94
        let bottomCurveY = rect.height * 0.99

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topInset, y: rect.minY + topY))
        path.addLine(to: CGPoint(x: rect.maxX - topInset, y: rect.minY + topY))
        path.addLine(to: CGPoint(x: rect.maxX - bottomInset, y: rect.minY + bottomY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + bottomInset, y: rect.minY + bottomY),
            control: CGPoint(x: rect.midX, y: rect.minY + bottomCurveY)
        )
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> WidgetGlassShape {
        var shape = self
        shape.inset += amount
        return shape
    }
}

private struct QuickAddButton: View {
    let amountML: Int

    var body: some View {
        Button(intent: WidgetQuickAddWaterIntent(amountML: amountML)) {
            Image(systemName: "plus")
        }
        .buttonStyle(WidgetQuickAddButtonStyle())
        .accessibilityLabel("Add water")
    }
}

private struct WidgetQuickAddButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            Circle()
                .fill(configuration.isPressed ? WidgetPalette.water : Color.white.opacity(0.86))
                .overlay {
                    Circle()
                        .stroke(
                            configuration.isPressed ? Color.white.opacity(0.76) : WidgetPalette.stroke.opacity(0.18),
                            lineWidth: 1
                        )
                }

            configuration.label
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(configuration.isPressed ? Color.white : WidgetPalette.ink)
                .opacity(configuration.isPressed ? 0 : 1)
                .scaleEffect(configuration.isPressed ? 0.45 : 1)

            Image(systemName: "drop.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Color.white)
                .opacity(configuration.isPressed ? 1 : 0)
                .scaleEffect(configuration.isPressed ? 1 : 0.45)
        }
        .frame(width: 36, height: 36)
        .shadow(color: WidgetPalette.water.opacity(configuration.isPressed ? 0.28 : 0.12), radius: 10, y: 5)
        .scaleEffect(configuration.isPressed ? 0.86 : 1)
        .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct WidgetQuickAddWaterIntent: AppIntent {
    static let title: LocalizedStringResource = "Add Water"
    static let description = IntentDescription("Add the default glass amount to Voda.")

    @Parameter(title: "Amount in ml")
    var amountML: Int

    init() {
        self.amountML = 250
    }

    init(amountML: Int) {
        self.amountML = amountML
    }

    func perform() async throws -> some IntentResult {
        let summary = try await QuickAddWaterPerformer.logWater(amountML: amountML)
        WidgetCenter.shared.reloadTimelines(ofKind: VodaWidgetKind.progress)
        await QuickAddWaterPerformer.refreshLiveActivities(with: summary)
        return .result()
    }
}

struct QuickAddWaterIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Add Water"
    static let description = IntentDescription("Add the default glass amount to Voda.")

    @Parameter(title: "Amount in ml")
    var amountML: Int

    init() {
        self.amountML = 250
    }

    init(amountML: Int) {
        self.amountML = amountML
    }

    func perform() async throws -> some IntentResult {
        let summary = try await QuickAddWaterPerformer.logWater(amountML: amountML)
        WidgetCenter.shared.reloadTimelines(ofKind: VodaWidgetKind.progress)
        await QuickAddWaterPerformer.refreshLiveActivities(with: summary)
        return .result()
    }
}

private enum QuickAddWaterPerformer {
    static func logWater(amountML: Int) async throws -> HydrationLogWriteSummary {
        let repository = SQLiteHydrationRepository()
        let amount = HydrationValidation.validatedDefaultAmount(amountML)
        return try await repository.appendLogAndLoadTodaySummary(
            HydrationLog(amountML: amount, source: .widget)
        )
    }

    static func refreshLiveActivities(with summary: HydrationLogWriteSummary) async {
        let state = HydrationActivityAttributes.ContentState(
            totalML: summary.todayTotalML,
            goalML: summary.settings.dailyGoalML,
            unitSystem: summary.settings.unitSystem,
            defaultAmountML: summary.settings.defaultAmountML
        )
        let content = ActivityContent(state: state, staleDate: HydrationActivityAttributes.staleDate())
        let activities = Activity<HydrationActivityAttributes>.activities
        if activities.isEmpty {
            if LiveActivityPreference.isEnabled, ActivityAuthorizationInfo().areActivitiesEnabled {
                _ = try? Activity.request(
                    attributes: HydrationActivityAttributes(),
                    content: content
                )
            }
        } else {
            for activity in activities {
                await activity.update(content)
            }
        }
    }
}

private struct WidgetSurface: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.98, green: 1.00, blue: 1.00),
                Color(red: 0.91, green: 0.99, blue: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

enum WidgetPalette {
    static let ink = Color(red: 0.06, green: 0.20, blue: 0.24)
    static let muted = Color(red: 0.30, green: 0.50, blue: 0.55)
    static let soft = Color(red: 0.42, green: 0.62, blue: 0.66)
    static let stroke = Color(red: 0.08, green: 0.35, blue: 0.42)
    static let water = Color(red: 0.29, green: 0.84, blue: 0.95)
    static let deepWater = Color(red: 0.04, green: 0.55, blue: 0.68)
}
