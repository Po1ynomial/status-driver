import Foundation
import IOKit
import IOKit.storage

package struct DiskIdentity: Equatable, Sendable {
    package let registryID: UInt64
    package let bsdName: String
    package let model: String
    package let capacityBytes: UInt64
    package let isSolidState: Bool?
    package let isRemovable: Bool
    package let isSystemDisk: Bool

    package var resourceID: PerformanceResourceID {
        .disk(registryID: registryID, bsdName: bsdName)
    }

    package init(
        registryID: UInt64,
        bsdName: String,
        model: String,
        capacityBytes: UInt64,
        isSolidState: Bool?,
        isRemovable: Bool,
        isSystemDisk: Bool
    ) {
        self.registryID = registryID
        self.bsdName = bsdName
        self.model = model
        self.capacityBytes = capacityBytes
        self.isSolidState = isSolidState
        self.isRemovable = isRemovable
        self.isSystemDisk = isSystemDisk
    }
}

package struct DiskCounters: Equatable, Sendable {
    package let bytesRead: UInt64
    package let bytesWritten: UInt64
    package let readOperations: UInt64
    package let writeOperations: UInt64
    package let readTimeNanoseconds: UInt64
    package let writeTimeNanoseconds: UInt64
    package let readErrors: UInt64
    package let writeErrors: UInt64

    package init(
        bytesRead: UInt64,
        bytesWritten: UInt64,
        readOperations: UInt64,
        writeOperations: UInt64,
        readTimeNanoseconds: UInt64,
        writeTimeNanoseconds: UInt64,
        readErrors: UInt64,
        writeErrors: UInt64
    ) {
        self.bytesRead = bytesRead
        self.bytesWritten = bytesWritten
        self.readOperations = readOperations
        self.writeOperations = writeOperations
        self.readTimeNanoseconds = readTimeNanoseconds
        self.writeTimeNanoseconds = writeTimeNanoseconds
        self.readErrors = readErrors
        self.writeErrors = writeErrors
    }
}

package struct DiskDeviceSnapshot: Equatable, Sendable {
    package let identity: DiskIdentity
    package let counters: DiskCounters

    package init(identity: DiskIdentity, counters: DiskCounters) {
        self.identity = identity
        self.counters = counters
    }
}

package struct DiskDetails: Equatable, Sendable {
    package let identity: DiskIdentity
    package let activity: Double
    package let readBytesPerSecond: Double
    package let writeBytesPerSecond: Double
    package let readOperationsPerSecond: Double
    package let writeOperationsPerSecond: Double
    package let averageResponseMilliseconds: Double?
    package let readErrorDelta: UInt64
    package let writeErrorDelta: UInt64
    package let transferCeilingBytesPerSecond: Double

    package init(
        identity: DiskIdentity,
        activity: Double,
        readBytesPerSecond: Double,
        writeBytesPerSecond: Double,
        readOperationsPerSecond: Double,
        writeOperationsPerSecond: Double,
        averageResponseMilliseconds: Double?,
        readErrorDelta: UInt64,
        writeErrorDelta: UInt64,
        transferCeilingBytesPerSecond: Double
    ) {
        self.identity = identity
        self.activity = activity
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
        self.readOperationsPerSecond = readOperationsPerSecond
        self.writeOperationsPerSecond = writeOperationsPerSecond
        self.averageResponseMilliseconds = averageResponseMilliseconds
        self.readErrorDelta = readErrorDelta
        self.writeErrorDelta = writeErrorDelta
        self.transferCeilingBytesPerSecond = transferCeilingBytesPerSecond
    }
}

package struct DiskTransferSample: Equatable, Sendable {
    package let timestamp: TimeInterval
    package let readBytesPerSecond: Double
    package let writeBytesPerSecond: Double

    package init(
        timestamp: TimeInterval,
        readBytesPerSecond: Double,
        writeBytesPerSecond: Double
    ) {
        self.timestamp = timestamp
        self.readBytesPerSecond = readBytesPerSecond
        self.writeBytesPerSecond = writeBytesPerSecond
    }
}

package enum DiskReadError: Error, Equatable, Sendable {
    case unavailable
}

package protocol DiskDiscovering: Sendable {
    func discover() async -> [DiskDeviceSnapshot]
}

package struct IOKitDiskDiscovery: DiskDiscovering {
    package init() {}

    package func discover() async -> [DiskDeviceSnapshot] {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching(kIOBlockStorageDriverClass),
            &iterator
        ) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var snapshots: [DiskDeviceSnapshot] = []
        var service = IOIteratorNext(iterator)
        while service != 0 {
            if let snapshot = diskSnapshot(for: service) {
                snapshots.append(snapshot)
            }
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }

        let nonRemovableCount = snapshots.filter { !$0.identity.isRemovable }.count
        return snapshots.map { snapshot in
            guard nonRemovableCount == 1, !snapshot.identity.isRemovable else { return snapshot }
            let identity = snapshot.identity
            return DiskDeviceSnapshot(
                identity: DiskIdentity(
                    registryID: identity.registryID,
                    bsdName: identity.bsdName,
                    model: identity.model,
                    capacityBytes: identity.capacityBytes,
                    isSolidState: identity.isSolidState,
                    isRemovable: identity.isRemovable,
                    isSystemDisk: true
                ),
                counters: snapshot.counters
            )
        }
        .sorted { $0.identity.bsdName < $1.identity.bsdName }
    }

    private func diskSnapshot(for service: io_registry_entry_t) -> DiskDeviceSnapshot? {
        guard let driverProperties = properties(of: service),
              let statistics = driverProperties[kIOBlockStorageDriverStatisticsKey] as? NSDictionary,
              let media = wholeMedia(below: service) else {
            return nil
        }
        defer { IOObjectRelease(media) }

        var registryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS,
              let mediaProperties = properties(of: media),
              let bsdName = mediaProperties[kIOBSDNameKey] as? String,
              let capacity = uint64(mediaProperties[kIOMediaSizeKey]) else {
            return nil
        }

        let model = registryName(media) ?? bsdName
        let isRemovable = (mediaProperties[kIOMediaRemovableKey] as? Bool) ?? false
        let isSolidState = (driverProperties[kIOPropertyMediumTypeKey] as? String).map {
            $0.localizedCaseInsensitiveContains("solid")
        } ?? (!isRemovable ? true : nil)

        guard let counters = counters(from: statistics) else { return nil }
        return DiskDeviceSnapshot(
            identity: DiskIdentity(
                registryID: registryID,
                bsdName: bsdName,
                model: model,
                capacityBytes: capacity,
                isSolidState: isSolidState,
                isRemovable: isRemovable,
                isSystemDisk: false
            ),
            counters: counters
        )
    }

    private func wholeMedia(below service: io_registry_entry_t) -> io_registry_entry_t? {
        var iterator: io_iterator_t = 0
        guard IORegistryEntryCreateIterator(
            service,
            kIOServicePlane,
            IOOptionBits(kIORegistryIterateRecursively),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var child = IOIteratorNext(iterator)
        while child != 0 {
            if let properties = properties(of: child),
               (properties[kIOMediaWholeKey] as? Bool) == true,
               properties[kIOBSDNameKey] is String {
                return child
            }
            IOObjectRelease(child)
            child = IOIteratorNext(iterator)
        }
        return nil
    }

    private func counters(from statistics: NSDictionary) -> DiskCounters? {
        guard let bytesRead = uint64(statistics[kIOBlockStorageDriverStatisticsBytesReadKey]),
              let bytesWritten = uint64(statistics[kIOBlockStorageDriverStatisticsBytesWrittenKey]),
              let reads = uint64(statistics[kIOBlockStorageDriverStatisticsReadsKey]),
              let writes = uint64(statistics[kIOBlockStorageDriverStatisticsWritesKey]),
              let readTime = uint64(statistics[kIOBlockStorageDriverStatisticsTotalReadTimeKey]),
              let writeTime = uint64(statistics[kIOBlockStorageDriverStatisticsTotalWriteTimeKey]) else {
            return nil
        }
        return DiskCounters(
            bytesRead: bytesRead,
            bytesWritten: bytesWritten,
            readOperations: reads,
            writeOperations: writes,
            readTimeNanoseconds: readTime,
            writeTimeNanoseconds: writeTime,
            readErrors: uint64(statistics[kIOBlockStorageDriverStatisticsReadErrorsKey]) ?? 0,
            writeErrors: uint64(statistics[kIOBlockStorageDriverStatisticsWriteErrorsKey]) ?? 0
        )
    }

    private func properties(of entry: io_registry_entry_t) -> NSDictionary? {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            entry,
            &unmanaged,
            kCFAllocatorDefault,
            0
        ) == KERN_SUCCESS else {
            return nil
        }
        return unmanaged?.takeRetainedValue() as NSDictionary?
    }

    private func registryName(_ entry: io_registry_entry_t) -> String? {
        var name = [CChar](repeating: 0, count: 128)
        guard IORegistryEntryGetName(entry, &name) == KERN_SUCCESS else { return nil }
        let bytes = name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }

    private func uint64(_ value: Any?) -> UInt64? {
        (value as? NSNumber)?.uint64Value
    }
}

package struct DiskPerformanceCalculator: Sendable {
    private var previous: (timestamp: TimeInterval, counters: DiskCounters)?
    private var filter = ExponentialMovingAverage(timeConstant: 0.75)
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

    package mutating func consume(_ snapshot: DiskDeviceSnapshot, at timestamp: TimeInterval) -> MetricReading? {
        guard let previous else {
            self.previous = (timestamp, snapshot.counters)
            return nil
        }
        self.previous = (timestamp, snapshot.counters)

        let elapsed = timestamp - previous.timestamp
        guard elapsed > 0,
              let bytesRead = delta(snapshot.counters.bytesRead, previous.counters.bytesRead),
              let bytesWritten = delta(snapshot.counters.bytesWritten, previous.counters.bytesWritten),
              let reads = delta(snapshot.counters.readOperations, previous.counters.readOperations),
              let writes = delta(snapshot.counters.writeOperations, previous.counters.writeOperations),
              let readTime = delta(snapshot.counters.readTimeNanoseconds, previous.counters.readTimeNanoseconds),
              let writeTime = delta(snapshot.counters.writeTimeNanoseconds, previous.counters.writeTimeNanoseconds),
              let readErrors = delta(snapshot.counters.readErrors, previous.counters.readErrors),
              let writeErrors = delta(snapshot.counters.writeErrors, previous.counters.writeErrors) else {
            return nil
        }

        let serviceTime = saturatingAdd(readTime, writeTime)
        let activity = min(Double(serviceTime) / (elapsed * 1_000_000_000), 1)
        let filteredActivity = filter.update(value: activity, at: timestamp)
        let readRate = Double(bytesRead) / elapsed
        let writeRate = Double(bytesWritten) / elapsed
        _ = scale.update(maximumValue: max(readRate, writeRate), at: timestamp)
        let operations = saturatingAdd(reads, writes)
        let averageResponse = operations > 0
            ? Double(serviceTime) / Double(operations) / 1_000_000
            : nil

        let details = DiskDetails(
            identity: snapshot.identity,
            activity: filteredActivity,
            readBytesPerSecond: readRate,
            writeBytesPerSecond: writeRate,
            readOperationsPerSecond: Double(reads) / elapsed,
            writeOperationsPerSecond: Double(writes) / elapsed,
            averageResponseMilliseconds: averageResponse,
            readErrorDelta: readErrors,
            writeErrorDelta: writeErrors,
            transferCeilingBytesPerSecond: scale.ceiling
        )
        return MetricReading(
            timestamp: timestamp,
            value: filteredActivity,
            resource: snapshot.identity.resourceID,
            availability: .available,
            details: .disk(details)
        )
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64? {
        current >= previous ? current - previous : nil
    }

    private func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }
}

package struct DiskMonitorUpdate: Equatable, Sendable {
    package let descriptors: [PerformanceResourceDescriptor]
    package let readings: [MetricReading]

    package init(descriptors: [PerformanceResourceDescriptor], readings: [MetricReading]) {
        self.descriptors = descriptors
        self.readings = readings
    }
}

package actor DiskMonitor {
    private let discovery: any DiskDiscovering
    private var calculators: [PerformanceResourceID: DiskPerformanceCalculator] = [:]
    private var identities: [PerformanceResourceID: DiskIdentity] = [:]
    private var lastDiscoveryTimestamp: TimeInterval?

    package init(discovery: any DiskDiscovering = IOKitDiskDiscovery()) {
        self.discovery = discovery
    }

    package func sample(at timestamp: TimeInterval, forceDiscovery: Bool = false) async -> DiskMonitorUpdate {
        let shouldDiscover = forceDiscovery
            || lastDiscoveryTimestamp.map { timestamp - $0 >= 5 } ?? true
        var readings: [MetricReading] = []

        if shouldDiscover {
            let snapshots = await discovery.discover()
            lastDiscoveryTimestamp = timestamp
            let discoveredIDs = Set(snapshots.map { $0.identity.resourceID })
            identities = Dictionary(uniqueKeysWithValues: snapshots.map {
                ($0.identity.resourceID, $0.identity)
            })
            calculators = calculators.filter { discoveredIDs.contains($0.key) }
            for snapshot in snapshots {
                var calculator = calculators[snapshot.identity.resourceID] ?? DiskPerformanceCalculator()
                if let reading = calculator.consume(snapshot, at: timestamp) {
                    readings.append(reading)
                }
                calculators[snapshot.identity.resourceID] = calculator
            }
        } else {
            let snapshots = await discovery.discover()
            for snapshot in snapshots where identities[snapshot.identity.resourceID] != nil {
                var calculator = calculators[snapshot.identity.resourceID] ?? DiskPerformanceCalculator()
                if let reading = calculator.consume(snapshot, at: timestamp) {
                    readings.append(reading)
                }
                calculators[snapshot.identity.resourceID] = calculator
            }
        }

        return DiskMonitorUpdate(
            descriptors: identities.values.sorted { $0.bsdName < $1.bsdName }.enumerated().map {
                index, identity in
                PerformanceResourceDescriptor(
                    id: identity.resourceID,
                    title: "Disk \(index)",
                    subtitle: identity.isSolidState == true ? "SSD" : identity.bsdName,
                    kind: .disk,
                    colorRole: .disk,
                    graphKind: .physicalFixed,
                    easterEggUtility: .car
                )
            },
            readings: readings
        )
    }
}
