import Darwin
import Foundation

package struct CPUPerformanceLevel: Equatable, Sendable {
    package let name: String
    package let physicalCoreCount: Int?
    package let logicalProcessorCount: Int?
    package let l1InstructionCacheBytes: UInt64?
    package let l1DataCacheBytes: UInt64?
    package let l2CacheBytes: UInt64?

    package init(
        name: String,
        physicalCoreCount: Int?,
        logicalProcessorCount: Int?,
        l1InstructionCacheBytes: UInt64?,
        l1DataCacheBytes: UInt64?,
        l2CacheBytes: UInt64?
    ) {
        self.name = name
        self.physicalCoreCount = physicalCoreCount
        self.logicalProcessorCount = logicalProcessorCount
        self.l1InstructionCacheBytes = l1InstructionCacheBytes
        self.l1DataCacheBytes = l1DataCacheBytes
        self.l2CacheBytes = l2CacheBytes
    }
}

package struct PerformanceHardwareProfile: Equatable, Sendable {
    package let cpuName: String?
    package let packageCount: Int?
    package let physicalCoreCount: Int?
    package let logicalProcessorCount: Int?
    package let virtualizationSupported: Bool?
    package let performanceLevels: [CPUPerformanceLevel]
    package let l3CacheBytes: UInt64?
    package let installedMemoryBytes: UInt64?
    package let memoryType: String?

    package init(
        cpuName: String?,
        packageCount: Int?,
        physicalCoreCount: Int?,
        logicalProcessorCount: Int?,
        virtualizationSupported: Bool?,
        performanceLevels: [CPUPerformanceLevel],
        l3CacheBytes: UInt64?,
        installedMemoryBytes: UInt64?,
        memoryType: String?
    ) {
        self.cpuName = cpuName
        self.packageCount = packageCount
        self.physicalCoreCount = physicalCoreCount
        self.logicalProcessorCount = logicalProcessorCount
        self.virtualizationSupported = virtualizationSupported
        self.performanceLevels = performanceLevels
        self.l3CacheBytes = l3CacheBytes
        self.installedMemoryBytes = installedMemoryBytes
        self.memoryType = memoryType
    }
}

package protocol SysctlValueReading: Sendable {
    func string(for name: String) -> String?
    func integer(for name: String) -> UInt64?
}

package struct DarwinSysctlReader: SysctlValueReading {
    package init() {}

    package func string(for name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        var bytes = [UInt8](repeating: 0, count: size)
        let result = bytes.withUnsafeMutableBytes { buffer in
            sysctlbyname(name, buffer.baseAddress, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        let content = bytes.prefix { $0 != 0 }
        return String(bytes: content, encoding: .utf8)
    }

    package func integer(for name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        guard sysctlbyname(name, &value, &size, nil, 0) == 0 else { return nil }

        switch size {
        case MemoryLayout<UInt32>.size:
            return UInt64(UInt32(truncatingIfNeeded: value))
        case MemoryLayout<UInt64>.size:
            return value
        default:
            return nil
        }
    }
}

package protocol HardwareProfileReading: Sendable {
    func readProfile() async -> PerformanceHardwareProfile
}

package struct SystemHardwareProfileReader: HardwareProfileReading {
    private let sysctl: any SysctlValueReading

    package init(sysctl: any SysctlValueReading = DarwinSysctlReader()) {
        self.sysctl = sysctl
    }

    package func readProfile() async -> PerformanceHardwareProfile {
        let physicalCoreCount = intValue("hw.physicalcpu")
        let logicalProcessorCount = intValue("hw.logicalcpu")
        let levelCount = intValue("hw.nperflevels") ?? 0
        var levels: [CPUPerformanceLevel] = []

        if levelCount > 0 {
            for index in 0..<levelCount {
                let prefix = "hw.perflevel\(index)"
                levels.append(
                    CPUPerformanceLevel(
                        name: sysctl.string(for: "\(prefix).name") ?? "Level \(index + 1)",
                        physicalCoreCount: intValue("\(prefix).physicalcpu"),
                        logicalProcessorCount: intValue("\(prefix).logicalcpu"),
                        l1InstructionCacheBytes: sysctl.integer(for: "\(prefix).l1icachesize"),
                        l1DataCacheBytes: sysctl.integer(for: "\(prefix).l1dcachesize"),
                        l2CacheBytes: sysctl.integer(for: "\(prefix).l2cachesize")
                    )
                )
            }
        } else {
            let genericLevel = CPUPerformanceLevel(
                name: "CPU",
                physicalCoreCount: physicalCoreCount,
                logicalProcessorCount: logicalProcessorCount,
                l1InstructionCacheBytes: sysctl.integer(for: "hw.l1icachesize"),
                l1DataCacheBytes: sysctl.integer(for: "hw.l1dcachesize"),
                l2CacheBytes: sysctl.integer(for: "hw.l2cachesize")
            )
            if genericLevel.physicalCoreCount != nil
                || genericLevel.l1InstructionCacheBytes != nil
                || genericLevel.l1DataCacheBytes != nil
                || genericLevel.l2CacheBytes != nil {
                levels.append(genericLevel)
            }
        }

        let isAppleSilicon = sysctl.integer(for: "hw.optional.arm64") == 1
        return PerformanceHardwareProfile(
            cpuName: sysctl.string(for: "machdep.cpu.brand_string"),
            packageCount: intValue("hw.packages"),
            physicalCoreCount: physicalCoreCount,
            logicalProcessorCount: logicalProcessorCount,
            virtualizationSupported: sysctl.integer(for: "kern.hv_support").map { $0 != 0 },
            performanceLevels: levels,
            l3CacheBytes: sysctl.integer(for: "hw.l3cachesize"),
            installedMemoryBytes: sysctl.integer(for: "hw.memsize"),
            memoryType: isAppleSilicon ? "Unified memory" : nil
        )
    }

    private func intValue(_ name: String) -> Int? {
        guard let value = sysctl.integer(for: name), value <= UInt64(Int.max) else { return nil }
        return Int(value)
    }
}

package struct SystemActivitySnapshot: Equatable, Sendable {
    package let timestamp: TimeInterval
    package let processCount: Int?
    package let threadCount: Int?
    package let uptime: TimeInterval?

    package init(
        timestamp: TimeInterval,
        processCount: Int?,
        threadCount: Int?,
        uptime: TimeInterval?
    ) {
        self.timestamp = timestamp
        self.processCount = processCount
        self.threadCount = threadCount
        self.uptime = uptime
    }
}

package protocol SystemActivityReading: Sendable {
    func readActivity(at timestamp: TimeInterval) async -> SystemActivitySnapshot
}

package struct DarwinSystemActivityReader: SystemActivityReading {
    package init() {}

    package func readActivity(at timestamp: TimeInterval) async -> SystemActivitySnapshot {
        guard let processIDs = readProcessIDs() else {
            return SystemActivitySnapshot(
                timestamp: timestamp,
                processCount: nil,
                threadCount: nil,
                uptime: ProcessInfo.processInfo.systemUptime
            )
        }

        var totalThreads = 0
        var inspectedProcess = false
        for processID in processIDs {
            var info = proc_taskinfo()
            let result = withUnsafeMutablePointer(to: &info) { pointer in
                proc_pidinfo(
                    processID,
                    PROC_PIDTASKINFO,
                    0,
                    pointer,
                    Int32(MemoryLayout<proc_taskinfo>.size)
                )
            }
            guard result == MemoryLayout<proc_taskinfo>.size else { continue }
            inspectedProcess = true
            totalThreads = saturatingAdd(totalThreads, max(0, Int(info.pti_threadnum)))
        }

        return SystemActivitySnapshot(
            timestamp: timestamp,
            processCount: processIDs.count,
            threadCount: inspectedProcess ? totalThreads : nil,
            uptime: ProcessInfo.processInfo.systemUptime
        )
    }

    private func readProcessIDs() -> [pid_t]? {
        let estimatedCount = proc_listallpids(nil, 0)
        guard estimatedCount > 0 else { return nil }

        var processIDs = [pid_t](repeating: 0, count: Int(estimatedCount) + 64)
        let count = processIDs.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        guard count >= 0 else { return nil }
        return processIDs.prefix(Int(count)).filter { $0 > 0 }
    }

    private func saturatingAdd(_ lhs: Int, _ rhs: Int) -> Int {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? Int.max : result.partialValue
    }
}

package func makeSystemActivityStream(
    reader: any SystemActivityReading = DarwinSystemActivityReader(),
    clock: any SamplingClock = ContinuousSamplingClock(),
    interval: Duration = .seconds(1)
) -> AsyncStream<SystemActivitySnapshot> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
        let task = Task.detached(priority: .utility) {
            while !Task.isCancelled {
                let timestamp = await clock.elapsedTime()
                continuation.yield(await reader.readActivity(at: timestamp))

                do {
                    try await clock.sleep(for: interval)
                } catch {
                    break
                }
            }
            continuation.finish()
        }
        continuation.onTermination = { @Sendable _ in task.cancel() }
    }
}
