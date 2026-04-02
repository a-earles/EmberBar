import SwiftUI

struct BurnRateCard: View {
    let burnRate: BurnRateData

    private var levelColor: Color {
        switch burnRate.level {
        case .idle: return .secondary
        case .light: return EmberTheme.safe
        case .moderate: return EmberTheme.warning
        case .fast: return EmberTheme.danger
        }
    }

    private var levelIcon: String {
        switch burnRate.level {
        case .idle: return "minus"
        case .light: return "chevron.down"
        case .moderate: return "circle.fill"
        case .fast: return "chevron.up"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Burn Rate")
                    .font(EmberTheme.sectionLabel)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.8)
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: levelIcon)
                        .font(.system(size: 9, weight: .bold))
                    Text(burnRate.level == .idle ? "Idle" : burnRate.level == .light ? "Light" : burnRate.level == .moderate ? "Moderate" : "Fast")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
                .foregroundColor(levelColor)
            }

            if let minutes = burnRate.minutesUntilLimit {
                HStack(spacing: 0) {
                    Text("Limit in ")
                        .font(EmberTheme.bodyText)
                        .foregroundColor(.secondary)
                    Text(TimeFormatting.minutesDuration(minutes))
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
            } else if burnRate.level == .idle {
                Text("No recent activity")
                    .font(EmberTheme.bodyText)
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                Text("Calculating...")
                    .font(EmberTheme.bodyText)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .cardStyle()
    }
}
