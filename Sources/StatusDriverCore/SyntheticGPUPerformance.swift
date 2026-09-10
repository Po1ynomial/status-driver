import Foundation

package actor SyntheticGPUMonitor {
    private let registryID: UInt64 = 0x675055
    private var deviceSource = BoundedRandomWalkSource(initialValue: 0.24, seed: 0x475055)

    package init() {}

    package func sample(at timestamp: TimeInterval) -> GPUMonitorUpdate {
        let device = deviceSource.nextSample(at: timestamp).value
        let details = GPUDetails(
            model: "Synthetic Apple GPU",
            deviceUtilization: device,
            rendererUtilization: min(device * 0.82, 1),
            tilerUtilization: min(device * 0.64, 1),
            inUseSystemMemoryBytes: UInt64(device * 1_500_000_000),
            supportsMetal: true,
            memoryType: "Unified memory"
        )
        let id = PerformanceResourceID.gpu(registryID: registryID)
        return GPUMonitorUpdate(
            descriptor: PerformanceResourceDescriptor(
                id: id,
                title: "GPU",
                subtitle: details.model,
                kind: .gpu,
                colorRole: .gpu,
                graphKind: .physicalFixed,
                easterEggUtility: .car
            ),
            reading: MetricReading(
                timestamp: timestamp,
                value: device,
                resource: id,
                availability: .available,
                details: .gpu(details)
            )
        )
    }
}
