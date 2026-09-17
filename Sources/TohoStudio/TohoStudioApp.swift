import SwiftUI

@main
struct TohoStudioApp: App {
    var body: some Scene {
        WindowGroup {
            SidebarView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
}
