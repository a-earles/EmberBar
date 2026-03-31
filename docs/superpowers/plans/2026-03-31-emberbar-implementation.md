# EmberBar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS menu bar app that tracks Claude AI usage with an ember gauge icon, burn rate predictions, peak-hour 2x awareness, and smart contextual notifications.

**Architecture:** SwiftUI menu bar app using NSStatusItem with custom-drawn ember gauge icon. NSPopover displays Dashboard Cards layout. Services layer handles API polling, Keychain storage, burn rate math, and notification dispatch. Onboarding wizard in a standalone NSWindow.

**Tech Stack:** Swift 5.9+, SwiftUI, AppKit, Security (Keychain), UserNotifications, ServiceManagement, URLSession. No external dependencies.

**Spec:** `docs/superpowers/specs/2026-03-31-emberbar-design.md`

---

### Task 1: Xcode Project Setup & App Shell

**Files:**
- Create: `EmberBar/EmberBar.xcodeproj` (via xcodebuild)
- Create: `EmberBar/EmberBar/App/EmberBarApp.swift`
- Create: `EmberBar/EmberBar/App/AppDelegate.swift`
- Create: `EmberBar/EmberBar/Info.plist`
- Create: `EmberBar/EmberBar/EmberBar.entitlements`

- [ ] **Step 1: Create Xcode project directory structure**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
mkdir -p EmberBar/EmberBar/App
mkdir -p EmberBar/EmberBar/MenuBar
mkdir -p EmberBar/EmberBar/Popover
mkdir -p EmberBar/EmberBar/Onboarding
mkdir -p EmberBar/EmberBar/Settings
mkdir -p EmberBar/EmberBar/Services
mkdir -p EmberBar/EmberBar/Models
mkdir -p EmberBar/EmberBar/Assets.xcassets/AppIcon.appiconset
```

- [ ] **Step 2: Create the Swift Package manifest**

We'll use Swift Package Manager instead of an .xcodeproj for simpler CLI-based builds. Create `EmberBar/Package.swift`:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "EmberBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "EmberBar",
            path: "EmberBar",
            resources: [
                .process("Assets.xcassets")
            ]
        )
    ]
)
```

- [ ] **Step 3: Create the app entry point**

Create `EmberBar/EmberBar/App/EmberBarApp.swift`:

```swift
import SwiftUI

@main
struct EmberBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
```

- [ ] **Step 4: Create the AppDelegate with status bar item**

Create `EmberBar/EmberBar/App/AppDelegate.swift`:

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "🔥 --%"
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 400)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: Text("EmberBar — Loading...")
                .frame(width: 320, height: 400)
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
```

- [ ] **Step 5: Create entitlements file**

Create `EmberBar/EmberBar/EmberBar.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.app-sandbox</key>
    <false/>
    <key>keychain-access-groups</key>
    <array>
        <string>$(AppIdentifierPrefix)com.emberbar.app</string>
    </array>
</dict>
</plist>
```

- [ ] **Step 6: Build and verify the app launches**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully. Running `.build/debug/EmberBar` shows a menu bar item with "🔥 --%" text.

- [ ] **Step 7: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/
git commit -m "feat: scaffold EmberBar project with menu bar shell"
```

---

### Task 2: Data Models

**Files:**
- Create: `EmberBar/EmberBar/Models/UsageData.swift`
- Create: `EmberBar/EmberBar/Models/BurnRate.swift`
- Create: `EmberBar/EmberBar/Models/AppSettings.swift`

- [ ] **Step 1: Create UsageData model**

Create `EmberBar/EmberBar/Models/UsageData.swift`:

```swift
import Foundation

struct UsageResponse: Codable {
    let fiveHour: UsageWindow?
    let sevenDay: UsageWindow?
    let sevenDaySonnet: UsageWindow?
    let sevenDayOpus: UsageWindow?
    let extraUsage: ExtraUsage?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDaySonnet = "seven_day_sonnet"
        case sevenDayOpus = "seven_day_opus"
        case extraUsage = "extra_usage"
    }
}

struct UsageWindow: Codable {
    let utilization: Double
    let resetsAt: String

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: resetsAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: resetsAt)
    }

    var timeUntilReset: TimeInterval? {
        guard let reset = resetDate else { return nil }
        let interval = reset.timeIntervalSinceNow
        return interval > 0 ? interval : nil
    }

    var utilizationFraction: Double {
        utilization / 100.0
    }
}

struct ExtraUsage: Codable {
    let isEnabled: Bool?
    let usedCredits: Double?
    let monthlyLimit: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
    }

    var usedDollars: Double? {
        guard let cents = usedCredits else { return nil }
        return cents / 100.0
    }

    var limitDollars: Double? {
        guard let cents = monthlyLimit else { return nil }
        return cents / 100.0
    }
}

struct Organization: Codable {
    let id: Int?
    let uuid: String
    let name: String?
}

struct UsageSnapshot {
    let timestamp: Date
    let sessionUtilization: Double
    let weeklyUtilization: Double?
    let sessionResetDate: Date?
    let weeklyResetDate: Date?
    let response: UsageResponse
}
```

- [ ] **Step 2: Create BurnRate model**

Create `EmberBar/EmberBar/Models/BurnRate.swift`:

```swift
import Foundation

enum BurnRateLevel: String {
    case idle = "— Idle"
    case light = "▼ Light"
    case moderate = "● Moderate"
    case fast = "▲ Fast"

    var color: String {
        switch self {
        case .idle: return "gray"
        case .light: return "green"
        case .moderate: return "amber"
        case .fast: return "red"
        }
    }
}

struct BurnRateData {
    let percentPerMinute: Double
    let minutesUntilLimit: Double?
    let estimatedMessagesRemaining: ClosedRange<Int>?
    let level: BurnRateLevel

    static let calculating = BurnRateData(
        percentPerMinute: 0,
        minutesUntilLimit: nil,
        estimatedMessagesRemaining: nil,
        level: .idle
    )

    static func compute(from samples: [UsageSample], currentUtilization: Double) -> BurnRateData {
        guard samples.count >= 3 else { return .calculating }

        let sorted = samples.sorted { $0.timestamp < $1.timestamp }
        guard let oldest = sorted.first, let newest = sorted.last else { return .calculating }

        let timeDelta = newest.timestamp.timeIntervalSince(oldest.timestamp) / 60.0 // minutes
        guard timeDelta > 0 else { return .calculating }

        let utilizationDelta = newest.utilization - oldest.utilization
        let ratePerMinute = max(0, utilizationDelta / timeDelta)

        let level: BurnRateLevel
        switch ratePerMinute {
        case 0: level = .idle
        case ..<0.5: level = .light
        case ..<2.0: level = .moderate
        default: level = .fast
        }

        let remaining = 100.0 - currentUtilization
        let minutesUntilLimit: Double? = ratePerMinute > 0 ? remaining / ratePerMinute : nil

        // Estimate messages remaining
        // Find samples where utilization increased to estimate cost per message
        let increases = zip(sorted, sorted.dropFirst()).filter { $1.utilization > $0.utilization }
        let estimatedMessages: ClosedRange<Int>?
        if !increases.isEmpty, ratePerMinute > 0 {
            let avgIncreasePerSample = increases.map { $1.utilization - $0.utilization }
                .reduce(0, +) / Double(increases.count)
            // Each increase is roughly one interaction cycle
            let costPerMessage = max(avgIncreasePerSample, 1.0)
            let lowEstimate = Int(remaining / (costPerMessage * 1.5))
            let highEstimate = Int(remaining / (costPerMessage * 0.7))
            estimatedMessages = max(0, lowEstimate)...max(1, highEstimate)
        } else if ratePerMinute == 0 && currentUtilization < 100 {
            // Fallback: assume 2-3% per message for Opus
            let lowEstimate = Int(remaining / 3.0)
            let highEstimate = Int(remaining / 1.5)
            estimatedMessages = max(0, lowEstimate)...max(1, highEstimate)
        } else {
            estimatedMessages = nil
        }

        return BurnRateData(
            percentPerMinute: ratePerMinute,
            minutesUntilLimit: minutesUntilLimit,
            estimatedMessagesRemaining: estimatedMessages,
            level: level
        )
    }
}

struct UsageSample {
    let timestamp: Date
    let utilization: Double
}
```

- [ ] **Step 3: Create AppSettings model**

Create `EmberBar/EmberBar/Models/AppSettings.swift`:

```swift
import Foundation

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var launchAtLogin: Bool {
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
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

    private init() {
        let defaults = UserDefaults.standard
        self.launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true
        self.refreshIntervalSeconds = defaults.object(forKey: "refreshInterval") as? Double ?? 60.0
        self.notifyAt75 = defaults.object(forKey: "notifyAt75") as? Bool ?? true
        self.notifyAt90 = defaults.object(forKey: "notifyAt90") as? Bool ?? true
        self.notifyBurnRate = defaults.object(forKey: "notifyBurnRate") as? Bool ?? true
        self.notifyPeakHours = defaults.object(forKey: "notifyPeakHours") as? Bool ?? true
        self.hasCompletedOnboarding = defaults.bool(forKey: "hasCompletedOnboarding")
        self.cachedOrgId = defaults.string(forKey: "cachedOrgId")
    }
}
```

- [ ] **Step 4: Build and verify models compile**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully.

- [ ] **Step 5: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Models/
git commit -m "feat: add data models for usage, burn rate, and settings"
```

---

### Task 3: Keychain Manager

**Files:**
- Create: `EmberBar/EmberBar/Services/KeychainManager.swift`

- [ ] **Step 1: Create KeychainManager**

Create `EmberBar/EmberBar/Services/KeychainManager.swift`:

```swift
import Foundation
import Security

enum KeychainError: Error {
    case saveFailed(OSStatus)
    case readFailed
    case deleteFailed(OSStatus)
}

struct KeychainManager {
    private static let service = "com.emberbar.session-cookie"
    private static let account = "claude-session"

    static func saveCookie(_ cookie: String) throws {
        let data = Data(cookie.utf8)

        // Delete existing first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.saveFailed(status)
        }
    }

    static func loadCookie() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    static func deleteCookie() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }

    static func hasCookie() -> Bool {
        loadCookie() != nil
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully.

- [ ] **Step 3: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Services/KeychainManager.swift
git commit -m "feat: add Keychain manager for secure cookie storage"
```

---

### Task 4: Claude API Client

**Files:**
- Create: `EmberBar/EmberBar/Services/ClaudeAPIClient.swift`

- [ ] **Step 1: Create the API client**

Create `EmberBar/EmberBar/Services/ClaudeAPIClient.swift`:

```swift
import Foundation

enum APIError: Error, LocalizedError {
    case noCookie
    case invalidCookie
    case networkError(Error)
    case invalidResponse(Int)
    case decodingError(Error)
    case noOrganization

    var errorDescription: String? {
        switch self {
        case .noCookie: return "No session cookie configured"
        case .invalidCookie: return "Session cookie is invalid or expired"
        case .networkError(let e): return "Network error: \(e.localizedDescription)"
        case .invalidResponse(let code): return "Server returned status \(code)"
        case .decodingError(let e): return "Failed to parse response: \(e.localizedDescription)"
        case .noOrganization: return "No organization found"
        }
    }
}

actor ClaudeAPIClient {
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        self.session = URLSession(configuration: config)
    }

    private func buildRequest(url: URL, cookie: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(cookie, forHTTPHeaderField: "Cookie")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("https://claude.ai", forHTTPHeaderField: "Referer")
        request.setValue("claude.ai", forHTTPHeaderField: "Origin")
        request.setValue("same-origin", forHTTPHeaderField: "Sec-Fetch-Site")
        request.setValue("cors", forHTTPHeaderField: "Sec-Fetch-Mode")
        request.setValue("empty", forHTTPHeaderField: "Sec-Fetch-Dest")
        return request
    }

    func fetchOrganizations(cookie: String) async throws -> [Organization] {
        guard let url = URL(string: "https://claude.ai/api/organizations") else {
            throw APIError.invalidCookie
        }

        let request = buildRequest(url: url, cookie: cookie)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(0)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.invalidCookie
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode([Organization].self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    func fetchUsage(cookie: String, orgId: String) async throws -> UsageResponse {
        guard let url = URL(string: "https://claude.ai/api/organizations/\(orgId)/usage") else {
            throw APIError.invalidResponse(0)
        }

        let request = buildRequest(url: url, cookie: cookie)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse(0)
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw APIError.invalidCookie
        }

        guard httpResponse.statusCode == 200 else {
            throw APIError.invalidResponse(httpResponse.statusCode)
        }

        do {
            return try JSONDecoder().decode(UsageResponse.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }

    /// Validates a cookie by attempting to fetch organizations.
    /// Returns the org UUID and plan name on success.
    func validateCookie(_ cookie: String) async throws -> (orgId: String, orgName: String) {
        let orgs = try await fetchOrganizations(cookie: cookie)
        guard let org = orgs.first else {
            throw APIError.noOrganization
        }
        return (org.uuid, org.name ?? "Personal")
    }
}
```

- [ ] **Step 2: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully.

- [ ] **Step 3: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Services/ClaudeAPIClient.swift
git commit -m "feat: add Claude API client for usage and org endpoints"
```

---

### Task 5: Burn Rate Calculator & Peak Hour Detector

**Files:**
- Create: `EmberBar/EmberBar/Services/BurnRateCalculator.swift`
- Create: `EmberBar/EmberBar/Services/PeakHourDetector.swift`

- [ ] **Step 1: Create BurnRateCalculator**

Create `EmberBar/EmberBar/Services/BurnRateCalculator.swift`:

```swift
import Foundation

class BurnRateCalculator {
    private var samples: [UsageSample] = []
    private let maxSamples = 20

    func addSample(utilization: Double) {
        let sample = UsageSample(timestamp: Date(), utilization: utilization)

        // Detect session reset: if utilization dropped significantly, clear history
        if let last = samples.last, last.utilization - utilization > 20 {
            samples.removeAll()
        }

        samples.append(sample)

        // Keep only the most recent samples
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
    }

    func currentBurnRate(currentUtilization: Double) -> BurnRateData {
        BurnRateData.compute(from: samples, currentUtilization: currentUtilization)
    }

    func reset() {
        samples.removeAll()
    }
}
```

- [ ] **Step 2: Create PeakHourDetector**

Create `EmberBar/EmberBar/Services/PeakHourDetector.swift`:

```swift
import Foundation

struct PeakHourDetector {
    /// Peak hours: 5:00 AM - 11:00 AM Pacific Time, Monday-Friday
    static func isPeakHour(at date: Date = Date()) -> Bool {
        guard let pacific = TimeZone(identifier: "America/Los_Angeles") else {
            return false
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = pacific

        let weekday = calendar.component(.weekday, from: date)
        // Sunday = 1, Saturday = 7
        let isWeekday = weekday >= 2 && weekday <= 6

        guard isWeekday else { return false }

        let hour = calendar.component(.hour, from: date)
        return hour >= 5 && hour < 11
    }

    /// Returns the end time of the current peak window, or nil if not in peak hours
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
```

- [ ] **Step 3: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully.

- [ ] **Step 4: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Services/BurnRateCalculator.swift EmberBar/EmberBar/Services/PeakHourDetector.swift
git commit -m "feat: add burn rate calculator and peak hour detector"
```

---

### Task 6: AppState (Central State Manager)

**Files:**
- Create: `EmberBar/EmberBar/App/AppState.swift`

- [ ] **Step 1: Create AppState**

Create `EmberBar/EmberBar/App/AppState.swift`:

```swift
import Foundation
import SwiftUI

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

    let settings = AppSettings.shared
    let apiClient = ClaudeAPIClient()
    let burnRateCalculator = BurnRateCalculator()

    private var refreshTimer: Timer?

    // MARK: - Computed Properties

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

    // MARK: - Usage Status Color

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

    // MARK: - Menu Bar Display

    var menuBarText: String {
        guard cookieIsValid, usageResponse != nil else { return "--%" }
        return "\(Int(sessionUtilization))%"
    }

    // MARK: - Actions

    func startPolling() {
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
        // Fetch immediately
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

            // Update burn rate
            if let session = response.fiveHour {
                burnRateCalculator.addSample(utilization: session.utilization)
                burnRate = burnRateCalculator.currentBurnRate(currentUtilization: session.utilization)
            }

            // Update peak hour status
            isPeakHour = PeakHourDetector.isPeakHour()
            peakEndTime = PeakHourDetector.peakEndTime()

        } catch let apiError as APIError {
            error = apiError
            if case .invalidCookie = apiError {
                cookieIsValid = false
            }
        } catch {
            self.error = .networkError(error)
        }

        isLoading = false
    }

    func validateAndSaveCookie(_ cookie: String) async -> Result<String, APIError> {
        do {
            let (orgId, orgName) = try await apiClient.validateCookie(cookie)
            try KeychainManager.saveCookie(cookie)
            settings.cachedOrgId = orgId
            cookieIsValid = true
            planName = orgName

            // Fetch initial usage
            await fetchUsage()

            return .success(orgName)
        } catch let apiError as APIError {
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
```

- [ ] **Step 2: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully.

- [ ] **Step 3: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/App/AppState.swift
git commit -m "feat: add central AppState with polling, burn rate, and cookie management"
```

---

### Task 7: Ember Gauge Menu Bar Icon

**Files:**
- Create: `EmberBar/EmberBar/MenuBar/EmberGaugeView.swift`
- Modify: `EmberBar/EmberBar/App/AppDelegate.swift`

- [ ] **Step 1: Create EmberGaugeView**

Create `EmberBar/EmberBar/MenuBar/EmberGaugeView.swift`:

```swift
import AppKit
import SwiftUI

struct EmberGaugeRenderer {
    /// Renders the ember gauge as an NSImage suitable for the status bar.
    /// Size: 18x18 points (standard menu bar icon size).
    static func render(utilization: Double, isValid: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            guard let context = NSGraphicsContext.current?.cgContext else { return false }

            let center = CGPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7.0
            let lineWidth: CGFloat = 2.0

            // Background ring
            context.setStrokeColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
            context.setLineWidth(lineWidth)
            context.addArc(center: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
            context.strokePath()

            if isValid {
                // Usage ring (depletes clockwise from top)
                let remaining = max(0, min(1, 1.0 - utilization / 100.0))
                let startAngle = CGFloat.pi / 2 // top
                let endAngle = startAngle + CGFloat.pi * 2 * CGFloat(remaining)

                let ringColor = gaugeColor(for: utilization)
                context.setStrokeColor(ringColor.cgColor)
                context.setLineWidth(lineWidth)
                context.setLineCap(.round)
                context.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
                context.strokePath()

                // Ember glow at center
                drawEmber(context: context, center: center, utilization: utilization)
            } else {
                // Gray dot when no connection
                context.setFillColor(NSColor.gray.withAlphaComponent(0.5).cgColor)
                context.fillEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
            }

            return true
        }

        image.isTemplate = false
        return image
    }

    private static func drawEmber(context: CGContext, center: CGPoint, utilization: Double) {
        // Ember brightness inversely proportional to usage (remaining fuel metaphor)
        let fuelRemaining = max(0, min(1, 1.0 - utilization / 100.0))

        if utilization >= 100 {
            // Ash state — tiny gray dot
            context.setFillColor(NSColor.gray.withAlphaComponent(0.3).cgColor)
            context.fillEllipse(in: CGRect(x: center.x - 1.5, y: center.y - 1.5, width: 3, height: 3))
            return
        }

        // Outer glow
        let glowRadius: CGFloat = 3.5 * CGFloat(0.4 + fuelRemaining * 0.6)
        let glowAlpha = 0.08 + fuelRemaining * 0.12
        context.setFillColor(NSColor(red: 1.0, green: 0.42, blue: 0.21, alpha: glowAlpha).cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - glowRadius, y: center.y - glowRadius,
            width: glowRadius * 2, height: glowRadius * 2
        ))

        // Mid glow
        let midRadius: CGFloat = 2.5 * CGFloat(0.5 + fuelRemaining * 0.5)
        let midAlpha = 0.15 + fuelRemaining * 0.2
        context.setFillColor(NSColor(red: 1.0, green: 0.55, blue: 0.26, alpha: midAlpha).cgColor)
        context.fillEllipse(in: CGRect(
            x: center.x - midRadius, y: center.y - midRadius,
            width: midRadius * 2, height: midRadius * 2
        ))

        // Core
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

        // Hot center point (only when bright)
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
            return NSColor(red: 0.29, green: 0.87, blue: 0.50, alpha: 1.0) // green
        case ..<70:
            return NSColor(red: 0.64, green: 0.90, blue: 0.21, alpha: 1.0) // yellow-green
        case ..<85:
            return NSColor(red: 0.96, green: 0.62, blue: 0.04, alpha: 1.0) // amber
        default:
            return NSColor(red: 0.94, green: 0.27, blue: 0.27, alpha: 1.0) // red
        }
    }
}
```

- [ ] **Step 2: Update AppDelegate to use ember gauge and wire up AppState**

Replace `EmberBar/EmberBar/App/AppDelegate.swift` with:

```swift
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let appState = AppState()
    private var stateObservation: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = EmberGaugeRenderer.render(utilization: 0, isValid: false)
            button.imagePosition = .imageLeading
            button.title = " --%"
            button.action = #selector(togglePopover)
            button.target = self

            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            ]
            button.attributedTitle = NSAttributedString(string: " --%", attributes: attributes)
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(appState)
        )

        // Observe state changes to update menu bar icon
        stateObservation = appState.$usageResponse.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateMenuBarIcon()
        }

        // Check if onboarding is needed
        if appState.settings.hasCompletedOnboarding && KeychainManager.hasCookie() {
            appState.cookieIsValid = true
            appState.startPolling()
        } else {
            showOnboarding()
        }

        // Register global keyboard shortcut (Cmd+Shift+E)
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 14 { // 14 = 'E'
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
    }

    private func updateMenuBarIcon() {
        guard let button = statusItem.button else { return }

        let utilization = appState.sessionUtilization
        let isValid = appState.cookieIsValid && appState.usageResponse != nil

        button.image = EmberGaugeRenderer.render(utilization: utilization, isValid: isValid)

        let text = " \(appState.menuBarText)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
        ]
        button.attributedTitle = NSAttributedString(string: text, attributes: attributes)
    }

    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func showOnboarding() {
        let onboardingWindow = OnboardingWindow(appState: appState, onComplete: { [weak self] in
            self?.appState.startPolling()
        })
        onboardingWindow.showWindow(nil)
        onboardingWindow.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
```

- [ ] **Step 3: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build 2>&1 | head -20
```

Expected: Will show errors about missing `PopoverView` and `OnboardingWindow` — that's expected. The EmberGaugeRenderer and updated AppDelegate code should be syntactically correct.

- [ ] **Step 4: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/MenuBar/ EmberBar/EmberBar/App/AppDelegate.swift
git commit -m "feat: add ember gauge menu bar icon with remaining-fuel metaphor"
```

---

### Task 8: Popover Dashboard Cards UI

**Files:**
- Create: `EmberBar/EmberBar/Popover/PopoverView.swift`
- Create: `EmberBar/EmberBar/Popover/SessionCard.swift`
- Create: `EmberBar/EmberBar/Popover/BurnRateCard.swift`
- Create: `EmberBar/EmberBar/Popover/WeeklyCard.swift`
- Create: `EmberBar/EmberBar/Popover/PeakWarningCard.swift`

- [ ] **Step 1: Create helper for formatting time intervals**

Create `EmberBar/EmberBar/Popover/TimeFormatting.swift`:

```swift
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
```

- [ ] **Step 2: Create SessionCard**

Create `EmberBar/EmberBar/Popover/SessionCard.swift`:

```swift
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

            // Progress bar
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
```

- [ ] **Step 3: Create BurnRateCard**

Create `EmberBar/EmberBar/Popover/BurnRateCard.swift`:

```swift
import SwiftUI

struct BurnRateCard: View {
    let burnRate: BurnRateData

    private var levelColor: Color {
        switch burnRate.level {
        case .idle: return .gray
        case .light: return .green
        case .moderate: return .orange
        case .fast: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BURN RATE")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .tracking(0.5)
                Spacer()
                Text(burnRate.level.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(levelColor)
            }

            if let minutes = burnRate.minutesUntilLimit {
                HStack(spacing: 4) {
                    Text("At this pace, you'll hit your limit in")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(TimeFormatting.minutesDuration(minutes))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)
                }
            } else if burnRate.level == .idle {
                Text("No recent usage detected")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            } else {
                Text("Calculating...")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}
```

- [ ] **Step 4: Create WeeklyCard**

Create `EmberBar/EmberBar/Popover/WeeklyCard.swift`:

```swift
import SwiftUI

struct WeeklyCard: View {
    let utilization: Double
    let resetTime: TimeInterval?

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
                Text("WEEKLY USAGE")
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
                        .fill(statusColor)
                        .frame(width: geo.size.width * min(1, utilization / 100), height: 6)
                }
            }
            .frame(height: 6)

            if let resetTime {
                Text("Resets in \(TimeFormatting.shortDuration(resetTime))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .background(Color(.controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
    }
}
```

- [ ] **Step 5: Create PeakWarningCard**

Create `EmberBar/EmberBar/Popover/PeakWarningCard.swift`:

```swift
import SwiftUI

struct PeakWarningCard: View {
    let peakEndTime: Date?

    var body: some View {
        HStack(spacing: 10) {
            Text("⚡")
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Peak Hours Active")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.orange)

                if let endTime = peakEndTime {
                    let remaining = endTime.timeIntervalSinceNow
                    if remaining > 0 {
                        Text("Usage may deplete 2x faster until \(endTimeString(endTime))")
                            .font(.system(size: 11))
                            .foregroundColor(.orange.opacity(0.7))
                    }
                } else {
                    Text("Usage may deplete 2x faster")
                        .font(.system(size: 11))
                        .foregroundColor(.orange.opacity(0.7))
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.orange.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private func endTimeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        formatter.timeZone = TimeZone(identifier: "America/Los_Angeles")
        return formatter.string(from: date) + " PT"
    }
}
```

- [ ] **Step 6: Create PopoverView**

Create `EmberBar/EmberBar/Popover/PopoverView.swift`:

```swift
import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("🔥")
                        .font(.system(size: 16))
                    Text("EmberBar")
                        .font(.system(size: 15, weight: .semibold))
                }
                Spacer()
                if !appState.planName.isEmpty {
                    Text(appState.planName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }
            .padding(.bottom, 4)

            if !appState.cookieIsValid {
                // Error state
                VStack(spacing: 12) {
                    Text("Not Connected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Set up your session cookie to start tracking.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Set Up Cookie") {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.showOnboarding()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxHeight: .infinity)
            } else if appState.usageResponse == nil && appState.isLoading {
                // Loading state
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading usage data...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                // Main content
                SessionCard(
                    utilization: appState.sessionUtilization,
                    resetTime: appState.sessionResetTime,
                    messagesRemaining: appState.burnRate.estimatedMessagesRemaining
                )

                BurnRateCard(burnRate: appState.burnRate)

                WeeklyCard(
                    utilization: appState.weeklyUtilization,
                    resetTime: appState.weeklyResetTime
                )

                if appState.isPeakHour {
                    PeakWarningCard(peakEndTime: appState.peakEndTime)
                }

                if let error = appState.error {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.system(size: 10))
                        Text(error.localizedDescription)
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                    .padding(.top, 2)
                }

                Spacer()

                // Footer
                HStack {
                    if let elapsed = appState.timeSinceLastUpdate {
                        Text("Updated \(TimeFormatting.shortDuration(elapsed)) ago")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    Spacer()
                    Button {
                        if let url = URL(string: "https://claude.ai") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Text("Open Claude")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in }

                    Button {
                        Task { await appState.fetchUsage() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(width: 320, minHeight: 200)
    }
}
```

- [ ] **Step 7: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build 2>&1 | head -20
```

Expected: Will still have errors about `OnboardingWindow` which we haven't created yet. All popover views should be syntactically correct.

- [ ] **Step 8: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Popover/
git commit -m "feat: add popover dashboard cards UI with session, burn rate, weekly, and peak hour cards"
```

---

### Task 9: Onboarding Wizard

**Files:**
- Create: `EmberBar/EmberBar/Onboarding/OnboardingWindow.swift`
- Create: `EmberBar/EmberBar/Onboarding/WelcomeStep.swift`
- Create: `EmberBar/EmberBar/Onboarding/InstructionsStep.swift`
- Create: `EmberBar/EmberBar/Onboarding/PasteValidateStep.swift`
- Create: `EmberBar/EmberBar/Onboarding/DoneStep.swift`

- [ ] **Step 1: Create OnboardingWindow**

Create `EmberBar/EmberBar/Onboarding/OnboardingWindow.swift`:

```swift
import AppKit
import SwiftUI

class OnboardingWindow: NSWindowController {
    convenience init(appState: AppState, onComplete: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "EmberBar Setup"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(
            rootView: OnboardingContainerView(appState: appState, onComplete: {
                onComplete()
                window.close()
            })
        )
        self.init(window: window)
    }
}

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case instructions
    case pasteValidate
    case done
}

struct OnboardingContainerView: View {
    @ObservedObject var appState: AppState
    let onComplete: () -> Void
    @State private var currentStep: OnboardingStep = .welcome

    var body: some View {
        VStack {
            // Progress indicator
            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.rawValue) { step in
                    Circle()
                        .fill(step.rawValue <= currentStep.rawValue ? Color.orange : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            Spacer()

            switch currentStep {
            case .welcome:
                WelcomeStep(onNext: { currentStep = .instructions })
            case .instructions:
                InstructionsStep(onNext: { currentStep = .pasteValidate })
            case .pasteValidate:
                PasteValidateStep(appState: appState, onNext: { currentStep = .done })
            case .done:
                DoneStep(appState: appState, onComplete: onComplete)
            }

            Spacer()
        }
        .frame(width: 500, height: 420)
    }
}
```

- [ ] **Step 2: Create WelcomeStep**

Create `EmberBar/EmberBar/Onboarding/WelcomeStep.swift`:

```swift
import SwiftUI

struct WelcomeStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("🔥")
                .font(.system(size: 64))

            Text("Welcome to EmberBar")
                .font(.system(size: 24, weight: .bold))

            Text("Never hit a Claude limit by surprise.")
                .font(.system(size: 15))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "flame.fill", text: "Real-time session & weekly usage tracking")
                FeatureRow(icon: "chart.line.uptrend.xyaxis", text: "Burn rate predictions")
                FeatureRow(icon: "bolt.fill", text: "Peak hour 2x detection")
                FeatureRow(icon: "bell.fill", text: "Smart contextual notifications")
            }
            .padding(.top, 8)

            Button(action: onNext) {
                Text("Get Started")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 200, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 12)
        }
        .padding(32)
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
    }
}
```

- [ ] **Step 3: Create InstructionsStep**

Create `EmberBar/EmberBar/Onboarding/InstructionsStep.swift`:

```swift
import SwiftUI

struct InstructionsStep: View {
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Get Your Session Cookie")
                .font(.system(size: 20, weight: .bold))

            Text("EmberBar needs your Claude session cookie to fetch usage data. Follow these steps:")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            VStack(alignment: .leading, spacing: 12) {
                InstructionRow(number: 1, title: "Open", detail: "claude.ai/settings/usage", isLink: true)
                InstructionRow(number: 2, title: "Open Developer Tools", detail: "Press  Cmd + Option + I", isLink: false)
                InstructionRow(number: 3, title: "Go to the", detail: "Network  tab", isLink: false)
                InstructionRow(number: 4, title: "Refresh the page", detail: "Press  Cmd + R", isLink: false)
                InstructionRow(number: 5, title: "Click the request named", detail: "\"usage\"", isLink: false)
                InstructionRow(number: 6, title: "Copy the full", detail: "\"Cookie\"  value from Request Headers", isLink: false)
            }
            .padding(20)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(10)

            Button(action: onNext) {
                Text("I've Copied the Cookie")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 200, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 8)
        }
        .padding(24)
    }
}

struct InstructionRow: View {
    let number: Int
    let title: String
    let detail: String
    let isLink: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.orange)
                .cornerRadius(12)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))
                if isLink {
                    Text(detail)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.blue)
                        .onTapGesture {
                            if let url = URL(string: "https://\(detail)") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                } else {
                    Text(detail)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundColor(.primary)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create PasteValidateStep**

Create `EmberBar/EmberBar/Onboarding/PasteValidateStep.swift`:

```swift
import SwiftUI

struct PasteValidateStep: View {
    @ObservedObject var appState: AppState
    let onNext: () -> Void
    @State private var cookieText: String = ""
    @State private var isValidating: Bool = false
    @State private var validationError: String?
    @State private var validationSuccess: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Paste Your Cookie")
                .font(.system(size: 20, weight: .bold))

            Text("Paste the full Cookie value you copied from the Request Headers.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            TextEditor(text: $cookieText)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: 1)
                )
                .cornerRadius(8)
                .overlay {
                    if cookieText.isEmpty {
                        Text("Paste your cookie here...")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary.opacity(0.5))
                            .allowsHitTesting(false)
                    }
                }

            if let error = validationError {
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text(error)
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                }
            }

            if let success = validationSuccess {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(success)
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                }
            }

            HStack(spacing: 12) {
                if validationSuccess != nil {
                    Button(action: onNext) {
                        Text("Continue")
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 140, height: 36)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                } else {
                    Button(action: validate) {
                        if isValidating {
                            ProgressView()
                                .controlSize(.small)
                                .frame(width: 140, height: 36)
                        } else {
                            Text("Connect")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 140, height: 36)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(cookieText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isValidating)
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
    }

    private var borderColor: Color {
        if validationError != nil { return .red }
        if validationSuccess != nil { return .green }
        return .gray.opacity(0.3)
    }

    private func validate() {
        let cookie = cookieText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cookie.isEmpty else { return }

        isValidating = true
        validationError = nil
        validationSuccess = nil

        Task {
            let result = await appState.validateAndSaveCookie(cookie)
            await MainActor.run {
                isValidating = false
                switch result {
                case .success(let orgName):
                    let resetInfo: String
                    if let reset = appState.sessionResetTime {
                        resetInfo = " Session resets in \(TimeFormatting.shortDuration(reset))."
                    } else {
                        resetInfo = ""
                    }
                    validationSuccess = "Connected! Organization: \(orgName).\(resetInfo)"
                case .failure(let error):
                    switch error {
                    case .invalidCookie:
                        validationError = "Invalid cookie. Make sure you copied the entire Cookie value, not just part of it."
                    default:
                        validationError = error.localizedDescription
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 5: Create DoneStep**

Create `EmberBar/EmberBar/Onboarding/DoneStep.swift`:

```swift
import SwiftUI
import ServiceManagement

struct DoneStep: View {
    @ObservedObject var appState: AppState
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundColor(.green)

            Text("You're All Set!")
                .font(.system(size: 24, weight: .bold))

            Text("EmberBar is now monitoring your Claude usage.\nCheck the menu bar for your ember gauge.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Toggle("Launch EmberBar at login", isOn: $appState.settings.launchAtLogin)
                .toggleStyle(.switch)
                .padding(.horizontal, 40)
                .onChange(of: appState.settings.launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        // Silently fail — login item registration can fail in dev builds
                    }
                }

            Button(action: {
                appState.settings.hasCompletedOnboarding = true
                onComplete()
            }) {
                Text("Finish")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 200, height: 36)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.top, 8)
        }
        .padding(32)
    }
}
```

- [ ] **Step 6: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Should compile successfully now — all referenced types exist.

- [ ] **Step 7: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Onboarding/
git commit -m "feat: add onboarding wizard with cookie paste and validation"
```

---

### Task 10: Notification Manager

**Files:**
- Create: `EmberBar/EmberBar/Services/NotificationManager.swift`
- Modify: `EmberBar/EmberBar/App/AppState.swift`

- [ ] **Step 1: Create NotificationManager**

Create `EmberBar/EmberBar/Services/NotificationManager.swift`:

```swift
import Foundation
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let settings = AppSettings.shared

    // Track which notifications have been sent this session to avoid repeats
    private var sentThisSession: Set<String> = []
    private var lastPeakHourNotified: Bool = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func evaluateAndNotify(
        sessionUtilization: Double,
        sessionResetTime: TimeInterval?,
        burnRate: BurnRateData,
        isPeakHour: Bool
    ) {
        let resetString = sessionResetTime.map { TimeFormatting.shortDuration($0) } ?? "unknown"
        let msgsString = burnRate.estimatedMessagesRemaining.map { "~\($0.lowerBound)-\($0.upperBound) msgs left" } ?? ""

        // Session 75% notification
        if settings.notifyAt75 && sessionUtilization >= 75 && sessionUtilization < 90 {
            sendOnce(
                id: "session-75",
                title: "Session 75% Used",
                body: "\(msgsString) · resets in \(resetString)"
            )
        }

        // Session 90% notification
        if settings.notifyAt90 && sessionUtilization >= 90 {
            sendOnce(
                id: "session-90",
                title: "Session 90% Used",
                body: "\(msgsString) · resets in \(resetString)"
            )
        }

        // Burn rate warning — approaching limit within 15 minutes
        if settings.notifyBurnRate,
           let minutes = burnRate.minutesUntilLimit,
           minutes <= 15, minutes > 0 {
            sendOnce(
                id: "burnrate-15min",
                title: "Approaching Session Limit",
                body: "At this pace, you'll hit your limit in ~\(Int(minutes)) min"
            )
        }

        // Peak hours notification
        if settings.notifyPeakHours && isPeakHour && !lastPeakHourNotified {
            sendOnce(
                id: "peak-hours",
                title: "Peak Hours Active",
                body: "Usage may deplete 2x faster until 11am PT"
            )
        }
        lastPeakHourNotified = isPeakHour

        // Cookie expired is handled directly by AppState
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

    // MARK: - Private

    private func sendOnce(id: String, title: String, body: String) {
        guard !sentThisSession.contains(id) else { return }
        sentThisSession.insert(id)
        send(id: id, title: title, body: body)
    }

    private func send(id: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: "emberbar-\(id)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

- [ ] **Step 2: Integrate NotificationManager into AppState**

In `EmberBar/EmberBar/App/AppState.swift`, add notification evaluation to the `fetchUsage` method. Replace the existing `fetchUsage` method:

Find:
```swift
            // Update peak hour status
            isPeakHour = PeakHourDetector.isPeakHour()
            peakEndTime = PeakHourDetector.peakEndTime()

        } catch let apiError as APIError {
```

Replace with:
```swift
            // Update peak hour status
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
```

Also add notification permission request in `startPolling`. Find:
```swift
    func startPolling() {
        refreshTimer?.invalidate()
```

Replace with:
```swift
    func startPolling() {
        NotificationManager.shared.requestPermission()
        refreshTimer?.invalidate()
```

And add cookie expiration notification. Find:
```swift
            if case .invalidCookie = apiError {
                cookieIsValid = false
            }
```

Replace with:
```swift
            if case .invalidCookie = apiError {
                cookieIsValid = false
                NotificationManager.shared.notifyCookieExpired()
            }
```

- [ ] **Step 3: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully.

- [ ] **Step 4: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Services/NotificationManager.swift EmberBar/EmberBar/App/AppState.swift
git commit -m "feat: add smart contextual notifications with burn rate and peak hour alerts"
```

---

### Task 11: Settings Window

**Files:**
- Create: `EmberBar/EmberBar/Settings/SettingsWindow.swift`
- Create: `EmberBar/EmberBar/Settings/GeneralSettings.swift`
- Create: `EmberBar/EmberBar/Settings/NotificationSettings.swift`
- Create: `EmberBar/EmberBar/Settings/AccountSettings.swift`

- [ ] **Step 1: Create GeneralSettings**

Create `EmberBar/EmberBar/Settings/GeneralSettings.swift`:

```swift
import SwiftUI
import ServiceManagement

struct GeneralSettings: View {
    @ObservedObject var settings = AppSettings.shared

    private let refreshOptions: [(String, Double)] = [
        ("30 seconds", 30),
        ("1 minute", 60),
        ("2 minutes", 120),
        ("5 minutes", 300),
    ]

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $settings.launchAtLogin)
                .onChange(of: settings.launchAtLogin) { _, newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch { }
                }

            Picker("Refresh interval", selection: $settings.refreshIntervalSeconds) {
                ForEach(refreshOptions, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }

            Section {
                HStack {
                    Text("Keyboard shortcut")
                    Spacer()
                    Text("⌘⇧E")
                        .font(.system(size: 12, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 2: Create NotificationSettings**

Create `EmberBar/EmberBar/Settings/NotificationSettings.swift`:

```swift
import SwiftUI

struct NotificationSettings: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        Form {
            Section("Session Alerts") {
                Toggle("Alert at 75% usage", isOn: $settings.notifyAt75)
                Toggle("Alert at 90% usage", isOn: $settings.notifyAt90)
                Toggle("Alert when approaching limit (burn rate)", isOn: $settings.notifyBurnRate)
            }

            Section("Peak Hours") {
                Toggle("Alert when peak hours start", isOn: $settings.notifyPeakHours)
            }

            Section {
                Text("Cookie expiration alerts are always enabled.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 3: Create AccountSettings**

Create `EmberBar/EmberBar/Settings/AccountSettings.swift`:

```swift
import SwiftUI

struct AccountSettings: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Form {
            Section("Account") {
                HStack {
                    Text("Plan")
                    Spacer()
                    Text(appState.planName.isEmpty ? "Unknown" : appState.planName)
                        .foregroundColor(.secondary)
                }

                HStack {
                    Text("Cookie status")
                    Spacer()
                    if appState.cookieIsValid {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 8, height: 8)
                            Text("Valid")
                                .foregroundColor(.green)
                        }
                    } else {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 8, height: 8)
                            Text("Expired / Not Set")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            Section {
                Button("Update Cookie...") {
                    if let appDelegate = NSApp.delegate as? AppDelegate {
                        appDelegate.showOnboarding()
                    }
                }

                Button("Clear Cookie & Sign Out", role: .destructive) {
                    appState.signOut()
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

- [ ] **Step 4: Create SettingsWindow with tabs**

Create `EmberBar/EmberBar/Settings/SettingsWindow.swift`:

```swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            NotificationSettings()
                .tabItem {
                    Label("Notifications", systemImage: "bell")
                }

            AccountSettings()
                .environmentObject(appState)
                .tabItem {
                    Label("Account", systemImage: "person.circle")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 420, height: 320)
    }
}

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("🔥")
                .font(.system(size: 48))
            Text("EmberBar")
                .font(.system(size: 20, weight: .bold))
            Text("Version 1.0.0")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Text("Track your Claude usage with predictive intelligence.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Divider()

            Text("No analytics. No telemetry. Privacy-first.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
```

- [ ] **Step 5: Wire settings into the popover footer**

In `EmberBar/EmberBar/Popover/PopoverView.swift`, add a settings button that opens the Settings window. Find the footer section and add a settings button. In `AppDelegate`, add a method to open settings.

Add to `AppDelegate.swift` — find `func showOnboarding()` and add after it:

```swift
    func openSettings() {
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 320),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "EmberBar Settings"
        settingsWindow.center()
        settingsWindow.contentView = NSHostingView(
            rootView: SettingsView()
                .environmentObject(appState)
        )
        settingsWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
```

Update the settings button in PopoverView.swift footer. Find:

```swift
                    Button {
                        Task { await appState.fetchUsage() }
                    } label: {
```

Add before it:

```swift
                    Button {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.openSettings()
                        }
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)

```

- [ ] **Step 6: Build and verify**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build
```

Expected: Compiles successfully.

- [ ] **Step 7: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/EmberBar/Settings/ EmberBar/EmberBar/App/AppDelegate.swift EmberBar/EmberBar/Popover/PopoverView.swift
git commit -m "feat: add settings window with general, notification, account, and about tabs"
```

---

### Task 12: Combine Sink Fix & Final Build

**Files:**
- Modify: `EmberBar/EmberBar/App/AppDelegate.swift`

- [ ] **Step 1: Add Combine import and fix sink**

The `$usageResponse.sink` in AppDelegate requires Combine. Update the import and fix the observation pattern.

In `AppDelegate.swift`, add `import Combine` at the top. Also change the `stateObservation` type:

Find:
```swift
    private var stateObservation: Any?
```

Replace with:
```swift
    private var stateObservation: AnyCancellable?
```

- [ ] **Step 2: Full build test**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build 2>&1
```

Expected: Compiles with zero errors.

- [ ] **Step 3: Run the app**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build && .build/debug/EmberBar &
```

Expected: App launches, shows menu bar icon with "🔥 --%" and opens the onboarding wizard.

- [ ] **Step 4: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/
git commit -m "fix: add Combine import and AnyCancellable type for state observation"
```

---

### Task 13: App Icon & Final Polish

**Files:**
- Create: `EmberBar/EmberBar/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify: `EmberBar/EmberBar/App/AppDelegate.swift` (right-click menu)

- [ ] **Step 1: Add right-click context menu to status bar**

Add a right-click menu for quick access to settings and quit. In `AppDelegate.swift`, add after the `togglePopover` setup in `applicationDidFinishLaunching`:

Find:
```swift
        // Check if onboarding is needed
```

Add before it:
```swift
        // Right-click menu
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit EmberBar", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = nil // Left click = popover, we'll handle right click differently

```

Actually, NSStatusItem doesn't natively distinguish left/right click easily with both a menu and an action. A simpler approach: add Quit and Settings to the popover footer instead, and use a menu only. Let's use left-click for the popover and add a "Quit" option to the popover.

Update PopoverView.swift footer. Find:
```swift
                    Button {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.openSettings()
                        }
                    } label: {
                        Image(systemName: "gear")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
```

Add after it:
```swift
                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
```

- [ ] **Step 2: Create basic AppIcon asset catalog entry**

Create `EmberBar/EmberBar/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "16x16"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "32x32"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "128x128"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "256x256"
    },
    {
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "512x512"
    },
    {
      "idiom" : "mac",
      "scale" : "2x",
      "size" : "512x512"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

Create `EmberBar/EmberBar/Assets.xcassets/Contents.json`:

```json
{
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Build and test final app**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build 2>&1
```

Expected: Clean build with zero errors.

- [ ] **Step 4: Commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add EmberBar/
git commit -m "feat: add quit button, app icon asset catalog, and final polish"
```

---

### Task 14: End-to-End Manual Test

- [ ] **Step 1: Launch and verify onboarding**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget/EmberBar"
swift build && .build/debug/EmberBar
```

Verify:
- App appears in menu bar with ember gauge icon and "--%"
- Onboarding wizard opens automatically
- Can navigate through Welcome → Instructions → Paste → Done steps
- Cookie paste field accepts text
- "Connect" validates against claude.ai API
- On success, shows plan name and enables "Continue"
- "Finish" closes wizard and starts polling

- [ ] **Step 2: Verify popover**

Click the menu bar icon. Verify:
- Popover opens with Dashboard Cards layout
- Session Usage card shows percentage and progress bar
- Burn Rate card shows "Calculating..." initially, then prediction after a few polls
- Weekly Usage card shows percentage
- Peak Hour card appears only during 5am-11am PT weekdays
- Footer shows "Updated Xm ago", Open Claude, Settings gear, Quit power icon
- Clicking "Open Claude" opens claude.ai in browser
- Clicking settings gear opens Settings window
- Clicking refresh icon triggers immediate fetch

- [ ] **Step 3: Verify menu bar updates**

Wait for 2-3 polling cycles (60s each). Verify:
- Percentage updates in menu bar
- Ember gauge color/brightness changes with utilization
- Ember dims as usage increases

- [ ] **Step 4: Verify keyboard shortcut**

Press Cmd+Shift+E. Verify popover toggles open/closed.

- [ ] **Step 5: Final commit**

```bash
cd "/Users/aearles/Desktop/Projects/Claude Widget"
git add -A
git commit -m "chore: complete v1 EmberBar implementation — ready for testing"
```
