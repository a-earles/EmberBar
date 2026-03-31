import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var usageResponse: UsageResponse?
    @Published var burnRate: BurnRateData = .calculating
    @Published var isPeakHour: Bool = false
    @Published var peakEndTime: Date?
    @Published var lastUpdated: Date?
    @Published var error: APIError?
    @Published var isLoading: Bool = false
    @Published var cookieIsValid: Bool = false
    @Published var planName: String = ""

    var settings = AppSettings.shared
    let apiClient = ClaudeAPIClient()
    let burnRateCalculator = BurnRateCalculator()

    private var refreshTimer: Timer?

    var sessionUtilization: Double {
        usageResponse?.fiveHour?.utilization ?? 0
    }

    var weeklyUtilization: Double {
        usageResponse?.sevenDay?.utilization ?? 0
    }

    var sessionResetTime: TimeInterval? {
        usageResponse?.fiveHour?.timeUntilReset
    }

    var weeklyResetTime: TimeInterval? {
        usageResponse?.sevenDay?.timeUntilReset
    }

    var timeSinceLastUpdate: TimeInterval? {
        guard let last = lastUpdated else { return nil }
        return Date().timeIntervalSince(last)
    }

    var sessionStatusColor: Color {
        colorForUtilization(sessionUtilization)
    }

    var weeklyStatusColor: Color {
        colorForUtilization(weeklyUtilization)
    }

    private func colorForUtilization(_ util: Double) -> Color {
        switch util {
        case ..<40: return .green
        case ..<70: return .yellow
        case ..<85: return .orange
        default: return .red
        }
    }

    var menuBarText: String {
        guard cookieIsValid, usageResponse != nil else { return "--%" }
        return "\(Int(sessionUtilization))%"
    }

    func startPolling() {
        NotificationManager.shared.requestPermission()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: settings.refreshIntervalSeconds,
            repeats: true
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                await self.fetchUsage()
            }
        }
        Task { await fetchUsage() }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func fetchUsage() async {
        guard let cookie = KeychainManager.loadCookie(),
              let orgId = settings.cachedOrgId else {
            error = .noCookie
            cookieIsValid = false
            return
        }

        isLoading = true
        error = nil

        do {
            let response = try await apiClient.fetchUsage(cookie: cookie, orgId: orgId)
            usageResponse = response
            lastUpdated = Date()
            cookieIsValid = true

            if let session = response.fiveHour {
                burnRateCalculator.addSample(utilization: session.utilization)
                burnRate = burnRateCalculator.currentBurnRate(currentUtilization: session.utilization)
            }

            isPeakHour = PeakHourDetector.isPeakHour()
            peakEndTime = PeakHourDetector.peakEndTime()

            // Evaluate notifications
            NotificationManager.shared.evaluateAndNotify(
                sessionUtilization: sessionUtilization,
                sessionResetTime: sessionResetTime,
                burnRate: burnRate,
                isPeakHour: isPeakHour
            )

        } catch let apiError as APIError {
            error = apiError
            if case .invalidCookie = apiError {
                cookieIsValid = false
                NotificationManager.shared.notifyCookieExpired()
            }
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    func validateAndSaveCookie(_ cookie: String) async -> Result<String, APIError> {
        print("[EmberBar] Validating cookie (\(cookie.prefix(20))...)")
        do {
            let (orgId, orgName) = try await apiClient.validateCookie(cookie)
            print("[EmberBar] Cookie valid! org=\(orgName) id=\(orgId)")
            try KeychainManager.saveCookie(cookie)
            print("[EmberBar] Cookie saved to Keychain")
            settings.cachedOrgId = orgId
            cookieIsValid = true
            planName = orgName

            await fetchUsage()
            print("[EmberBar] Initial fetch complete")

            return .success(orgName)
        } catch let apiError as APIError {
            print("[EmberBar] Validation failed: \(apiError)")
            return .failure(apiError)
        } catch {
            return .failure(.networkError(error))
        }
    }

    func signOut() {
        stopPolling()
        try? KeychainManager.deleteCookie()
        settings.cachedOrgId = nil
        settings.hasCompletedOnboarding = false
        usageResponse = nil
        burnRate = .calculating
        burnRateCalculator.reset()
        cookieIsValid = false
        lastUpdated = nil
        error = nil
    }
}
