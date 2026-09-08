import Darwin
import Foundation

package struct MemoryStatistics: Equatable, Sendable {
    package let internalPages: UInt64
    package let purgeablePages: UInt64
    package let wiredPages: UInt64
    package let compressorPages: UInt64
    package let externalPages: UInt64
    package let physicalPages: UInt64
    package let pageSizeBytes: UInt64

    package init(
        internalPages: UInt64,
        purgeablePages: UInt64,
        wiredPages: UInt64,
        compressorPages: UInt64,
        externalPages: UInt64 = 0,
        physicalPages: UInt64,
        pageSizeBytes: UInt64 = 1
    ) {
        self.internalPages = internalPages
        self.purgeablePages = purgeablePages
        self.wiredPages = wiredPages
        self.compressorPages = compressorPages
        self.externalPages = externalPages
        self.physicalPages = physicalPages
        self.pageSizeBytes = pageSizeBytes
    }
}

package struct MemoryDetails: Equatable, Sendable {
    package let statistics: MemoryStatistics
    package let installedBytes: UInt64
    package let inUseBytes: UInt64
    package let availableBytes: UInt64
    package let appBytes: UInt64
    package let wiredBytes: UInt64
    package let compressedBytes: UInt64
    package let fileCacheBytes: UInt64

    package var appFraction: Double { fraction(appBytes) }
    package var wiredFraction: Double { fraction(wiredBytes) }
    package var compressedFraction: Double { fraction(compressedBytes) }
    package var availableFraction: Double { fraction(availableBytes) }

    private func fraction(_ bytes: UInt64) -> Double {
        guard installedBytes > 0 else { return 0 }
        return min(Double(bytes) / Double(installedBytes), 1)
    }
}

package struct MemoryUsage: Equatable, Sendable {
    package let utilization: Double
    package let details: MemoryDetails
}

package enum MemoryReadError: Error, Equatable, Sendable {
    case kernel(Int32)
    case sysctl(Int32)
    case invalidPageSize
}

package protocol MemoryStatisticsReader: Sendable {
    func readStatistics() async -> Result<MemoryStatistics, MemoryReadError>
}

package actor MachMemoryStatisticsReader: MemoryStatisticsReader {
    private struct PhysicalMemory: Sendable {
        let pages: UInt64
        let pageSizeBytes: UInt64
    }

    private var cachedPhysicalMemory: PhysicalMemory?

    package init() {}

    package func readStatistics() -> Result<MemoryStatistics, MemoryReadError> {
        let physicalMemory: PhysicalMemory
        switch resolvePhysicalMemory() {
        case let .success(value):
            physicalMemory = value
        case let .failure(error):
            return .failure(error)
        }

        var info = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else {
            return .failure(.kernel(result))
        }

        return .success(
            MemoryStatistics(
                internalPages: UInt64(info.internal_page_count),
                purgeablePages: UInt64(info.purgeable_count),
                wiredPages: UInt64(info.wire_count),
                compressorPages: UInt64(info.compressor_page_count),
                externalPages: UInt64(info.external_page_count),
                physicalPages: physicalMemory.pages,
                pageSizeBytes: physicalMemory.pageSizeBytes
            )
        )
    }

    private func resolvePhysicalMemory() -> Result<PhysicalMemory, MemoryReadError> {
        if let cachedPhysicalMemory {
            return .success(cachedPhysicalMemory)
        }

        var pageSize: vm_size_t = 0
        let pageSizeResult = host_page_size(mach_host_self(), &pageSize)
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

        let physicalMemory = PhysicalMemory(
            pages: physicalBytes / UInt64(pageSize),
            pageSizeBytes: UInt64(pageSize)
        )
        guard physicalMemory.pages > 0 else {
            return .failure(.invalidPageSize)
        }
        cachedPhysicalMemory = physicalMemory
        return .success(physicalMemory)
    }
}

package enum MemoryUsageCalculator {
    package static func calculate(from statistics: MemoryStatistics) -> MemoryUsage? {
        guard statistics.physicalPages > 0, statistics.pageSizeBytes > 0 else { return nil }

        let appPages = statistics.internalPages >= statistics.purgeablePages
            ? statistics.internalPages - statistics.purgeablePages
            : 0
        let boundedAppPages = min(appPages, statistics.physicalPages)
        let afterAppPages = statistics.physicalPages - boundedAppPages
        let boundedWiredPages = min(statistics.wiredPages, afterAppPages)
        let afterWiredPages = afterAppPages - boundedWiredPages
        let boundedCompressedPages = min(statistics.compressorPages, afterWiredPages)
        let availablePages = afterWiredPages - boundedCompressedPages
        let boundedUsedPages = statistics.physicalPages - availablePages

        let installedBytes = saturatingMultiply(
            statistics.physicalPages,
            statistics.pageSizeBytes
        )
        guard installedBytes > 0 else { return nil }

        let details = MemoryDetails(
            statistics: statistics,
            installedBytes: installedBytes,
            inUseBytes: saturatingMultiply(boundedUsedPages, statistics.pageSizeBytes),
            availableBytes: saturatingMultiply(
                availablePages,
                statistics.pageSizeBytes
            ),
            appBytes: saturatingMultiply(
                boundedAppPages,
                statistics.pageSizeBytes
            ),
            wiredBytes: saturatingMultiply(
                boundedWiredPages,
                statistics.pageSizeBytes
            ),
            compressedBytes: saturatingMultiply(
                boundedCompressedPages,
                statistics.pageSizeBytes
            ),
            fileCacheBytes: saturatingMultiply(
                min(statistics.externalPages, availablePages),
                statistics.pageSizeBytes
            )
        )
        return MemoryUsage(
            utilization: min(Double(boundedUsedPages) / Double(statistics.physicalPages), 1),
            details: details
        )
    }

    package static func utilization(from statistics: MemoryStatistics) -> Double? {
        calculate(from: statistics)?.utilization
    }

    private static func saturatingMultiply(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.multipliedReportingOverflow(by: rhs)
        return result.overflow ? UInt64.max : result.partialValue
    }
}

package actor MemoryMetricProducer: MetricReadingProducer {
    private let reader: any MemoryStatisticsReader
    private var filter: ExponentialMovingAverage
    private var lastValidValue = 0.5
    private var lastValidDetails: MemoryDetails?

    package init(
        reader: any MemoryStatisticsReader = MachMemoryStatisticsReader(),
        smoothingTimeConstant: TimeInterval = 0.75
    ) {
        self.reader = reader
        filter = ExponentialMovingAverage(timeConstant: smoothingTimeConstant)
    }

    package func reading(at timestamp: TimeInterval) async -> MetricReading {
        guard case let .success(statistics) = await reader.readStatistics(),
              let usage = MemoryUsageCalculator.calculate(from: statistics) else {
            return MetricReading(
                timestamp: timestamp,
                value: lastValidValue,
                metric: .memory,
                availability: .unavailable,
                details: lastValidDetails.map(MetricReadingDetails.memory)
            )
        }

        lastValidValue = filter.update(value: usage.utilization, at: timestamp)
        lastValidDetails = usage.details
        return MetricReading(
            timestamp: timestamp,
            value: lastValidValue,
            metric: .memory,
            availability: .available,
            details: .memory(usage.details)
        )
    }
}
