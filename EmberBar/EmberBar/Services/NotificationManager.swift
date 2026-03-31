import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let settings = AppSettings.shared
    private var isAvailable = false

    private var sentThisSession: Set<String> = []
    private var lastPeakHourNotified: Bool = false

    private override init() {
        super.init()
        // UNUserNotificationCenter crashes without a bundle identifier (dev builds via SPM)
        if Bundle.main.bundleIdentifier != nil {
            UNUserNotificationCenter.current().delegate = self
            isAvailable = true
        } else {
            print("[EmberBar] Notifications unavailable — no bundle identifier (dev build)")
        }
    }

    func requestPermission() {
        guard isAvailable else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            print("[EmberBar] Notification permission: granted=\(granted) error=\(String(describing: error))")
        }
    }

    func evaluateAndNotify(
        sessionUtilization: Double,
        sessionResetTime: TimeInterval?,
        burnRate: BurnRateData,
        isPeakHour: Bool
    ) {
        let resetString = sessionResetTime.map { TimeFormatting.shortDuration($0) } ?? "unknown"
        let msgsString = burnRate.estimatedMessagesRemaining.map { "~\($0.lowerBound)-\($0.upperBound) msgs left" } ?? ""

        if settings.notifyAt75 && sessionUtilization >= 75 && sessionUtilization < 90 {
            sendOnce(
                id: "session-75",
                title: "Session 75% Used",
                body: "\(msgsString) · resets in \(resetString)"
            )
        }

        if settings.notifyAt90 && sessionUtilization >= 90 {
            sendOnce(
                id: "session-90",
                title: "Session 90% Used",
                body: "\(msgsString) · resets in \(resetString)"
            )
        }

        if settings.notifyBurnRate,
           let minutes = burnRate.minutesUntilLimit,
           minutes <= 15, minutes > 0 {
            sendOnce(
                id: "burnrate-15min",
                title: "Approaching Session Limit",
                body: "At this pace, you'll hit your limit in ~\(Int(minutes)) min"
            )
        }

        if settings.notifyPeakHours && isPeakHour && !lastPeakHourNotified {
            sendOnce(
                id: "peak-hours",
                title: "Peak Hours Active",
                body: "Usage may deplete 2x faster until 11am PT"
            )
        }
        lastPeakHourNotified = isPeakHour
    }

    func notifyCookieExpired() {
        send(
            id: "cookie-expired",
            title: "Session Expired",
            body: "Click to update your EmberBar cookie"
        )
    }

    func resetSessionTracking() {
        sentThisSession.removeAll()
    }

    private func sendOnce(id: String, title: String, body: String) {
        guard !sentThisSession.contains(id) else { return }
        sentThisSession.insert(id)
        send(id: id, title: title, body: body)
    }

    private func send(id: String, title: String, body: String) {
        guard isAvailable else {
            print("[EmberBar] [Notification] \(title): \(body)")
            return
        }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: "emberbar-\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
