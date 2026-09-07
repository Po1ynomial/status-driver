import Foundation

package struct MetricSample: Equatable, Sendable {
    package let timestamp: TimeInterval
    package let value: Double

    package init(timestamp: TimeInterval, value: Double) {
        self.timestamp = timestamp
        self.value = value.isFinite ? min(max(value, 0), 1) : 0
    }
}

package protocol MetricSampleSource {
    mutating func nextSample(at timestamp: TimeInterval) -> MetricSample
}

package struct BoundedRandomWalkSource: MetricSampleSource {
    package private(set) var currentValue: Double
    private var generator = SystemRandomNumberGenerator()

    package init(initialValue: Double = 0.5) {
        currentValue = MetricSample(timestamp: 0, value: initialValue).value
    }

    package mutating func nextSample(at timestamp: TimeInterval) -> MetricSample {
        let pullTowardMiddle = (0.5 - currentValue) * 0.025
        let randomStep = Double.random(in: -0.035...0.035, using: &generator)
        currentValue = min(max(currentValue + pullTowardMiddle + randomStep, 0.04), 0.96)
        return MetricSample(timestamp: timestamp, value: currentValue)
    }
}
