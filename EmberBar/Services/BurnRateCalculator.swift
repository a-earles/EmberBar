import Foundation

class BurnRateCalculator {
    private var samples: [UsageSample] = []
    private let maxSamples = 20

    func addSample(utilization: Double) {
        let sample = UsageSample(timestamp: Date(), utilization: utilization)

        if let last = samples.last, last.utilization - utilization > 20 {
            samples.removeAll()
        }

        samples.append(sample)

        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    func currentBurnRate(currentUtilization: Double) -> BurnRateData {
        BurnRateData.compute(from: samples, currentUtilization: currentUtilization)
    }

    func reset() {
        samples.removeAll()
    }
}
