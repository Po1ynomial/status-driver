import Combine
import StatusDriverCore

@MainActor
final class TelemetrySession: ObservableObject {
    @Published private(set) var latestCPUReading: MetricReading?
    @Published private(set) var latestMemoryReading: MetricReading?
    @Published private(set) var selectedMetric: MetricIdentity = .cpu

    let sourceMode: MetricSourceMode
    private var selection = MetricSelectionState()
    private var isRunning = false

    init(sourceMode: MetricSourceMode) {
        self.sourceMode = sourceMode
    }

    func run(scene: TerrainScene) async {
        guard !isRunning else { return }
        isRunning = true
        latestCPUReading = nil
        latestMemoryReading = nil
        defer { isRunning = false }

        let producer: any MetricSnapshotProducer = switch sourceMode {
        case .live:
            ConcurrentMetricSnapshotProducer()
        case .synthetic:
            SyntheticMetricSnapshotProducer()
        }

        var cpuStartupGate = MetricStartupGate(sourceMode: sourceMode)
        var memoryStartupGate = MetricStartupGate(sourceMode: sourceMode)
        for await snapshot in makeMetricStream(producer: producer) {
            if Task.isCancelled { break }

            if let reading = cpuStartupGate.consume(snapshot.cpu) {
                scene.ingest(reading)
            }
            if let reading = memoryStartupGate.consume(snapshot.memory) {
                scene.ingest(reading)
            }
            latestCPUReading = snapshot.cpu
            latestMemoryReading = snapshot.memory
        }
    }

    func reading(for metric: MetricIdentity) -> MetricReading? {
        switch metric {
        case .cpu:
            latestCPUReading
        case .memory:
            latestMemoryReading
        }
    }

    func select(_ metric: MetricIdentity, in scene: TerrainScene) {
        let availability = reading(for: metric)?.availability ?? .unavailable
        var candidate = selection
        guard candidate.select(metric, availability: availability),
              scene.selectMetric(metric) else { return }

        selection = candidate
        selectedMetric = candidate.selectedMetric
    }
}
