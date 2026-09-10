import CoreGraphics
import Foundation

package struct NetworkGraphMapping: Equatable, Sendable {
    package let samples: [NetworkThroughputSample]
    package let ceiling: Double
    package let size: CGSize
    package let visibleDuration: TimeInterval

    package init(
        samples: [NetworkThroughputSample],
        ceiling: Double,
        size: CGSize,
        visibleDuration: TimeInterval = 60
    ) {
        self.samples = samples
        self.ceiling = max(1, ceiling)
        self.size = size
        self.visibleDuration = visibleDuration
    }

    package var latestTimestamp: TimeInterval? {
        samples.last?.timestamp
    }

    package func timestamp(at fraction: CGFloat) -> TimeInterval? {
        latestTimestamp.map { $0 - visibleDuration + Double(fraction) * visibleDuration }
    }

    package func screenX(for timestamp: TimeInterval) -> CGFloat? {
        guard let latestTimestamp else { return nil }
        return CGFloat((timestamp - (latestTimestamp - visibleDuration)) / visibleDuration)
            * size.width
    }

    package func terrainHeight(at timestamp: TimeInterval) -> CGFloat {
        normalizedValue(at: timestamp) * size.height
    }

    package func highestTerrain(
        from startTimestamp: TimeInterval,
        through endTimestamp: TimeInterval
    ) -> (timestamp: TimeInterval, height: CGFloat) {
        let lower = min(startTimestamp, endTimestamp)
        let upper = max(startTimestamp, endTimestamp)
        var candidates = [
            (lower, terrainHeight(at: lower)),
            (upper, terrainHeight(at: upper)),
        ]
        candidates += samples
            .filter { $0.timestamp > lower && $0.timestamp < upper }
            .map { ($0.timestamp, normalizedHeight(for: $0)) }
        return candidates.max { $0.1 < $1.1 } ?? (upper, 0)
    }

    private func normalizedValue(at timestamp: TimeInterval) -> CGFloat {
        guard let first = samples.first, let last = samples.last else { return 0 }
        if timestamp <= first.timestamp { return normalizedHeight(for: first) }
        if timestamp >= last.timestamp { return normalizedHeight(for: last) }

        guard let upperIndex = samples.firstIndex(where: { $0.timestamp >= timestamp }),
              upperIndex > 0 else { return 0 }
        let lower = samples[upperIndex - 1]
        let upper = samples[upperIndex]
        let progress = (timestamp - lower.timestamp) / (upper.timestamp - lower.timestamp)
        let value = lower.combinedBytesPerSecond
            + (upper.combinedBytesPerSecond - lower.combinedBytesPerSecond) * progress
        return CGFloat(min(max(value / ceiling, 0), 1))
    }

    private func normalizedHeight(for sample: NetworkThroughputSample) -> CGFloat {
        CGFloat(min(max(sample.combinedBytesPerSecond / ceiling, 0), 1)) * size.height
    }
}

package enum NetworkPacketState: Equatable, Sendable {
    case flying(height: CGFloat, velocity: CGFloat)
    case stuck(timestamp: TimeInterval)
}

package struct NetworkPacketFlight: Equatable, Sendable {
    package static let horizontalFraction: CGFloat = 0.30
    package static let halfWidth: CGFloat = 13
    package static let halfHeight: CGFloat = 9

    package private(set) var state: NetworkPacketState = .flying(height: 0, velocity: 0)
    private var previousLatestTimestamp: TimeInterval?
    private var graphSize: CGSize = .zero

    package init() {}

    package mutating func reset(in mapping: NetworkGraphMapping) {
        graphSize = mapping.size
        previousLatestTimestamp = mapping.latestTimestamp
        let ceiling = max(Self.halfHeight, mapping.size.height - Self.halfHeight)
        guard let timestamp = mapping.timestamp(at: Self.horizontalFraction) else {
            state = .flying(height: mapping.size.height * 0.65, velocity: 0)
            return
        }
        let terrain = mapping.terrainHeight(at: timestamp)
        let height = max(mapping.size.height * 0.65, terrain + Self.halfHeight * 2)
        if height > ceiling {
            state = .stuck(timestamp: timestamp)
        } else {
            state = .flying(height: height, velocity: 0)
        }
    }

    package mutating func flap() {
        guard case let .flying(height, _) = state else { return }
        state = .flying(height: height, velocity: 185)
    }

    package mutating func update(
        deltaTime: TimeInterval,
        mapping: NetworkGraphMapping
    ) {
        if graphSize != mapping.size {
            reset(in: mapping)
            return
        }

        switch state {
        case let .flying(height, velocity):
            updateFlight(
                height: height,
                velocity: velocity,
                deltaTime: deltaTime,
                mapping: mapping
            )
        case let .stuck(timestamp):
            if let x = mapping.screenX(for: timestamp),
               x + Self.halfWidth < 0 {
                reset(in: mapping)
            }
        }
        previousLatestTimestamp = mapping.latestTimestamp
    }

    package func position(in mapping: NetworkGraphMapping) -> CGPoint? {
        switch state {
        case let .flying(height, _):
            return CGPoint(x: mapping.size.width * Self.horizontalFraction, y: height)
        case let .stuck(timestamp):
            guard let x = mapping.screenX(for: timestamp) else { return nil }
            return CGPoint(
                x: x,
                y: mapping.terrainHeight(at: timestamp) + Self.halfHeight
            )
        }
    }

    private mutating func updateFlight(
        height: CGFloat,
        velocity: CGFloat,
        deltaTime: TimeInterval,
        mapping: NetworkGraphMapping
    ) {
        let dt = CGFloat(min(max(deltaTime, 0), 0.05))
        var nextVelocity = velocity - 285 * dt
        var nextHeight = height + nextVelocity * dt
        let ceiling = mapping.size.height - Self.halfHeight
        if nextHeight > ceiling {
            nextHeight = ceiling
            nextVelocity = 0
        }

        guard let currentTimestamp = mapping.timestamp(at: Self.horizontalFraction) else {
            state = .flying(height: nextHeight, velocity: nextVelocity)
            return
        }
        let previousTarget = previousLatestTimestamp.map {
            $0 - mapping.visibleDuration
                + Double(Self.horizontalFraction) * mapping.visibleDuration
        } ?? currentTimestamp
        let sweptTerrain = mapping.highestTerrain(
            from: previousTarget,
            through: currentTimestamp
        )
        let lowestPacketBottom = min(height, nextHeight) - Self.halfHeight
        if lowestPacketBottom <= sweptTerrain.height {
            state = .stuck(timestamp: sweptTerrain.timestamp)
        } else {
            state = .flying(height: nextHeight, velocity: nextVelocity)
        }
    }
}

package func networkEasterEggUtility(for identity: NetworkIdentity) -> EasterEggUtility {
    if identity.portName.localizedCaseInsensitiveContains("thunderbolt") {
        return .none
    }
    return .packet
}
