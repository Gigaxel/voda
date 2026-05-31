#if canImport(HealthKit) && os(iOS)
import Foundation
import HealthKit

public final class AppleHealthKitService: HealthKitWaterWriting, @unchecked Sendable {
    private let store = HKHealthStore()

    public init() {}

    public func authorizationState() async -> HealthKitAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return .unavailable
        }

        switch store.authorizationStatus(for: type) {
        case .notDetermined:
            return .notDetermined
        case .sharingDenied:
            return .sharingDenied
        case .sharingAuthorized:
            return .sharingAuthorized
        @unknown default:
            return .notDetermined
        }
    }

    public func requestAuthorization() async throws -> HealthKitAuthorizationState {
        guard HKHealthStore.isHealthDataAvailable(),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return .unavailable
        }

        try await store.requestAuthorization(toShare: [type], read: [])
        return await authorizationState()
    }

    public func writeWater(amountML: Int, date: Date) async throws -> String? {
        guard amountML > 0,
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return nil
        }

        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(amountML))
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        try await store.save(sample)
        return sample.uuid.uuidString
    }

    public func deleteWaterSample(identifier: String) async throws {
        guard let uuid = UUID(uuidString: identifier),
              let type = HKQuantityType.quantityType(forIdentifier: .dietaryWater) else {
            return
        }

        let predicate = HKQuery.predicateForObject(with: uuid)
        try await store.deleteObjects(of: type, predicate: predicate)
    }
}
#endif
