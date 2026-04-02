import Foundation

struct PeakHourDetector {
    static func isPeakHour(at date: Date = Date()) -> Bool {
        guard let pacific = TimeZone(identifier: "America/Los_Angeles") else {
            return false
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let weekday = calendar.component(.weekday, from: date)
        let isWeekday = weekday >= 2 && weekday <= 6

        guard isWeekday else { return false }

        let hour = calendar.component(.hour, from: date)
        return hour >= 5 && hour < 11
    }

    static func peakEndTime(at date: Date = Date()) -> Date? {
        guard isPeakHour(at: date) else { return nil }

        guard let pacific = TimeZone(identifier: "America/Los_Angeles") else {
            return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = 11
        components.minute = 0
        components.second = 0

        return calendar.date(from: components)
    }
}
