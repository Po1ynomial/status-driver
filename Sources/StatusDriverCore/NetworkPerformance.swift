import Darwin
import Foundation
import SystemConfiguration

package enum PhysicalNetworkKind: Equatable, Sendable {
    case wifi
    case ethernet
}

package func physicalNetworkKind(interfaceType: String) -> PhysicalNetworkKind? {
    if interfaceType == (kSCNetworkInterfaceTypeIEEE80211 as String) {
        return .wifi
    }
    if interfaceType == (kSCNetworkInterfaceTypeEthernet as String) {
        return .ethernet
    }
    return nil
}

package struct NetworkIdentity: Equatable, Sendable {
    package let interfaceName: String
    package let portName: String
    package let kind: PhysicalNetworkKind

    package var resourceID: PerformanceResourceID {
        .network(interfaceName: interfaceName)
    }

    package init(interfaceName: String, portName: String, kind: PhysicalNetworkKind) {
        self.interfaceName = interfaceName
        self.portName = portName
        self.kind = kind
    }
}

package struct NetworkCounters: Equatable, Sendable {
    package let receivedBytes: UInt64
    package let sentBytes: UInt64
    package let receivedPackets: UInt64
    package let sentPackets: UInt64
    package let inputErrors: UInt64
    package let outputErrors: UInt64
    package let inputDrops: UInt64
    package let linkSpeedBitsPerSecond: UInt64?
    package let isConnected: Bool
    package let ipv4Addresses: [String]
    package let ipv6Addresses: [String]

    package init(
        receivedBytes: UInt64,
        sentBytes: UInt64,
        receivedPackets: UInt64,
        sentPackets: UInt64,
        inputErrors: UInt64,
        outputErrors: UInt64,
        inputDrops: UInt64,
        linkSpeedBitsPerSecond: UInt64?,
        isConnected: Bool,
        ipv4Addresses: [String],
        ipv6Addresses: [String]
    ) {
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.receivedPackets = receivedPackets
        self.sentPackets = sentPackets
        self.inputErrors = inputErrors
        self.outputErrors = outputErrors
        self.inputDrops = inputDrops
        self.linkSpeedBitsPerSecond = linkSpeedBitsPerSecond
        self.isConnected = isConnected
        self.ipv4Addresses = ipv4Addresses
        self.ipv6Addresses = ipv6Addresses
    }
}

package struct NetworkDeviceSnapshot: Equatable, Sendable {
    package let identity: NetworkIdentity
    package let counters: NetworkCounters

    package init(identity: NetworkIdentity, counters: NetworkCounters) {
        self.identity = identity
        self.counters = counters
    }
}

package struct NetworkDetails: Equatable, Sendable {
    package let identity: NetworkIdentity
    package let isConnected: Bool
    package let receiveBytesPerSecond: Double
    package let sendBytesPerSecond: Double
    package let combinedBytesPerSecond: Double
    package let receivePacketsPerSecond: Double
    package let sendPacketsPerSecond: Double
    package let inputErrorDelta: UInt64
    package let outputErrorDelta: UInt64
    package let inputDropDelta: UInt64
    package let linkSpeedBitsPerSecond: UInt64?
    package let ipv4Addresses: [String]
    package let ipv6Addresses: [String]
    package let graphCeilingBytesPerSecond: Double

    package init(
        identity: NetworkIdentity,
        isConnected: Bool,
        receiveBytesPerSecond: Double,
        sendBytesPerSecond: Double,
        combinedBytesPerSecond: Double,
        receivePacketsPerSecond: Double,
        sendPacketsPerSecond: Double,
        inputErrorDelta: UInt64,
        outputErrorDelta: UInt64,
        inputDropDelta: UInt64,
        linkSpeedBitsPerSecond: UInt64?,
        ipv4Addresses: [String],
        ipv6Addresses: [String],
        graphCeilingBytesPerSecond: Double
    ) {
        self.identity = identity
        self.isConnected = isConnected
        self.receiveBytesPerSecond = receiveBytesPerSecond
        self.sendBytesPerSecond = sendBytesPerSecond
        self.combinedBytesPerSecond = combinedBytesPerSecond
        self.receivePacketsPerSecond = receivePacketsPerSecond
        self.sendPacketsPerSecond = sendPacketsPerSecond
        self.inputErrorDelta = inputErrorDelta
        self.outputErrorDelta = outputErrorDelta
        self.inputDropDelta = inputDropDelta
        self.linkSpeedBitsPerSecond = linkSpeedBitsPerSecond
        self.ipv4Addresses = ipv4Addresses
        self.ipv6Addresses = ipv6Addresses
        self.graphCeilingBytesPerSecond = graphCeilingBytesPerSecond
    }
}

package struct NetworkThroughputSample: Equatable, Sendable {
    package let timestamp: TimeInterval
    package let receiveBytesPerSecond: Double
    package let sendBytesPerSecond: Double

    package var combinedBytesPerSecond: Double {
        receiveBytesPerSecond + sendBytesPerSecond
    }

    package init(
        timestamp: TimeInterval,
        receiveBytesPerSecond: Double,
        sendBytesPerSecond: Double
    ) {
        self.timestamp = timestamp
        self.receiveBytesPerSecond = receiveBytesPerSecond
        self.sendBytesPerSecond = sendBytesPerSecond
    }
}

package protocol NetworkDiscovering: Sendable {
    func discoverIdentities() async -> [NetworkIdentity]
    func readSnapshots(for identities: [NetworkIdentity]) async -> [NetworkDeviceSnapshot]
}

package struct SystemNetworkDiscovery: NetworkDiscovering {
    private struct LinkData {
        let receivedBytes: UInt64
        let sentBytes: UInt64
        let receivedPackets: UInt64
        let sentPackets: UInt64
        let inputErrors: UInt64
        let outputErrors: UInt64
        let inputDrops: UInt64
        let linkSpeed: UInt64?
        let isConnected: Bool
    }

    package init() {}

    package func discoverIdentities() async -> [NetworkIdentity] {
        physicalInterfaces()
    }

    package func readSnapshots(
        for identities: [NetworkIdentity]
    ) async -> [NetworkDeviceSnapshot] {
        let countersByName = interfaceCounters()
        return identities.map { identity in
            NetworkDeviceSnapshot(
                identity: identity,
                counters: countersByName[identity.interfaceName] ?? NetworkCounters(
                    receivedBytes: 0,
                    sentBytes: 0,
                    receivedPackets: 0,
                    sentPackets: 0,
                    inputErrors: 0,
                    outputErrors: 0,
                    inputDrops: 0,
                    linkSpeedBitsPerSecond: nil,
                    isConnected: false,
                    ipv4Addresses: [],
                    ipv6Addresses: []
                )
            )
        }
        .sorted { $0.identity.interfaceName < $1.identity.interfaceName }
    }

    private func physicalInterfaces() -> [NetworkIdentity] {
        let interfaces = SCNetworkInterfaceCopyAll()
        let count = CFArrayGetCount(interfaces)
        var result: [NetworkIdentity] = []

        for index in 0..<count {
            let pointer = CFArrayGetValueAtIndex(interfaces, index)
            let interface = unsafeBitCast(pointer, to: SCNetworkInterface.self)
            guard let bsdName = SCNetworkInterfaceGetBSDName(interface) as String?,
                  let type = SCNetworkInterfaceGetInterfaceType(interface) as String? else {
                continue
            }

            let kind: PhysicalNetworkKind
            guard let discoveredKind = physicalNetworkKind(interfaceType: type) else {
                continue
            }
            kind = discoveredKind

            let portName = (SCNetworkInterfaceGetLocalizedDisplayName(interface) as String?)
                ?? (kind == .wifi ? "Wi-Fi" : "Ethernet")
            result.append(
                NetworkIdentity(
                    interfaceName: bsdName,
                    portName: portName,
                    kind: kind
                )
            )
        }
        return result
    }

    private func interfaceCounters() -> [String: NetworkCounters] {
        let links = linkData()
        let addresses = interfaceAddresses()
        var result: [String: NetworkCounters] = [:]
        for (name, link) in links {
            let address = addresses[name] ?? (ipv4: [], ipv6: [])
            result[name] = NetworkCounters(
                receivedBytes: link.receivedBytes,
                sentBytes: link.sentBytes,
                receivedPackets: link.receivedPackets,
                sentPackets: link.sentPackets,
                inputErrors: link.inputErrors,
                outputErrors: link.outputErrors,
                inputDrops: link.inputDrops,
                linkSpeedBitsPerSecond: link.linkSpeed,
                isConnected: link.isConnected,
                ipv4Addresses: address.ipv4,
                ipv6Addresses: address.ipv6
            )
        }
        return result
    }

    private func linkData() -> [String: LinkData] {
        var mib = [CTL_NET, PF_ROUTE, 0, 0, NET_RT_IFLIST2, 0]
        var size = 0
        guard sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) == 0, size > 0 else {
            return [:]
        }
        var bytes = [UInt8](repeating: 0, count: size)
        let readResult = bytes.withUnsafeMutableBytes { buffer in
            sysctl(&mib, u_int(mib.count), buffer.baseAddress, &size, nil, 0)
        }
        guard readResult == 0 else { return [:] }

        var result: [String: LinkData] = [:]
        bytes.withUnsafeBytes { buffer in
            var offset = 0
            while offset + MemoryLayout<if_msghdr2>.size <= size {
                let messageLength = Int(
                    buffer.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
                )
                guard messageLength > 0, offset + messageLength <= size else { break }
                let messageType = buffer.loadUnaligned(
                    fromByteOffset: offset + MemoryLayout<UInt16>.size + MemoryLayout<UInt8>.size,
                    as: UInt8.self
                )
                if messageType == UInt8(RTM_IFINFO2),
                   messageLength >= MemoryLayout<if_msghdr2>.size {
                    let message = buffer.loadUnaligned(
                        fromByteOffset: offset,
                        as: if_msghdr2.self
                    )
                    var name = [CChar](repeating: 0, count: Int(IFNAMSIZ))
                    if if_indextoname(UInt32(message.ifm_index), &name) != nil {
                        let nameBytes = name.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
                        let interfaceName = String(decoding: nameBytes, as: UTF8.self)
                        let data = message.ifm_data
                        let flags = Int32(message.ifm_flags)
                        result[interfaceName] = LinkData(
                            receivedBytes: data.ifi_ibytes,
                            sentBytes: data.ifi_obytes,
                            receivedPackets: data.ifi_ipackets,
                            sentPackets: data.ifi_opackets,
                            inputErrors: data.ifi_ierrors,
                            outputErrors: data.ifi_oerrors,
                            inputDrops: data.ifi_iqdrops,
                            linkSpeed: data.ifi_baudrate > 0 ? data.ifi_baudrate : nil,
                            isConnected: (flags & IFF_UP) != 0 && (flags & IFF_RUNNING) != 0
                        )
                    }
                }
                offset += messageLength
            }
        }
        return result
    }

    private func interfaceAddresses() -> [String: (ipv4: [String], ipv6: [String])] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let head else { return [:] }
        defer { freeifaddrs(head) }

        struct Addresses {
            var ipv4: [String] = []
            var ipv6: [String] = []
        }

        var mutable: [String: Addresses] = [:]
        var current: UnsafeMutablePointer<ifaddrs>? = head
        while let entry = current?.pointee {
            let name = String(cString: entry.ifa_name)
            var addresses = mutable[name] ?? Addresses()
            let family = Int32(entry.ifa_addr?.pointee.sa_family ?? 0)

            if (family == AF_INET || family == AF_INET6),
               let address = numericAddress(entry.ifa_addr) {
                if family == AF_INET {
                    addresses.ipv4.append(address)
                } else {
                    addresses.ipv6.append(address)
                }
            }

            mutable[name] = addresses
            current = entry.ifa_next
        }

        return mutable.mapValues { value in
            (
                ipv4: Array(Set(value.ipv4)).sorted(),
                ipv6: Array(Set(value.ipv6)).sorted()
            )
        }
    }

    private func numericAddress(_ address: UnsafePointer<sockaddr>?) -> String? {
        guard let address else { return nil }
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            socklen_t(address.pointee.sa_len),
            &host,
            socklen_t(host.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        let bytes = host.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

package struct NetworkPerformanceCalculator: Sendable {
    private var previous: (timestamp: TimeInterval, counters: NetworkCounters)?
    private var scale = AdaptiveScale(
        ladder: [100_000, 1_000_000, 10_000_000, 100_000_000, 1_000_000_000, 10_000_000_000],
        initialCeiling: 1_000_000
    )

    package init() {}

    package mutating func consume(
        _ snapshot: NetworkDeviceSnapshot,
        at timestamp: TimeInterval
    ) -> MetricReading? {
        guard let previous else {
            self.previous = (timestamp, snapshot.counters)
            return nil
        }
        self.previous = (timestamp, snapshot.counters)

        let elapsed = timestamp - previous.timestamp
        guard elapsed > 0,
              let receivedBytes = delta(snapshot.counters.receivedBytes, previous.counters.receivedBytes),
              let sentBytes = delta(snapshot.counters.sentBytes, previous.counters.sentBytes),
              let receivedPackets = delta(snapshot.counters.receivedPackets, previous.counters.receivedPackets),
              let sentPackets = delta(snapshot.counters.sentPackets, previous.counters.sentPackets),
              let inputErrors = delta(snapshot.counters.inputErrors, previous.counters.inputErrors),
              let outputErrors = delta(snapshot.counters.outputErrors, previous.counters.outputErrors),
              let inputDrops = delta(snapshot.counters.inputDrops, previous.counters.inputDrops) else {
            return nil
        }

        let receiveRate = Double(receivedBytes) / elapsed
        let sendRate = Double(sentBytes) / elapsed
        let combinedRate = receiveRate + sendRate
        _ = scale.update(maximumValue: combinedRate, at: timestamp)
        let normalized = min(combinedRate / scale.ceiling, 1)

        let details = NetworkDetails(
            identity: snapshot.identity,
            isConnected: snapshot.counters.isConnected,
            receiveBytesPerSecond: receiveRate,
            sendBytesPerSecond: sendRate,
            combinedBytesPerSecond: combinedRate,
            receivePacketsPerSecond: Double(receivedPackets) / elapsed,
            sendPacketsPerSecond: Double(sentPackets) / elapsed,
            inputErrorDelta: inputErrors,
            outputErrorDelta: outputErrors,
            inputDropDelta: inputDrops,
            linkSpeedBitsPerSecond: snapshot.counters.linkSpeedBitsPerSecond,
            ipv4Addresses: snapshot.counters.ipv4Addresses,
            ipv6Addresses: snapshot.counters.ipv6Addresses,
            graphCeilingBytesPerSecond: scale.ceiling
        )
        return MetricReading(
            timestamp: timestamp,
            value: normalized,
            resource: snapshot.identity.resourceID,
            availability: snapshot.counters.isConnected ? .available : .unavailable,
            details: .network(details)
        )
    }

    private func delta(_ current: UInt64, _ previous: UInt64) -> UInt64? {
        current >= previous ? current - previous : nil
    }
}

package struct NetworkMonitorUpdate: Equatable, Sendable {
    package let descriptors: [PerformanceResourceDescriptor]
    package let readings: [MetricReading]

    package init(descriptors: [PerformanceResourceDescriptor], readings: [MetricReading]) {
        self.descriptors = descriptors
        self.readings = readings
    }
}

package actor NetworkMonitor {
    private let discovery: any NetworkDiscovering
    private var calculators: [PerformanceResourceID: NetworkPerformanceCalculator] = [:]
    private var identities: [PerformanceResourceID: NetworkIdentity] = [:]
    private var lastDiscoveryTimestamp: TimeInterval?

    package init(discovery: any NetworkDiscovering = SystemNetworkDiscovery()) {
        self.discovery = discovery
    }

    package func sample(at timestamp: TimeInterval) async -> NetworkMonitorUpdate {
        if lastDiscoveryTimestamp.map({ timestamp - $0 >= 5 }) ?? true {
            let discovered = await discovery.discoverIdentities()
            let discoveredIDs = Set(discovered.map(\.resourceID))
            identities = Dictionary(uniqueKeysWithValues: discovered.map {
                ($0.resourceID, $0)
            })
            calculators = calculators.filter { discoveredIDs.contains($0.key) }
            lastDiscoveryTimestamp = timestamp
        }

        let snapshots = await discovery.readSnapshots(
            for: identities.values.sorted { $0.interfaceName < $1.interfaceName }
        )

        var readings: [MetricReading] = []
        for snapshot in snapshots {
            var calculator = calculators[snapshot.identity.resourceID] ?? NetworkPerformanceCalculator()
            if let reading = calculator.consume(snapshot, at: timestamp) {
                readings.append(reading)
            }
            calculators[snapshot.identity.resourceID] = calculator
        }

        let descriptors = identities.values.sorted { $0.interfaceName < $1.interfaceName }.map {
            identity in
            let colorRole: PerformanceColorRole = switch identity.kind {
            case .wifi: .wifi
            case .ethernet: .ethernet
            }
            return PerformanceResourceDescriptor(
                id: identity.resourceID,
                title: identity.portName,
                subtitle: identity.interfaceName,
                kind: .network,
                colorRole: colorRole,
                graphKind: .adaptiveNonphysical,
                easterEggUtility: networkEasterEggUtility(for: identity)
            )
        }
        return NetworkMonitorUpdate(descriptors: descriptors, readings: readings)
    }
}
