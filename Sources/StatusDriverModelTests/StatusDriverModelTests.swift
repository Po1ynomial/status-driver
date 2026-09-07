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
            ("pruning overlap", { pruningOverlap() }),
            ("bounded retention", { boundedRetention() }),
            ("point mapping", { pointMapping() }),
            ("terrain interpolation", { terrainInterpolation() }),
            ("driving key map", { drivingKeyMap() }),
            ("shared terrain geometry", { sharedTerrainGeometry() }),
            ("CPU utilization", { cpuUtilization() }),
            ("CPU counter rollover", { cpuCounterRollover() }),
            ("CPU zero delta", { cpuZeroDelta() }),
            ("CPU smoothing", { cpuSmoothing() }),
            ("CPU failure recovery", cpuFailureRecovery),
            ("source selection", { sourceSelection() }),
            ("stream skips deadline backfill", streamSkipsDeadlineBackfill),
            ("stream cancellation", streamCancellation),
            ("live Mach CPU sample", liveMachCPUSample),
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
                source: .cpu,
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

    private static func cpuSmoothing() -> Bool {
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
            .failure(.kernel(KERN_FAILURE)),
            .success(CPUTicks(user: 122, system: 61, idle: 877, nice: 0)),
        ])
        let producer = CPUMetricProducer(reader: reader, smoothingTimeConstant: 0.75)

        let baseline = await producer.reading(at: 0)
        let live = await producer.reading(at: 0.15)
        let failed = await producer.reading(at: 0.30)
        let recovered = await producer.reading(at: 0.45)

        return baseline.availability == .unavailable
            && baseline.value == 0.5
            && live.availability == .available
            && live.value == 0.6
            && failed.availability == .unavailable
            && failed.value == live.value
            && recovered.availability == .available
            && recovered.value < live.value
            && recovered.value > 0.5
    }

    private static func sourceSelection() -> Bool {
        MetricSourceMode(arguments: ["StatusDriver"]) == .cpu
            && MetricSourceMode(arguments: ["StatusDriver", "--synthetic"]) == .synthetic
    }

    private static func streamSkipsDeadlineBackfill() async -> Bool {
        let clock = ManualSamplingClock()
        let producer = FixedMetricProducer()
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
        let producer = FixedMetricProducer()
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

private actor FixedMetricProducer: MetricReadingProducer {
    func reading(at timestamp: TimeInterval) -> MetricReading {
        MetricReading(
            timestamp: timestamp,
            value: 0.5,
            source: .synthetic,
            availability: .available
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
