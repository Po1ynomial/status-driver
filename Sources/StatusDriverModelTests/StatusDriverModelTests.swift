import CoreGraphics
import Darwin
import Foundation
import StatusDriverCore
import SystemConfiguration

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
            ("60-second graph timeline", { graphTimelineMapping() }),
            ("hidden collision extension", { hiddenCollisionExtension() }),
            ("easter egg input routing", { easterEggInputRouting() }),
            ("resource easter egg state", { resourceEasterEggState() }),
            ("boat motion", { boatMotion() }),
            ("tetromino shapes and bag", { tetrominoShapesAndBag() }),
            ("tetromino drop clock", { tetrominoDropClock() }),
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
            ("chart bucket averaging", { chartBucketAveraging() }),
            ("chart skips gap backfill", { chartSkipsGapBackfill() }),
            ("chart history density", { chartHistoryDensity() }),
            ("committed chart samples", { committedChartSamples() }),
            ("physical graph edge coverage", { physicalGraphEdgeCoverage() }),
            ("independent metric histories", { independentMetricHistories() }),
            ("dual history retention", { dualHistoryRetention() }),
            ("left terrain margin retention", { leftTerrainMarginRetention() }),
            ("metric selection rules", { resourceSelectionRules() }),
            ("resource inventory reconciliation", { resourceInventoryReconciliation() }),
            ("adaptive scale hysteresis", { adaptiveScaleHysteresis() }),
            ("deterministic synthetic source", { deterministicSyntheticSource() }),
            ("disk performance calculation", { diskPerformanceCalculation() }),
            ("disk counter reset", { diskCounterReset() }),
            ("synthetic disk coherence", syntheticDiskCoherence),
            ("network performance calculation", { networkPerformanceCalculation() }),
            ("network counter reset", { networkCounterReset() }),
            ("physical network filtering", { physicalNetworkFiltering() }),
            ("network discovery cadence", networkDiscoveryCadence),
            ("synthetic network coherence", syntheticNetworkCoherence),
            ("GPU performance clamping", { gpuPerformanceClamping() }),
            ("GPU rediscovery cadence", gpuRediscoveryCadence),
            ("synthetic GPU coherence", syntheticGPUCoherence),
            ("source selection", { sourceSelection() }),
            ("startup reading gate", { startupReadingGate() }),
            ("stream skips deadline backfill", streamSkipsDeadlineBackfill),
            ("stream cancellation", streamCancellation),
            ("hardware profile mapping", hardwareProfileMapping),
            ("partial hardware profile", partialHardwareProfile),
            ("secondary activity stream", secondaryActivityStream),
            ("live Mach CPU sample", liveMachCPUSample),
            ("live Mach memory sample", liveMachMemorySample),
            ("live IOKit disk discovery", liveDiskDiscovery),
            ("live physical network discovery", liveNetworkDiscovery),
            ("live IOKit GPU reading", liveGPUReading),
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
                resource: .cpu,
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

    private static func graphTimelineMapping() -> Bool {
        let timeline = GraphTimelineLayout(width: 900, visibleDuration: 60)
        return timeline.pointsPerSecond == 15
            && timeline.worldX(for: 100) == 1_500
            && timeline.cameraCenterX(endingAt: 100) == 1_050
            && timeline.visibleWorldRange(endingAt: 100) == 600...1_500
    }

    private static func hiddenCollisionExtension() -> Bool {
        let samples = [
            MetricSample(timestamp: 0, value: 0.5),
            MetricSample(timestamp: 1, value: 0.5),
        ]
        let layout = TerrainLayout(pointsPerSecond: 20, bottomInset: 0, topInset: 0)
        let geometry = TerrainGeometry(samples: samples, layout: layout, sceneHeight: 100)
        guard let visible = geometry.linePath(),
              let collision = geometry.collisionPath(rightExtension: 120) else { return false }

        return visible.boundingBox.maxX == 20
            && collision.boundingBox.maxX == 140
            && collision.boundingBox.maxY == visible.boundingBox.maxY
    }

    private static func easterEggInputRouting() -> Bool {
        let pressLeft = EasterEggInputEvent(key: .left, phase: .pressed)
        let releaseLeft = EasterEggInputEvent(key: .left, phase: .released)
        let repeatRight = EasterEggInputEvent(key: .right, phase: .pressed, isRepeat: true)
        let pressDown = EasterEggInputEvent(key: .down, phase: .pressed)
        let releaseDown = EasterEggInputEvent(key: .down, phase: .released)
        let pressUp = EasterEggInputEvent(key: .up, phase: .pressed)
        let pressSpace = EasterEggInputEvent(key: .space, phase: .pressed)
        let repeatSpace = EasterEggInputEvent(key: .space, phase: .pressed, isRepeat: true)
        let pressReset = EasterEggInputEvent(key: .reset, phase: .pressed)
        let repeatReset = EasterEggInputEvent(key: .reset, phase: .pressed, isRepeat: true)
        let pressToggle = EasterEggInputEvent(key: .toggle, phase: .pressed)

        return routeEasterEggInput(pressLeft, utility: .car)
            == EasterEggInputRoute(
                command: .setMovement(.left, isPressed: true),
                consumesEvent: true
            )
            && routeEasterEggInput(releaseLeft, utility: .boat)
                == EasterEggInputRoute(
                    command: .setMovement(.left, isPressed: false),
                    consumesEvent: true
                )
            && routeEasterEggInput(repeatRight, utility: .tetromino)
                == EasterEggInputRoute(command: .stepRight, consumesEvent: true)
            && routeEasterEggInput(pressDown, utility: .tetromino)
                == EasterEggInputRoute(
                    command: .setFastDrop(isPressed: true),
                    consumesEvent: true
                )
            && routeEasterEggInput(releaseDown, utility: .tetromino)
                == EasterEggInputRoute(
                    command: .setFastDrop(isPressed: false),
                    consumesEvent: true
                )
            && routeEasterEggInput(pressUp, utility: .tetromino)
                == EasterEggInputRoute(command: .rotateClockwise, consumesEvent: true)
            && routeEasterEggInput(pressSpace, utility: .packet)
                == EasterEggInputRoute(command: .flap, consumesEvent: true)
            && routeEasterEggInput(repeatSpace, utility: .packet)
                == EasterEggInputRoute(command: nil, consumesEvent: true)
            && routeEasterEggInput(pressReset, utility: .none)
                == EasterEggInputRoute(command: nil, consumesEvent: false)
            && routeEasterEggInput(pressReset, utility: .car)
                == EasterEggInputRoute(command: .reset, consumesEvent: true)
            && routeEasterEggInput(repeatReset, utility: .car)
                == EasterEggInputRoute(command: nil, consumesEvent: true)
            && routeEasterEggInput(pressToggle, utility: .none)
                == EasterEggInputRoute(command: .toggle, consumesEvent: true)
    }

    private static func resourceEasterEggState() -> Bool {
        var state = EasterEggState()
        guard !state.isEnabled else { return false }
        state.toggle()
        let car = state.activeUtility(for: .cpu)
        let network = state.activeUtility(
            for: PerformanceResourceDescriptor(
                id: .network(interfaceName: "en0"),
                title: "Wi-Fi",
                kind: .network,
                colorRole: .wifi,
                graphKind: .adaptiveNonphysical,
                easterEggUtility: .none
            )
        )
        state.toggle()
        return car == .car
            && network == .none
            && state.activeUtility(for: .cpu) == .none
    }

    private static func boatMotion() -> Bool {
        var motion = BoatMotionModel(position: CGPoint(x: 100, y: 50))
        for _ in 0..<120 {
            motion.update(
                deltaTime: 1.0 / 60,
                targetSurfaceY: 80,
                surfaceSlope: 0.25,
                movements: [.right]
            )
        }
        let raised = motion.state
        guard raised.position.y > 79,
              raised.position.y < 82,
              raised.position.x > 100,
              raised.horizontalVelocity > 0,
              raised.rotation > 0,
              raised.rotation <= 0.30 else { return false }

        for _ in 0..<30 {
            motion.update(
                deltaTime: 1.0 / 60,
                targetSurfaceY: 80,
                surfaceSlope: 0,
                movements: [.left]
            )
        }
        guard motion.state.horizontalVelocity < raised.horizontalVelocity else { return false }

        motion.reset(at: CGPoint(x: 40, y: 70))
        return motion.state == BoatMotionState(position: CGPoint(x: 40, y: 70))
    }

    private static func tetrominoShapesAndBag() -> Bool {
        guard TetrominoKind.allCases.allSatisfy({
            $0.cells.count == 4 && Set($0.cells).count == 4
        }) else { return false }

        let original = TetrominoKind.t.cells
        let rotated = original.map { $0.rotatedClockwise() }
        let restored = (0..<3).reduce(rotated) { cells, _ in
            cells.map { $0.rotatedClockwise() }
        }
        guard Set(original) == Set(restored) else { return false }

        var first = TetrominoBag(seed: 42)
        var second = TetrominoBag(seed: 42)
        let firstBag = (0..<7).map { _ in first.next() }
        let secondBag = (0..<7).map { _ in second.next() }
        return firstBag == secondBag && Set(firstBag) == Set(TetrominoKind.allCases)
    }

    private static func tetrominoDropClock() -> Bool {
        var clock = TetrominoDropClock()
        let normal = (0..<31).reduce(0) { count, _ in
            count + clock.advance(by: 1.0 / 60)
        }
        guard normal == 0, clock.advance(by: 1.0 / 60) == 1 else { return false }

        clock.reset()
        clock.isFastDropping = true
        let fast = (0..<30).reduce(0) { count, _ in
            count + clock.advance(by: 1.0 / 60)
        }
        return fast >= 6 && clock.isFastDropping
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

        return live.resource == .memory
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
        return snapshot.cpu.resource == .cpu
            && snapshot.memory.resource == .memory
            && snapshot.cpu.availability == .available
            && snapshot.memory.availability == .available
            && snapshot.cpu.value < 0.4
            && snapshot.memory.value > 0.6
    }

    private static func chartBucketAveraging() -> Bool {
        var histories = MetricHistoryStore(
            sampleInterval: 0.15,
            retentionDuration: 65,
            chartInterval: 1
        )
        let initial = histories.ingestUpdate(
            metricReading(timestamp: 0, value: 0.2, resource: .cpu)
        )
        let firstOpenBucketUpdate = histories.ingestUpdate(
            metricReading(timestamp: 0.3, value: 0.4, resource: .cpu)
        )
        let secondOpenBucketUpdate = histories.ingestUpdate(
            metricReading(timestamp: 0.9, value: 0.8, resource: .cpu)
        )

        let exposedBeforeFinalization = histories.samples(for: .cpu)
        guard initial == .historyChanged,
              firstOpenBucketUpdate == .timelineAdvanced,
              secondOpenBucketUpdate == .timelineAdvanced,
              exposedBeforeFinalization.last == MetricSample(timestamp: 0, value: 0.2) else {
            return false
        }

        let bucketClose = histories.ingestUpdate(
            metricReading(timestamp: 1.05, value: 0.6, resource: .cpu)
        )
        let finalized = histories.samples(for: .cpu)
        guard bucketClose == .historyChanged, finalized.count >= 2 else { return false }
        let retainedPrefix = Array(finalized.dropLast())
        guard let retainedStart = retainedPrefix.first?.timestamp else { return false }
        let expectedRetainedPrefix = exposedBeforeFinalization.filter {
            $0.timestamp >= retainedStart
        }
        guard retainedPrefix == expectedRetainedPrefix else { return false }
        let average = finalized[finalized.count - 1]
        return average.timestamp == 0.9
            && approximatelyEqual(average.value, (0.2 + 0.4 + 0.8) / 3)
    }

    private static func chartSkipsGapBackfill() -> Bool {
        var histories = MetricHistoryStore(
            sampleInterval: 0.15,
            retentionDuration: 65,
            chartInterval: 1
        )
        histories.ingest(metricReading(timestamp: 0, value: 0.2, resource: .cpu))
        histories.ingest(metricReading(timestamp: 0.5, value: 0.4, resource: .cpu))
        histories.ingest(metricReading(timestamp: 10, value: 0.6, resource: .cpu))

        let samples = histories.samples(for: .cpu)
        let positiveTimestamps = samples.map(\.timestamp).filter { $0 > 0 }
        return positiveTimestamps == [0.5]
    }

    private static func chartHistoryDensity() -> Bool {
        var histories = MetricHistoryStore(
            sampleInterval: 0.15,
            retentionDuration: 65,
            chartInterval: 1
        )
        for index in 0..<400 {
            histories.ingest(
                metricReading(
                    timestamp: Double(index) * 0.15,
                    value: Double(index % 10) / 10,
                    resource: .cpu
                )
            )
        }

        let count = histories.samples(for: .cpu).count
        return count >= 60 && count <= 68
    }

    private static func committedChartSamples() -> Bool {
        let resource = PerformanceResourceID.gpu(registryID: 9)
        var committed = MetricHistoryStore(
            sampleInterval: 0.15,
            retentionDuration: 65,
            chartInterval: 1
        )
        var readings = MetricHistoryStore(
            sampleInterval: 0.15,
            retentionDuration: 65,
            chartInterval: 1
        )

        for timestamp in 0...2 {
            let reading = metricReading(
                timestamp: Double(timestamp),
                value: Double(timestamp) / 10,
                resource: resource
            )
            committed.ingest(reading, input: .committedSamples)
            readings.ingest(reading)
        }

        return committed.samples(for: resource).suffix(3) == [
            MetricSample(timestamp: 0, value: 0),
            MetricSample(timestamp: 1, value: 0.1),
            MetricSample(timestamp: 2, value: 0.2),
        ]
            && readings.samples(for: resource).last?.timestamp == 1
    }

    private static func physicalGraphEdgeCoverage() -> Bool {
        let timeline = GraphTimelineLayout(width: 900, visibleDuration: 60)
        let beforeEndpoint = timeline.visibleEndTimestamp(
            sourceTimestamp: 2.5,
            commitDelay: 1,
            latestCommittedTimestamp: 2
        )
        let cappedAtEndpoint = timeline.visibleEndTimestamp(
            sourceTimestamp: 3.25,
            commitDelay: 1,
            latestCommittedTimestamp: 2
        )
        let withoutHistory = timeline.visibleEndTimestamp(
            sourceTimestamp: 3.25,
            commitDelay: 1,
            latestCommittedTimestamp: nil
        )

        return beforeEndpoint == 1.5
            && cappedAtEndpoint == 2
            && withoutHistory == 2.25
    }

    private static func independentMetricHistories() -> Bool {
        var histories = MetricHistoryStore(sampleInterval: 0.15, retentionDuration: 1)
        histories.ingest(metricReading(timestamp: 0, value: 0.2, resource: .cpu))
        histories.ingest(metricReading(timestamp: 0, value: 0.7, resource: .memory))
        histories.ingest(metricReading(timestamp: 2, value: 0.3, resource: .cpu))
        histories.ingest(metricReading(timestamp: 3.1, value: 0.4, resource: .cpu))

        let cpu = histories.samples(for: .cpu)
        let memory = histories.samples(for: .memory)
        return cpu.last?.value == 0.3
            && cpu.first?.timestamp == 2
            && memory.last?.value == 0.7
            && memory.last?.timestamp == 0
            && histories.ingest(metricReading(timestamp: 3.1, value: 0.9, resource: .cpu)) == false
    }

    private static func dualHistoryRetention() -> Bool {
        var histories = MetricHistoryStore(sampleInterval: 0.1, retentionDuration: 60)
        for index in 0..<10_000 {
            let timestamp = Double(index) * 0.1
            histories.ingest(metricReading(timestamp: timestamp, value: 0.2, resource: .cpu))
            histories.ingest(metricReading(timestamp: timestamp, value: 0.7, resource: .memory))
        }

        return histories.samples(for: .cpu).count <= 602
            && histories.samples(for: .memory).count <= 602
    }

    private static func leftTerrainMarginRetention() -> Bool {
        var histories = MetricHistoryStore(sampleInterval: 1, retentionDuration: 65)
        for timestamp in 0...100 {
            histories.ingest(
                metricReading(
                    timestamp: Double(timestamp),
                    value: 0.5,
                    resource: .cpu
                )
            )
        }

        guard let first = histories.samples(for: .cpu).first?.timestamp else { return false }
        let visibleLeftTimestamp = 100.0 - 1.0 - 60.0
        let margin = visibleLeftTimestamp - first
        return first <= 35 && margin >= 5 && margin <= 6
    }

    private static func resourceSelectionRules() -> Bool {
        var selection = MetricSelectionState()
        let rejectsCurrent = !selection.select(.cpu, availability: .available)
        let rejectsUnavailable = !selection.select(.memory, availability: .unavailable)
        let selectsMemory = selection.select(.memory, availability: .available)
        let rejectsUnavailableSwitch = !selection.select(.cpu, availability: .unavailable)
        let remainsSelectedWhenUnavailable = selection.selectedResource == .memory
        let selectsCPU = selection.select(.cpu, availability: .available)

        return rejectsCurrent
            && rejectsUnavailable
            && selectsMemory
            && rejectsUnavailableSwitch
            && remainsSelectedWhenUnavailable
            && selectsCPU
            && selection.selectedResource == .cpu
    }

    private static func resourceInventoryReconciliation() -> Bool {
        let disk = PerformanceResourceDescriptor(
            id: .disk(registryID: 7, bsdName: "disk0"),
            title: "Disk 0",
            kind: .disk,
            colorRole: .disk,
            graphKind: .physicalFixed,
            easterEggUtility: .car
        )
        let network = PerformanceResourceDescriptor(
            id: .network(interfaceName: "en0"),
            title: "Wi-Fi",
            kind: .network,
            colorRole: .wifi,
            graphKind: .adaptiveNonphysical,
            easterEggUtility: .none
        )
        let gpu = PerformanceResourceDescriptor(
            id: .gpu(registryID: 9),
            title: "GPU",
            kind: .gpu,
            colorRole: .gpu,
            graphKind: .physicalFixed,
            easterEggUtility: .car
        )

        var inventory = PerformanceResourceInventory()
        inventory.reconcile(
            discovered: [gpu, network, disk],
            managedKinds: [.disk, .network, .gpu],
            selectedResource: .cpu
        )
        guard inventory.records.map(\.id) == [.cpu, .memory, disk.id, network.id, gpu.id] else {
            return false
        }

        inventory.reconcile(
            discovered: [],
            managedKinds: [.disk, .network, .gpu],
            selectedResource: disk.id
        )
        let remaining = inventory.records
        let retainedSelectedDisk = remaining.contains {
            $0.id == disk.id && $0.availability == .unavailable
        }
        let retainedNetwork = remaining.contains {
            $0.id == network.id && $0.availability == .disconnected
        }
        let retainedGPU = remaining.contains {
            $0.id == gpu.id && $0.availability == .unavailable
        }
        guard retainedSelectedDisk && retainedNetwork && retainedGPU else {
            return false
        }

        inventory.reconcile(
            discovered: [],
            managedKinds: [.disk, .network, .gpu],
            selectedResource: .cpu
        )
        return !inventory.records.contains { $0.id == disk.id }
            && inventory.records.contains { $0.id == network.id }
            && inventory.records.contains { $0.id == gpu.id }
    }

    private static func adaptiveScaleHysteresis() -> Bool {
        var scale = AdaptiveScale(
            ladder: [100, 1_000, 10_000],
            initialCeiling: 1_000,
            lowerDelay: 30
        )
        let raised = scale.update(maximumValue: 950, at: 0)
        guard raised, scale.ceiling == 10_000 else { return false }
        _ = scale.update(maximumValue: 100, at: 1)
        let tooEarly = scale.update(maximumValue: 100, at: 30)
        let lowered = scale.update(maximumValue: 100, at: 31)
        return !tooEarly && lowered && scale.ceiling == 1_000
    }

    private static func deterministicSyntheticSource() -> Bool {
        var first = BoundedRandomWalkSource(initialValue: 0.5, seed: 42)
        var second = BoundedRandomWalkSource(initialValue: 0.5, seed: 42)
        var different = BoundedRandomWalkSource(initialValue: 0.5, seed: 43)
        let firstValues = (0..<20).map { first.nextSample(at: Double($0)).value }
        let secondValues = (0..<20).map { second.nextSample(at: Double($0)).value }
        let differentValues = (0..<20).map { different.nextSample(at: Double($0)).value }
        return firstValues == secondValues && firstValues != differentValues
    }

    private static func diskPerformanceCalculation() -> Bool {
        let identity = testDiskIdentity()
        var calculator = DiskPerformanceCalculator()
        let first = DiskDeviceSnapshot(
            identity: identity,
            counters: diskCounters(
                bytesRead: 1_000,
                bytesWritten: 2_000,
                reads: 10,
                writes: 20,
                readTime: 100_000_000,
                writeTime: 200_000_000
            )
        )
        let second = DiskDeviceSnapshot(
            identity: identity,
            counters: diskCounters(
                bytesRead: 3_000,
                bytesWritten: 5_000,
                reads: 14,
                writes: 26,
                readTime: 500_000_000,
                writeTime: 900_000_000
            )
        )

        guard calculator.consume(first, at: 0) == nil,
              let reading = calculator.consume(second, at: 1),
              case let .disk(details)? = reading.details else { return false }
        return reading.resource == identity.resourceID
            && reading.value == 1
            && details.readBytesPerSecond == 2_000
            && details.writeBytesPerSecond == 3_000
            && details.readOperationsPerSecond == 4
            && details.writeOperationsPerSecond == 6
            && details.averageResponseMilliseconds == 110
    }

    private static func diskCounterReset() -> Bool {
        let identity = testDiskIdentity()
        var calculator = DiskPerformanceCalculator()
        let high = DiskDeviceSnapshot(
            identity: identity,
            counters: diskCounters(
                bytesRead: 10,
                bytesWritten: 10,
                reads: 10,
                writes: 10,
                readTime: 10,
                writeTime: 10
            )
        )
        let reset = DiskDeviceSnapshot(
            identity: identity,
            counters: diskCounters(
                bytesRead: 1,
                bytesWritten: 1,
                reads: 1,
                writes: 1,
                readTime: 1,
                writeTime: 1
            )
        )
        _ = calculator.consume(high, at: 0)
        return calculator.consume(reset, at: 1) == nil
    }

    private static func syntheticDiskCoherence() async -> Bool {
        let firstMonitor = SyntheticDiskMonitor()
        let secondMonitor = SyntheticDiskMonitor()
        let first = await firstMonitor.sample(at: 1)
        let second = await secondMonitor.sample(at: 1)
        guard first == second,
              let reading = first.readings.first,
              case let .disk(details)? = reading.details else { return false }
        return first.descriptors.first?.kind == .disk
            && first.descriptors.first?.easterEggUtility == .tetromino
            && reading.availability == .available
            && details.readBytesPerSecond + details.writeBytesPerSecond > 0
            && details.readErrorDelta == 0
            && details.writeErrorDelta == 0
    }

    private static func networkPerformanceCalculation() -> Bool {
        let identity = testNetworkIdentity()
        var calculator = NetworkPerformanceCalculator()
        let first = NetworkDeviceSnapshot(
            identity: identity,
            counters: networkCounters(received: 1_000, sent: 2_000, connected: true)
        )
        let second = NetworkDeviceSnapshot(
            identity: identity,
            counters: networkCounters(
                received: 201_000,
                sent: 102_000,
                connected: true,
                receivedPackets: 210,
                sentPackets: 120
            )
        )
        guard calculator.consume(first, at: 0) == nil,
              let reading = calculator.consume(second, at: 1),
              case let .network(details)? = reading.details else { return false }
        return reading.resource == identity.resourceID
            && reading.availability == .available
            && details.receiveBytesPerSecond == 200_000
            && details.sendBytesPerSecond == 100_000
            && details.combinedBytesPerSecond == 300_000
            && details.receivePacketsPerSecond == 200
            && details.sendPacketsPerSecond == 100
            && reading.value == 0.3
    }

    private static func networkCounterReset() -> Bool {
        let identity = testNetworkIdentity()
        var calculator = NetworkPerformanceCalculator()
        _ = calculator.consume(
            NetworkDeviceSnapshot(
                identity: identity,
                counters: networkCounters(received: 100, sent: 100, connected: true)
            ),
            at: 0
        )
        return calculator.consume(
            NetworkDeviceSnapshot(
                identity: identity,
                counters: networkCounters(received: 1, sent: 1, connected: true)
            ),
            at: 1
        ) == nil
    }

    private static func physicalNetworkFiltering() -> Bool {
        physicalNetworkKind(interfaceType: kSCNetworkInterfaceTypeIEEE80211 as String) == .wifi
            && physicalNetworkKind(interfaceType: kSCNetworkInterfaceTypeEthernet as String)
                == .ethernet
            && physicalNetworkKind(interfaceType: "Bridge") == nil
    }

    private static func networkDiscoveryCadence() async -> Bool {
        let discovery = CountingNetworkDiscovery(identity: testNetworkIdentity())
        let monitor = NetworkMonitor(discovery: discovery)
        _ = await monitor.sample(at: 0)
        _ = await monitor.sample(at: 1)
        _ = await monitor.sample(at: 5.1)
        let counts = await discovery.counts
        return counts.identityReads == 2 && counts.snapshotReads == 3
    }

    private static func syntheticNetworkCoherence() async -> Bool {
        let firstMonitor = SyntheticNetworkMonitor()
        let secondMonitor = SyntheticNetworkMonitor()
        let first = await firstMonitor.sample(at: 1)
        let second = await secondMonitor.sample(at: 1)
        guard first == second,
              let reading = first.readings.first,
              case let .network(details)? = reading.details else { return false }
        return first.descriptors.first?.graphKind == .adaptiveNonphysical
            && first.descriptors.first?.easterEggUtility == EasterEggUtility.none
            && details.combinedBytesPerSecond
                == details.receiveBytesPerSecond + details.sendBytesPerSecond
            && reading.availability == .available
    }

    private static func gpuPerformanceClamping() -> Bool {
        var calculator = GPUPerformanceCalculator()
        let reading = calculator.reading(
            from: GPUSnapshot(
                registryID: 9,
                model: "GPU",
                deviceUtilizationPercent: 140,
                rendererUtilizationPercent: -5,
                tilerUtilizationPercent: .nan,
                inUseSystemMemoryBytes: 10
            ),
            at: 0
        )
        guard case let .gpu(details)? = reading.details else { return false }
        return reading.value == 1
            && details.rendererUtilization == 0
            && details.tilerUtilization == 0
            && details.inUseSystemMemoryBytes == 10
    }

    private static func gpuRediscoveryCadence() async -> Bool {
        let reader = CountingGPUReader()
        let monitor = GPUMonitor(reader: reader)
        _ = await monitor.sample(at: 0)
        _ = await monitor.sample(at: 1)
        _ = await monitor.sample(at: 5)
        return await reader.readCount == 2
    }

    private static func syntheticGPUCoherence() async -> Bool {
        let firstMonitor = SyntheticGPUMonitor()
        let secondMonitor = SyntheticGPUMonitor()
        let first = await firstMonitor.sample(at: 1)
        let second = await secondMonitor.sample(at: 1)
        guard first == second,
              first.descriptor?.graphKind == .physicalFixed,
              first.descriptor?.easterEggUtility == .car,
              let reading = first.reading,
              case let .gpu(details)? = reading.details else { return false }
        return reading.value == details.deviceUtilization
            && details.supportsMetal
            && details.memoryType == "Unified memory"
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
            resource: .cpu,
            availability: .unavailable
        )
        let available = metricReading(timestamp: 0.15, value: 0.2, resource: .cpu)
        guard liveGate.consume(unavailable) == nil,
              liveGate.consume(available) == available else { return false }

        var failedLiveGate = MetricStartupGate(sourceMode: .live, unavailableGracePeriod: 0.3)
        guard failedLiveGate.consume(unavailable) == nil else { return false }
        let fallback = metricReading(
            timestamp: 0.3,
            value: 0.5,
            resource: .cpu,
            availability: .unavailable
        )

        var syntheticGate = MetricStartupGate(sourceMode: .synthetic)
        let synthetic = metricReading(timestamp: 0, value: 0.4, resource: .cpu)
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

    private static func liveDiskDiscovery() async -> Bool {
        let snapshots = await IOKitDiskDiscovery().discover()
        return snapshots.contains {
            !$0.identity.bsdName.isEmpty
                && !$0.identity.model.isEmpty
                && $0.identity.capacityBytes > 0
        }
    }

    private static func liveNetworkDiscovery() async -> Bool {
        let discovery = SystemNetworkDiscovery()
        let identities = await discovery.discoverIdentities()
        guard identities.contains(where: { $0.interfaceName == "en0" && $0.kind == .wifi }) else {
            return false
        }
        let snapshots = await discovery.readSnapshots(for: identities)
        return snapshots.contains {
            $0.identity.interfaceName == "en0"
                && $0.counters.receivedBytes > 0
                && $0.counters.sentBytes > 0
        }
    }

    private static func liveGPUReading() async -> Bool {
        guard let snapshot = await IOKitGPUReader().readGPU() else { return false }
        return !snapshot.model.isEmpty
            && snapshot.deviceUtilizationPercent.isFinite
            && snapshot.deviceUtilizationPercent >= 0
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
        resource: PerformanceResourceID,
        availability: MetricAvailability = .available
    ) -> MetricReading {
        MetricReading(
            timestamp: timestamp,
            value: value,
            resource: resource,
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

    private static func testDiskIdentity() -> DiskIdentity {
        DiskIdentity(
            registryID: 7,
            bsdName: "disk0",
            model: "Test SSD",
            capacityBytes: 1_000_000,
            isSolidState: true,
            isRemovable: false,
            isSystemDisk: true
        )
    }

    private static func diskCounters(
        bytesRead: UInt64,
        bytesWritten: UInt64,
        reads: UInt64,
        writes: UInt64,
        readTime: UInt64,
        writeTime: UInt64
    ) -> DiskCounters {
        DiskCounters(
            bytesRead: bytesRead,
            bytesWritten: bytesWritten,
            readOperations: reads,
            writeOperations: writes,
            readTimeNanoseconds: readTime,
            writeTimeNanoseconds: writeTime,
            readErrors: 0,
            writeErrors: 0
        )
    }

    private static func testNetworkIdentity() -> NetworkIdentity {
        NetworkIdentity(interfaceName: "en0", portName: "Wi-Fi", kind: .wifi)
    }

    private static func networkCounters(
        received: UInt64,
        sent: UInt64,
        connected: Bool,
        receivedPackets: UInt64 = 10,
        sentPackets: UInt64 = 20
    ) -> NetworkCounters {
        NetworkCounters(
            receivedBytes: received,
            sentBytes: sent,
            receivedPackets: receivedPackets,
            sentPackets: sentPackets,
            inputErrors: 0,
            outputErrors: 0,
            inputDrops: 0,
            linkSpeedBitsPerSecond: nil,
            isConnected: connected,
            ipv4Addresses: ["192.0.2.1"],
            ipv6Addresses: []
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
                resource: .cpu,
                availability: .available
            ),
            memory: MetricReading(
                timestamp: timestamp,
                value: 0.7,
                resource: .memory,
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

private actor CountingNetworkDiscovery: NetworkDiscovering {
    struct Counts: Sendable {
        let identityReads: Int
        let snapshotReads: Int
    }

    private let identity: NetworkIdentity
    private var identityReadCount = 0
    private var snapshotReadCount = 0

    var counts: Counts {
        Counts(identityReads: identityReadCount, snapshotReads: snapshotReadCount)
    }

    init(identity: NetworkIdentity) {
        self.identity = identity
    }

    func discoverIdentities() -> [NetworkIdentity] {
        identityReadCount += 1
        return [identity]
    }

    func readSnapshots(for identities: [NetworkIdentity]) -> [NetworkDeviceSnapshot] {
        snapshotReadCount += 1
        let value = UInt64(snapshotReadCount * 1_000)
        return identities.map {
            NetworkDeviceSnapshot(
                identity: $0,
                counters: NetworkCounters(
                    receivedBytes: value,
                    sentBytes: value,
                    receivedPackets: value,
                    sentPackets: value,
                    inputErrors: 0,
                    outputErrors: 0,
                    inputDrops: 0,
                    linkSpeedBitsPerSecond: nil,
                    isConnected: true,
                    ipv4Addresses: [],
                    ipv6Addresses: []
                )
            )
        }
    }
}

private actor CountingGPUReader: GPUReading {
    private(set) var readCount = 0

    func readGPU() -> GPUSnapshot? {
        readCount += 1
        return nil
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
