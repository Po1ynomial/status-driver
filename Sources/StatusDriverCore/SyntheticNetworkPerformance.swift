import Foundation

package actor SyntheticNetworkMonitor {
    private let identity = NetworkIdentity(
        interfaceName: "synthetic-en0",
        portName: "Wi-Fi",
        kind: .wifi
    )
    private var receiveSource = BoundedRandomWalkSource(initialValue: 0.22, seed: 0x57494649)
    private var sendSource = BoundedRandomWalkSource(initialValue: 0.08, seed: 0x53454E44)
    private var scale = AdaptiveScale(
        ladder: [100_000, 1_000_000, 10_000_000, 100_000_000, 1_000_000_000, 10_000_000_000],
        initialCeiling: 1_000_000
    )

    package init() {}

    package func sample(at timestamp: TimeInterval) -> NetworkMonitorUpdate {
        let receiveRate = receiveSource.nextSample(at: timestamp).value * 8_000_000
        let sendRate = sendSource.nextSample(at: timestamp).value * 3_000_000
        let combinedRate = receiveRate + sendRate
        _ = scale.update(maximumValue: combinedRate, at: timestamp)

        let details = NetworkDetails(
            identity: identity,
            isConnected: true,
            receiveBytesPerSecond: receiveRate,
            sendBytesPerSecond: sendRate,
            combinedBytesPerSecond: combinedRate,
            receivePacketsPerSecond: receiveRate / 1_200,
            sendPacketsPerSecond: sendRate / 1_100,
            inputErrorDelta: 0,
            outputErrorDelta: 0,
            inputDropDelta: 0,
            linkSpeedBitsPerSecond: nil,
            ipv4Addresses: ["192.0.2.42"],
            ipv6Addresses: ["2001:db8::42"],
            graphCeilingBytesPerSecond: scale.ceiling
        )
        let reading = MetricReading(
            timestamp: timestamp,
            value: min(combinedRate / scale.ceiling, 1),
            resource: identity.resourceID,
            availability: .available,
            details: .network(details)
        )
        let descriptor = PerformanceResourceDescriptor(
            id: identity.resourceID,
            title: identity.portName,
            subtitle: identity.interfaceName,
            kind: .network,
            colorRole: .wifi,
            graphKind: .adaptiveNonphysical,
            easterEggUtility: .packet
        )
        return NetworkMonitorUpdate(descriptors: [descriptor], readings: [reading])
    }
}
