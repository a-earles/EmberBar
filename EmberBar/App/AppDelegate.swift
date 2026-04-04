import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    var popover: NSPopover!
    let appState = AppState()
    private var stateObservation: AnyCancellable?
    private var onboardingWindowController: OnboardingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = EmberGaugeRenderer.render(utilization: 0, isValid: false)
            button.imagePosition = .imageLeading
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            ]
            button.attributedTitle = NSAttributedString(string: " --%", attributes: attributes)
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(appState)
        )

        stateObservation = appState.$usageResponse.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateMenuBarIcon()
        }

        // Resize popover when navigating between pages
        NotificationCenter.default.addObserver(forName: .popoverNavigate, object: nil, queue: .main) { [weak self] notification in
            guard let self, let page = notification.object as? PopoverPage else { return }
            MainActor.assumeIsolated {
                let height: CGFloat = (page == .settings) ? 520 : 420
                self.popover.contentSize = NSSize(width: 320, height: height)
            }
        }

        // Listen for onboarding requests from the popover
        NotificationCenter.default.addObserver(forName: .showOnboarding, object: nil, queue: .main) { [weak self] notification in
            guard let self else { return }
            let step = notification.object as? OnboardingStep ?? .welcome
            MainActor.assumeIsolated {
                self.popover.performClose(nil)
                self.showOnboarding(startingAt: step)
            }
        }

        if appState.settings.hasCompletedOnboarding && KeychainManager.hasCookie() {
            appState.cookieIsValid = true
            appState.startPolling()
        } else {
            showOnboarding()
        }

        // Check Accessibility permission for global keyboard shortcut
        if !AXIsProcessTrusted() {
            // Show prompt on first launch only, not every time
            if !appState.settings.hasPromptedAccessibility {
                appState.settings.hasPromptedAccessibility = true
                showAccessibilityPrompt()
            }
        }

        // Global shortcut: Ctrl+Shift+E — requires Accessibility permission
        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 14 && event.modifierFlags.contains(.shift) &&
               (event.modifierFlags.contains(.control) || event.modifierFlags.contains(.command)) {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
        // Local monitor: fires when popover has focus
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 14 && event.modifierFlags.contains(.shift) &&
               (event.modifierFlags.contains(.control) || event.modifierFlags.contains(.command)) {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
                return nil
            }
            return event
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
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    func showOnboarding(startingAt step: OnboardingStep = .welcome) {
        onboardingWindowController = OnboardingWindow(appState: appState, initialStep: step, onComplete: { [weak self] in
            self?.appState.startPolling()
        })
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let window = self?.onboardingWindowController?.window else { return }
            if let screen = NSScreen.main {
                let sf = screen.visibleFrame
                let wf = window.frame
                let x = sf.origin.x + (sf.width - wf.width) / 2
                let y = sf.origin.y + (sf.height - wf.height) / 2
                window.setFrameOrigin(NSPoint(x: x, y: y))
            }
            window.level = .floating
            window.orderFrontRegardless()
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func showAccessibilityPrompt() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = "EmberBar needs Accessibility permission to use the Ctrl+Shift+E keyboard shortcut.\n\nPlease enable it in:\nSystem Settings → Privacy & Security → Accessibility"
        alert.alertStyle = .informational
        if let icon = NSImage(named: NSImage.applicationIconName) {
            alert.icon = icon
        }
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Skip for Now")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
