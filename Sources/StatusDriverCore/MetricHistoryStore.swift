import Foundation

package enum MetricHistoryUpdate: Equatable, Sendable {
    case rejected
    case timelineAdvanced
    case historyChanged

    package var wasAccepted: Bool {
        self != .rejected
    }
}

package struct MetricHistoryStore {
    private let retentionDuration: TimeInterval
    private let chartInterval: TimeInterval
    private var buffers: [MetricIdentity: ChartSampleBuffer] = [:]

    package init(
        sampleInterval: TimeInterval,
        retentionDuration: TimeInterval,
        chartInterval: TimeInterval = 1
    ) {
        precondition(sampleInterval > 0)
        precondition(retentionDuration >= 0)
        precondition(chartInterval > 0)
        self.retentionDuration = retentionDuration
        self.chartInterval = chartInterval
    }

    @discardableResult
    package mutating func ingest(_ reading: MetricReading) -> Bool {
        ingestUpdate(reading).wasAccepted
    }

    @discardableResult
    package mutating func ingestUpdate(_ reading: MetricReading) -> MetricHistoryUpdate {
        var buffer = buffers[reading.metric] ?? ChartSampleBuffer()
        let update = buffer.ingest(
            reading.sample,
            chartInterval: chartInterval,
            retentionDuration: retentionDuration
        )
        if update.wasAccepted {
            buffers[reading.metric] = buffer
        }
        return update
    }

    package func samples(for metric: MetricIdentity) -> [MetricSample] {
        buffers[metric]?.samples ?? []
    }
}

private struct ChartSampleBuffer {
    private struct Bucket {
        let index: Int
        var sum: Double
        var count: Int
        var lastTimestamp: TimeInterval

        var average: Double {
            sum / Double(count)
        }
    }

    private var originTimestamp: TimeInterval?
    private var finalized: [MetricSample] = []
    private var activeBucket: Bucket?
    private var latestInputTimestamp: TimeInterval?

    var samples: [MetricSample] {
        finalized
    }

    mutating func ingest(
        _ sample: MetricSample,
        chartInterval: TimeInterval,
        retentionDuration: TimeInterval
    ) -> MetricHistoryUpdate {
        guard latestInputTimestamp.map({ sample.timestamp > $0 }) ?? true else {
            return .rejected
        }

        guard let originTimestamp, var activeBucket else {
            initialize(
                with: sample,
                chartInterval: chartInterval,
                retentionDuration: retentionDuration
            )
            return .historyChanged
        }

        latestInputTimestamp = sample.timestamp
        let bucketIndex = Int(floor((sample.timestamp - originTimestamp) / chartInterval))
        guard bucketIndex > activeBucket.index else {
            activeBucket.sum += sample.value
            activeBucket.count += 1
            activeBucket.lastTimestamp = sample.timestamp
            self.activeBucket = activeBucket
            return .timelineAdvanced
        }

        let finalizedSample = MetricSample(
            timestamp: activeBucket.lastTimestamp,
            value: activeBucket.average
        )
        if finalized.last?.timestamp == finalizedSample.timestamp {
            precondition(finalized.last?.value == finalizedSample.value)
        } else {
            finalized.append(finalizedSample)
        }

        self.activeBucket = Bucket(
            index: bucketIndex,
            sum: sample.value,
            count: 1,
            lastTimestamp: sample.timestamp
        )
        pruneFinalized(before: sample.timestamp - retentionDuration)
        return .historyChanged
    }

    private mutating func initialize(
        with sample: MetricSample,
        chartInterval: TimeInterval,
        retentionDuration: TimeInterval
    ) {
        originTimestamp = sample.timestamp
        let historyCount = Int(ceil(retentionDuration / chartInterval))
        if historyCount > 0 {
            for offset in stride(from: historyCount, through: 0, by: -1) {
                finalized.append(
                    MetricSample(
                        timestamp: sample.timestamp - Double(offset) * chartInterval,
                        value: sample.value
                    )
                )
            }
        } else {
            finalized.append(sample)
        }
        activeBucket = Bucket(
            index: 0,
            sum: sample.value,
            count: 1,
            lastTimestamp: sample.timestamp
        )
        latestInputTimestamp = sample.timestamp
    }

    private mutating func pruneFinalized(before cutoff: TimeInterval) {
        guard finalized.count > 1 else { return }
        let firstAtOrAfterCutoff = finalized.firstIndex { $0.timestamp >= cutoff }
            ?? finalized.endIndex
        let removalCount = max(0, firstAtOrAfterCutoff - 1)
        if removalCount > 0 {
            finalized.removeFirst(removalCount)
        }
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
