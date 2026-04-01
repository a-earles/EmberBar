import SwiftUI

struct EmberLogo: View {
    var size: CGFloat = 24

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // Flame shape — teardrop curving to a point
            var flame = Path()
            flame.move(to: CGPoint(x: w * 0.5, y: 0))
            flame.addCurve(
                to: CGPoint(x: w * 0.85, y: h * 0.55),
                control1: CGPoint(x: w * 0.52, y: h * 0.15),
                control2: CGPoint(x: w * 0.95, y: h * 0.35)
            )
            flame.addCurve(
                to: CGPoint(x: w * 0.5, y: h),
                control1: CGPoint(x: w * 0.8, y: h * 0.75),
                control2: CGPoint(x: w * 0.65, y: h * 0.95)
            )
            flame.addCurve(
                to: CGPoint(x: w * 0.15, y: h * 0.55),
                control1: CGPoint(x: w * 0.35, y: h * 0.95),
                control2: CGPoint(x: w * 0.2, y: h * 0.75)
            )
            flame.addCurve(
                to: CGPoint(x: w * 0.5, y: 0),
                control1: CGPoint(x: w * 0.05, y: h * 0.35),
                control2: CGPoint(x: w * 0.48, y: h * 0.15)
            )
            flame.closeSubpath()

            // Outer flame gradient
            let gradient = Gradient(colors: [
                Color(red: 1.0, green: 0.70, blue: 0.27),  // bright amber top
                Color(red: 1.0, green: 0.42, blue: 0.21),  // warm orange mid
                Color(red: 0.85, green: 0.25, blue: 0.10),  // deep ember base
            ])
            context.fill(flame, with: .linearGradient(
                gradient,
                startPoint: CGPoint(x: w * 0.5, y: 0),
                endPoint: CGPoint(x: w * 0.5, y: h)
            ))

            // Inner bright core — smaller flame offset upward
            var core = Path()
            let coreScale: CGFloat = 0.45
            let coreOffsetY: CGFloat = h * 0.2
            core.move(to: CGPoint(x: w * 0.5, y: coreOffsetY))
            core.addCurve(
                to: CGPoint(x: w * (0.5 + coreScale * 0.3), y: coreOffsetY + h * coreScale * 0.6),
                control1: CGPoint(x: w * 0.51, y: coreOffsetY + h * coreScale * 0.2),
                control2: CGPoint(x: w * (0.5 + coreScale * 0.4), y: coreOffsetY + h * coreScale * 0.4)
            )
            core.addCurve(
                to: CGPoint(x: w * 0.5, y: coreOffsetY + h * coreScale),
                control1: CGPoint(x: w * (0.5 + coreScale * 0.2), y: coreOffsetY + h * coreScale * 0.8),
                control2: CGPoint(x: w * 0.55, y: coreOffsetY + h * coreScale * 0.95)
            )
            core.addCurve(
                to: CGPoint(x: w * (0.5 - coreScale * 0.3), y: coreOffsetY + h * coreScale * 0.6),
                control1: CGPoint(x: w * 0.45, y: coreOffsetY + h * coreScale * 0.95),
                control2: CGPoint(x: w * (0.5 - coreScale * 0.2), y: coreOffsetY + h * coreScale * 0.8)
            )
            core.addCurve(
                to: CGPoint(x: w * 0.5, y: coreOffsetY),
                control1: CGPoint(x: w * (0.5 - coreScale * 0.4), y: coreOffsetY + h * coreScale * 0.4),
                control2: CGPoint(x: w * 0.49, y: coreOffsetY + h * coreScale * 0.2)
            )
            core.closeSubpath()

            let coreGradient = Gradient(colors: [
                Color(red: 1.0, green: 0.95, blue: 0.7),   // bright white-yellow
                Color(red: 1.0, green: 0.80, blue: 0.35),   // golden
            ])
            context.fill(core, with: .linearGradient(
                coreGradient,
                startPoint: CGPoint(x: w * 0.5, y: coreOffsetY),
                endPoint: CGPoint(x: w * 0.5, y: coreOffsetY + h * coreScale)
            ))
        }
        .frame(width: size, height: size)
    }
}
