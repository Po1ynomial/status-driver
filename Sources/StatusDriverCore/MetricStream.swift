import Foundation

package protocol MetricReadingProducer: Sendable {
    func reading(at timestamp: TimeInterval) async -> MetricReading
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
    producer: any MetricReadingProducer,
    clock: any SamplingClock = ContinuousSamplingClock(),
    interval: Duration = .milliseconds(150)
) -> AsyncStream<MetricReading> {
    AsyncStream(bufferingPolicy: .bufferingNewest(512)) { continuation in
        let task = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                let timestamp = await clock.elapsedTime()
                let reading = await producer.reading(at: timestamp)
                continuation.yield(reading)

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
    private var source: BoundedRandomWalkSource

    package init(initialValue: Double = 0.5) {
        source = BoundedRandomWalkSource(initialValue: initialValue)
    }

    package func reading(at timestamp: TimeInterval) -> MetricReading {
        let sample = source.nextSample(at: timestamp)
        return MetricReading(
            timestamp: timestamp,
            value: sample.value,
            source: .synthetic,
            availability: .available
        )
    }
}
