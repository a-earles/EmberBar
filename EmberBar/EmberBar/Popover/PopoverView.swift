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
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .settings:
                SettingsPage(currentPage: $currentPage)
                    .environmentObject(appState)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .frame(width: 320)
        .animation(.easeInOut(duration: 0.2), value: currentPage)
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
                HStack(spacing: 8) {
                    EmberLogo(size: 22)
                    Text("EmberBar")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                }
                Spacer()
                if !appState.planName.isEmpty {
                    Text(appState.planName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }
            }
            .padding(.bottom, 2)

            if !appState.cookieIsValid {
                VStack(spacing: 12) {
                    EmberLogo(size: 48)
                    Text("Not Connected")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Set up your session cookie to start tracking.")
                        .font(EmberTheme.bodyText)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Set Up Cookie") {
                        if let appDelegate = NSApp.delegate as? AppDelegate {
                            appDelegate.showOnboarding()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(EmberTheme.ember)
                }
                .frame(maxHeight: .infinity)
            } else if appState.usageResponse == nil && appState.isLoading {
                VStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Loading...")
                        .font(EmberTheme.bodyText)
                        .foregroundColor(.secondary)
                }
                .frame(maxHeight: .infinity)
            } else {
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
                            .foregroundColor(EmberTheme.warning)
                            .font(.system(size: 10))
                        Text(error.localizedDescription)
                            .font(EmberTheme.captionText)
                            .foregroundColor(EmberTheme.warning)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 4)

                // Footer
                VStack(spacing: 6) {
                    if let elapsed = appState.timeSinceLastUpdate {
                        Text("Updated \(TimeFormatting.shortDuration(elapsed)) ago")
                            .font(EmberTheme.tinyText)
                            .foregroundColor(.secondary.opacity(0.4))
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 0.5)

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
                .padding(.top, 2)
            }
        }
        .padding(16)
    }
}

// MARK: - Settings Page

struct SettingsPage: View {
    @EnvironmentObject var appState: AppState
    @Binding var currentPage: PopoverPage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                HStack {
                    FooterNSButton(title: "Back", systemImage: "chevron.left") {
                        currentPage = .dashboard
                    }
                    Spacer()
                    Text("Settings")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Color.clear.frame(width: 50, height: 1)
                }
                .padding(.bottom, 12)

                // GENERAL
                sectionHeader("General")

                VStack(spacing: 0) {
                    settingsRow {
                        SettingsToggle(label: "Launch at login", isOn: $appState.settings.launchAtLogin)
                    }
                    settingsDivider()
                    settingsRow {
                        HStack {
                            Text("Refresh")
                                .font(EmberTheme.bodyText)
                            Spacer()
                            Picker("", selection: $appState.settings.refreshIntervalSeconds) {
                                Text("30s").tag(30.0)
                                Text("1m").tag(60.0)
                                Text("2m").tag(120.0)
                                Text("5m").tag(300.0)
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                    }
                    settingsDivider()
                    settingsRow {
                        HStack {
                            Text("Shortcut")
                                .font(EmberTheme.bodyText)
                            Spacer()
                            Text("\u{2318}\u{21E7}E")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(5)
                        }
                    }
                }
                .background(EmberTheme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(EmberTheme.cardBorder, lineWidth: 0.5)
                )
                .padding(.bottom, 16)

                // NOTIFICATIONS
                sectionHeader("Notifications")

                VStack(spacing: 0) {
                    settingsRow {
                        SettingsToggle(label: "At 75% usage", isOn: $appState.settings.notifyAt75)
                    }
                    settingsDivider()
                    settingsRow {
                        SettingsToggle(label: "At 90% usage", isOn: $appState.settings.notifyAt90)
                    }
                    settingsDivider()
                    settingsRow {
                        SettingsToggle(label: "Burn rate warning", isOn: $appState.settings.notifyBurnRate)
                    }
                    settingsDivider()
                    settingsRow {
                        SettingsToggle(label: "Peak hours alert", isOn: $appState.settings.notifyPeakHours)
                    }
                }
                .background(EmberTheme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(EmberTheme.cardBorder, lineWidth: 0.5)
                )
                .padding(.bottom, 16)

                // ACCOUNT
                sectionHeader("Account")

                VStack(spacing: 0) {
                    settingsRow {
                        HStack {
                            Text("Status")
                                .font(EmberTheme.bodyText)
                            Spacer()
                            HStack(spacing: 5) {
                                Circle()
                                    .fill(appState.cookieIsValid ? EmberTheme.safe : EmberTheme.danger)
                                    .frame(width: 7, height: 7)
                                Text(appState.cookieIsValid ? "Connected" : "Disconnected")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(appState.cookieIsValid ? EmberTheme.safe : EmberTheme.danger)
                            }
                        }
                    }
                    settingsDivider()
                    settingsRow {
                        FooterNSButton(title: "Update Cookie...", systemImage: "key") {
                            if let appDelegate = NSApp.delegate as? AppDelegate {
                                appDelegate.showOnboarding()
                            }
                        }
                    }
                    settingsDivider()
                    settingsRow {
                        FooterNSButton(title: "Sign Out", systemImage: "rectangle.portrait.and.arrow.right") {
                            appState.signOut()
                            currentPage = .dashboard
                        }
                    }
                }
                .background(EmberTheme.cardBackground)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(EmberTheme.cardBorder, lineWidth: 0.5)
                )
                .padding(.bottom, 16)

                // About
                VStack(spacing: 4) {
                    Text("EmberBar v1.0.0")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("No analytics \u{00B7} No telemetry \u{00B7} Privacy-first")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary.opacity(0.3))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            }
            .padding(16)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.secondary.opacity(0.5))
            .tracking(0.8)
            .padding(.leading, 4)
            .padding(.bottom, 6)
    }

    private func settingsRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
    }

    private func settingsDivider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
            .frame(height: 0.5)
            .padding(.leading, 12)
    }
}

struct SettingsToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(label, isOn: $isOn)
            .font(EmberTheme.bodyText)
            .toggleStyle(.switch)
            .controlSize(.small)
    }
}

// MARK: - Footer Button (NSButton-backed)

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
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
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
