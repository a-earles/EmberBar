import Foundation

enum BurnRateLevel: String {
    case idle = "— Idle"
    case light = "▼ Light"
    case moderate = "● Moderate"
    case fast = "▲ Fast"

    var color: String {
        switch self {
        case .idle: return "gray"
        case .light: return "green"
        case .moderate: return "amber"
        case .fast: return "red"
        }
    }
}

struct BurnRateData {
    let percentPerMinute: Double
    let minutesUntilLimit: Double?
    let estimatedMessagesRemaining: ClosedRange<Int>?
    let level: BurnRateLevel

    static let calculating = BurnRateData(
        percentPerMinute: 0,
        minutesUntilLimit: nil,
        estimatedMessagesRemaining: nil,
        level: .idle
    )

    static func compute(from samples: [UsageSample], currentUtilization: Double) -> BurnRateData {
        guard samples.count >= 3 else { return .calculating }

        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard let oldest = sorted.first, let newest = sorted.last else { return .calculating }

        let timeDelta = newest.timestamp.timeIntervalSince(oldest.timestamp) / 60.0
        guard timeDelta > 0 else { return .calculating }

        let utilizationDelta = newest.utilization - oldest.utilization
        let ratePerMinute = max(0, utilizationDelta / timeDelta)

        let level: BurnRateLevel
        switch ratePerMinute {
        case 0: level = .idle
        case ..<0.5: level = .light
        case ..<2.0: level = .moderate
        default: level = .fast
        }

        let remaining = 100.0 - currentUtilization
        let minutesUntilLimit: Double? = ratePerMinute > 0 ? remaining / ratePerMinute : nil

        let increases = zip(sorted, sorted.dropFirst()).filter { $1.utilization > $0.utilization }
        let estimatedMessages: ClosedRange<Int>?
        if !increases.isEmpty, ratePerMinute > 0 {
            let avgIncreasePerSample = increases.map { $1.utilization - $0.utilization }
                .reduce(0, +) / Double(increases.count)
            let costPerMessage = max(avgIncreasePerSample, 1.0)
            let lowEstimate = Int(remaining / (costPerMessage * 1.5))
            let highEstimate = Int(remaining / (costPerMessage * 0.7))
            estimatedMessages = max(0, lowEstimate)...max(1, highEstimate)
        } else if ratePerMinute == 0 && currentUtilization < 100 {
            let lowEstimate = Int(remaining / 3.0)
            let highEstimate = Int(remaining / 1.5)
            estimatedMessages = max(0, lowEstimate)...max(1, highEstimate)
        } else {
            estimatedMessages = nil
        }

        return BurnRateData(
            percentPerMinute: ratePerMinute,
            minutesUntilLimit: minutesUntilLimit,
            estimatedMessagesRemaining: estimatedMessages,
            level: level
        )
    }
}

struct UsageSample {
    let timestamp: Date
    let utilization: Double
}
