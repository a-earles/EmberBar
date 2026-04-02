import SwiftUI

struct PeakWarningCard: View {
    let peakEndTime: Date?

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16))
                .foregroundColor(EmberTheme.warning)

            VStack(alignment: .leading, spacing: 3) {
                Text("Peak Hours Active")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(EmberTheme.warning)

                if let endTime = peakEndTime, endTime.timeIntervalSinceNow > 0 {
                    Text("2x burn rate until \(localEndTimeString(endTime))")
                        .font(EmberTheme.captionText)
                        .foregroundColor(EmberTheme.warning.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("Usage may deplete faster (5am\u{2013}11am PT)")
                        .font(EmberTheme.captionText)
                        .foregroundColor(EmberTheme.warning.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(EmberTheme.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(EmberTheme.warning.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: EmberTheme.cardCornerRadius)
                .stroke(EmberTheme.warning.opacity(0.2), lineWidth: 0.5)
        )
        .cornerRadius(EmberTheme.cardCornerRadius)
    }

    private func localEndTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone.current
        let localTime = formatter.string(from: date)
        let tzAbbr = TimeZone.current.abbreviation() ?? ""
        return "\(localTime) \(tzAbbr)"
    }
}
