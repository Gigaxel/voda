import SwiftUI
#if os(iOS)
import UIKit
#endif

struct AqualumeRootView: View {
    @EnvironmentObject private var state: HydrationAppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false
    @State private var rippleID = UUID()
    @State private var floatingAmount: Int?
    @State private var celebrationID = UUID()
    @State private var celebrationActive = false

    var body: some View {
        NavigationStack {
            ZStack {
                AqualumeBackground()

                VStack(spacing: 20) {
                    ProgressReadout(
                        totalML: state.todayTotalML,
                        goalML: state.settings.dailyGoalML,
                        unitSystem: state.settings.unitSystem
                    )

                    HydrationGlassView(
                        progress: state.progress,
                        reachedGoal: state.hasReachedGoal,
                        design: .tumbler,
                        rippleID: rippleID,
                        floatingAmount: floatingAmount.map {
                            "+" + HydrationAmountFormatter.amount($0, unitSystem: state.settings.unitSystem)
                        },
                        reduceMotion: reduceMotion
                    ) {
                        Task {
                            await log(amountML: state.settings.defaultAmountML)
                        }
                    }
                    .frame(maxWidth: 360, maxHeight: 500)
                    .layoutPriority(1)
                    .accessibilityLabel("Hydration glass")
                    .accessibilityValue("\(HydrationAmountFormatter.amount(state.todayTotalML, unitSystem: state.settings.unitSystem)) of \(HydrationAmountFormatter.amount(state.settings.dailyGoalML, unitSystem: state.settings.unitSystem))")
                    .accessibilityHint("Adds your default amount")

                    QuickAmountControl(
                        amountsML: state.quickAmountsML,
                        unitSystem: state.settings.unitSystem
                    ) { amount in
                        Task { await log(amountML: amount) }
                    }

                    HStack(spacing: 16) {
                        Button {
                            Task { await state.undoLatest() }
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                        }
                        .buttonStyle(AqualumeHomeActionButtonStyle())
                        .disabled(!state.canUndo)

                        NavigationLink {
                            HistoryView()
                        } label: {
                            Label("History", systemImage: "chart.bar")
                        }
                        .buttonStyle(AqualumeHomeActionButtonStyle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)
                .padding(.bottom, 28)

                ConfettiCelebrationView(
                    trigger: celebrationID,
                    isActive: celebrationActive,
                    reduceMotion: reduceMotion
                )
                .ignoresSafeArea()
            }
            .navigationTitle("Aqualume")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: onboardingPresented) {
                OnboardingView()
                    .environmentObject(state)
                    .interactiveDismissDisabled()
            }
            .task(id: hydrationAppIconTaskID) {
                await AqualumeAlternateAppIcon.apply(name: hydrationAppIconName)
            }
            .task(id: state.currentDateKey) {
                await refreshAfterNextDayStarts()
            }
        }
    }

    private var onboardingPresented: Binding<Bool> {
        Binding(
            get: { state.hasLoaded && !state.settings.hasCompletedOnboarding },
            set: { _ in }
        )
    }

    private func log(amountML: Int) async {
        let hadReachedGoal = state.hasReachedGoal
        await state.log(amountML: amountML)
        let didReachGoal = !hadReachedGoal && state.hasReachedGoal

        rippleID = UUID()
        floatingAmount = amountML
        AqualumeHaptics.log()

        if didReachGoal {
            triggerGoalCelebration()
            AqualumeHaptics.goal()
        }

        guard !reduceMotion else {
            floatingAmount = nil
            return
        }
        try? await Task.sleep(nanoseconds: 1_100_000_000)
        floatingAmount = nil
    }

    private func triggerGoalCelebration() {
        let newID = UUID()
        celebrationID = newID
        celebrationActive = true

        Task {
            try? await Task.sleep(nanoseconds: reduceMotion ? 1_200_000_000 : 4_600_000_000)
            guard celebrationID == newID else { return }
            celebrationActive = false
        }
    }

    private var hydrationAppIconName: String? {
        guard !state.hasReachedGoal else { return nil }
        return state.progress >= 0.5 ? "AppIconMid" : "AppIconEmpty"
    }

    private var hydrationAppIconTaskID: String {
        "\(state.currentDateKey)-\(hydrationAppIconName ?? "full")"
    }

    private func refreshAfterNextDayStarts() async {
        let calendar = Calendar.current
        let nextDay = calendar.startOfDay(for: Date().addingTimeInterval(86_400))
            .addingTimeInterval(1)
        let interval = max(1, nextDay.timeIntervalSinceNow)
        try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        guard !Task.isCancelled else { return }
        state.refreshForCurrentDate()
    }
}

private enum OnboardingWeightUnit: String, CaseIterable, Identifiable {
    case kilograms
    case pounds

    var id: String { rawValue }

    var title: String {
        switch self {
        case .kilograms: "kg"
        case .pounds: "lb"
        }
    }
}

private struct OnboardingView: View {
    @EnvironmentObject private var state: HydrationAppState
    @State private var gender: HydrationProfileGender = .preferNotToSay
    @State private var weightUnit: OnboardingWeightUnit = .kilograms
    @State private var weightValue = 70.0
    @State private var hasInitialized = false

    var body: some View {
        NavigationStack {
            ZStack {
                AqualumeBackground()

                VStack(alignment: .leading, spacing: 10) {
                    Text("A good first goal starts with a quick body-weight estimate.")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 20)
                        .padding(.trailing, 12)

                    Form {
                        Section("Profile") {
                            Picker("Gender", selection: $gender) {
                                ForEach(HydrationProfileGender.allCases, id: \.self) { option in
                                    Text(option.displayName).tag(option)
                                }
                            }

                            Picker("Weight unit", selection: $weightUnit) {
                                ForEach(OnboardingWeightUnit.allCases) { unit in
                                    Text(unit.title).tag(unit)
                                }
                            }
                            .pickerStyle(.segmented)
                            .onChange(of: weightUnit) { oldValue, newValue in
                                convertWeight(from: oldValue, to: newValue)
                            }

                            LabeledContent("Weight") {
                                HStack(spacing: 8) {
                                    TextField("Weight", value: weightBinding, format: .number.precision(.fractionLength(0)))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(minWidth: 72)
                                    Text(weightUnit.title)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Slider(value: weightBinding, in: weightRange, step: weightStep)
                                .accessibilityLabel("Weight")
                                .accessibilityValue(weightText)
                        }

                        Section("Recommended Daily Goal") {
                            LabeledContent("Starting goal", value: recommendationText)
                            Text("You can tune the daily goal later in Settings.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Set Your Goal")
            .safeAreaInset(edge: .bottom) {
                Button {
                    Task { await completeOnboarding() }
                } label: {
                    Text("Start with \(recommendationText)")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.05, green: 0.58, blue: 0.48))
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
            .onAppear(perform: initializeDefaults)
        }
    }

    private var weightRange: ClosedRange<Double> {
        switch weightUnit {
        case .kilograms:
            return HydrationValidation.minimumProfileWeightKG...HydrationValidation.maximumProfileWeightKG
        case .pounds:
            let minimum = HydrationGoalRecommender.pounds(
                fromKilograms: HydrationValidation.minimumProfileWeightKG
            )
            let maximum = HydrationGoalRecommender.pounds(
                fromKilograms: HydrationValidation.maximumProfileWeightKG
            )
            return minimum...maximum
        }
    }

    private var weightStep: Double {
        switch weightUnit {
        case .kilograms: 1
        case .pounds: 1
        }
    }

    private var weightBinding: Binding<Double> {
        Binding(
            get: { weightValue },
            set: { weightValue = min(max($0, weightRange.lowerBound), weightRange.upperBound) }
        )
    }

    private var weightKG: Double {
        switch weightUnit {
        case .kilograms:
            weightValue
        case .pounds:
            HydrationGoalRecommender.kilograms(fromPounds: weightValue)
        }
    }

    private var recommendedGoalML: Int {
        HydrationGoalRecommender.dailyGoalML(weightKG: weightKG, gender: gender)
    }

    private var recommendationText: String {
        HydrationAmountFormatter.amount(recommendedGoalML, unitSystem: state.settings.unitSystem)
    }

    private var weightText: String {
        switch weightUnit {
        case .kilograms:
            "\(Int(weightValue.rounded())) kg"
        case .pounds:
            "\(Int(weightValue.rounded())) lb"
        }
    }

    private func initializeDefaults() {
        guard !hasInitialized else { return }
        hasInitialized = true
        gender = state.settings.profileGender ?? .preferNotToSay
        weightUnit = state.settings.unitSystem == .imperial ? .pounds : .kilograms
        let defaultWeightKG = state.settings.profileWeightKG ?? 70
        switch weightUnit {
        case .kilograms:
            weightValue = defaultWeightKG
        case .pounds:
            weightValue = HydrationGoalRecommender.pounds(fromKilograms: defaultWeightKG)
        }
    }

    private func convertWeight(from oldUnit: OnboardingWeightUnit, to newUnit: OnboardingWeightUnit) {
        guard oldUnit != newUnit else { return }
        switch (oldUnit, newUnit) {
        case (.kilograms, .pounds):
            weightValue = HydrationGoalRecommender.pounds(fromKilograms: weightValue)
        case (.pounds, .kilograms):
            weightValue = HydrationGoalRecommender.kilograms(fromPounds: weightValue)
        case (.kilograms, .kilograms), (.pounds, .pounds):
            break
        }
    }

    private func completeOnboarding() async {
        let safeWeightKG = HydrationValidation.validatedProfileWeightKG(weightKG)
        let goalML = HydrationGoalRecommender.dailyGoalML(weightKG: safeWeightKG, gender: gender)
        await state.updateSettings {
            $0.profileGender = gender
            $0.profileWeightKG = safeWeightKG
            $0.dailyGoalML = goalML
            $0.hasCompletedOnboarding = true
        }
    }
}

#if os(iOS)
@MainActor
private enum AqualumeAlternateAppIcon {
    static func apply(name: String?) async {
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        guard UIApplication.shared.supportsAlternateIcons else { return }
        guard UIApplication.shared.alternateIconName != name else { return }

        await withCheckedContinuation { continuation in
            UIApplication.shared.setAlternateIconName(name) { _ in
                continuation.resume()
            }
        }
    }
}
#else
private enum AqualumeAlternateAppIcon {
    static func apply(name: String?) async {}
}
#endif

struct AqualumeBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.03, green: 0.07, blue: 0.12), Color(red: 0.04, green: 0.13, blue: 0.22)]
                : [Color(red: 0.91, green: 0.98, blue: 0.99), Color(red: 0.74, green: 0.92, blue: 0.96)],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay {
            Image(colorScheme == .dark ? "BackgroundDarkMoonwater" : "BackgroundLightAqua")
                .resizable()
                .scaledToFill()
                .opacity(colorScheme == .dark ? 0.42 : 0.24)
                .saturation(colorScheme == .dark ? 1 : 0.82)
        }
        .overlay {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [Color.clear, Color.clear]
                    : [Color.white.opacity(0.10), Color(red: 0.05, green: 0.38, blue: 0.45).opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }
}

private struct AqualumeHomeActionButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.callout, design: .rounded, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 112)
            .background {
                Capsule()
                    .fill(backgroundColor)
                    .overlay {
                        Capsule()
                            .stroke(borderColor, lineWidth: 1)
                    }
            }
            .shadow(color: shadowColor, radius: 10, y: 4)
            .opacity(isEnabled ? 1 : 0.44)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.16), value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        colorScheme == .dark
            ? Color(red: 0.80, green: 0.98, blue: 1.0)
            : Color(red: 0.01, green: 0.24, blue: 0.30)
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.12)
            : Color.white.opacity(0.82)
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.22)
            : Color(red: 0.02, green: 0.37, blue: 0.44).opacity(0.26)
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.18)
            : Color(red: 0.02, green: 0.31, blue: 0.38).opacity(0.12)
    }
}
