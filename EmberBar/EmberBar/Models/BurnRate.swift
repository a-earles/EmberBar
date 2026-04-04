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

    // Minimum observation window before reporting a rate.
    // Prevents a single prompt spike from producing a wildly inflated burn rate.
    private static let minimumWindowMinutes = 5.0

    static func compute(from samples: [UsageSample], currentUtilization: Double) -> BurnRateData {
        guard samples.count >= 3 else { return .calculating }

        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard let oldest = sorted.first, let newest = sorted.last else { return .calculating }

        let timeDelta = newest.timestamp.timeIntervalSince(oldest.timestamp) / 60.0
        guard timeDelta >= minimumWindowMinutes else { return .calculating }

        // Linear regression over all samples gives a stable slope even when
        // individual prompts cause bursty jumps (old first/last delta was too volatile).
        let ratePerMinute = max(0, linearRegressionSlope(samples: sorted))

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

    // Returns the best-fit slope (% per minute) over all samples via OLS linear regression.
    // Far more stable than (newest - oldest) / time because individual prompt spikes
    // are smoothed by the surrounding plateau readings.
    private static func linearRegressionSlope(samples: [UsageSample]) -> Double {
        let n = Double(samples.count)
        let t0 = samples[0].timestamp
        let xs = samples.map { $0.timestamp.timeIntervalSince(t0) / 60.0 }
        let ys = samples.map { $0.utilization }

        let sumX = xs.reduce(0, +)
        let sumY = ys.reduce(0, +)
        let sumXY = zip(xs, ys).map { $0 * $1 }.reduce(0, +)
        let sumXX = xs.map { $0 * $0 }.reduce(0, +)

        let denom = n * sumXX - sumX * sumX
        guard abs(denom) > 1e-10 else { return 0 }
        return (n * sumXY - sumX * sumY) / denom
    }
}

struct UsageSample {
    let timestamp: Date
    let utilization: Double
}
