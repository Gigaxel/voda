import SwiftUI

struct ProgressReadout: View {
    let totalML: Int
    let goalML: Int
    let unitSystem: HydrationUnitSystem

    var body: some View {
        VStack(spacing: 4) {
            Text(HydrationAmountFormatter.amount(totalML, unitSystem: unitSystem))
                .font(.system(size: 46, weight: .semibold, design: .rounded))
                .contentTransition(.numericText())
                .minimumScaleFactor(0.75)
                .accessibilityLabel("Water today")

            Text("of \(HydrationAmountFormatter.amount(goalML, unitSystem: unitSystem))")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
    }
}
