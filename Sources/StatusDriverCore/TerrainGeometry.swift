import CoreGraphics
import Foundation

package struct GraphTimelineLayout: Equatable {
    package let width: CGFloat
    package let visibleDuration: TimeInterval

    package init(width: CGFloat, visibleDuration: TimeInterval = 60) {
        precondition(width > 0)
        precondition(visibleDuration > 0)
        self.width = width
        self.visibleDuration = visibleDuration
    }

    package var pointsPerSecond: CGFloat {
        width / CGFloat(visibleDuration)
    }

    package func worldX(for timestamp: TimeInterval) -> CGFloat {
        CGFloat(timestamp) * pointsPerSecond
    }

    package func cameraCenterX(endingAt timestamp: TimeInterval) -> CGFloat {
        worldX(for: timestamp) - width / 2
    }

    package func visibleWorldRange(endingAt timestamp: TimeInterval) -> ClosedRange<CGFloat> {
        let right = worldX(for: timestamp)
        return (right - width)...right
    }
}

package struct TerrainLayout: Equatable {
    package let pointsPerSecond: CGFloat
    package let bottomInset: CGFloat
    package let topInset: CGFloat

    package init(pointsPerSecond: CGFloat, bottomInset: CGFloat, topInset: CGFloat) {
        self.pointsPerSecond = pointsPerSecond
        self.bottomInset = bottomInset
        self.topInset = topInset
    }

    package func point(for sample: MetricSample, sceneHeight: CGFloat) -> CGPoint {
        let usableHeight = max(0, sceneHeight - bottomInset - topInset)
        return CGPoint(
            x: CGFloat(sample.timestamp) * pointsPerSecond,
            y: bottomInset + CGFloat(sample.value) * usableHeight
        )
    }
}

package struct TerrainGeometry {
    package let points: [CGPoint]

    package init(samples: [MetricSample], layout: TerrainLayout, sceneHeight: CGFloat) {
        points = samples.map { layout.point(for: $0, sceneHeight: sceneHeight) }
    }

    package func height(atWorldX x: CGFloat) -> CGFloat? {
        guard let first = points.first, let last = points.last else { return nil }
        if x <= first.x { return first.y }
        if x >= last.x { return last.y }

        guard let upperIndex = points.firstIndex(where: { $0.x >= x }), upperIndex > 0 else {
            return nil
        }
        let lower = points[upperIndex - 1]
        let upper = points[upperIndex]
        let progress = (x - lower.x) / (upper.x - lower.x)
        return lower.y + (upper.y - lower.y) * progress
    }

    package func linePath() -> CGPath? {
        guard let first = points.first, points.count >= 2 else { return nil }

        let path = CGMutablePath()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    package func collisionPath(rightExtension: CGFloat) -> CGPath? {
        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return nil
        }

        let path = CGMutablePath()
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        if rightExtension > 0 {
            path.addLine(to: CGPoint(x: last.x + rightExtension, y: last.y))
        }
        return path
    }

    package func fillPath(baseline: CGFloat = 0) -> CGPath? {
        guard let first = points.first, let last = points.last, points.count >= 2 else {
            return nil
        }

        let path = CGMutablePath()
        path.move(to: CGPoint(x: first.x, y: baseline))
        path.addLine(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        path.addLine(to: CGPoint(x: last.x, y: baseline))
        path.closeSubpath()
        return path
    }
}
