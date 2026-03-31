import SwiftUI

struct BurnRateCard: View {
    let burnRate: BurnRateData

    private var levelColor: Color {
        switch burnRate.level {
        case .idle: return .gray
        case .light: return .green
        case .moderate: return .orange
        case .fast: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BURN RATE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Spacer()
                Text(burnRate.level.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(levelColor)
            }

            if let minutes = burnRate.minutesUntilLimit {
                HStack(spacing: 4) {
                    Text("At this pace, you'll hit your limit in")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(TimeFormatting.minutesDuration(minutes))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
            } else if burnRate.level == .idle {
                Text("No recent usage detected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Calculating...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}
