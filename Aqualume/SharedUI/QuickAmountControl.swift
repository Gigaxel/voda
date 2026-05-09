import SwiftUI

struct QuickAmountControl: View {
    let amountsML: [Int]
    let unitSystem: HydrationUnitSystem
    let onSelect: (Int) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(amountsML, id: \.self) { amount in
                Button {
                    onSelect(amount)
                } label: {
                    Text(HydrationAmountFormatter.amount(amount, unitSystem: unitSystem))
                        .font(.system(.callout, design: .rounded, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.10, green: 0.67, blue: 0.74).opacity(0.86))
            }
        }
        .accessibilityElement(children: .contain)
    }
}
