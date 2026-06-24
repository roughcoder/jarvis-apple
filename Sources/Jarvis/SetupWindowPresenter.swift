import AppKit
import SwiftUI

@MainActor
final class SetupWindowPresenter {
    static let shared = SetupWindowPresenter()

    private var window: NSWindow?
    private var delegate: SetupWindowDelegate?

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
        window.setContentSize(NSSize(width: 980, height: 720))
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace]
        let delegate = SetupWindowDelegate(settings: settings) { [weak self] in
            self?.window = nil
            self?.delegate = nil
        }
        window.delegate = delegate
        self.delegate = delegate
        center(window)
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate()
        self.window = window
    }

    private func center(_ window: NSWindow) {
        let visibleFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = window.frame.size
        let origin = NSPoint(
            x: visibleFrame.midX - size.width / 2,
            y: visibleFrame.midY - size.height / 2
        )
        window.setFrameOrigin(origin)
    }
}

@MainActor
private final class SetupWindowDelegate: NSObject, NSWindowDelegate {
    private let settings: AppSettings
    private let onClose: () -> Void

    init(settings: AppSettings, onClose: @escaping () -> Void) {
        self.settings = settings
        self.onClose = onClose
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard !settings.setupCompleted else { return true }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Close setup without applying?"
        alert.informativeText = "Jarvis is not configured yet. You can leave to find details, but setup will reopen until it is applied."
        alert.addButton(withTitle: "Keep Setup Open")
        alert.addButton(withTitle: "Close Anyway")
        return alert.runModal() == .alertSecondButtonReturn
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }
}
