import SwiftUI

@main
struct StatusDriverApp: App {
    var body: some Scene {
        WindowGroup("Status Driver") {
            TerrainView()
        }
        .defaultSize(width: 1_200, height: 700)
        .windowResizability(.contentMinSize)
    }
}
