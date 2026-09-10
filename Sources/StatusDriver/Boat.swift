import AppKit
import SpriteKit
import StatusDriverCore

@MainActor
final class Boat {
    static let surfaceOffset: CGFloat = 9

    private let node: SKNode
    private var motion: BoatMotionModel

    var position: CGPoint {
        motion.state.position
    }

    init(in scene: SKScene, at position: CGPoint) {
        node = Self.makeNode()
        motion = BoatMotionModel(position: position)
        node.position = position
        scene.addChild(node)
    }

    func update(
        deltaTime: TimeInterval,
        targetSurfaceY: CGFloat,
        surfaceSlope: CGFloat,
        movements: Set<EasterEggMovement>
    ) {
        motion.update(
            deltaTime: deltaTime,
            targetSurfaceY: targetSurfaceY,
            surfaceSlope: surfaceSlope,
            movements: movements
        )
        node.position = motion.state.position
        node.zRotation = motion.state.rotation
    }

    func remove() {
        node.removeFromParent()
    }

    func isFullyOutside(_ rect: CGRect) -> Bool {
        let frame = node.calculateAccumulatedFrame()
        return frame.maxX < rect.minX
            || frame.minX > rect.maxX
            || frame.maxY < rect.minY
            || frame.minY > rect.maxY
    }

    private static func makeNode() -> SKNode {
        let root = SKNode()
        root.name = "memory-boat"
        root.zPosition = 14

        let hullPath = CGMutablePath()
        hullPath.move(to: CGPoint(x: -26, y: 2))
        hullPath.addLine(to: CGPoint(x: 25, y: 2))
        hullPath.addLine(to: CGPoint(x: 17, y: -9))
        hullPath.addLine(to: CGPoint(x: -18, y: -9))
        hullPath.closeSubpath()
        let hull = SKShapeNode(path: hullPath)
        hull.fillColor = NSColor(red: 0.50, green: 0.28, blue: 0.70, alpha: 1)
        hull.strokeColor = NSColor(red: 0.16, green: 0.13, blue: 0.18, alpha: 1)
        hull.lineWidth = 2
        root.addChild(hull)

        let mastPath = CGMutablePath()
        mastPath.move(to: CGPoint(x: -2, y: 2))
        mastPath.addLine(to: CGPoint(x: -2, y: 28))
        let mast = SKShapeNode(path: mastPath)
        mast.strokeColor = hull.strokeColor
        mast.lineWidth = 2
        root.addChild(mast)

        let sailPath = CGMutablePath()
        sailPath.move(to: CGPoint(x: 0, y: 25))
        sailPath.addLine(to: CGPoint(x: 0, y: 5))
        sailPath.addLine(to: CGPoint(x: 17, y: 5))
        sailPath.closeSubpath()
        let sail = SKShapeNode(path: sailPath)
        sail.fillColor = NSColor(red: 0.98, green: 0.73, blue: 0.27, alpha: 1)
        sail.strokeColor = hull.strokeColor
        sail.lineWidth = 1.5
        root.addChild(sail)
        return root
    }
}
