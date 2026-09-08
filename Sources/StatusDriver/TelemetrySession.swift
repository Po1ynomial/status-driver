import Combine
import StatusDriverCore

@MainActor
final class TelemetrySession: ObservableObject {
    @Published private(set) var latestReading: MetricReading?
    @Published private(set) var latestMemoryReading: MetricReading?

    let sourceMode: MetricSourceMode
    private var isRunning = false

    init(sourceMode: MetricSourceMode) {
        self.sourceMode = sourceMode
    }

    func run(scene: TerrainScene) async {
        guard !isRunning else { return }
        isRunning = true
        latestReading = nil
        latestMemoryReading = nil
        defer { isRunning = false }

        let producer: any MetricSnapshotProducer = switch sourceMode {
        case .live:
            ConcurrentMetricSnapshotProducer()
        case .synthetic:
            SyntheticMetricSnapshotProducer()
        }

        var cpuStartupGate = MetricStartupGate(sourceMode: sourceMode)
        for await snapshot in makeMetricStream(producer: producer) {
            if Task.isCancelled { break }
            latestReading = snapshot.cpu
            latestMemoryReading = snapshot.memory
            if let terrainReading = cpuStartupGate.consume(snapshot.cpu) {
                scene.ingest(terrainReading)
            }
        }
    }
}
