import SpriteKit
import StatusDriverCore
import SwiftUI

struct TerrainView: View {
    @ObservedObject var telemetry: TelemetrySession
    @State private var scene: TerrainScene

    init(telemetry: TelemetrySession) {
        self.telemetry = telemetry
        let scene = TerrainScene(size: CGSize(width: 1_200, height: 700))
        scene.scaleMode = .resizeFill
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            SpriteKitView(scene: scene)
                .frame(minWidth: 720, minHeight: 440)

            MetricAnnotation(
                reading: telemetry.latestReading,
                sourceMode: telemetry.sourceMode
            )
            .padding(18)
            .allowsHitTesting(false)
        }
        .task {
            await telemetry.run(scene: scene)
        }
    }
}

private struct MetricAnnotation: View {
    let reading: MetricReading?
    let sourceMode: MetricSourceMode

    var body: some View {
        HStack(spacing: 9) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 7, height: 7)
            Text(label)
                .font(.custom("Avenir Next Condensed Demi Bold", size: 16))
                .tracking(0.8)
        }
        .foregroundStyle(Color(red: 0.105, green: 0.16, blue: 0.15))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Color(red: 0.965, green: 0.945, blue: 0.89)
                .opacity(0.92),
            in: RoundedRectangle(cornerRadius: 7)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color(red: 0.105, green: 0.16, blue: 0.15).opacity(0.22))
        }
        .accessibilityLabel(label)
    }

    private var label: String {
        switch (sourceMode, reading?.availability) {
        case (.cpu, .some(.available)):
            "CPU \(percentage)%"
        case (.cpu, _):
            "CPU unavailable"
        case (.synthetic, _):
            "SYNTHETIC \(percentage)%"
        }
    }

    private var percentage: Int {
        Int(((reading?.value ?? 0.5) * 100).rounded())
    }

    private var indicatorColor: Color {
        if sourceMode == .cpu, reading?.availability != .available {
            return Color(red: 0.78, green: 0.24, blue: 0.12)
        }
        return Color(red: 0.95, green: 0.31, blue: 0.08)
    }
}

private struct SpriteKitView: NSViewRepresentable {
    let scene: TerrainScene

    func makeNSView(context: Context) -> SKView {
        let view = FocusableSKView(frame: CGRect(x: 0, y: 0, width: 1_200, height: 700))
        view.ignoresSiblingOrder = true
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ view: SKView, context: Context) {
        if view.scene !== scene {
            view.presentScene(scene)
        }
    }
}

private final class FocusableSKView: SKView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async {
            window.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
