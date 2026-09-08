import CoreGraphics
import Darwin
import Foundation
import StatusDriverCore

@main
struct StatusDriverModelTests {
    private typealias Check = (name: String, body: () async -> Bool)

    static func main() async {
        let checks: [Check] = [
            ("sample normalization", { sampleNormalization() }),
            ("random walk bounds", { randomWalkBounds() }),
            ("flat history prefill", { flatHistoryPrefill() }),
            ("pruning overlap", { pruningOverlap() }),
            ("bounded retention", { boundedRetention() }),
            ("point mapping", { pointMapping() }),
            ("terrain interpolation", { terrainInterpolation() }),
            ("driving key map", { drivingKeyMap() }),
            ("shared terrain geometry", { sharedTerrainGeometry() }),
            ("CPU utilization", { cpuUtilization() }),
            ("CPU counter rollover", { cpuCounterRollover() }),
            ("CPU zero delta", { cpuZeroDelta() }),
            ("metric smoothing", { metricSmoothing() }),
            ("CPU zero-delta and failure recovery", cpuFailureRecovery),
            ("memory utilization", { memoryUtilization() }),
            ("memory detail calculation", { memoryDetailCalculation() }),
            ("memory arithmetic bounds", { memoryArithmeticBounds() }),
            ("memory failure recovery", memoryFailureRecovery),
            ("metric failure isolation", metricFailureIsolation),
            ("dual synthetic channels", dualSyntheticChannels),
            ("independent metric histories", { independentMetricHistories() }),
            ("dual history retention", { dualHistoryRetention() }),
            ("metric selection rules", { metricSelectionRules() }),
            ("metric selection key map", { metricSelectionKeyMap() }),
            ("source selection", { sourceSelection() }),
            ("startup reading gate", { startupReadingGate() }),
            ("stream skips deadline backfill", streamSkipsDeadlineBackfill),
            ("stream cancellation", streamCancellation),
            ("hardware profile mapping", hardwareProfileMapping),
            ("partial hardware profile", partialHardwareProfile),
            ("secondary activity stream", secondaryActivityStream),
            ("live Mach CPU sample", liveMachCPUSample),
            ("live Mach memory sample", liveMachMemorySample),
            ("live hardware profile", liveHardwareProfile),
            ("live system activity", liveSystemActivity),
        ]

        var failures = 0
        for check in checks {
            if await check.body() {
                print("PASS  \(check.name)")
            } else {
                failures += 1
                print("FAIL  \(check.name)")
            }
        }

        print("\n\(checks.count - failures)/\(checks.count) checks passed")
        if failures > 0 {
            exit(EXIT_FAILURE)
        }
    }

    private static func sampleNormalization() -> Bool {
        MetricSample(timestamp: 0, value: -0.5).value == 0
            && MetricSample(timestamp: 0, value: 1.5).value == 1
            && MetricSample(timestamp: 0, value: .nan).value == 0
            && MetricSample(timestamp: 0, value: 0.35).value == 0.35
            && MetricReading(
                timestamp: 0,
                value: .infinity,
                metric: .cpu,
                availability: .available
            ).value == 0
    }

    private static func randomWalkBounds() -> Bool {
        var source = BoundedRandomWalkSource(initialValue: 0.5)
        for index in 0..<10_000 {
            let sample = source.nextSample(at: Double(index))
            if !(0...1).contains(sample.value) {
                return false
            }
        }
        return true
    }

    private static func flatHistoryPrefill() -> Bool {
        var buffer = RollingSampleBuffer()
        buffer.prefill(endingAt: 10, value: 0.4, interval: 0.15, duration: 1)

        return approximatelyEqual(buffer.samples.first?.timestamp ?? -1, 8.95)
            && approximatelyEqual(buffer.samples.last?.timestamp ?? -1, 10)
            && buffer.samples.allSatisfy { $0.value == 0.4 }
    }

    private static func pruningOverlap() -> Bool {
        var buffer = RollingSampleBuffer()
        for timestamp in 0...10 {
            buffer.append(MetricSample(timestamp: Double(timestamp), value: 0.5))
        }

        buffer.prune(before: 5.5)
        return buffer.samples.first?.timestamp == 5
            && buffer.samples.last?.timestamp == 10
    }

    private static func boundedRetention() -> Bool {
        var buffer = RollingSampleBuffer()
        let interval = 0.1
        let retention = 60.0

        for index in 0..<10_000 {
            let timestamp = Double(index) * interval
            buffer.append(MetricSample(timestamp: timestamp, value: 0.5))
            buffer.prune(before: timestamp - retention)
        }

        return buffer.samples.count <= 602
    }

    private static func pointMapping() -> Bool {
        let layout = TerrainLayout(pointsPerSecond: 20, bottomInset: 10, topInset: 10)
        let sample = MetricSample(timestamp: 2, value: 0.5)
        return layout.point(for: sample, sceneHeight: 110) == CGPoint(x: 40, y: 55)
    }

    private static func terrainInterpolation() -> Bool {
        let samples = [
            MetricSample(timestamp: 0, value: 0),
            MetricSample(timestamp: 1, value: 1),
        ]
        let layout = TerrainLayout(pointsPerSecond: 20, bottomInset: 10, topInset: 10)
        let geometry = TerrainGeometry(samples: samples, layout: layout, sceneHeight: 110)

        return geometry.height(atWorldX: 10) == 55
            && geometry.height(atWorldX: -10) == 10
            && geometry.height(atWorldX: 30) == 100
    }

    private static func drivingKeyMap() -> Bool {
        drivingInput(forKeyCode: 124) == .control(.driveRight)
            && drivingInput(forKeyCode: 2) == .control(.driveRight)
            && drivingInput(forKeyCode: 123) == .control(.brakeOrDriveLeft)
            && drivingInput(forKeyCode: 0) == .control(.brakeOrDriveLeft)
            && drivingInput(forKeyCode: 15) == .reset
            && drivingInput(forKeyCode: 126) == nil
            && drivingInput(forKeyCode: 125) == nil
            && drivingInput(forKeyCode: 13) == nil
            && drivingInput(forKeyCode: 1) == nil
            && drivingInput(forKeyCode: 99) == nil
    }

    private static func sharedTerrainGeometry() -> Bool {
        let samples = [
            MetricSample(timestamp: 0, value: 0.25),
            MetricSample(timestamp: 1, value: 0.75),
            MetricSample(timestamp: 2, value: 0.5),
        ]
        let layout = TerrainLayout(pointsPerSecond: 20, bottomInset: 10, topInset: 10)
        let geometry = TerrainGeometry(samples: samples, layout: layout, sceneHeight: 110)
        let expected = [
            CGPoint(x: 0, y: 32.5),
            CGPoint(x: 20, y: 77.5),
            CGPoint(x: 40, y: 55),
        ]

        return geometry.points == expected
            && geometry.linePath() != nil
            && geometry.fillPath() != nil
    }

    private static func cpuUtilization() -> Bool {
        var calculator = CPUUtilizationCalculator()
        let first = CPUTicks(user: 100, system: 50, idle: 850, nice: 5)
        let second = CPUTicks(user: 112, system: 56, idle: 862, nice: 11)

        return calculator.consume(first) == nil
            && approximatelyEqual(calculator.consume(second) ?? -1, 2.0 / 3.0)
    }

    private static func cpuCounterRollover() -> Bool {
        var calculator = CPUUtilizationCalculator()
        let nearLimit = UInt32.max - 4
        _ = calculator.consume(CPUTicks(user: nearLimit, system: 0, idle: nearLimit, nice: 0))
        let utilization = calculator.consume(CPUTicks(user: 3, system: 0, idle: 3, nice: 0))
        return utilization == 0.5
    }

    private static func cpuZeroDelta() -> Bool {
        var calculator = CPUUtilizationCalculator()
        let ticks = CPUTicks(user: 10, system: 20, idle: 30, nice: 40)
        return calculator.consume(ticks) == nil
            && calculator.consume(ticks) == nil
    }

    private static func metricSmoothing() -> Bool {
        var filter = ExponentialMovingAverage(timeConstant: 0.75)
        let first = filter.update(value: 0, at: 0)
        let second = filter.update(value: 1, at: 0.75)
        let nonfinite = filter.update(value: .nan, at: 1.5)
        return first == 0
            && approximatelyEqual(second, 1 - exp(-1))
            && nonfinite.isFinite
    }

    private static func cpuFailureRecovery() async -> Bool {
        let reader = ScriptedTickReader(results: [
            .success(CPUTicks(user: 100, system: 50, idle: 850, nice: 0)),
            .success(CPUTicks(user: 112, system: 56, idle: 862, nice: 0)),
            .success(CPUTicks(user: 112, system: 56, idle: 862, nice: 0)),
            .failure(.kernel(KERN_FAILURE)),
            .success(CPUTicks(user: 122, system: 61, idle: 877, nice: 0)),
        ])
        let producer = CPUMetricProducer(reader: reader, smoothingTimeConstant: 0.75)

        let baseline = await producer.reading(at: 0)
        let live = await producer.reading(at: 0.15)
        let zeroDelta = await producer.reading(at: 0.30)
        let failed = await producer.reading(at: 0.45)
        let recovered = await producer.reading(at: 0.60)

        return baseline.availability == .unavailable
            && live.availability == .available
            && live.value == 0.6
            && zeroDelta.availability == .available
            && zeroDelta.value == live.value
            && failed.availability == .unavailable
            && failed.value == live.value
            && recovered.availability == .available
            && recovered.value < live.value
            && recovered.value > 0.5
    }

    private static func memoryUtilization() -> Bool {
        let statistics = MemoryStatistics(
            internalPages: 600,
            purgeablePages: 100,
            wiredPages: 200,
            compressorPages: 100,
            physicalPages: 1_000
        )
        return MemoryUsageCalculator.utilization(from: statistics) == 0.8
    }

    private static func memoryDetailCalculation() -> Bool {
        let statistics = MemoryStatistics(
            internalPages: 600,
            purgeablePages: 100,
            wiredPages: 200,
            compressorPages: 100,
            externalPages: 150,
            physicalPages: 1_000,
            pageSizeBytes: 4_096
        )
        guard let usage = MemoryUsageCalculator.calculate(from: statistics) else { return false }
        let details = usage.details

        return usage.utilization == 0.8
            && details.statistics == statistics
            && details.installedBytes == 4_096_000
            && details.inUseBytes == 3_276_800
            && details.availableBytes == 819_200
            && details.appBytes == 2_048_000
            && details.wiredBytes == 819_200
            && details.compressedBytes == 409_600
            && details.fileCacheBytes == 614_400
            && details.appFraction == 0.5
            && details.wiredFraction == 0.2
            && details.compressedFraction == 0.1
            && details.availableFraction == 0.2
    }

    private static func memoryArithmeticBounds() -> Bool {
        let purgeableExceedsInternal = MemoryStatistics(
            internalPages: 50,
            purgeablePages: 100,
            wiredPages: 100,
            compressorPages: 50,
            physicalPages: 1_000
        )
        let overflowing = MemoryStatistics(
            internalPages: UInt64.max,
            purgeablePages: 0,
            wiredPages: UInt64.max,
            compressorPages: UInt64.max,
            physicalPages: 1
        )
        let noMemory = MemoryStatistics(
            internalPages: 0,
            purgeablePages: 0,
            wiredPages: 0,
            compressorPages: 0,
            physicalPages: 0
        )

        let overflowingUsage = MemoryUsageCalculator.calculate(from: overflowing)
        let compositionTotal = overflowingUsage.map {
            $0.details.appFraction
                + $0.details.wiredFraction
                + $0.details.compressedFraction
                + $0.details.availableFraction
        }

        return MemoryUsageCalculator.utilization(from: purgeableExceedsInternal) == 0.15
            && overflowingUsage?.utilization == 1
            && compositionTotal == 1
            && MemoryUsageCalculator.utilization(from: noMemory) == nil
    }

    private static func memoryFailureRecovery() async -> Bool {
        let reader = ScriptedMemoryReader(results: [
            .success(memoryStatistics(usedFraction: 0.8)),
            .failure(.kernel(KERN_FAILURE)),
            .success(memoryStatistics(usedFraction: 0.6)),
        ])
        let producer = MemoryMetricProducer(reader: reader, smoothingTimeConstant: 0.75)

        let live = await producer.reading(at: 0)
        let failed = await producer.reading(at: 0.75)
        let recovered = await producer.reading(at: 1.5)

        return live.metric == .memory
            && live.availability == .available
            && live.value == 0.8
            && live.details != nil
            && failed.availability == .unavailable
            && failed.value == live.value
            && failed.details == live.details
            && recovered.availability == .available
            && recovered.value < live.value
            && recovered.value > 0.6
    }

    private static func metricFailureIsolation() async -> Bool {
        let cpuReader = ScriptedTickReader(results: [
            .success(CPUTicks(user: 100, system: 50, idle: 850, nice: 0)),
            .success(CPUTicks(user: 112, system: 56, idle: 862, nice: 0)),
        ])
        let memoryReader = ScriptedMemoryReader(results: [
            .success(memoryStatistics(usedFraction: 0.7)),
            .failure(.kernel(KERN_FAILURE)),
        ])
        let producer = ConcurrentMetricSnapshotProducer(
            cpuProducer: CPUMetricProducer(reader: cpuReader),
            memoryProducer: MemoryMetricProducer(reader: memoryReader)
        )

        let first = await producer.snapshot(at: 0)
        let second = await producer.snapshot(at: 0.15)
        return first.cpu.availability == .unavailable
            && first.memory.availability == .available
            && second.memory.availability == .unavailable
            && second.cpu.availability == .available
    }

    private static func dualSyntheticChannels() async -> Bool {
        let producer = SyntheticMetricSnapshotProducer(
            cpuInitialValue: 0.2,
            memoryInitialValue: 0.8
        )
        let snapshot = await producer.snapshot(at: 0)
        return snapshot.cpu.metric == .cpu
            && snapshot.memory.metric == .memory
            && snapshot.cpu.availability == .available
            && snapshot.memory.availability == .available
            && snapshot.cpu.value < 0.4
            && snapshot.memory.value > 0.6
    }

    private static func independentMetricHistories() -> Bool {
        var histories = MetricHistoryStore(sampleInterval: 0.15, retentionDuration: 1)
        histories.ingest(metricReading(timestamp: 0, value: 0.2, metric: .cpu))
        histories.ingest(metricReading(timestamp: 0, value: 0.7, metric: .memory))
        histories.ingest(metricReading(timestamp: 2, value: 0.3, metric: .cpu))

        let cpu = histories.samples(for: .cpu)
        let memory = histories.samples(for: .memory)
        return cpu.last?.value == 0.3
            && cpu.first?.timestamp == 0
            && memory.last?.value == 0.7
            && memory.last?.timestamp == 0
            && histories.ingest(metricReading(timestamp: 2, value: 0.9, metric: .cpu)) == false
    }

    private static func dualHistoryRetention() -> Bool {
        var histories = MetricHistoryStore(sampleInterval: 0.1, retentionDuration: 60)
        for index in 0..<10_000 {
            let timestamp = Double(index) * 0.1
            histories.ingest(metricReading(timestamp: timestamp, value: 0.2, metric: .cpu))
            histories.ingest(metricReading(timestamp: timestamp, value: 0.7, metric: .memory))
        }

        return histories.samples(for: .cpu).count <= 602
            && histories.samples(for: .memory).count <= 602
    }

    private static func metricSelectionRules() -> Bool {
        var selection = MetricSelectionState()
        let rejectsCurrent = !selection.select(.cpu, availability: .available)
        let rejectsUnavailable = !selection.select(.memory, availability: .unavailable)
        let selectsMemory = selection.select(.memory, availability: .available)
        let rejectsUnavailableSwitch = !selection.select(.cpu, availability: .unavailable)
        let remainsSelectedWhenUnavailable = selection.selectedMetric == .memory
        let selectsCPU = selection.select(.cpu, availability: .available)

        return rejectsCurrent
            && rejectsUnavailable
            && selectsMemory
            && rejectsUnavailableSwitch
            && remainsSelectedWhenUnavailable
            && selectsCPU
            && selection.selectedMetric == .cpu
    }

    private static func metricSelectionKeyMap() -> Bool {
        metricSelection(forKeyCode: 18) == .cpu
            && metricSelection(forKeyCode: 19) == .memory
            && metricSelection(forKeyCode: 20) == nil
    }

    private static func sourceSelection() -> Bool {
        MetricSourceMode(arguments: ["StatusDriver"]) == .live
            && MetricSourceMode(arguments: ["StatusDriver", "--synthetic"]) == .synthetic
    }

    private static func startupReadingGate() -> Bool {
        var liveGate = MetricStartupGate(sourceMode: .live, unavailableGracePeriod: 0.3)
        let unavailable = metricReading(
            timestamp: 0,
            value: 0.5,
            metric: .cpu,
            availability: .unavailable
        )
        let available = metricReading(timestamp: 0.15, value: 0.2, metric: .cpu)
        guard liveGate.consume(unavailable) == nil,
              liveGate.consume(available) == available else { return false }

        var failedLiveGate = MetricStartupGate(sourceMode: .live, unavailableGracePeriod: 0.3)
        guard failedLiveGate.consume(unavailable) == nil else { return false }
        let fallback = metricReading(
            timestamp: 0.3,
            value: 0.5,
            metric: .cpu,
            availability: .unavailable
        )

        var syntheticGate = MetricStartupGate(sourceMode: .synthetic)
        let synthetic = metricReading(timestamp: 0, value: 0.4, metric: .cpu)
        return failedLiveGate.consume(fallback) == fallback
            && syntheticGate.consume(synthetic) == synthetic
    }

    private static func streamSkipsDeadlineBackfill() async -> Bool {
        let clock = ManualSamplingClock()
        let producer = FixedSnapshotProducer()
        let stream = makeMetricStream(producer: producer, clock: clock)
        var iterator = stream.makeAsyncIterator()

        guard let first = await iterator.next(),
              await waitUntil({ await clock.hasSleeper }),
              await clock.lastSleepDuration == .milliseconds(150) else { return false }
        await clock.advance(by: 10)

        guard let second = await iterator.next(),
              await waitUntil({ await clock.hasSleeper }) else { return false }
        await clock.advance(by: 10)

        guard let third = await iterator.next() else { return false }
        return first.timestamp == 0
            && second.timestamp == 10
            && third.timestamp == 20
    }

    private static func streamCancellation() async -> Bool {
        let clock = ManualSamplingClock()
        let producer = FixedSnapshotProducer()
        let consumer = Task {
            for await _ in makeMetricStream(producer: producer, clock: clock) {}
        }

        guard await waitUntil({ await clock.hasSleeper }) else {
            consumer.cancel()
            return false
        }
        consumer.cancel()
        return await waitUntil({ await clock.wasCancelled })
    }

    private static func hardwareProfileMapping() async -> Bool {
        let sysctl = DictionarySysctlReader(
            strings: [
                "machdep.cpu.brand_string": "Example CPU",
                "hw.perflevel0.name": "Performance",
                "hw.perflevel1.name": "Efficiency",
            ],
            integers: [
                "hw.packages": 1,
                "hw.physicalcpu": 10,
                "hw.logicalcpu": 10,
                "hw.nperflevels": 2,
                "hw.perflevel0.physicalcpu": 4,
                "hw.perflevel0.logicalcpu": 4,
                "hw.perflevel0.l1icachesize": 192,
                "hw.perflevel0.l1dcachesize": 128,
                "hw.perflevel0.l2cachesize": 16_384,
                "hw.perflevel1.physicalcpu": 6,
                "hw.perflevel1.logicalcpu": 6,
                "hw.perflevel1.l1icachesize": 128,
                "hw.perflevel1.l1dcachesize": 64,
                "hw.perflevel1.l2cachesize": 4_096,
                "kern.hv_support": 1,
                "hw.memsize": 16_000,
                "hw.optional.arm64": 1,
            ]
        )
        let profile = await SystemHardwareProfileReader(sysctl: sysctl).readProfile()

        return profile.cpuName == "Example CPU"
            && profile.packageCount == 1
            && profile.physicalCoreCount == 10
            && profile.logicalProcessorCount == 10
            && profile.virtualizationSupported == true
            && profile.performanceLevels.count == 2
            && profile.performanceLevels[0].name == "Performance"
            && profile.performanceLevels[1].physicalCoreCount == 6
            && profile.l3CacheBytes == nil
            && profile.installedMemoryBytes == 16_000
            && profile.memoryType == "Unified memory"
    }

    private static func partialHardwareProfile() async -> Bool {
        let profile = await SystemHardwareProfileReader(
            sysctl: DictionarySysctlReader(
                strings: ["machdep.cpu.brand_string": "Partial CPU"],
                integers: [:]
            )
        ).readProfile()

        return profile.cpuName == "Partial CPU"
            && profile.packageCount == nil
            && profile.performanceLevels.isEmpty
            && profile.virtualizationSupported == nil
            && profile.installedMemoryBytes == nil
            && profile.memoryType == nil
    }

    private static func secondaryActivityStream() async -> Bool {
        let clock = ManualSamplingClock()
        let reader = FixedSystemActivityReader()
        let stream = makeSystemActivityStream(reader: reader, clock: clock)
        var iterator = stream.makeAsyncIterator()

        guard let first = await iterator.next(),
              first.processCount == 4,
              first.threadCount == nil,
              first.uptime == 12,
              await waitUntil({ await clock.hasSleeper }),
              await clock.lastSleepDuration == .seconds(1) else { return false }
        await clock.advance(by: 5)
        guard let second = await iterator.next() else { return false }
        return second.timestamp == 5
    }

    private static func liveMachCPUSample() async -> Bool {
        let reader = MachCPUTickReader()
        guard case let .success(first) = await reader.readTicks() else { return false }

        var calculator = CPUUtilizationCalculator()
        _ = calculator.consume(first)
        for _ in 0..<5 {
            try? await ContinuousClock().sleep(for: .milliseconds(150))
            guard case let .success(next) = await reader.readTicks() else { continue }
            if let utilization = calculator.consume(next) {
                return (0...1).contains(utilization)
            }
        }
        return false
    }

    private static func liveMachMemorySample() async -> Bool {
        let reader = MachMemoryStatisticsReader()
        guard case let .success(statistics) = await reader.readStatistics(),
              statistics.physicalPages > 0,
              let utilization = MemoryUsageCalculator.utilization(from: statistics) else {
            return false
        }
        guard (0...1).contains(utilization),
              let usage = MemoryUsageCalculator.calculate(from: statistics) else { return false }
        return usage.details.installedBytes > 0
            && usage.details.inUseBytes <= usage.details.installedBytes
            && usage.details.availableBytes <= usage.details.installedBytes
    }

    private static func liveHardwareProfile() async -> Bool {
        let profile = await SystemHardwareProfileReader().readProfile()
        return !(profile.cpuName ?? "").isEmpty
            && (profile.packageCount ?? 0) > 0
            && (profile.physicalCoreCount ?? 0) > 0
            && (profile.logicalProcessorCount ?? 0) > 0
            && (profile.installedMemoryBytes ?? 0) > 0
            && !profile.performanceLevels.isEmpty
    }

    private static func liveSystemActivity() async -> Bool {
        let activity = await DarwinSystemActivityReader().readActivity(at: 1)
        return activity.timestamp == 1
            && (activity.processCount ?? 0) > 0
            && (activity.threadCount ?? 0) > 0
            && (activity.uptime ?? 0) > 0
    }

    private static func metricReading(
        timestamp: TimeInterval,
        value: Double,
        metric: MetricIdentity,
        availability: MetricAvailability = .available
    ) -> MetricReading {
        MetricReading(
            timestamp: timestamp,
            value: value,
            metric: metric,
            availability: availability
        )
    }

    private static func memoryStatistics(usedFraction: Double) -> MemoryStatistics {
        MemoryStatistics(
            internalPages: UInt64(usedFraction * 1_000),
            purgeablePages: 0,
            wiredPages: 0,
            compressorPages: 0,
            physicalPages: 1_000
        )
    }

    private static func approximatelyEqual(_ lhs: Double, _ rhs: Double) -> Bool {
        abs(lhs - rhs) < 1e-9
    }

    private static func waitUntil(_ predicate: () async -> Bool) async -> Bool {
        for _ in 0..<1_000 {
            if await predicate() { return true }
            await Task.yield()
        }
        return false
    }
}

private actor ScriptedTickReader: CPUTickReader {
    private var results: [Result<CPUTicks, CPUTickReadError>]

    init(results: [Result<CPUTicks, CPUTickReadError>]) {
        self.results = results
    }

    func readTicks() -> Result<CPUTicks, CPUTickReadError> {
        guard !results.isEmpty else { return .failure(.kernel(KERN_FAILURE)) }
        return results.removeFirst()
    }
}

private actor ScriptedMemoryReader: MemoryStatisticsReader {
    private var results: [Result<MemoryStatistics, MemoryReadError>]

    init(results: [Result<MemoryStatistics, MemoryReadError>]) {
        self.results = results
    }

    func readStatistics() -> Result<MemoryStatistics, MemoryReadError> {
        guard !results.isEmpty else { return .failure(.kernel(KERN_FAILURE)) }
        return results.removeFirst()
    }
}

private actor FixedSnapshotProducer: MetricSnapshotProducer {
    func snapshot(at timestamp: TimeInterval) -> MetricSnapshot {
        MetricSnapshot(
            timestamp: timestamp,
            cpu: MetricReading(
                timestamp: timestamp,
                value: 0.5,
                metric: .cpu,
                availability: .available
            ),
            memory: MetricReading(
                timestamp: timestamp,
                value: 0.7,
                metric: .memory,
                availability: .available
            )
        )
    }
}

private struct DictionarySysctlReader: SysctlValueReading {
    let strings: [String: String]
    let integers: [String: UInt64]

    func string(for name: String) -> String? {
        strings[name]
    }

    func integer(for name: String) -> UInt64? {
        integers[name]
    }
}

private struct FixedSystemActivityReader: SystemActivityReading {
    func readActivity(at timestamp: TimeInterval) -> SystemActivitySnapshot {
        SystemActivitySnapshot(
            timestamp: timestamp,
            processCount: 4,
            threadCount: nil,
            uptime: 12
        )
    }
}

private actor ManualSamplingClock: SamplingClock {
    private var currentTime: TimeInterval = 0
    private var sleeper: CheckedContinuation<Void, any Error>?
    private(set) var wasCancelled = false
    private(set) var lastSleepDuration: Duration?

    var hasSleeper: Bool { sleeper != nil }

    func elapsedTime() -> TimeInterval {
        currentTime
    }

    func sleep(for duration: Duration) async throws {
        lastSleepDuration = duration
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleeper = continuation
            }
        } onCancel: {
            Task { await self.cancelSleep() }
        }
    }

    func advance(by interval: TimeInterval) {
        currentTime += interval
        let continuation = sleeper
        sleeper = nil
        continuation?.resume(returning: ())
    }

    private func cancelSleep() {
        wasCancelled = true
        let continuation = sleeper
        sleeper = nil
        continuation?.resume(throwing: CancellationError())
    }
}
