import AppKit
import SwiftUI
import Combine

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let appState = AppState()
    private var stateObservation: AnyCancellable?
    private var onboardingWindowController: OnboardingWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[EmberBar] App launching...")
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

        print("[EmberBar] Status item created")

        if appState.settings.hasCompletedOnboarding && KeychainManager.hasCookie() {
            print("[EmberBar] Onboarding complete, starting polling...")
            appState.cookieIsValid = true
            appState.startPolling()
        } else {
            print("[EmberBar] Showing onboarding...")
            showOnboarding()
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 14 {
                DispatchQueue.main.async {
                    self?.togglePopover()
                }
            }
        }
        print("[EmberBar] Launch complete")
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
        onboardingWindowController = OnboardingWindow(appState: appState, onComplete: { [weak self] in
            self?.appState.startPolling()
        })
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Force center on the screen where the cursor is
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let window = self?.onboardingWindowController?.window else { return }
            // Use the screen containing the mouse cursor
            let mouseLocation = NSEvent.mouseLocation
            var targetScreen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            if targetScreen == nil { targetScreen = NSScreen.screens.last ?? NSScreen.main }
            if let screen = targetScreen {
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
}
