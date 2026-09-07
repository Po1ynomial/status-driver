import CoreGraphics

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
