import SwiftUI

/// EmberBar flame logo — matches the app icon bezier curves exactly.
/// Used in the popover header and onboarding screens.
struct EmberLogo: View {
    var size: CGFloat = 24

    var body: some View {
        Canvas { context, canvasSize in
            let s = canvasSize.width // assume square

            // Outer flame — same bezier curves as the Playwright-generated app icon
            var flame = Path()
            flame.move(to: CGPoint(x: s * 0.50, y: s * 0.12))
            flame.addCurve(
                to: CGPoint(x: s * 0.68, y: s * 0.42),
                control1: CGPoint(x: s * 0.52, y: s * 0.22),
                control2: CGPoint(x: s * 0.62, y: s * 0.30)
            )
            flame.addCurve(
                to: CGPoint(x: s * 0.72, y: s * 0.74),
                control1: CGPoint(x: s * 0.75, y: s * 0.55),
                control2: CGPoint(x: s * 0.76, y: s * 0.65)
            )
            flame.addCurve(
                to: CGPoint(x: s * 0.50, y: s * 0.88),
                control1: CGPoint(x: s * 0.68, y: s * 0.83),
                control2: CGPoint(x: s * 0.58, y: s * 0.88)
            )
            flame.addCurve(
                to: CGPoint(x: s * 0.28, y: s * 0.74),
                control1: CGPoint(x: s * 0.42, y: s * 0.88),
                control2: CGPoint(x: s * 0.32, y: s * 0.83)
            )
            flame.addCurve(
                to: CGPoint(x: s * 0.32, y: s * 0.42),
                control1: CGPoint(x: s * 0.24, y: s * 0.65),
                control2: CGPoint(x: s * 0.25, y: s * 0.55)
            )
            flame.addCurve(
                to: CGPoint(x: s * 0.50, y: s * 0.12),
                control1: CGPoint(x: s * 0.38, y: s * 0.30),
                control2: CGPoint(x: s * 0.48, y: s * 0.22)
            )
            flame.closeSubpath()

            // Outer gradient: golden tip → orange → deep ember
            let outerGradient = Gradient(colors: [
                Color(red: 1.0, green: 0.84, blue: 0.31),  // #FFD54F
                Color(red: 1.0, green: 0.54, blue: 0.40),  // #FF8A65
                Color(red: 0.90, green: 0.29, blue: 0.10),  // #E64A19
                Color(red: 0.75, green: 0.21, blue: 0.05),  // #BF360C
            ])
            context.fill(flame, with: .linearGradient(
                outerGradient,
                startPoint: CGPoint(x: s * 0.5, y: s * 0.12),
                endPoint: CGPoint(x: s * 0.5, y: s * 0.88)
            ))

            // Inner core flame — same curves as app icon
            var core = Path()
            core.move(to: CGPoint(x: s * 0.50, y: s * 0.28))
            core.addCurve(
                to: CGPoint(x: s * 0.61, y: s * 0.50),
                control1: CGPoint(x: s * 0.51, y: s * 0.35),
                control2: CGPoint(x: s * 0.58, y: s * 0.40)
            )
            core.addCurve(
                to: CGPoint(x: s * 0.58, y: s * 0.72),
                control1: CGPoint(x: s * 0.64, y: s * 0.58),
                control2: CGPoint(x: s * 0.62, y: s * 0.66)
            )
            core.addCurve(
                to: CGPoint(x: s * 0.50, y: s * 0.78),
                control1: CGPoint(x: s * 0.55, y: s * 0.76),
                control2: CGPoint(x: s * 0.52, y: s * 0.78)
            )
            core.addCurve(
                to: CGPoint(x: s * 0.42, y: s * 0.72),
                control1: CGPoint(x: s * 0.48, y: s * 0.78),
                control2: CGPoint(x: s * 0.45, y: s * 0.76)
            )
            core.addCurve(
                to: CGPoint(x: s * 0.39, y: s * 0.50),
                control1: CGPoint(x: s * 0.38, y: s * 0.66),
                control2: CGPoint(x: s * 0.36, y: s * 0.58)
            )
            core.addCurve(
                to: CGPoint(x: s * 0.50, y: s * 0.28),
                control1: CGPoint(x: s * 0.42, y: s * 0.40),
                control2: CGPoint(x: s * 0.49, y: s * 0.35)
            )
            core.closeSubpath()

            // Core gradient: bright white-yellow → golden
            let coreGradient = Gradient(colors: [
                Color(red: 1.0, green: 0.98, blue: 0.77),  // #FFF9C4
                Color(red: 1.0, green: 0.80, blue: 0.50),  // #FFCC80
                Color(red: 1.0, green: 0.60, blue: 0.00),  // #FF9800
            ])
            context.fill(core, with: .linearGradient(
                coreGradient,
                startPoint: CGPoint(x: s * 0.5, y: s * 0.28),
                endPoint: CGPoint(x: s * 0.5, y: s * 0.78)
            ))
        }
        .frame(width: size, height: size)
    }
}
