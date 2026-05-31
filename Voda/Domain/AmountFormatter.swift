import Foundation

public enum HydrationAmountFormatter {
    private static let millilitersPerOunce = 29.5735295625

    public static func ounces(fromMilliliters milliliters: Int) -> Double {
        Double(milliliters) / millilitersPerOunce
    }

    public static func milliliters(fromOunces ounces: Double) -> Int {
        Int((ounces * millilitersPerOunce).rounded())
    }

    public static func amount(_ milliliters: Int, unitSystem: HydrationUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            if milliliters >= 1_000 {
                let liters = Double(milliliters) / 1_000
                return String(format: "%.2f L", locale: Locale(identifier: "en_US_POSIX"), liters)
            }
            return "\(milliliters) ml"
        case .imperial:
            let ounces = ounces(fromMilliliters: milliliters)
            return ounces.formatted(.number.precision(.fractionLength(ounces >= 10 ? 0 : 1))) + " oz"
        }
    }

    public static func compactAmount(_ milliliters: Int, unitSystem: HydrationUnitSystem) -> String {
        switch unitSystem {
        case .metric:
            return "\(milliliters)"
        case .imperial:
            return ounces(fromMilliliters: milliliters).formatted(.number.precision(.fractionLength(0)))
        }
    }
}
