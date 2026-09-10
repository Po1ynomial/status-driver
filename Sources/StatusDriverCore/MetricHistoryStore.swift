import Foundation

package enum MetricHistoryUpdate: Equatable, Sendable {
    case rejected
    case timelineAdvanced
    case historyChanged

    package var wasAccepted: Bool {
        self != .rejected
    }
}

package enum MetricHistoryInput: Equatable, Sendable {
    case readings
    case committedSamples
}

package struct MetricHistoryStore {
    private let retentionDuration: TimeInterval
    private let chartInterval: TimeInterval
    private var inputKinds: [PerformanceResourceID: MetricHistoryInput] = [:]
    private var chartBuffers: [PerformanceResourceID: ChartSampleBuffer] = [:]
    private var committedBuffers: [PerformanceResourceID: CommittedSampleBuffer] = [:]

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
    package mutating func ingest(
        _ reading: MetricReading,
        input: MetricHistoryInput = .readings
    ) -> Bool {
        ingestUpdate(reading, input: input).wasAccepted
    }

    @discardableResult
    package mutating func ingestUpdate(
        _ reading: MetricReading,
        input: MetricHistoryInput = .readings
    ) -> MetricHistoryUpdate {
        precondition(
            inputKinds[reading.resource].map { $0 == input } ?? true,
            "A resource cannot change history input kind"
        )

        let update: MetricHistoryUpdate
        switch input {
        case .readings:
            var buffer = chartBuffers[reading.resource] ?? ChartSampleBuffer()
            update = buffer.ingest(
                reading.sample,
                chartInterval: chartInterval,
                retentionDuration: retentionDuration
            )
            if update.wasAccepted {
                chartBuffers[reading.resource] = buffer
            }
        case .committedSamples:
            var buffer = committedBuffers[reading.resource] ?? CommittedSampleBuffer()
            update = buffer.ingest(
                reading.sample,
                chartInterval: chartInterval,
                retentionDuration: retentionDuration
            )
            if update.wasAccepted {
                committedBuffers[reading.resource] = buffer
            }
        }

        if update.wasAccepted {
            inputKinds[reading.resource] = input
        }
        return update
    }

    package func samples(for resource: PerformanceResourceID) -> [MetricSample] {
        switch inputKinds[resource] {
        case .readings:
            chartBuffers[resource]?.samples ?? []
        case .committedSamples:
            committedBuffers[resource]?.samples ?? []
        case nil:
            []
        }
    }
}

private struct CommittedSampleBuffer {
    private var buffer = RollingSampleBuffer()

    var samples: [MetricSample] {
        buffer.samples
    }

    mutating func ingest(
        _ sample: MetricSample,
        chartInterval: TimeInterval,
        retentionDuration: TimeInterval
    ) -> MetricHistoryUpdate {
        guard buffer.samples.last.map({ sample.timestamp > $0.timestamp }) ?? true else {
            return .rejected
        }

        if buffer.samples.isEmpty {
            buffer.prefill(
                endingAt: sample.timestamp,
                value: sample.value,
                interval: chartInterval,
                duration: retentionDuration
            )
        } else {
            buffer.append(sample)
            buffer.prune(before: sample.timestamp - retentionDuration)
        }
        return .historyChanged
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
    package private(set) var selectedResource: PerformanceResourceID

    package init(selectedResource: PerformanceResourceID = .cpu) {
        self.selectedResource = selectedResource
    }

    @discardableResult
    package mutating func select(
        _ resource: PerformanceResourceID,
        availability: MetricAvailability
    ) -> Bool {
        guard resource != selectedResource, availability == .available else {
            return false
        }
        selectedResource = resource
        return true
    }
}
