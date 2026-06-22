import AppKit

@MainActor
enum AppWindowPresenter {
    static func openSettings() {
        NSApplication.shared.activate()

        if NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) {
            return
        }

        NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
    }
}
