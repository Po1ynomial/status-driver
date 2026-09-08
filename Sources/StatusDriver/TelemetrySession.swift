import Combine
import StatusDriverCore

@MainActor
final class TelemetrySession: ObservableObject {
    @Published private(set) var latestCPUReading: MetricReading?
    @Published private(set) var latestMemoryReading: MetricReading?
    @Published private(set) var selectedMetric: MetricIdentity = .cpu
    @Published private(set) var hardwareProfile: PerformanceHardwareProfile?
    @Published private(set) var systemActivity: SystemActivitySnapshot?
    @Published private(set) var cpuHistory: [MetricSample] = []
    @Published private(set) var memoryHistory: [MetricSample] = []

    let sourceMode: MetricSourceMode
    private var selection = MetricSelectionState()
    private var interfaceHistories = MetricHistoryStore(
        sampleInterval: 0.15,
        retentionDuration: 60
    )
    private var isRunning = false

    init(sourceMode: MetricSourceMode) {
        self.sourceMode = sourceMode
    }

    func run(scene: TerrainScene) async {
        guard !isRunning else { return }
        isRunning = true
        latestCPUReading = nil
        latestMemoryReading = nil
        cpuHistory = []
        memoryHistory = []
        interfaceHistories = MetricHistoryStore(sampleInterval: 0.15, retentionDuration: 60)
        hardwareProfile = await SystemHardwareProfileReader().readProfile()
        defer { isRunning = false }

        async let activityResult: Void = consumeSystemActivity()
        await consumeMetrics(scene: scene)
        _ = await activityResult
    }

    func reading(for metric: MetricIdentity) -> MetricReading? {
        switch metric {
        case .cpu:
            latestCPUReading
        case .memory:
            latestMemoryReading
        }
    }

    @discardableResult
    func select(_ metric: MetricIdentity) -> Bool {
        let availability = reading(for: metric)?.availability ?? .unavailable
        let hasHistory = switch metric {
        case .cpu:
            cpuHistory.count >= 2
        case .memory:
            memoryHistory.count >= 2
        }
        var candidate = selection
        guard hasHistory, candidate.select(metric, availability: availability) else {
            return false
        }

        selection = candidate
        selectedMetric = candidate.selectedMetric
        return true
    }

    private func consumeMetrics(scene: TerrainScene) async {
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
                ingest(reading, into: scene)
            }
            if let reading = memoryStartupGate.consume(snapshot.memory) {
                ingest(reading, into: scene)
            }
            latestCPUReading = snapshot.cpu
            latestMemoryReading = snapshot.memory
        }
    }

    private func consumeSystemActivity() async {
        for await activity in makeSystemActivityStream() {
            if Task.isCancelled { break }
            systemActivity = activity
        }
    }

    private func ingest(_ reading: MetricReading, into scene: TerrainScene) {
        guard interfaceHistories.ingest(reading) else { return }
        scene.ingest(reading)

        switch reading.metric {
        case .cpu:
            cpuHistory = interfaceHistories.samples(for: .cpu)
        case .memory:
            memoryHistory = interfaceHistories.samples(for: .memory)
        }
    }
}
