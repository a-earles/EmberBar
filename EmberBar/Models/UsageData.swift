import Foundation

struct UsageResponse: Codable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let sevenDayOpus: UsageWindow?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case extraUsage = "extra_usage"
    }
}

struct UsageWindow: Codable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    var timeUntilReset: TimeInterval? {
        guard let reset = resetDate else { return nil }
        let interval = reset.timeIntervalSinceNow
        return interval > 0 ? interval : nil
    }

    var utilizationFraction: Double {
        utilization / 100.0
    }
}

struct ExtraUsage: Codable {
    let isEnabled: Bool?
    let usedCredits: Double?
    let monthlyLimit: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
    }

    var usedDollars: Double? {
        guard let cents = usedCredits else { return nil }
        return cents / 100.0
    }

    var limitDollars: Double? {
        guard let cents = monthlyLimit else { return nil }
        return cents / 100.0
    }
}

struct Organization: Codable {
    let id: Int?
    let uuid: String
    let name: String?
}

struct UsageSnapshot {
    let timestamp: Date
    let sessionUtilization: Double
    let weeklyUtilization: Double?
    let sessionResetDate: Date?
    let weeklyResetDate: Date?
    let response: UsageResponse
}
