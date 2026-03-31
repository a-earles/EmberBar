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
