import Foundation
import IOKit

package struct GPUSnapshot: Equatable, Sendable {
    package let registryID: UInt64
    package let model: String
    package let deviceUtilizationPercent: Double
    package let rendererUtilizationPercent: Double?
    package let tilerUtilizationPercent: Double?
    package let inUseSystemMemoryBytes: UInt64?

    package var resourceID: PerformanceResourceID {
        .gpu(registryID: registryID)
    }

    package init(
        registryID: UInt64,
        model: String,
        deviceUtilizationPercent: Double,
        rendererUtilizationPercent: Double?,
        tilerUtilizationPercent: Double?,
        inUseSystemMemoryBytes: UInt64?
    ) {
        self.registryID = registryID
        self.model = model
        self.deviceUtilizationPercent = deviceUtilizationPercent
        self.rendererUtilizationPercent = rendererUtilizationPercent
        self.tilerUtilizationPercent = tilerUtilizationPercent
        self.inUseSystemMemoryBytes = inUseSystemMemoryBytes
    }
}

package struct GPUDetails: Equatable, Sendable {
    package let model: String
    package let deviceUtilization: Double
    package let rendererUtilization: Double?
    package let tilerUtilization: Double?
    package let inUseSystemMemoryBytes: UInt64?
    package let supportsMetal: Bool
    package let memoryType: String?

    package init(
        model: String,
        deviceUtilization: Double,
        rendererUtilization: Double?,
        tilerUtilization: Double?,
        inUseSystemMemoryBytes: UInt64?,
        supportsMetal: Bool,
        memoryType: String?
    ) {
        self.model = model
        self.deviceUtilization = deviceUtilization
        self.rendererUtilization = rendererUtilization
        self.tilerUtilization = tilerUtilization
        self.inUseSystemMemoryBytes = inUseSystemMemoryBytes
        self.supportsMetal = supportsMetal
        self.memoryType = memoryType
    }
}

package protocol GPUReading: Sendable {
    func readGPU() async -> GPUSnapshot?
}

package struct IOKitGPUReader: GPUReading {
    package init() {}

    package func readGPU() async -> GPUSnapshot? {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(
            kIOMainPortDefault,
            IOServiceMatching("IOAccelerator"),
            &iterator
        ) == KERN_SUCCESS else {
            return nil
        }
        defer { IOObjectRelease(iterator) }

        var service = IOIteratorNext(iterator)
        while service != 0 {
            defer { IOObjectRelease(service) }
            if let snapshot = snapshot(for: service) {
                return snapshot
            }
            service = IOIteratorNext(iterator)
        }
        return nil
    }

    private func snapshot(for service: io_registry_entry_t) -> GPUSnapshot? {
        guard let properties = properties(of: service),
              let statistics = properties["PerformanceStatistics"] as? NSDictionary,
              let deviceUtilization = double(statistics["Device Utilization %"]) else {
            return nil
        }

        var registryID: UInt64 = 0
        guard IORegistryEntryGetRegistryEntryID(service, &registryID) == KERN_SUCCESS else {
            return nil
        }

        let model = decodeModel(properties["model"])
            ?? (properties["MetalPluginName"] as? String)
            ?? "Apple GPU"
        return GPUSnapshot(
            registryID: registryID,
            model: model,
            deviceUtilizationPercent: deviceUtilization,
            rendererUtilizationPercent: double(statistics["Renderer Utilization %"]),
            tilerUtilizationPercent: double(statistics["Tiler Utilization %"]),
            inUseSystemMemoryBytes: uint64(statistics["In use system memory"])
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

    private func decodeModel(_ value: Any?) -> String? {
        if let string = value as? String { return string }
        if let data = value as? Data {
            return String(decoding: data.prefix { $0 != 0 }, as: UTF8.self)
        }
        return nil
    }

    private func double(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private func uint64(_ value: Any?) -> UInt64? {
        (value as? NSNumber)?.uint64Value
    }
}

package struct GPUPerformanceCalculator: Sendable {
    private var filter = ExponentialMovingAverage(timeConstant: 0.75)

    package init() {}

    package mutating func reading(from snapshot: GPUSnapshot, at timestamp: TimeInterval) -> MetricReading {
        let device = normalized(snapshot.deviceUtilizationPercent)
        let filtered = filter.update(value: device, at: timestamp)
        let details = GPUDetails(
            model: snapshot.model,
            deviceUtilization: filtered,
            rendererUtilization: snapshot.rendererUtilizationPercent.map(normalized),
            tilerUtilization: snapshot.tilerUtilizationPercent.map(normalized),
            inUseSystemMemoryBytes: snapshot.inUseSystemMemoryBytes,
            supportsMetal: true,
            memoryType: "Unified memory"
        )
        return MetricReading(
            timestamp: timestamp,
            value: filtered,
            resource: snapshot.resourceID,
            availability: .available,
            details: .gpu(details)
        )
    }

    private func normalized(_ percent: Double) -> Double {
        guard percent.isFinite else { return 0 }
        return min(max(percent / 100, 0), 1)
    }
}

package struct GPUMonitorUpdate: Equatable, Sendable {
    package let descriptor: PerformanceResourceDescriptor?
    package let reading: MetricReading?

    package init(descriptor: PerformanceResourceDescriptor?, reading: MetricReading?) {
        self.descriptor = descriptor
        self.reading = reading
    }
}

package actor GPUMonitor {
    private let reader: any GPUReading
    private var calculator = GPUPerformanceCalculator()
    private var lastSnapshot: GPUSnapshot?
    private var lastAttemptTimestamp: TimeInterval?

    package init(reader: any GPUReading = IOKitGPUReader()) {
        self.reader = reader
    }

    package func sample(at timestamp: TimeInterval) async -> GPUMonitorUpdate {
        let shouldRead = lastSnapshot != nil
            || lastAttemptTimestamp.map { timestamp - $0 >= 5 } ?? true
        guard shouldRead else {
            return GPUMonitorUpdate(
                descriptor: lastSnapshot.map(descriptor),
                reading: nil
            )
        }

        lastAttemptTimestamp = timestamp
        guard let snapshot = await reader.readGPU() else {
            return GPUMonitorUpdate(
                descriptor: lastSnapshot.map(descriptor),
                reading: lastSnapshot.map {
                    let prior = calculator.reading(from: $0, at: timestamp)
                    return MetricReading(
                        timestamp: timestamp,
                        value: prior.value,
                        resource: prior.resource,
                        availability: .unavailable,
                        details: prior.details
                    )
                }
            )
        }

        lastSnapshot = snapshot
        return GPUMonitorUpdate(
            descriptor: descriptor(snapshot),
            reading: calculator.reading(from: snapshot, at: timestamp)
        )
    }

    private func descriptor(_ snapshot: GPUSnapshot) -> PerformanceResourceDescriptor {
        PerformanceResourceDescriptor(
            id: snapshot.resourceID,
            title: "GPU",
            subtitle: snapshot.model,
            kind: .gpu,
            colorRole: .gpu,
            graphKind: .physicalFixed,
            easterEggUtility: .car
        )
    }
}
