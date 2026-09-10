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
    @Published private(set) var resourceReadings: [PerformanceResourceID: MetricReading] = [:]
    @Published private(set) var resourceHistories: [PerformanceResourceID: [MetricSample]] = [:]
    @Published private(set) var diskTransferHistories:
        [PerformanceResourceID: [DiskTransferSample]] = [:]
    @Published private(set) var networkThroughputHistories:
        [PerformanceResourceID: [NetworkThroughputSample]] = [:]

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
        resourceReadings = [:]
        resourceHistories = [:]
        diskTransferHistories = [:]
        networkThroughputHistories = [:]
        interfaceHistories = MetricHistoryStore(sampleInterval: 0.15, retentionDuration: 65)
        hardwareProfile = await SystemHardwareProfileReader().readProfile()
        defer { isRunning = false }

        let telemetryClock: any SamplingClock = ContinuousSamplingClock()
        async let activityResult: Void = consumeSystemActivity(clock: telemetryClock)
        async let diskResult: Void = consumeDisks(scene: scene, clock: telemetryClock)
        async let networkResult: Void = consumeNetworks(clock: telemetryClock)
        async let gpuResult: Void = consumeGPU(scene: scene, clock: telemetryClock)
        await consumeMetrics(scene: scene, clock: telemetryClock)
        _ = await activityResult
        _ = await diskResult
        _ = await networkResult
        _ = await gpuResult
    }

    func reading(for resource: PerformanceResourceID) -> MetricReading? {
        let reading: MetricReading? = switch resource {
        case .cpu:
            latestCPUReading
        case .memory:
            latestMemoryReading
        case .disk:
            resourceReadings[resource]
        case .network, .gpu:
            resourceReadings[resource]
        }
        guard let reading,
              let record = resources.first(where: { $0.id == resource }),
              record.availability != .available else {
            return reading
        }
        return MetricReading(
            timestamp: reading.timestamp,
            value: reading.value,
            resource: reading.resource,
            availability: .unavailable,
            details: reading.details
        )
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
            resourceHistories[resource] ?? []
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
        let descriptor = descriptor(for: resource)
        let hasHistory = descriptor?.graphKind == .adaptiveNonphysical || {
            switch resource {
            case .cpu:
                cpuHistory.count >= 2
            case .memory:
                memoryHistory.count >= 2
            case .disk, .network, .gpu:
                (resourceHistories[resource]?.count ?? 0) >= 2
            }
        }()
        var candidate = selection
        guard hasHistory, candidate.select(resource, availability: availability) else {
            return false
        }

        selection = candidate
        selectedResource = candidate.selectedResource
        return true
    }

    private func consumeMetrics(scene: TerrainScene, clock: any SamplingClock) async {
        let producer: any MetricSnapshotProducer = switch sourceMode {
        case .live:
            ConcurrentMetricSnapshotProducer()
        case .synthetic:
            SyntheticMetricSnapshotProducer()
        }

        var cpuStartupGate = MetricStartupGate(sourceMode: sourceMode)
        var memoryStartupGate = MetricStartupGate(sourceMode: sourceMode)
        for await snapshot in makeMetricStream(producer: producer, clock: clock) {
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

    private func consumeSystemActivity(clock: any SamplingClock) async {
        for await activity in makeSystemActivityStream(clock: clock) {
            if Task.isCancelled { break }
            systemActivity = activity
        }
    }

    private func consumeDisks(scene: TerrainScene, clock: any SamplingClock) async {
        let liveMonitor = DiskMonitor()
        let syntheticMonitor = SyntheticDiskMonitor()

        while !Task.isCancelled {
            let timestamp = await clock.elapsedTime()
            let update: DiskMonitorUpdate
            switch sourceMode {
            case .live:
                update = await liveMonitor.sample(at: timestamp)
            case .synthetic:
                update = await syntheticMonitor.sample(at: timestamp)
            }
            reconcileDiskResources(update.descriptors)
            for reading in update.readings {
                resourceReadings[reading.resource] = reading
                ingest(reading, into: scene)
                appendDiskTransfer(reading)
            }

            do {
                try await clock.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
    }

    private func consumeNetworks(clock: any SamplingClock) async {
        let liveMonitor = NetworkMonitor()
        let syntheticMonitor = SyntheticNetworkMonitor()

        while !Task.isCancelled {
            let timestamp = await clock.elapsedTime()
            let update: NetworkMonitorUpdate
            switch sourceMode {
            case .live:
                update = await liveMonitor.sample(at: timestamp)
            case .synthetic:
                update = await syntheticMonitor.sample(at: timestamp)
            }
            reconcileNetworkResources(update.descriptors)
            for reading in update.readings {
                resourceReadings[reading.resource] = reading
                if case let .network(details)? = reading.details {
                    inventory.setAvailability(
                        details.isConnected ? .available : .disconnected,
                        for: reading.resource
                    )
                }
                appendNetworkThroughput(reading)
            }
            resources = inventory.records

            do {
                try await clock.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
    }

    private func consumeGPU(scene: TerrainScene, clock: any SamplingClock) async {
        let liveMonitor = GPUMonitor()
        let syntheticMonitor = SyntheticGPUMonitor()

        while !Task.isCancelled {
            let timestamp = await clock.elapsedTime()
            let update: GPUMonitorUpdate
            switch sourceMode {
            case .live:
                update = await liveMonitor.sample(at: timestamp)
            case .synthetic:
                update = await syntheticMonitor.sample(at: timestamp)
            }
            reconcileGPUResource(update.descriptor)
            if let reading = update.reading {
                resourceReadings[reading.resource] = reading
                ingest(reading, into: scene)
                inventory.setAvailability(
                    reading.availability == .available ? .available : .unavailable,
                    for: reading.resource
                )
                resources = inventory.records
            }

            do {
                try await clock.sleep(for: .seconds(1))
            } catch {
                break
            }
        }
    }

    private func reconcileDiskResources(_ descriptors: [PerformanceResourceDescriptor]) {
        inventory.reconcile(
            discovered: descriptors,
            managedKinds: [.disk],
            selectedResource: selectedResource
        )
        resources = inventory.records
    }

    private func reconcileNetworkResources(_ descriptors: [PerformanceResourceDescriptor]) {
        inventory.reconcile(
            discovered: descriptors,
            managedKinds: [.network],
            selectedResource: selectedResource
        )
        for descriptor in descriptors {
            if let reading = resourceReadings[descriptor.id],
               case let .network(details)? = reading.details,
               !details.isConnected {
                inventory.setAvailability(.disconnected, for: descriptor.id)
            }
        }
        resources = inventory.records
    }

    private func reconcileGPUResource(_ descriptor: PerformanceResourceDescriptor?) {
        inventory.reconcile(
            discovered: descriptor.map { [$0] } ?? [],
            managedKinds: [.gpu],
            selectedResource: selectedResource
        )
        resources = inventory.records
    }

    private func appendDiskTransfer(_ reading: MetricReading) {
        guard case let .disk(details)? = reading.details else { return }
        var samples = diskTransferHistories[reading.resource] ?? []
        samples.append(
            DiskTransferSample(
                timestamp: reading.timestamp,
                readBytesPerSecond: details.readBytesPerSecond,
                writeBytesPerSecond: details.writeBytesPerSecond
            )
        )
        samples.removeAll { $0.timestamp < reading.timestamp - 60 }
        diskTransferHistories[reading.resource] = samples
    }

    private func appendNetworkThroughput(_ reading: MetricReading) {
        guard case let .network(details)? = reading.details else { return }
        var samples = networkThroughputHistories[reading.resource] ?? []
        samples.append(
            NetworkThroughputSample(
                timestamp: reading.timestamp,
                receiveBytesPerSecond: details.receiveBytesPerSecond,
                sendBytesPerSecond: details.sendBytesPerSecond
            )
        )
        samples.removeAll { $0.timestamp < reading.timestamp - 60 }
        networkThroughputHistories[reading.resource] = samples
    }

    private func ingest(_ reading: MetricReading, into scene: TerrainScene) {
        let historyInput: MetricHistoryInput = switch reading.resource {
        case .cpu, .memory:
            .readings
        case .disk, .network, .gpu:
            .committedSamples
        }
        let update = interfaceHistories.ingestUpdate(reading, input: historyInput)
        guard update.wasAccepted else { return }
        scene.ingest(reading, historyInput: historyInput)
        guard update == .historyChanged else { return }

        switch reading.resource {
        case .cpu:
            cpuHistory = interfaceHistories.samples(for: .cpu)
        case .memory:
            memoryHistory = interfaceHistories.samples(for: .memory)
        case .disk, .network, .gpu:
            resourceHistories[reading.resource] = interfaceHistories.samples(for: reading.resource)
        }
    }
}
