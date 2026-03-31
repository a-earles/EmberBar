import SwiftUI

struct SessionCard: View {
    let utilization: Double
    let resetTime: TimeInterval?
    let messagesRemaining: ClosedRange<Int>?

    private var statusColor: Color {
        switch utilization {
        case ..<40: return .green
        case ..<70: return .yellow
        case ..<85: return .orange
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SESSION USAGE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Spacer()
                Text("\(Int(utilization))%")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundColor(statusColor)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: gradientColors,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * min(1, utilization / 100), height: 6)
                }
            }
            .frame(height: 6)

            HStack {
                if let resetTime {
                    Text("Resets in \(TimeFormatting.shortDuration(resetTime))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                } else {
                    Text("Reset time unknown")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let range = messagesRemaining {
                    Text("~\(range.lowerBound)-\(range.upperBound) msgs left")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }

    private var gradientColors: [Color] {
        if utilization < 40 {
            return [.green]
        } else if utilization < 70 {
            return [.green, .yellow]
        } else if utilization < 85 {
            return [.green, .yellow, .orange]
        } else {
            return [.green, .orange, .red]
        }
    }
}
