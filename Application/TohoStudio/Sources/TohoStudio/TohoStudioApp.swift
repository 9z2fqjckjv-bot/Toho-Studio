import SwiftUI
import AppKit

@main
struct TohoStudioApp: App {
    @StateObject private var appState = AppState.shared

    init() {
        // Configure macOS app behavior
        NSApplication.shared.setActivationPolicy(.regular)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .frame(minWidth: 1024, minHeight: 700)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            MenuBarCommands(appState: appState)
        }
    }
}
