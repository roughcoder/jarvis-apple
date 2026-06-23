import AppKit
import SwiftUI

@MainActor
enum AppWindowPresenter {
    private static var settingsWindow: NSWindow?

    static func openSettings(settings: AppSettings) {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let content = SettingsView()
            .environmentObject(settings)
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Jarvis Settings"
        window.setContentSize(NSSize(width: 560, height: 450))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
        settingsWindow = window
    }
}
