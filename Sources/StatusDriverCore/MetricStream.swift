import Foundation

package protocol MetricReadingProducer: Sendable {
    func reading(at timestamp: TimeInterval) async -> MetricReading
}

package protocol MetricSnapshotProducer: Sendable {
    func snapshot(at timestamp: TimeInterval) async -> MetricSnapshot
}

package struct ConcurrentMetricSnapshotProducer: MetricSnapshotProducer {
    private let cpuProducer: any MetricReadingProducer
    private let memoryProducer: any MetricReadingProducer

    package init(
        cpuProducer: any MetricReadingProducer = CPUMetricProducer(),
        memoryProducer: any MetricReadingProducer = MemoryMetricProducer()
    ) {
        self.cpuProducer = cpuProducer
        self.memoryProducer = memoryProducer
    }

    package func snapshot(at timestamp: TimeInterval) async -> MetricSnapshot {
        async let cpu = cpuProducer.reading(at: timestamp)
        async let memory = memoryProducer.reading(at: timestamp)
        return await MetricSnapshot(timestamp: timestamp, cpu: cpu, memory: memory)
    }
}

package struct SyntheticMetricSnapshotProducer: MetricSnapshotProducer {
    private let cpuProducer: SyntheticMetricProducer
    private let memoryProducer: SyntheticMetricProducer

    package init(cpuInitialValue: Double = 0.45, memoryInitialValue: Double = 0.70) {
        cpuProducer = SyntheticMetricProducer(metric: .cpu, initialValue: cpuInitialValue)
        memoryProducer = SyntheticMetricProducer(metric: .memory, initialValue: memoryInitialValue)
    }

    package func snapshot(at timestamp: TimeInterval) async -> MetricSnapshot {
        async let cpu = cpuProducer.reading(at: timestamp)
        async let memory = memoryProducer.reading(at: timestamp)
        return await MetricSnapshot(timestamp: timestamp, cpu: cpu, memory: memory)
    }
}

package protocol SamplingClock: Sendable {
    func elapsedTime() async -> TimeInterval
    func sleep(for duration: Duration) async throws
}

package struct ContinuousSamplingClock: SamplingClock {
    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant

    package init() {
        origin = clock.now
    }

    package func elapsedTime() async -> TimeInterval {
        let components = origin.duration(to: clock.now).components
        return Double(components.seconds) + Double(components.attoseconds) / 1e18
    }

    package func sleep(for duration: Duration) async throws {
        try await clock.sleep(for: duration)
    }
}

package func makeMetricStream(
    producer: any MetricSnapshotProducer,
    clock: any SamplingClock = ContinuousSamplingClock(),
    interval: Duration = .milliseconds(150)
) -> AsyncStream<MetricSnapshot> {
    AsyncStream(bufferingPolicy: .bufferingNewest(512)) { continuation in
        let task = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                let timestamp = await clock.elapsedTime()
                let snapshot = await producer.snapshot(at: timestamp)
                continuation.yield(snapshot)

                do {
                    try await clock.sleep(for: interval)
                } catch {
                    break
                }
            }
            continuation.finish()
        }

        continuation.onTermination = { @Sendable _ in
            task.cancel()
        }
    }
}

package actor SyntheticMetricProducer: MetricReadingProducer {
    private let metric: MetricIdentity
    private var source: BoundedRandomWalkSource

    package init(metric: MetricIdentity, initialValue: Double) {
        self.metric = metric
        source = BoundedRandomWalkSource(initialValue: initialValue)
    }

    package func reading(at timestamp: TimeInterval) -> MetricReading {
        let sample = source.nextSample(at: timestamp)
        return MetricReading(
            timestamp: timestamp,
            value: sample.value,
            metric: metric,
            availability: .available
        )
    }
}
