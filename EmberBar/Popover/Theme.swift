import SwiftUI

enum EmberTheme {
    // Brand colors
    static let ember = Color(red: 1.0, green: 0.42, blue: 0.21)       // #FF6B35
    static let emberLight = Color(red: 1.0, green: 0.70, blue: 0.27)  // #FFB347
    static let emberDark = Color(red: 0.85, green: 0.25, blue: 0.10)  // #D94019

    // Status colors
    static let safe = Color(red: 0.30, green: 0.85, blue: 0.45)       // green
    static let caution = Color(red: 0.95, green: 0.75, blue: 0.15)    // yellow
    static let warning = Color(red: 1.0, green: 0.60, blue: 0.10)     // orange
    static let danger = Color(red: 0.95, green: 0.25, blue: 0.25)     // red

    // Card styling
    static let cardBackground = Color(.controlBackgroundColor).opacity(0.4)
    static let cardBorder = Color.white.opacity(0.06)
    static let cardCornerRadius: CGFloat = 12
    static let cardPadding: CGFloat = 14

    // Typography
    static let sectionLabel = Font.system(size: 10, weight: .semibold)
    static let valueText = Font.system(size: 13, weight: .bold, design: .rounded)
    static let bodyText = Font.system(size: 12)
    static let captionText = Font.system(size: 11)
    static let tinyText = Font.system(size: 10)

    static func statusColor(for utilization: Double) -> Color {
        switch utilization {
        case ..<35: return safe
        case ..<65: return caution
        case ..<85: return warning
        default: return danger
        }
    }

    static func statusGradient(for utilization: Double) -> [Color] {
        switch utilization {
        case ..<35: return [safe]
        case ..<65: return [safe, caution]
        case ..<85: return [safe, caution, warning]
        default: return [safe, warning, danger]
        }
    }
}

// Reusable card modifier
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(EmberTheme.cardPadding)
            .background(EmberTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: EmberTheme.cardCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: EmberTheme.cardCornerRadius, style: .continuous)
                    .stroke(EmberTheme.cardBorder, lineWidth: 0.5)
            )
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }
}
