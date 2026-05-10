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

                VStack(spacing: 22) {
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
                    .frame(maxWidth: 310, maxHeight: 390)
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

                    HistoryMiniChart(summaries: state.sevenDaySummaries)
                        .frame(height: 74)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 18)

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
            .task(id: hydrationAppIconName) {
                await AqualumeAlternateAppIcon.apply(name: hydrationAppIconName)
            }
        }
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
        guard state.todayTotalML > 0 else { return nil }
        guard !state.hasReachedGoal else { return "AppIconFull" }

        if state.progress >= 0.5 {
            return "AppIconMid"
        }
        return "AppIconLow"
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
