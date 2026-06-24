import AppKit
import SwiftUI

@MainActor
final class SetupWindowPresenter {
    static let shared = SetupWindowPresenter()

    private var window: NSWindow?

    private init() {}

    func show(settings: AppSettings, viewModel: JarvisViewModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApplication.shared.activate()
            return
        }

        let content = SetupWizardView()
            .environmentObject(settings)
            .environmentObject(viewModel)
        let hostingController = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: hostingController)
        window.title = "Jarvis Setup"
        window.setContentSize(NSSize(width: 920, height: 680))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
        self.window = window
    }
}
