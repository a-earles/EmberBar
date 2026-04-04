import AppKit
import SwiftUI

class OnboardingWindow: NSWindowController {
    convenience init(appState: AppState, initialStep: OnboardingStep = .welcome, onComplete: @escaping () -> Void) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 560),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "EmberBar Setup"
        window.isReleasedWhenClosed = false
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - 250
            let y = screenFrame.midY - 280
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else {
            window.center()
        }
        window.contentView = NSHostingView(
            rootView: OnboardingContainerView(appState: appState, initialStep: initialStep, onComplete: {
                onComplete()
                window.close()
            })
        )
        self.init(window: window)
    }
}

enum OnboardingStep {
    case welcome
    case browserLogin    // Tier 1: embedded browser auto-detects cookie
    case pasteValidate   // Tier 2: manual cookie paste fallback
    case done
}

struct OnboardingContainerView: View {
    @ObservedObject var appState: AppState
    let onComplete: () -> Void
    let initialStep: OnboardingStep
    @State private var currentStep: OnboardingStep

    init(appState: AppState, initialStep: OnboardingStep = .welcome, onComplete: @escaping () -> Void) {
        self.appState = appState
        self.onComplete = onComplete
        self.initialStep = initialStep
        self._currentStep = State(initialValue: initialStep)
    }

    var body: some View {
        VStack {
            // Top bar: quit button + progress dots
            ZStack {
                // Progress dots centered
                HStack(spacing: 8) {
                    progressDot(active: true)                                          // welcome
                    progressDot(active: currentStep != .welcome)                       // connect
                    progressDot(active: currentStep == .done)                          // done
                }

                // Quit button trailing
                HStack {
                    Spacer()
                    Button(action: { NSApp.terminate(nil) }) {
                        Image(systemName: "power")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .help("Quit EmberBar")
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            switch currentStep {
            case .welcome:
                WelcomeStep(onNext: { currentStep = .browserLogin })
            case .browserLogin:
                BrowserLoginStep(
                    appState: appState,
                    onSuccess: { currentStep = .done },
                    onManualFallback: { currentStep = .pasteValidate }
                )
            case .pasteValidate:
                PasteValidateStep(appState: appState, onNext: { currentStep = .done })
            case .done:
                DoneStep(appState: appState, onComplete: onComplete)
            }

            Spacer()
        }
        .frame(minWidth: 500, minHeight: 560)
    }

    private func progressDot(active: Bool) -> some View {
        Circle()
            .fill(active ? Color.orange : Color.gray.opacity(0.3))
            .frame(width: 8, height: 8)
    }
}
