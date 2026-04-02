import Foundation

enum TimeFormatting {
    static func shortDuration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval) / 60
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        if hours > 24 {
            let days = hours / 24
            let remainingHours = hours % 24
            return "\(days)d \(remainingHours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    static func minutesDuration(_ minutes: Double) -> String {
        if minutes > 120 {
            return "\(Int(minutes / 60))h \(Int(minutes.truncatingRemainder(dividingBy: 60)))m"
        } else {
            return "~\(Int(minutes)) min"
        }
    }
}
