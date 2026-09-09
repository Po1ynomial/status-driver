import AppKit
import StatusDriverCore
import SwiftUI

@main
@MainActor
struct StatusDriverApp: App {
    @StateObject private var telemetry: TelemetrySession

    init() {
        _telemetry = StateObject(
            wrappedValue: TelemetrySession(
                sourceMode: MetricSourceMode(arguments: CommandLine.arguments)
            )
        )
        NSApplication.shared.setActivationPolicy(.regular)
        DispatchQueue.main.async {
            NSApplication.shared.activate()
        }
    }

    var body: some Scene {
        Window("Status Driver", id: "main") {
            TerrainView(telemetry: telemetry)
        }
        .defaultSize(width: 1_200, height: 700)
        .windowResizability(.contentMinSize)
    }
}
