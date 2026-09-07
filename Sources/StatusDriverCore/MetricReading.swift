import Foundation

package enum MetricSourceIdentity: String, Equatable, Sendable {
    case cpu
    case synthetic
}

package enum MetricAvailability: Equatable, Sendable {
    case available
    case unavailable
}

package struct MetricReading: Equatable, Sendable {
    package let timestamp: TimeInterval
    package let value: Double
    package let source: MetricSourceIdentity
    package let availability: MetricAvailability

    package init(
        timestamp: TimeInterval,
        value: Double,
        source: MetricSourceIdentity,
        availability: MetricAvailability
    ) {
        self.timestamp = timestamp
        self.value = value.isFinite ? min(max(value, 0), 1) : 0
        self.source = source
        self.availability = availability
    }

    package var sample: MetricSample {
        MetricSample(timestamp: timestamp, value: value)
    }
}

package enum MetricSourceMode: Equatable, Sendable {
    case cpu
    case synthetic

    package init(arguments: [String]) {
        self = arguments.contains("--synthetic") ? .synthetic : .cpu
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
