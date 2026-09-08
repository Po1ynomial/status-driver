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

            MetricSelector(
                cpu: telemetry.latestCPUReading,
                memory: telemetry.latestMemoryReading,
                selectedMetric: telemetry.selectedMetric,
                sourceMode: telemetry.sourceMode
            ) { metric in
                telemetry.select(metric, in: scene)
            }
            .padding(18)
        }
        .task {
            scene.onMetricSelectionRequest = { [weak telemetry, weak scene] metric in
                guard let telemetry, let scene else { return }
                telemetry.select(metric, in: scene)
            }
            defer { scene.onMetricSelectionRequest = nil }
            await telemetry.run(scene: scene)
        }
    }
}

private struct MetricSelector: View {
    let cpu: MetricReading?
    let memory: MetricReading?
    let selectedMetric: MetricIdentity
    let sourceMode: MetricSourceMode
    let onSelect: (MetricIdentity) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if sourceMode == .synthetic {
                Text("SYNTHETIC")
                    .font(.custom("Avenir Next Condensed Demi Bold", size: 12))
                    .tracking(1.1)
                    .foregroundStyle(ink.opacity(0.72))
                    .padding(.horizontal, 8)
            }

            MetricButton(
                metric: .cpu,
                reading: cpu,
                isSelected: selectedMetric == .cpu,
                onSelect: onSelect
            )
            MetricButton(
                metric: .memory,
                reading: memory,
                isSelected: selectedMetric == .memory,
                onSelect: onSelect
            )
        }
        .padding(5)
        .background(paper.opacity(0.94), in: RoundedRectangle(cornerRadius: 9))
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(ink.opacity(0.16))
        }
    }

    private var ink: Color {
        Color(red: 0.105, green: 0.16, blue: 0.15)
    }

    private var paper: Color {
        Color(red: 0.965, green: 0.945, blue: 0.89)
    }
}

private struct MetricButton: View {
    let metric: MetricIdentity
    let reading: MetricReading?
    let isSelected: Bool
    let onSelect: (MetricIdentity) -> Void

    var body: some View {
        Button {
            onSelect(metric)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 7, height: 7)
                Text(label)
                    .font(.custom("Avenir Next Condensed Demi Bold", size: 15))
                    .tracking(0.65)
            }
            .foregroundStyle(ink.opacity(isAvailable || isSelected ? 1 : 0.48))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected ? orange.opacity(0.10) : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(
                        isSelected ? orange.opacity(0.82) : ink.opacity(0.10),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(!isAvailable)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var label: String {
        let name = metric == .cpu ? "CPU" : "MEMORY"
        guard isAvailable else { return "\(name) unavailable" }
        let percentage = Int(((reading?.value ?? 0.5) * 100).rounded())
        return "\(name) \(percentage)%"
    }

    private var isAvailable: Bool {
        reading?.availability == .available
    }

    private var indicatorColor: Color {
        if !isAvailable { return warning }
        return isSelected ? orange : ink.opacity(0.38)
    }

    private var ink: Color {
        Color(red: 0.105, green: 0.16, blue: 0.15)
    }

    private var orange: Color {
        Color(red: 0.95, green: 0.31, blue: 0.08)
    }

    private var warning: Color {
        Color(red: 0.78, green: 0.24, blue: 0.12)
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
