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
        popover.contentSize = NSSize(width: 320, height: 500)
        popover.behavior = .semitransient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView()
                .environmentObject(appState)
        )

        stateObservation = appState.$usageResponse.receive(on: RunLoop.main).sink { [weak self] _ in
            self?.updateMenuBarIcon()
        }

        if appState.settings.hasCompletedOnboarding && KeychainManager.hasCookie() {
            appState.cookieIsValid = true
            appState.startPolling()
        } else {
            showOnboarding()
        }

        NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 14 {
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
        onboardingWindowController = OnboardingWindow(appState: appState, onComplete: { [weak self] in
            self?.appState.startPolling()
        })
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let window = self?.onboardingWindowController?.window else { return }
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
}
