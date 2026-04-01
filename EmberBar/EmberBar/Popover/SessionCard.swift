import SwiftUI

struct SessionCard: View {
    let utilization: Double
    let resetTime: TimeInterval?
    let messagesRemaining: ClosedRange<Int>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Session")
                    .font(EmberTheme.sectionLabel)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(EmberTheme.statusColor(for: utilization))
            }

            // Progress bar with glow
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 8)

                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: EmberTheme.statusGradient(for: utilization),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(1, max(0.02, utilization / 100)), height: 8)
                        .shadow(color: EmberTheme.statusColor(for: utilization).opacity(0.5), radius: 4, y: 0)
                }
            }
            .frame(height: 8)

            HStack {
                if let resetTime {
                    Label(TimeFormatting.shortDuration(resetTime), systemImage: "clock")
                        .font(EmberTheme.captionText)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let range = messagesRemaining {
                    Text("~\(range.lowerBound)–\(range.upperBound) msgs left")
                        .font(EmberTheme.captionText)
                        .foregroundColor(.secondary)
                }
            }
        }
        .cardStyle()
    }
}
