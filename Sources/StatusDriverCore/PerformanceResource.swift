import Foundation

package enum PerformanceResourceID: Hashable, Sendable {
    case cpu
    case memory
    case disk(registryID: UInt64, bsdName: String)
    case network(interfaceName: String)
    case gpu(registryID: UInt64)
}

package enum PerformanceResourceKind: Int, Comparable, Hashable, Sendable {
    case cpu
    case memory
    case disk
    case network
    case gpu

    package static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

package enum PerformanceColorRole: Hashable, Sendable {
    case cpu
    case memory
    case disk
    case wifi
    case ethernet
    case network(Int)
    case gpu
}

package enum PerformanceGraphKind: Equatable, Sendable {
    case physicalFixed
    case adaptiveNonphysical
}

package enum EasterEggUtility: Equatable, Sendable {
    case car
    case none
}

package struct PerformanceResourceDescriptor: Identifiable, Equatable, Sendable {
    package let id: PerformanceResourceID
    package let title: String
    package let subtitle: String?
    package let kind: PerformanceResourceKind
    package let colorRole: PerformanceColorRole
    package let graphKind: PerformanceGraphKind
    package let easterEggUtility: EasterEggUtility

    package init(
        id: PerformanceResourceID,
        title: String,
        subtitle: String? = nil,
        kind: PerformanceResourceKind,
        colorRole: PerformanceColorRole,
        graphKind: PerformanceGraphKind,
        easterEggUtility: EasterEggUtility
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.colorRole = colorRole
        self.graphKind = graphKind
        self.easterEggUtility = easterEggUtility
    }

    package static let cpu = PerformanceResourceDescriptor(
        id: .cpu,
        title: "CPU",
        kind: .cpu,
        colorRole: .cpu,
        graphKind: .physicalFixed,
        easterEggUtility: .car
    )

    package static let memory = PerformanceResourceDescriptor(
        id: .memory,
        title: "Memory",
        kind: .memory,
        colorRole: .memory,
        graphKind: .physicalFixed,
        easterEggUtility: .car
    )
}

package enum PerformanceResourceAvailability: Equatable, Sendable {
    case available
    case unavailable
    case disconnected
}

package struct PerformanceResourceRecord: Identifiable, Equatable, Sendable {
    package let descriptor: PerformanceResourceDescriptor
    package var availability: PerformanceResourceAvailability

    package var id: PerformanceResourceID { descriptor.id }

    package init(
        descriptor: PerformanceResourceDescriptor,
        availability: PerformanceResourceAvailability = .available
    ) {
        self.descriptor = descriptor
        self.availability = availability
    }
}

package struct PerformanceResourceInventory: Sendable {
    private var recordsByID: [PerformanceResourceID: PerformanceResourceRecord]

    package init() {
        recordsByID = [
            .cpu: PerformanceResourceRecord(descriptor: .cpu),
            .memory: PerformanceResourceRecord(descriptor: .memory),
        ]
    }

    package var records: [PerformanceResourceRecord] {
        recordsByID.values.sorted { lhs, rhs in
            let leftKey = sortKey(lhs.descriptor)
            let rightKey = sortKey(rhs.descriptor)
            return leftKey < rightKey
        }
    }

    package mutating func reconcile(
        discovered: [PerformanceResourceDescriptor],
        managedKinds: Set<PerformanceResourceKind>,
        selectedResource: PerformanceResourceID
    ) {
        let discoveredByID = Dictionary(uniqueKeysWithValues: discovered.map { ($0.id, $0) })

        for descriptor in discovered {
            recordsByID[descriptor.id] = PerformanceResourceRecord(descriptor: descriptor)
        }

        for record in Array(recordsByID.values) where managedKinds.contains(record.descriptor.kind)
            && discoveredByID[record.id] == nil {
            switch record.descriptor.kind {
            case .disk where record.id != selectedResource:
                recordsByID.removeValue(forKey: record.id)
            case .network:
                recordsByID[record.id]?.availability = .disconnected
            case .disk, .gpu:
                recordsByID[record.id]?.availability = .unavailable
            case .cpu, .memory:
                break
            }
        }
    }

    package mutating func setAvailability(
        _ availability: PerformanceResourceAvailability,
        for id: PerformanceResourceID
    ) {
        recordsByID[id]?.availability = availability
    }

    package func descriptor(for id: PerformanceResourceID) -> PerformanceResourceDescriptor? {
        recordsByID[id]?.descriptor
    }

    private func sortKey(_ descriptor: PerformanceResourceDescriptor) -> String {
        let kind = String(format: "%02d", descriptor.kind.rawValue)
        switch descriptor.id {
        case .cpu, .memory:
            return kind
        case let .disk(registryID, bsdName):
            return "\(kind)-\(bsdName)-\(registryID)"
        case let .network(interfaceName):
            return "\(kind)-\(interfaceName)"
        case let .gpu(registryID):
            return "\(kind)-\(registryID)"
        }
    }
}

package struct AdaptiveScale: Equatable, Sendable {
    package let ladder: [Double]
    package let lowerDelay: TimeInterval
    package private(set) var ceiling: Double
    private var lowSince: TimeInterval?

    package init(
        ladder: [Double],
        initialCeiling: Double,
        lowerDelay: TimeInterval = 30
    ) {
        precondition(!ladder.isEmpty && ladder.allSatisfy { $0 > 0 })
        precondition(ladder == ladder.sorted())
        precondition(ladder.contains(initialCeiling))
        self.ladder = ladder
        self.lowerDelay = lowerDelay
        ceiling = initialCeiling
    }

    @discardableResult
    package mutating func update(maximumValue: Double, at timestamp: TimeInterval) -> Bool {
        let value = maximumValue.isFinite ? max(0, maximumValue) : 0
        let previousCeiling = ceiling

        while value > ceiling * 0.9,
              let index = ladder.firstIndex(of: ceiling),
              index + 1 < ladder.count {
            ceiling = ladder[index + 1]
        }
        if ceiling != previousCeiling {
            lowSince = nil
            return true
        }

        guard value < ceiling * 0.2,
              let index = ladder.firstIndex(of: ceiling),
              index > 0 else {
            lowSince = nil
            return false
        }

        if let lowSince, timestamp - lowSince >= lowerDelay {
            ceiling = ladder[index - 1]
            self.lowSince = nil
            return true
        }
        if lowSince == nil {
            lowSince = timestamp
        }
        return false
    }
}

package struct EasterEggState: Equatable, Sendable {
    package private(set) var isEnabled = false

    package init() {}

    package mutating func toggle() {
        isEnabled.toggle()
    }

    package func activeUtility(for descriptor: PerformanceResourceDescriptor) -> EasterEggUtility {
        isEnabled ? descriptor.easterEggUtility : .none
    }
}
