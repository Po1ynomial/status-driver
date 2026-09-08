import Foundation

package enum MetricIdentity: String, Equatable, Hashable, Sendable {
    case cpu
    case memory
}

package enum MetricAvailability: Equatable, Sendable {
    case available
    case unavailable
}

package enum MetricReadingDetails: Equatable, Sendable {
    case memory(MemoryDetails)
}

package struct MetricReading: Equatable, Sendable {
    package let timestamp: TimeInterval
    package let value: Double
    package let metric: MetricIdentity
    package let availability: MetricAvailability
    package let details: MetricReadingDetails?

    package init(
        timestamp: TimeInterval,
        value: Double,
        metric: MetricIdentity,
        availability: MetricAvailability,
        details: MetricReadingDetails? = nil
    ) {
        self.timestamp = timestamp
        self.value = value.isFinite ? min(max(value, 0), 1) : 0
        self.metric = metric
        self.availability = availability
        self.details = details
    }

    package var sample: MetricSample {
        MetricSample(timestamp: timestamp, value: value)
    }
}

package struct MetricSnapshot: Equatable, Sendable {
    package let timestamp: TimeInterval
    package let cpu: MetricReading
    package let memory: MetricReading

    package init(timestamp: TimeInterval, cpu: MetricReading, memory: MetricReading) {
        precondition(cpu.metric == .cpu)
        precondition(memory.metric == .memory)
        precondition(cpu.timestamp == timestamp && memory.timestamp == timestamp)
        self.timestamp = timestamp
        self.cpu = cpu
        self.memory = memory
    }
}

package enum MetricSourceMode: Equatable, Sendable {
    case live
    case synthetic

    package init(arguments: [String]) {
        self = arguments.contains("--synthetic") ? .synthetic : .live
    }
}

package struct MetricStartupGate: Sendable {
    private let sourceMode: MetricSourceMode
    private let unavailableGracePeriod: TimeInterval
    private var firstTimestamp: TimeInterval?
    private var hasOpened = false

    package init(
        sourceMode: MetricSourceMode,
        unavailableGracePeriod: TimeInterval = 0.3
    ) {
        self.sourceMode = sourceMode
        self.unavailableGracePeriod = unavailableGracePeriod
    }

    package mutating func consume(_ reading: MetricReading) -> MetricReading? {
        guard !hasOpened else { return reading }

        if sourceMode == .synthetic || reading.availability == .available {
            hasOpened = true
            return reading
        }

        let start = firstTimestamp ?? reading.timestamp
        firstTimestamp = start
        if reading.timestamp - start >= unavailableGracePeriod {
            hasOpened = true
            return reading
        }
        return nil
    }
}
