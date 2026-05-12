import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: HydrationAppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Hydration") {
                    Stepper(
                        "Daily goal: \(HydrationAmountFormatter.amount(state.settings.dailyGoalML, unitSystem: state.settings.unitSystem))",
                        value: goalBinding,
                        in: HydrationValidation.minimumGoalML...HydrationValidation.maximumGoalML,
                        step: 50
                    )

                    Stepper(
                        "Default add: \(HydrationAmountFormatter.amount(state.settings.defaultAmountML, unitSystem: state.settings.unitSystem))",
                        value: defaultAmountBinding,
                        in: HydrationValidation.minimumDefaultAmountML...HydrationValidation.maximumDefaultAmountML,
                        step: 25
                    )

                    Picker("Units", selection: unitBinding) {
                        Text("ml/L").tag(HydrationUnitSystem.metric)
                        Text("oz").tag(HydrationUnitSystem.imperial)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Reminders") {
                    Toggle("Reminders", isOn: reminderBinding)
                    Stepper("Start: \(state.settings.reminderSchedule.startHour):00", value: startHourBinding, in: 0...23)
                    Stepper("End: \(state.settings.reminderSchedule.endHour):00", value: endHourBinding, in: 0...23)
                    Stepper("Every \(state.settings.reminderSchedule.intervalMinutes) min", value: intervalBinding, in: 60...240, step: 30)
                }

                Section("Streak") {
                    LabeledContent("Current", value: "\(state.streakStatus.currentDays)d")
                    LabeledContent("Best", value: "\(state.streakStatus.bestDays)d")
                    Toggle("Streak notifications", isOn: streakNotificationBinding)
                }

                Section("Health") {
                    HStack {
                        Text("HealthKit")
                        Spacer()
                        Text(healthLabel)
                            .foregroundStyle(.secondary)
                    }
                    Button("Enable Dietary Water Writes") {
                        Task { await state.requestHealthKitAuthorization() }
                    }
                }

                Section("About") {
                    LabeledContent("Aqualume", value: "Fill your day.")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var healthLabel: String {
        switch state.healthKitState {
        case .unavailable: "Unavailable"
        case .notDetermined: "Not Set"
        case .sharingDenied: "Denied"
        case .sharingAuthorized: "Enabled"
        }
    }

    private var goalBinding: Binding<Int> {
        Binding(
            get: { state.settings.dailyGoalML },
            set: { value in Task { await state.updateSettings { $0.dailyGoalML = value } } }
        )
    }

    private var defaultAmountBinding: Binding<Int> {
        Binding(
            get: { state.settings.defaultAmountML },
            set: { value in Task { await state.updateSettings { $0.defaultAmountML = value } } }
        )
    }

    private var unitBinding: Binding<HydrationUnitSystem> {
        Binding(
            get: { state.settings.unitSystem },
            set: { value in Task { await state.updateSettings { $0.unitSystem = value } } }
        )
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { state.settings.remindersEnabled },
            set: { value in Task { await state.updateSettings { $0.remindersEnabled = value } } }
        )
    }

    private var streakNotificationBinding: Binding<Bool> {
        Binding(
            get: { state.settings.streakNotificationsEnabled },
            set: { value in Task { await state.updateSettings { $0.streakNotificationsEnabled = value } } }
        )
    }

    private var startHourBinding: Binding<Int> {
        Binding(
            get: { state.settings.reminderSchedule.startHour },
            set: { value in Task { await state.updateSettings { $0.reminderSchedule.startHour = value } } }
        )
    }

    private var endHourBinding: Binding<Int> {
        Binding(
            get: { state.settings.reminderSchedule.endHour },
            set: { value in Task { await state.updateSettings { $0.reminderSchedule.endHour = value } } }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { state.settings.reminderSchedule.intervalMinutes },
            set: { value in Task { await state.updateSettings { $0.reminderSchedule.intervalMinutes = value } } }
        )
    }
}
