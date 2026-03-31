import SwiftUI
import ServiceManagement

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
                .onChange(of: settings.launchAtLogin) { newValue in
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
