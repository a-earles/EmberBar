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
                .onChange(of: appState.settings.launchAtLogin) { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch { }
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
