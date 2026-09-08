import Darwin
import Foundation

package struct MemoryStatistics: Equatable, Sendable {
    package let internalPages: UInt64
    package let purgeablePages: UInt64
    package let wiredPages: UInt64
    package let compressorPages: UInt64
    package let physicalPages: UInt64

    package init(
        internalPages: UInt64,
        purgeablePages: UInt64,
        wiredPages: UInt64,
        compressorPages: UInt64,
        physicalPages: UInt64
    ) {
        self.internalPages = internalPages
        self.purgeablePages = purgeablePages
        self.wiredPages = wiredPages
        self.compressorPages = compressorPages
        self.physicalPages = physicalPages
    }
}

package enum MemoryReadError: Error, Equatable, Sendable {
    case kernel(Int32)
    case sysctl(Int32)
    case invalidPageSize
}

package protocol MemoryStatisticsReader: Sendable {
    func readStatistics() async -> Result<MemoryStatistics, MemoryReadError>
}

package struct MachMemoryStatisticsReader: MemoryStatisticsReader {
    package init() {}

    package func readStatistics() async -> Result<MemoryStatistics, MemoryReadError> {
        let host = mach_host_self()
        var pageSize: vm_size_t = 0
        let pageSizeResult = host_page_size(host, &pageSize)
        guard pageSizeResult == KERN_SUCCESS else {
            return .failure(.kernel(pageSizeResult))
        }
        guard pageSize > 0 else {
            return .failure(.invalidPageSize)
        }

        var physicalBytes: UInt64 = 0
        var physicalBytesSize = MemoryLayout<UInt64>.size
        guard sysctlbyname("hw.memsize", &physicalBytes, &physicalBytesSize, nil, 0) == 0 else {
            return .failure(.sysctl(errno))
        }

        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let statisticsResult = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(host, HOST_VM_INFO64, rebound, &count)
            }
        }
        guard statisticsResult == KERN_SUCCESS else {
            return .failure(.kernel(statisticsResult))
        }

        return .success(
            MemoryStatistics(
                internalPages: UInt64(info.internal_page_count),
                purgeablePages: UInt64(info.purgeable_count),
                wiredPages: UInt64(info.wire_count),
                compressorPages: UInt64(info.compressor_page_count),
                physicalPages: physicalBytes / UInt64(pageSize)
            )
        )
    }
}

package enum MemoryUsageCalculator {
    package static func utilization(from statistics: MemoryStatistics) -> Double? {
        guard statistics.physicalPages > 0 else { return nil }

        let appPages = statistics.internalPages >= statistics.purgeablePages
            ? statistics.internalPages - statistics.purgeablePages
            : 0
        let appAndWired = saturatingAdd(appPages, statistics.wiredPages)
        let usedPages = saturatingAdd(appAndWired, statistics.compressorPages)
        return min(Double(usedPages) / Double(statistics.physicalPages), 1)
    }

    private static func saturatingAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }
}

package actor MemoryMetricProducer: MetricReadingProducer {
    private let reader: any MemoryStatisticsReader
    private var filter: ExponentialMovingAverage
    private var lastValidValue = 0.5

    package init(
        reader: any MemoryStatisticsReader = MachMemoryStatisticsReader(),
        smoothingTimeConstant: TimeInterval = 0.75
    ) {
        self.reader = reader
        filter = ExponentialMovingAverage(timeConstant: smoothingTimeConstant)
    }

    package func reading(at timestamp: TimeInterval) async -> MetricReading {
        guard case let .success(statistics) = await reader.readStatistics(),
              let utilization = MemoryUsageCalculator.utilization(from: statistics) else {
            return MetricReading(
                timestamp: timestamp,
                value: lastValidValue,
                metric: .memory,
                availability: .unavailable
            )
        }

        lastValidValue = filter.update(value: utilization, at: timestamp)
        return MetricReading(
            timestamp: timestamp,
            value: lastValidValue,
            metric: .memory,
            availability: .available
        )
    }
}
