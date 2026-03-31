import AppKit
import SwiftUI

struct EmberGaugeRenderer {
    static func render(utilization: Double, isValid: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.0
            let lineWidth: CGFloat = 2.0

            context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(lineWidth)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()

            if isValid {
                let remaining = max(0, min(1, 1.0 - utilization / 100.0))
                let startAngle = CGFloat.pi / 2
                let endAngle = startAngle + CGFloat.pi * 2 * CGFloat(remaining)

                let ringColor = gaugeColor(for: utilization)
                context.setStrokeColor(ringColor.cgColor)
                context.setLineWidth(lineWidth)
                context.setLineCap(.round)
                context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.strokePath()

                drawEmber(context: context, center: center, utilization: utilization)
            } else {
                context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    private static func drawEmber(context: CGContext, center: CGPoint, utilization: Double) {
        let fuelRemaining = max(0, min(1, 1.0 - utilization / 100.0))

        if utilization >= 100 {
            context.setFillColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3))
            return
        }

        let glowRadius: CGFloat = 3.5 * CGFloat(0.4 + fuelRemaining * 0.6)
        let glowAlpha = 0.08 + fuelRemaining * 0.12
        context.setFillColor(NSColor(red: 1.0, green: 0.42, blue: 0.21, alpha: glowAlpha).cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - glowRadius, y: center.y - glowRadius,
            width: glowRadius * 2, height: glowRadius * 2
        ))

        let midRadius: CGFloat = 2.5 * CGFloat(0.5 + fuelRemaining * 0.5)
        let midAlpha = 0.15 + fuelRemaining * 0.2
        context.setFillColor(NSColor(red: 1.0, green: 0.55, blue: 0.26, alpha: midAlpha).cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - midRadius, y: center.y - midRadius,
            width: midRadius * 2, height: midRadius * 2
        ))

        let coreRadius: CGFloat = 1.5 * CGFloat(0.5 + fuelRemaining * 0.5)
        let coreAlpha = 0.3 + fuelRemaining * 0.6
        let coreColor: NSColor
        if fuelRemaining > 0.5 {
            coreColor = NSColor(red: 1.0, green: 0.88, blue: 0.7, alpha: coreAlpha)
        } else if fuelRemaining > 0.2 {
            coreColor = NSColor(red: 0.96, green: 0.58, blue: 0.24, alpha: coreAlpha)
        } else {
            coreColor = NSColor(red: 0.5, green: 0.27, blue: 0.17, alpha: coreAlpha)
        }
        context.setFillColor(coreColor.cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - coreRadius, y: center.y - coreRadius,
            width: coreRadius * 2, height: coreRadius * 2
        ))

        if fuelRemaining > 0.3 {
            let dotRadius: CGFloat = 0.7 * CGFloat(fuelRemaining)
            let dotAlpha = fuelRemaining * 0.9
            context.setFillColor(NSColor(red: 1.0, green: 0.95, blue: 0.88, alpha: dotAlpha).cgColor)
            context.fillEllipse(in: CGRect(
                x: center.x - dotRadius, y: center.y - dotRadius,
                width: dotRadius * 2, height: dotRadius * 2
            ))
        }
    }

    private static func gaugeColor(for utilization: Double) -> NSColor {
        switch utilization {
        case ..<40:
            return NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1.0)
        case ..<70:
            return NSColor(red: 0.64, green: 0.90, blue: 0.21, alpha: 1.0)
        case ..<85:
            return NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0)
        default:
            return NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0)
        }
    }
}
