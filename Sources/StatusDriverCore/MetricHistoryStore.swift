import Foundation

package struct MetricHistoryStore {
    private let sampleInterval: TimeInterval
    private let retentionDuration: TimeInterval
    private var buffers: [MetricIdentity: RollingSampleBuffer] = [:]

    package init(sampleInterval: TimeInterval, retentionDuration: TimeInterval) {
        precondition(sampleInterval > 0)
        precondition(retentionDuration >= 0)
        self.sampleInterval = sampleInterval
        self.retentionDuration = retentionDuration
    }

    @discardableResult
    package mutating func ingest(_ reading: MetricReading) -> Bool {
        var buffer = buffers[reading.metric] ?? RollingSampleBuffer()
        guard buffer.samples.last.map({ reading.timestamp > $0.timestamp }) ?? true else {
            return false
        }

        if buffer.samples.isEmpty {
            buffer.prefill(
                endingAt: reading.timestamp,
                value: reading.value,
                interval: sampleInterval,
                duration: retentionDuration
            )
        } else {
            buffer.append(reading.sample)
            buffer.prune(before: reading.timestamp - retentionDuration)
        }
        buffers[reading.metric] = buffer
        return true
    }

    package func samples(for metric: MetricIdentity) -> [MetricSample] {
        buffers[metric]?.samples ?? []
    }
}

package struct MetricSelectionState: Equatable, Sendable {
    package private(set) var selectedMetric: MetricIdentity

    package init(selectedMetric: MetricIdentity = .cpu) {
        self.selectedMetric = selectedMetric
    }

    @discardableResult
    package mutating func select(
        _ metric: MetricIdentity,
        availability: MetricAvailability
    ) -> Bool {
        guard metric != selectedMetric, availability == .available else {
            return false
        }
        selectedMetric = metric
        return true
    }
}

package func metricSelection(forKeyCode keyCode: UInt16) -> MetricIdentity? {
    switch keyCode {
    case 18:
        .cpu
    case 19:
        .memory
    default:
        nil
    }
}
