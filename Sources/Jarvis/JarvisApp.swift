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
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            if settings.setupCompleted {
                MenuContentView()
                    .environmentObject(settings)
                    .environmentObject(viewModel)
                    .task {
                        await viewModel.startPolling()
                    }
            } else {
                SetupWizardView()
                    .environmentObject(settings)
                    .environmentObject(viewModel)
                    .frame(width: 860, height: 620)
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
            SetupWizardView()
                .environmentObject(settings)
                .environmentObject(viewModel)
        }
        .defaultSize(width: 920, height: 680)
    }
}
