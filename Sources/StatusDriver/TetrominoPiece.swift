import AppKit
import SpriteKit
import StatusDriverCore

@MainActor
final class TetrominoPiece {
    static let blockSize: CGFloat = 18

    let node = SKNode()
    private let kind: TetrominoKind
    private var cells: [TetrominoCell]
    private var blocks: [SKShapeNode] = []

    var isControlled = true

    init(kind: TetrominoKind, in scene: SKScene, at position: CGPoint) {
        self.kind = kind
        cells = kind.cells
        node.name = "disk-tetromino"
        node.position = position
        node.zPosition = 15
        rebuildBlocks()
        scene.addChild(node)
    }

    func move(x: Int, y: Int) {
        guard isControlled else { return }
        node.position.x += CGFloat(x) * Self.blockSize
        node.position.y += CGFloat(y) * Self.blockSize
    }

    func rotateClockwise() {
        guard isControlled, kind != .o else { return }
        cells = cells.map { $0.rotatedClockwise() }
        rebuildBlocks()
    }

    func blockFrames(in scene: SKScene) -> [CGRect] {
        blocks.map { block in
            let center = scene.convert(.zero, from: block)
            return CGRect(
                x: center.x - Self.blockSize / 2,
                y: center.y - Self.blockSize / 2,
                width: Self.blockSize,
                height: Self.blockSize
            )
        }
    }

    func release() {
        guard isControlled else { return }
        isControlled = false
        let bodies = cells.map { cell -> SKPhysicsBody in
            let center = CGPoint(
                x: CGFloat(cell.x) * Self.blockSize,
                y: CGFloat(cell.y) * Self.blockSize
            )
            return SKPhysicsBody(
                rectangleOf: CGSize(width: Self.blockSize - 1, height: Self.blockSize - 1),
                center: center
            )
        }
        let body = SKPhysicsBody(bodies: bodies)
        body.mass = 0.75
        body.friction = 0.72
        body.restitution = 0.04
        body.linearDamping = 0.12
        body.angularDamping = 0.16
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.tetromino
        body.collisionBitMask = PhysicsCategory.terrain | PhysicsCategory.tetromino
        body.contactTestBitMask = 0
        node.physicsBody = body
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

    private func rebuildBlocks() {
        blocks.forEach { $0.removeFromParent() }
        blocks = cells.map { cell in
            let block = SKShapeNode(
                rectOf: CGSize(width: Self.blockSize - 1, height: Self.blockSize - 1),
                cornerRadius: 2
            )
            block.position = CGPoint(
                x: CGFloat(cell.x) * Self.blockSize,
                y: CGFloat(cell.y) * Self.blockSize
            )
            block.fillColor = Self.color(for: kind)
            block.strokeColor = NSColor(white: 0.12, alpha: 0.88)
            block.lineWidth = 1.2
            node.addChild(block)
            return block
        }
    }

    private static func color(for kind: TetrominoKind) -> NSColor {
        switch kind {
        case .i:
            NSColor(red: 0.10, green: 0.78, blue: 0.86, alpha: 1)
        case .o:
            NSColor(red: 0.96, green: 0.78, blue: 0.12, alpha: 1)
        case .t:
            NSColor(red: 0.64, green: 0.32, blue: 0.78, alpha: 1)
        case .s:
            NSColor(red: 0.25, green: 0.72, blue: 0.29, alpha: 1)
        case .z:
            NSColor(red: 0.86, green: 0.20, blue: 0.18, alpha: 1)
        case .j:
            NSColor(red: 0.15, green: 0.38, blue: 0.85, alpha: 1)
        case .l:
            NSColor(red: 0.94, green: 0.47, blue: 0.12, alpha: 1)
        }
    }
}
