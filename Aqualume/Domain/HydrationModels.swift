import Foundation

public enum HydrationUnitSystem: String, Codable, CaseIterable, Equatable, Sendable {
    case metric
    case imperial
}

public enum HydrationGlassDesign: String, Codable, CaseIterable, Equatable, Sendable {
    case classic
    case prism
    case tumbler
    case flute

    public var displayName: String {
        switch self {
        case .classic: "Classic"
        case .prism: "Prism"
        case .tumbler: "Tumbler"
        case .flute: "Flute"
        }
    }
}

public enum HydrationProfileGender: String, Codable, CaseIterable, Equatable, Sendable {
    case female
    case male
    case nonBinary
    case preferNotToSay

    public var displayName: String {
        switch self {
        case .female: "Female"
        case .male: "Male"
        case .nonBinary: "Non-binary"
        case .preferNotToSay: "Prefer not to say"
        }
    }
}

public enum HydrationLogSource: String, Codable, CaseIterable, Equatable, Sendable {
    case iPhone
    case watch
    case widget
    case appIntent
}

public struct HydrationLog: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var amountML: Int
    public var loggedAt: Date
    public var source: HydrationLogSource
    public var healthKitSampleIdentifier: String?

    public init(
        id: UUID = UUID(),
        amountML: Int,
        loggedAt: Date = Date(),
        source: HydrationLogSource,
        healthKitSampleIdentifier: String? = nil
    ) {
        self.id = id
        self.amountML = amountML
        self.loggedAt = loggedAt
        self.source = source
        self.healthKitSampleIdentifier = healthKitSampleIdentifier
    }
}

public struct ReminderSchedule: Codable, Equatable, Sendable {
    public var startHour: Int
    public var endHour: Int
    public var intervalMinutes: Int

    public init(startHour: Int = 9, endHour: Int = 21, intervalMinutes: Int = 120) {
        self.startHour = startHour
        self.endHour = endHour
        self.intervalMinutes = intervalMinutes
    }
}

public struct UserHydrationSettings: Codable, Equatable, Sendable {
    public var dailyGoalML: Int
    public var defaultAmountML: Int
    public var unitSystem: HydrationUnitSystem
    public var glassDesign: HydrationGlassDesign
    public var profileGender: HydrationProfileGender?
    public var profileWeightKG: Double?
    public var hasCompletedOnboarding: Bool
    public var remindersEnabled: Bool
    public var reminderSchedule: ReminderSchedule
    public var streakNotificationsEnabled: Bool
    public var healthKitEnabled: Bool

    public init(
        dailyGoalML: Int = 2_000,
        defaultAmountML: Int = 250,
        unitSystem: HydrationUnitSystem = .metric,
        glassDesign: HydrationGlassDesign = .tumbler,
        profileGender: HydrationProfileGender? = nil,
        profileWeightKG: Double? = nil,
        hasCompletedOnboarding: Bool = false,
        remindersEnabled: Bool = false,
        reminderSchedule: ReminderSchedule = ReminderSchedule(),
        streakNotificationsEnabled: Bool = false,
        healthKitEnabled: Bool = false
    ) {
        self.dailyGoalML = dailyGoalML
        self.defaultAmountML = defaultAmountML
        self.unitSystem = unitSystem
        self.glassDesign = glassDesign
        self.profileGender = profileGender
        self.profileWeightKG = profileWeightKG
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.remindersEnabled = remindersEnabled
        self.reminderSchedule = reminderSchedule
        self.streakNotificationsEnabled = streakNotificationsEnabled
        self.healthKitEnabled = healthKitEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case dailyGoalML
        case defaultAmountML
        case unitSystem
        case glassDesign
        case profileGender
        case profileWeightKG
        case hasCompletedOnboarding
        case remindersEnabled
        case reminderSchedule
        case streakNotificationsEnabled
        case healthKitEnabled
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dailyGoalML = try container.decodeIfPresent(Int.self, forKey: .dailyGoalML) ?? 2_000
        defaultAmountML = try container.decodeIfPresent(Int.self, forKey: .defaultAmountML) ?? 250
        unitSystem = try container.decodeIfPresent(HydrationUnitSystem.self, forKey: .unitSystem) ?? .metric
        glassDesign = try container.decodeIfPresent(HydrationGlassDesign.self, forKey: .glassDesign) ?? .tumbler
        profileGender = try container.decodeIfPresent(HydrationProfileGender.self, forKey: .profileGender)
        profileWeightKG = try container.decodeIfPresent(Double.self, forKey: .profileWeightKG)
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        remindersEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersEnabled) ?? false
        reminderSchedule = try container.decodeIfPresent(ReminderSchedule.self, forKey: .reminderSchedule) ?? ReminderSchedule()
        streakNotificationsEnabled = try container.decodeIfPresent(Bool.self, forKey: .streakNotificationsEnabled) ?? false
        healthKitEnabled = try container.decodeIfPresent(Bool.self, forKey: .healthKitEnabled) ?? false
    }
}

public struct DailyHydrationSummary: Identifiable, Equatable, Sendable {
    public var id: String { dateKey }
    public var dateKey: String
    public var date: Date
    public var totalML: Int
    public var goalML: Int

    public var progress: Double {
        guard goalML > 0 else { return 0 }
        return min(Double(totalML) / Double(goalML), 1)
    }

    public var reachedGoal: Bool {
        totalML >= goalML
    }
}

public struct HydrationStreakStatus: Equatable, Sendable {
    public var currentDays: Int
    public var bestDays: Int
    public var goalDays: Int
    public var achievedToday: Bool
    public var dateKey: String

    public var nextMilestone: Int {
        [3, 7, 14, 30, 60, 90, 180, 365].first { $0 > currentDays } ?? currentDays + 50
    }

    public init(
        currentDays: Int,
        bestDays: Int,
        goalDays: Int,
        achievedToday: Bool,
        dateKey: String
    ) {
        self.currentDays = currentDays
        self.bestDays = bestDays
        self.goalDays = goalDays
        self.achievedToday = achievedToday
        self.dateKey = dateKey
    }
}

public enum HydrationValidation {
    public static let quickAmountsML = [100, 250, 330, 500]
    public static let minimumGoalML = 250
    public static let maximumGoalML = 10_000
    public static let minimumDefaultAmountML = 25
    public static let maximumDefaultAmountML = 2_000
    public static let minimumProfileWeightKG = 30.0
    public static let maximumProfileWeightKG = 250.0

    public static func validatedGoal(_ value: Int) -> Int {
        min(max(value, minimumGoalML), maximumGoalML)
    }

    public static func validatedDefaultAmount(_ value: Int) -> Int {
        min(max(value, minimumDefaultAmountML), maximumDefaultAmountML)
    }

    public static func validatedProfileWeightKG(_ value: Double) -> Double {
        min(max(value, minimumProfileWeightKG), maximumProfileWeightKG)
    }
}

public enum HydrationGoalRecommender {
    private static let poundsPerKilogram = 2.2046226218

    public static func kilograms(fromPounds pounds: Double) -> Double {
        pounds / poundsPerKilogram
    }

    public static func pounds(fromKilograms kilograms: Double) -> Double {
        kilograms * poundsPerKilogram
    }

    public static func dailyGoalML(weightKG: Double, gender: HydrationProfileGender) -> Int {
        let safeWeight = HydrationValidation.validatedProfileWeightKG(weightKG)
        let multiplier: Double
        switch gender {
        case .female:
            multiplier = 31
        case .male:
            multiplier = 35
        case .nonBinary, .preferNotToSay:
            multiplier = 33
        }

        let rawGoal = safeWeight * multiplier
        let roundedGoal = Int((rawGoal / 50).rounded() * 50)
        return HydrationValidation.validatedGoal(roundedGoal)
    }
}
