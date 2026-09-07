import Foundation

package struct RollingSampleBuffer {
    package private(set) var samples: [MetricSample] = []

    package init() {}

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
