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
