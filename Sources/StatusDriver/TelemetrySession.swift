import Combine
import StatusDriverCore

@MainActor
final class TelemetrySession: ObservableObject {
    @Published private(set) var latestCPUReading: MetricReading?
    @Published private(set) var latestMemoryReading: MetricReading?
    @Published private(set) var selectedResource: PerformanceResourceID = .cpu
    @Published private(set) var resources: [PerformanceResourceRecord] = [
        PerformanceResourceRecord(descriptor: .cpu),
        PerformanceResourceRecord(descriptor: .memory),
    ]
    @Published private(set) var easterEggEnabled = false
    @Published private(set) var hardwareProfile: PerformanceHardwareProfile?
    @Published private(set) var systemActivity: SystemActivitySnapshot?
    @Published private(set) var cpuHistory: [MetricSample] = []
    @Published private(set) var memoryHistory: [MetricSample] = []

    let sourceMode: MetricSourceMode
    private var selection = MetricSelectionState()
    private var inventory = PerformanceResourceInventory()
    private var easterEgg = EasterEggState()
    private var interfaceHistories = MetricHistoryStore(
        sampleInterval: 0.15,
        retentionDuration: 65
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
        interfaceHistories = MetricHistoryStore(sampleInterval: 0.15, retentionDuration: 65)
        hardwareProfile = await SystemHardwareProfileReader().readProfile()
        defer { isRunning = false }

        async let activityResult: Void = consumeSystemActivity()
        await consumeMetrics(scene: scene)
        _ = await activityResult
    }

    func reading(for resource: PerformanceResourceID) -> MetricReading? {
        switch resource {
        case .cpu:
            latestCPUReading
        case .memory:
            latestMemoryReading
        case .disk, .network, .gpu:
            nil
        }
    }

    func descriptor(for resource: PerformanceResourceID) -> PerformanceResourceDescriptor? {
        inventory.descriptor(for: resource)
    }

    func history(for resource: PerformanceResourceID) -> [MetricSample] {
        switch resource {
        case .cpu:
            cpuHistory
        case .memory:
            memoryHistory
        case .disk, .network, .gpu:
            []
        }
    }

    var activeEasterEggUtility: EasterEggUtility {
        guard let descriptor = descriptor(for: selectedResource) else { return .none }
        return easterEgg.activeUtility(for: descriptor)
    }

    func toggleEasterEgg() {
        easterEgg.toggle()
        easterEggEnabled = easterEgg.isEnabled
    }

    @discardableResult
    func select(_ resource: PerformanceResourceID) -> Bool {
        let availability = reading(for: resource)?.availability ?? .unavailable
        let hasHistory = switch resource {
        case .cpu:
            cpuHistory.count >= 2
        case .memory:
            memoryHistory.count >= 2
        case .disk, .network, .gpu:
            false
        }
        var candidate = selection
        guard hasHistory, candidate.select(resource, availability: availability) else {
            return false
        }

        selection = candidate
        selectedResource = candidate.selectedResource
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
        let update = interfaceHistories.ingestUpdate(reading)
        guard update.wasAccepted else { return }
        scene.ingest(reading)
        guard update == .historyChanged else { return }

        switch reading.resource {
        case .cpu:
            cpuHistory = interfaceHistories.samples(for: .cpu)
        case .memory:
            memoryHistory = interfaceHistories.samples(for: .memory)
        case .disk, .network, .gpu:
            break
        }
    }
}
