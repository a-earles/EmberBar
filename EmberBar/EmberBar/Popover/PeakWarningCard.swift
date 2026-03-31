import SwiftUI

struct PeakWarningCard: View {
    let peakEndTime: Date?

    var body: some View {
        HStack(spacing: 10) {
            Text("\u{26A1}")
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Peak Hours Active")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)

                if let endTime = peakEndTime {
                    let remaining = endTime.timeIntervalSinceNow
                    if remaining > 0 {
                        Text("Usage may deplete 2x faster until \(endTimeString(endTime))")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                } else {
                    Text("Usage may deplete 2x faster")
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.7))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func endTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date) + " PT"
    }
}
