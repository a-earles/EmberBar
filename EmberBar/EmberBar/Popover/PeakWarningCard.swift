import SwiftUI

struct PeakWarningCard: View {
    let peakEndTime: Date?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\u{26A1}")
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 4) {
                Text("Peak Hours Active")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)

                if let endTime = peakEndTime {
                    let remaining = endTime.timeIntervalSinceNow
                    if remaining > 0 {
                        Text("Usage may deplete 2x faster until \(localEndTimeString(endTime))")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Usage may deplete 2x faster during peak hours (5am–11am PT)")
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
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

    /// Shows the peak end time in the user's local timezone
    private func localEndTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        let localTime = formatter.string(from: date)

        // Add timezone abbreviation so users know it's localized
        let tzAbbr = TimeZone.current.abbreviation() ?? ""
        return "\(localTime) \(tzAbbr)"
    }
}
