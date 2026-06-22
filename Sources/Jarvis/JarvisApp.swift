import AppKit
import SwiftUI

@main
struct JarvisApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var viewModel: JarvisViewModel

    init() {
        let settings = AppSettings()
        let viewModel = JarvisViewModel(settings: settings)
        _settings = StateObject(wrappedValue: settings)
        _viewModel = StateObject(wrappedValue: viewModel)
        NSApplication.shared.setActivationPolicy(.accessory)
        if settings.shouldAutoOpenSetup {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                SetupWindowPresenter.shared.show(settings: settings, viewModel: viewModel)
                settings.markSetupAutoOpened()
            }
        }
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
            Label("Jarvis", systemImage: AppIdentity.menuBarSymbolName)
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

        Window("Jarvis Setup", id: "setup") {
            SetupGuideView()
                .environmentObject(settings)
                .environmentObject(viewModel)
        }
        .defaultSize(width: 720, height: 560)
    }
}
