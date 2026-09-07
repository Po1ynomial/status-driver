import CoreGraphics
import Darwin
import StatusDriverCore

@main
struct StatusDriverModelTests {
    private typealias Check = (name: String, body: () -> Bool)

    static func main() {
        let checks: [Check] = [
            ("sample normalization", sampleNormalization),
            ("random walk bounds", randomWalkBounds),
            ("pruning overlap", pruningOverlap),
            ("bounded retention", boundedRetention),
            ("point mapping", pointMapping),
            ("terrain interpolation", terrainInterpolation),
            ("driving key map", drivingKeyMap),
            ("shared terrain geometry", sharedTerrainGeometry),
        ]

        var failures = 0
        for check in checks {
            if check.body() {
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
}
