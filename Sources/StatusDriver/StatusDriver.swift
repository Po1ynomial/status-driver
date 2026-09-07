import AppKit
import SwiftUI

@main
struct StatusDriverApp: App {
    init() {
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate()
        }
    }

    var body: some Scene {
        WindowGroup("Status Driver") {
            TerrainView()
        }
        .defaultSize(width: 1_200, height: 700)
        .windowResizability(.contentMinSize)
    }
}
