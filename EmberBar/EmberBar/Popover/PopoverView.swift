import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 10) {
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

                    Button {
                        NSApp.terminate(nil)
                    } label: {
                        Image(systemName: "power")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)

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
        .frame(width: 320, height: 420)
    }
}
