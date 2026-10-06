import SwiftUI

struct DayLogEditorView: View {
    @EnvironmentObject private var state: HydrationAppState
    @Environment(\.dismiss) private var dismiss

    let summary: DailyHydrationSummary

    @State private var logs: [HydrationLog] = []
    @State private var hasLoaded = false
    @State private var draft: LogDraft?
    @State private var errorMessage: String?

    private let calendar = Calendar.current

    private var unitSystem: HydrationUnitSystem {
        state.settings.unitSystem
    }

    private var totalML: Int {
        logs.reduce(0) { $0 + max(0, $1.amountML) }
    }

    private var progress: Double {
        guard summary.goalML > 0 else { return 0 }
        return min(Double(totalML) / Double(summary.goalML), 1)
    }

    /// Entries can be placed anywhere on this day, but never in the future.
    private var timeRange: ClosedRange<Date> {
        let start = calendar.startOfDay(for: summary.date)
        let endOfDay = calendar.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? summary.date
        return start...max(start, min(endOfDay, Date()))
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(HydrationAmountFormatter.amount(totalML, unitSystem: unitSystem))
                            .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                            .contentTransition(.numericText())
                        Text("\(Int(progress * 100))% of \(HydrationAmountFormatter.amount(summary.goalML, unitSystem: unitSystem)) goal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ProgressView(value: progress)
                            .padding(.top, 4)
                    }
                    .padding(.vertical, 6)
                    .animation(.default, value: totalML)
                }

                Section("Entries") {
                    if !hasLoaded {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else if logs.isEmpty {
                        Text("Nothing logged this day.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(logs) { log in
                            Button {
                                draft = LogDraft(log: log)
                            } label: {
                                LogEntryRow(log: log, unitSystem: unitSystem)
                            }
                            .accessibilityHint("Edit entry")
                        }
                        .onDelete { offsets in
                            let removed = offsets.map { logs[$0] }
                            Task {
                                do {
                                    try await delete(removed)
                                } catch {
                                    errorMessage = "Unable to delete this entry."
                                }
                            }
                        }
                    }
                }

                Section {
                    Button {
                        draft = LogDraft(newEntryAt: defaultNewEntryTime, amountML: state.settings.defaultAmountML)
                    } label: {
                        Label("Add Water", systemImage: "plus.circle.fill")
                    }
                }
            }
            .tint(Color(red: 0.10, green: 0.67, blue: 0.74))
            .navigationTitle(Text(summary.date, format: .dateTime.weekday(.wide).month().day()))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                await reload()
            }
            .sheet(item: $draft) { draft in
                LogEntryEditor(
                    draft: draft,
                    unitSystem: unitSystem,
                    timeRange: timeRange,
                    onSave: { amountML, loggedAt in
                        try await save(draft, amountML: amountML, loggedAt: loggedAt)
                    },
                    onDelete: deleteAction(for: draft)
                )
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var defaultNewEntryTime: Date {
        if calendar.isDateInToday(summary.date) {
            return Date()
        }
        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: summary.date) ?? summary.date
        return min(max(noon, timeRange.lowerBound), timeRange.upperBound)
    }

    private func reload() async {
        do {
            logs = try await state.logs(on: summary.date)
        } catch {
            errorMessage = "Unable to load entries for this day."
        }
        hasLoaded = true
    }

    private func deleteAction(for draft: LogDraft) -> (() async throws -> Void)? {
        guard let log = draft.log else { return nil }
        return { try await delete([log]) }
    }

    private func save(_ draft: LogDraft, amountML: Int, loggedAt: Date) async throws {
        if let log = draft.log {
            try await state.updateLog(log, amountML: amountML, loggedAt: loggedAt)
        } else {
            try await state.addLog(amountML: amountML, loggedAt: loggedAt)
        }
        await reload()
    }

    private func delete(_ removed: [HydrationLog]) async throws {
        do {
            for log in removed {
                try await state.deleteLog(log)
            }
        } catch {
            await reload()
            throw error
        }
        await reload()
    }
}

private struct LogDraft: Identifiable {
    let id = UUID()
    /// The entry being edited, or `nil` when adding a new one.
    let log: HydrationLog?
    let amountML: Int
    let loggedAt: Date

    init(log: HydrationLog) {
        self.log = log
        self.amountML = log.amountML
        self.loggedAt = log.loggedAt
    }

    init(newEntryAt loggedAt: Date, amountML: Int) {
        self.log = nil
        self.amountML = amountML
        self.loggedAt = loggedAt
    }
}

private struct LogEntryRow: View {
    let log: HydrationLog
    let unitSystem: HydrationUnitSystem

    var body: some View {
        HStack {
            Image(systemName: "drop.fill")
                .foregroundStyle(Color(red: 0.10, green: 0.67, blue: 0.74))
            Text(log.loggedAt, format: .dateTime.hour().minute())
                .foregroundStyle(Color.primary)
            Spacer()
            Text(HydrationAmountFormatter.amount(log.amountML, unitSystem: unitSystem))
                .font(.system(.body, design: .rounded, weight: .semibold))
                .foregroundStyle(Color.primary)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.secondary.opacity(0.6))
        }
        .contentShape(.rect)
    }
}

private struct LogEntryEditor: View {
    @Environment(\.dismiss) private var dismiss

    let draft: LogDraft
    let unitSystem: HydrationUnitSystem
    let timeRange: ClosedRange<Date>
    let onSave: (Int, Date) async throws -> Void
    let onDelete: (() async throws -> Void)?

    @State private var amountML: Int
    @State private var loggedAt: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(
        draft: LogDraft,
        unitSystem: HydrationUnitSystem,
        timeRange: ClosedRange<Date>,
        onSave: @escaping (Int, Date) async throws -> Void,
        onDelete: (() async throws -> Void)?
    ) {
        self.draft = draft
        self.unitSystem = unitSystem
        self.timeRange = timeRange
        self.onSave = onSave
        self.onDelete = onDelete
        _amountML = State(initialValue: HydrationValidation.validatedDefaultAmount(draft.amountML))
        _loggedAt = State(initialValue: min(max(draft.loggedAt, timeRange.lowerBound), timeRange.upperBound))
    }

    private var amountStepML: Int {
        unitSystem == .metric ? 25 : HydrationAmountFormatter.milliliters(fromOunces: 1)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    Stepper(
                        value: $amountML,
                        in: HydrationValidation.minimumDefaultAmountML...HydrationValidation.maximumDefaultAmountML,
                        step: amountStepML
                    ) {
                        HStack {
                            Text("Amount")
                            Spacer()
                            Text(HydrationAmountFormatter.amount(amountML, unitSystem: unitSystem))
                                .font(.system(.body, design: .rounded, weight: .semibold))
                                .monospacedDigit()
                        }
                    }

                    QuickAmountControl(
                        amountsML: HydrationValidation.quickAmountsML,
                        unitSystem: unitSystem
                    ) { amount in
                        amountML = amount
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                }

                Section {
                    DatePicker("Time", selection: $loggedAt, in: timeRange, displayedComponents: .hourAndMinute)
                }

                if let onDelete {
                    Section {
                        Button("Delete Entry", role: .destructive) {
                            perform(failureMessage: "Unable to delete this entry.") { try await onDelete() }
                        }
                    }
                }
            }
            .disabled(isSaving)
            .navigationTitle(draft.log == nil ? "Add Water" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        perform(failureMessage: "Unable to save this entry.") { try await onSave(amountML, loggedAt) }
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert(
                "Something went wrong",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func perform(failureMessage: String, _ action: @escaping () async throws -> Void) {
        isSaving = true
        Task {
            do {
                try await action()
                dismiss()
            } catch {
                errorMessage = failureMessage
            }
            isSaving = false
        }
    }
}
