import Darwin
import Foundation

package struct CPUTicks: Equatable, Sendable {
    package let user: UInt32
    package let system: UInt32
    package let idle: UInt32
    package let nice: UInt32

    package init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }
}

package enum CPUTickReadError: Error, Equatable, Sendable {
    case kernel(Int32)
}

package protocol CPUTickReader: Sendable {
    func readTicks() async -> Result<CPUTicks, CPUTickReadError>
}

package struct MachCPUTickReader: CPUTickReader {
    package init() {}

    package func readTicks() async -> Result<CPUTicks, CPUTickReadError> {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, rebound, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return .failure(.kernel(result))
        }
        return .success(
            CPUTicks(
                user: info.cpu_ticks.0,
                system: info.cpu_ticks.1,
                idle: info.cpu_ticks.2,
                nice: info.cpu_ticks.3
            )
        )
    }
}

package struct CPUUtilizationCalculator: Sendable {
    private var previous: CPUTicks?

    package init() {}

    package mutating func consume(_ ticks: CPUTicks) -> Double? {
        guard let previous else {
            self.previous = ticks
            return nil
        }
        self.previous = ticks

        let user = UInt64(ticks.user &- previous.user)
        let system = UInt64(ticks.system &- previous.system)
        let idle = UInt64(ticks.idle &- previous.idle)
        let nice = UInt64(ticks.nice &- previous.nice)
        let busy = user + system + nice
        let total = busy + idle
        guard total > 0 else { return nil }
        return min(max(Double(busy) / Double(total), 0), 1)
    }
}

package struct ExponentialMovingAverage: Sendable {
    package let timeConstant: TimeInterval
    private var filteredValue: Double?
    private var previousTimestamp: TimeInterval?

    package init(timeConstant: TimeInterval = 0.75) {
        precondition(timeConstant > 0)
        self.timeConstant = timeConstant
    }

    package mutating func update(value: Double, at timestamp: TimeInterval) -> Double {
        let normalizedValue = value.isFinite ? min(max(value, 0), 1) : 0
        guard let filteredValue, let previousTimestamp else {
            self.filteredValue = normalizedValue
            self.previousTimestamp = timestamp
            return normalizedValue
        }

        let elapsed = max(0, timestamp - previousTimestamp)
        let alpha = 1 - exp(-elapsed / timeConstant)
        let updatedValue = filteredValue + alpha * (normalizedValue - filteredValue)
        self.filteredValue = updatedValue
        self.previousTimestamp = timestamp
        return updatedValue
    }
}

package actor CPUMetricProducer: MetricReadingProducer {
    private let reader: any CPUTickReader
    private var calculator = CPUUtilizationCalculator()
    private var filter: ExponentialMovingAverage
    private var hasValidValue = false
    private var lastValidValue = 0.5

    package init(
        reader: any CPUTickReader = MachCPUTickReader(),
        smoothingTimeConstant: TimeInterval = 0.75
    ) {
        self.reader = reader
        filter = ExponentialMovingAverage(timeConstant: smoothingTimeConstant)
    }

    package func reading(at timestamp: TimeInterval) async -> MetricReading {
        switch await reader.readTicks() {
        case let .success(ticks):
            guard let utilization = calculator.consume(ticks) else {
                return readingWithoutNewTicks(at: timestamp)
            }
            lastValidValue = filter.update(value: utilization, at: timestamp)
            hasValidValue = true
            return MetricReading(
                timestamp: timestamp,
                value: lastValidValue,
                source: .cpu,
                availability: .available
            )
        case .failure:
            return unavailableReading(at: timestamp)
        }
    }

    private func readingWithoutNewTicks(at timestamp: TimeInterval) -> MetricReading {
        MetricReading(
            timestamp: timestamp,
            value: lastValidValue,
            source: .cpu,
            availability: hasValidValue ? .available : .unavailable
        )
    }

    private func unavailableReading(at timestamp: TimeInterval) -> MetricReading {
        MetricReading(
            timestamp: timestamp,
            value: lastValidValue,
            source: .cpu,
            availability: .unavailable
        )
    }
}
