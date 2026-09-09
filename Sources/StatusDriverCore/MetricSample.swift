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
    private var generator: SeededRandomNumberGenerator

    package init(initialValue: Double = 0.5, seed: UInt64 = 0x535441545553) {
        currentValue = MetricSample(timestamp: 0, value: initialValue).value
        generator = SeededRandomNumberGenerator(seed: seed)
    }

    package mutating func nextSample(at timestamp: TimeInterval) -> MetricSample {
        let pullTowardMiddle = (0.5 - currentValue) * 0.025
        let randomStep = Double.random(in: -0.035...0.035, using: &generator)
        currentValue = min(max(currentValue + pullTowardMiddle + randomStep, 0.04), 0.96)
        return MetricSample(timestamp: timestamp, value: currentValue)
    }
}

private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
