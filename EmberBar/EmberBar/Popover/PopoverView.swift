import SwiftUI

enum PopoverPage {
    case dashboard
    case settings
}

struct PopoverView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentPage: PopoverPage = .dashboard

    var body: some View {
        VStack(spacing: 0) {
            switch currentPage {
            case .dashboard:
                DashboardPage(currentPage: $currentPage)
                    .environmentObject(appState)
            case .settings:
                SettingsPage(currentPage: $currentPage)
                    .environmentObject(appState)
            }
        }
        .frame(width: 320)
    }
}

// MARK: - Dashboard Page

struct DashboardPage: View {
    @EnvironmentObject var appState: AppState
    @Binding var currentPage: PopoverPage

    var body: some View {
        VStack(spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Text("\u{1F525}")
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
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading usage data...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
                // Cards
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
                VStack(spacing: 6) {
                    if let elapsed = appState.timeSinceLastUpdate {
                        Text("Updated \(TimeFormatting.shortDuration(elapsed)) ago")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.5))
                    }

                    Divider()

                    HStack(spacing: 0) {
                        FooterNSButton(title: "Open Claude", systemImage: "globe") {
                            if let url = URL(string: "https://claude.ai") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        Spacer()
                        FooterNSButton(title: "Settings", systemImage: "gear") {
                            currentPage = .settings
                        }
                        FooterNSButton(title: "Refresh", systemImage: "arrow.clockwise") {
                            Task { await appState.fetchUsage() }
                        }
                        FooterNSButton(title: "Quit", systemImage: "power") {
                            NSApp.terminate(nil)
                        }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
    }
}

// MARK: - Settings Page (inside popover)

struct SettingsPage: View {
    @EnvironmentObject var appState: AppState
    @Binding var currentPage: PopoverPage

    var body: some View {
        VStack(spacing: 0) {
            // Header with back button
            HStack {
                FooterNSButton(title: "Back", systemImage: "chevron.left") {
                    currentPage = .dashboard
                }
                Spacer()
                Text("Settings")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                // Invisible spacer to center title
                Text("Back")
                    .font(.system(size: 11))
                    .hidden()
                    .frame(width: 50)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // General
                    SettingsSection(title: "General") {
                        SettingsToggle(label: "Launch at login", isOn: $appState.settings.launchAtLogin)

                        HStack {
                            Text("Refresh interval")
                                .font(.system(size: 12))
                            Spacer()
                            Picker("", selection: $appState.settings.refreshIntervalSeconds) {
                                Text("30s").tag(30.0)
                                Text("1m").tag(60.0)
                                Text("2m").tag(120.0)
                                Text("5m").tag(300.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 180)
                        }

                        HStack {
                            Text("Keyboard shortcut")
                                .font(.system(size: 12))
                            Spacer()
                            Text("⌘⇧E")
                                .font(.system(size: 11, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }

                    // Notifications
                    SettingsSection(title: "Notifications") {
                        SettingsToggle(label: "Alert at 75% usage", isOn: $appState.settings.notifyAt75)
                        SettingsToggle(label: "Alert at 90% usage", isOn: $appState.settings.notifyAt90)
                        SettingsToggle(label: "Burn rate warning", isOn: $appState.settings.notifyBurnRate)
                        SettingsToggle(label: "Peak hours alert", isOn: $appState.settings.notifyPeakHours)
                    }

                    // Account
                    SettingsSection(title: "Account") {
                        HStack {
                            Text("Status")
                                .font(.system(size: 12))
                            Spacer()
                            if appState.cookieIsValid {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text("Connected")
                                        .font(.system(size: 11))
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.red).frame(width: 6, height: 6)
                                    Text("Not connected")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red)
                                }
                            }
                        }

                        FooterNSButton(title: "Update Cookie...", systemImage: "key") {
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.showOnboarding()
                            }
                        }

                        FooterNSButton(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                            appState.signOut()
                            currentPage = .dashboard
                        }
                    }

                    // About
                    VStack(spacing: 4) {
                        Text("EmberBar v1.0.0")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text("No analytics · No telemetry · Privacy-first")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
                .padding(16)
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(.secondary)
                .tracking(0.5)
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding(12)
            .background(Color(.controlBackgroundColor).opacity(0.5))
            .cornerRadius(8)
        }
    }
}

struct SettingsToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .font(.system(size: 12))
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}

// MARK: - Footer Button (NSButton-backed for reliable clicks in NSPopover)

struct FooterNSButton: NSViewRepresentable {
    let title: String
    let systemImage: String
    let action: () -> Void

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(frame: .zero)
        button.bezelStyle = .recessed
        button.isBordered = false
        button.target = context.coordinator
        button.action = #selector(Coordinator.clicked)
        button.font = NSFont.systemFont(ofSize: 10)
        button.contentTintColor = .secondaryLabelColor

        if let image = NSImage(systemSymbolName: systemImage, accessibilityDescription: title) {
            let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
            button.image = image.withSymbolConfiguration(config)
            button.imagePosition = .imageLeading
        }
        button.title = title

        return button
    }

    func updateNSView(_ button: NSButton, context: Context) {
        context.coordinator.action = action
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    class Coordinator: NSObject {
        var action: () -> Void
        init(action: @escaping () -> Void) { self.action = action }
        @objc func clicked() { action() }
    }
}
