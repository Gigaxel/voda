import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: HydrationAppState
    @Environment(\.dismiss) private var dismiss
    @State private var pendingUnitSystem: HydrationUnitSystem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Hydration") {
                    Stepper(
                        "Daily goal: \(HydrationAmountFormatter.amount(state.settings.dailyGoalML, unitSystem: displayedUnitSystem))",
                        value: goalBinding,
                        in: HydrationValidation.minimumGoalML...HydrationValidation.maximumGoalML,
                        step: 50
                    )

                    Stepper(
                        "Default add: \(HydrationAmountFormatter.amount(state.settings.defaultAmountML, unitSystem: displayedUnitSystem))",
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
                    TimePickerRow("Start", selection: reminderStartTimeBinding)
                    TimePickerRow("End", selection: reminderEndTimeBinding)
                    Stepper(
                        "Every \(state.settings.reminderSchedule.intervalMinutes) min",
                        value: intervalBinding,
                        in: HydrationValidation.minimumReminderIntervalMinutes...HydrationValidation.maximumReminderIntervalMinutes,
                        step: 30
                    )
                }

                Section("Live Activity") {
                    Toggle("Show on Lock Screen", isOn: liveActivityBinding)
                    Text("Track today's progress on the Lock Screen and Dynamic Island.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Streak") {
                    LabeledContent("Current", value: "\(state.streakStatus.currentDays)d")
                    LabeledContent("Best", value: "\(state.streakStatus.bestDays)d")
                    TimePickerRow("Reminder", selection: streakReminderTimeBinding)
                    Toggle("Streak notifications", isOn: streakNotificationBinding)
                }

                Section("Health") {
                    HStack {
                        Text("HealthKit")
                        Spacer()
                        Text(healthLabel)
                            .foregroundStyle(.secondary)
                    }
                    Button {
                        Task { await state.requestHealthKitAuthorization() }
                    } label: {
                        Label("Enable Dietary Water Writes", systemImage: "heart.text.square")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                }

                Section("About") {
                    LabeledContent("Aqualume", value: "Fill your day.")
                }

                if showsDevelopmentOnboardingControls {
                    Section("Development") {
                        Button("Replay Onboarding") {
                            Task {
                                await state.replayOnboardingForDevelopment()
                                dismiss()
                            }
                        }
                    }
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

    private var showsDevelopmentOnboardingControls: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["AQUALUME_ENABLE_ONBOARDING_RESET"] == "1"
        #else
        false
        #endif
    }

    private var displayedUnitSystem: HydrationUnitSystem {
        pendingUnitSystem ?? state.settings.unitSystem
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
            get: { displayedUnitSystem },
            set: { value in
                pendingUnitSystem = value
                Task { @MainActor in
                    await state.updateSettings { $0.unitSystem = value }
                    if pendingUnitSystem == value {
                        pendingUnitSystem = nil
                    }
                }
            }
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

    private var liveActivityBinding: Binding<Bool> {
        Binding(
            get: { LiveActivityPreference.isEnabled },
            set: { value in
                LiveActivityPreference.setEnabled(value)
                Task { await state.refreshLiveActivity() }
            }
        )
    }

    private var reminderStartTimeBinding: Binding<Date> {
        Binding(
            get: {
                timeDate(
                    hour: state.settings.reminderSchedule.startHour,
                    minute: state.settings.reminderSchedule.startMinute
                )
            },
            set: { value in
                let time = timeComponents(from: value)
                Task {
                    await state.updateSettings {
                        $0.reminderSchedule.startHour = time.hour
                        $0.reminderSchedule.startMinute = time.minute
                    }
                }
            }
        )
    }

    private var reminderEndTimeBinding: Binding<Date> {
        Binding(
            get: {
                timeDate(
                    hour: state.settings.reminderSchedule.endHour,
                    minute: state.settings.reminderSchedule.endMinute
                )
            },
            set: { value in
                let time = timeComponents(from: value)
                Task {
                    await state.updateSettings {
                        $0.reminderSchedule.endHour = time.hour
                        $0.reminderSchedule.endMinute = time.minute
                    }
                }
            }
        )
    }

    private var streakReminderTimeBinding: Binding<Date> {
        Binding(
            get: {
                timeDate(
                    hour: state.settings.streakReminderHour,
                    minute: state.settings.streakReminderMinute
                )
            },
            set: { value in
                let time = timeComponents(from: value)
                Task {
                    await state.updateSettings {
                        $0.streakReminderHour = time.hour
                        $0.streakReminderMinute = time.minute
                    }
                }
            }
        )
    }

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { state.settings.reminderSchedule.intervalMinutes },
            set: { value in Task { await state.updateSettings { $0.reminderSchedule.intervalMinutes = value } } }
        )
    }

    private func timeDate(hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.calendar = .current
        components.year = 2000
        components.month = 1
        components.day = 1
        components.hour = HydrationValidation.validatedHour(hour)
        components.minute = HydrationValidation.validatedMinute(minute)
        return components.date ?? Date(timeIntervalSinceReferenceDate: 0)
    }

    private func timeComponents(from date: Date) -> (hour: Int, minute: Int) {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (
            HydrationValidation.validatedHour(components.hour ?? 0),
            HydrationValidation.validatedMinute(components.minute ?? 0)
        )
    }
}

private struct TimePickerRow: View {
    let title: String
    @Binding private var selection: Date
    @State private var draftSelection: Date
    @State private var isPresented = false

    init(_ title: String, selection: Binding<Date>) {
        self.title = title
        _selection = selection
        _draftSelection = State(initialValue: selection.wrappedValue)
    }

    var body: some View {
        Button {
            draftSelection = selection
            isPresented = true
        } label: {
            LabeledContent(title, value: selection.formatted(date: .omitted, time: .shortened))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens time picker")
        .sheet(isPresented: $isPresented) {
            NavigationStack {
                DatePicker(title, selection: $draftSelection, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .navigationTitle(title)
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                isPresented = false
                            }
                        }

                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                selection = draftSelection
                                isPresented = false
                            }
                        }
                    }
            }
            .presentationDetents([.medium])
        }
    }
}
