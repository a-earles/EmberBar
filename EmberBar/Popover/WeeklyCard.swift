import SwiftUI

struct WeeklyCard: View {
    let utilization: Double
    let resetTime: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Weekly")
                    .font(EmberTheme.sectionLabel)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(EmberTheme.statusColor(for: utilization))
            }

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(EmberTheme.statusColor(for: utilization))
                        .frame(width: geo.size.width * min(1, max(0.02, utilization / 100)), height: 8)
                        .shadow(color: EmberTheme.statusColor(for: utilization).opacity(0.5), radius: 4, y: 0)
                }
            }
            .frame(height: 8)

            if let resetTime {
                Label(TimeFormatting.shortDuration(resetTime), systemImage: "clock")
                    .font(EmberTheme.captionText)
                    .foregroundColor(.secondary)
            }
        }
        .cardStyle()
    }
}
