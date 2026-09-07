import Combine
import StatusDriverCore

@MainActor
final class TelemetrySession: ObservableObject {
    @Published private(set) var latestReading: MetricReading?

    let sourceMode: MetricSourceMode
    private var isRunning = false

    init(sourceMode: MetricSourceMode) {
        self.sourceMode = sourceMode
    }

    func run(scene: TerrainScene) async {
        guard !isRunning else { return }
        isRunning = true
        latestReading = nil
        defer { isRunning = false }

        let producer: any MetricReadingProducer = switch sourceMode {
        case .cpu:
            CPUMetricProducer()
        case .synthetic:
            SyntheticMetricProducer()
        }

        var startupGate = MetricStartupGate(sourceMode: sourceMode)
        for await reading in makeMetricStream(producer: producer) {
            if Task.isCancelled { break }
            latestReading = reading
            if let terrainReading = startupGate.consume(reading) {
                scene.ingest(terrainReading)
            }
        }
    }
}
