import Foundation
import ServiceManagement

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                #if DEBUG
                print("[EmberBar] Launch at login: \(error.localizedDescription)")
                #endif
            }
        }
    }

    @Published var refreshIntervalSeconds: Double {
        didSet { UserDefaults.standard.set(refreshIntervalSeconds, forKey: "refreshInterval") }
    }

    @Published var notifyAt75: Bool {
        didSet { UserDefaults.standard.set(notifyAt75, forKey: "notifyAt75") }
    }

    @Published var notifyAt90: Bool {
        didSet { UserDefaults.standard.set(notifyAt90, forKey: "notifyAt90") }
    }

    @Published var notifyBurnRate: Bool {
        didSet { UserDefaults.standard.set(notifyBurnRate, forKey: "notifyBurnRate") }
    }

    @Published var notifyPeakHours: Bool {
        didSet { UserDefaults.standard.set(notifyPeakHours, forKey: "notifyPeakHours") }
    }

    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "hasCompletedOnboarding") }
    }

    @Published var cachedOrgId: String? {
        didSet { UserDefaults.standard.set(cachedOrgId, forKey: "cachedOrgId") }
    }

    @Published var hasPromptedAccessibility: Bool {
        didSet { UserDefaults.standard.set(hasPromptedAccessibility, forKey: "hasPromptedAccessibility") }
    }

    private init() {
        let defaults = UserDefaults.standard
        // Read actual system state so the toggle reflects reality
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.refreshIntervalSeconds = defaults.object(forKey: "refreshInterval") as? Double ?? 60.0
        self.notifyAt75 = defaults.object(forKey: "notifyAt75") as? Bool ?? true
        self.notifyAt90 = defaults.object(forKey: "notifyAt90") as? Bool ?? true
        self.notifyBurnRate = defaults.object(forKey: "notifyBurnRate") as? Bool ?? true
        self.notifyPeakHours = defaults.object(forKey: "notifyPeakHours") as? Bool ?? true
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        self.cachedOrgId = defaults.string(forKey: "cachedOrgId")
        self.hasPromptedAccessibility = defaults.bool(forKey: "hasPromptedAccessibility")
    }
}
