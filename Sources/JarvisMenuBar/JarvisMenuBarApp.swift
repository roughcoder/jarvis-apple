import AppKit
import SwiftUI

@main
struct JarvisMenuBarApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var viewModel: JarvisViewModel

    init() {
        let settings = AppSettings()
        _settings = StateObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: JarvisViewModel(settings: settings))
        NSApplication.shared.setActivationPolicy(.accessory)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(settings)
                .environmentObject(viewModel)
                .task {
                    await viewModel.startPolling()
                }
        } label: {
            Label("Jarvis", systemImage: viewModel.fleetStatus.overall.symbolName)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settings)
        }

        Window("Jarvis Command Progress", id: "command-progress") {
            CommandProgressWindow()
                .environmentObject(viewModel)
        }
        .defaultSize(width: 760, height: 520)
    }
}
