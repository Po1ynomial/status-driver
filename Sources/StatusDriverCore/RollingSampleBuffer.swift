import Foundation

package struct RollingSampleBuffer {
    package private(set) var samples: [MetricSample] = []

    package init() {}

    package mutating func prefill(
        endingAt timestamp: TimeInterval,
        value: Double,
        interval: TimeInterval,
        duration: TimeInterval
    ) {
        precondition(interval > 0)
        precondition(duration >= 0)

        samples.removeAll(keepingCapacity: true)
        let segmentCount = max(1, Int(ceil(duration / interval)))
        let startTimestamp = timestamp - Double(segmentCount) * interval
        for index in 0...segmentCount {
            append(
                MetricSample(
                    timestamp: startTimestamp + Double(index) * interval,
                    value: value
                )
            )
        }
    }

    package mutating func append(_ sample: MetricSample) {
        precondition(
            samples.last.map { sample.timestamp > $0.timestamp } ?? true,
            "Metric samples must have increasing timestamps"
        )
        samples.append(sample)
    }

    package mutating func prune(before cutoff: TimeInterval) {
        guard samples.count > 2 else { return }

        let firstAtOrAfterCutoff = samples.firstIndex { $0.timestamp >= cutoff } ?? samples.endIndex
        let removalCount = max(0, firstAtOrAfterCutoff - 1)
        if removalCount > 0 {
            samples.removeFirst(removalCount)
        }
    }
}
