import Foundation

package actor SyntheticDiskMonitor {
    private let identity = DiskIdentity(
        registryID: 0xD15C,
        bsdName: "synthetic-disk0",
        model: "Synthetic SSD",
        capacityBytes: 1_000_000_000_000,
        isSolidState: true,
        isRemovable: false,
        isSystemDisk: true
    )
    private var activitySource = BoundedRandomWalkSource(initialValue: 0.18, seed: 0xD15C)
    private var scale = AdaptiveScale(
        ladder: [
            1_000_000,
            10_000_000,
            100_000_000,
            500_000_000,
            1_000_000_000,
            2_000_000_000,
            5_000_000_000,
            10_000_000_000,
        ],
        initialCeiling: 100_000_000
    )

    package init() {}

    package func sample(at timestamp: TimeInterval) -> DiskMonitorUpdate {
        let activity = activitySource.nextSample(at: timestamp).value
        let totalRate = activity * 240_000_000
        let readRate = totalRate * 0.62
        let writeRate = totalRate * 0.38
        let readOperations = readRate / 65_536
        let writeOperations = writeRate / 65_536
        _ = scale.update(maximumValue: max(readRate, writeRate), at: timestamp)
        let operationCount = max(1, readOperations + writeOperations)

        let details = DiskDetails(
            identity: identity,
            activity: activity,
            readBytesPerSecond: readRate,
            writeBytesPerSecond: writeRate,
            readOperationsPerSecond: readOperations,
            writeOperationsPerSecond: writeOperations,
            averageResponseMilliseconds: activity * 1_000 / operationCount,
            readErrorDelta: 0,
            writeErrorDelta: 0,
            transferCeilingBytesPerSecond: scale.ceiling
        )
        let reading = MetricReading(
            timestamp: timestamp,
            value: activity,
            resource: identity.resourceID,
            availability: .available,
            details: .disk(details)
        )
        let descriptor = PerformanceResourceDescriptor(
            id: identity.resourceID,
            title: "Disk 0",
            subtitle: "SSD",
            kind: .disk,
            colorRole: .disk,
            graphKind: .physicalFixed,
            easterEggUtility: .tetromino
        )
        return DiskMonitorUpdate(descriptors: [descriptor], readings: [reading])
    }
}
