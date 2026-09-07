import AppKit
import SpriteKit
import StatusDriverCore

@MainActor
final class TerrainScene: SKScene {
    private struct Configuration {
        let sampleInterval: TimeInterval = 0.15
        let pointsPerSecond: CGFloat = 120
        let viewportDelay: TimeInterval = 2.75
        let retentionDuration: TimeInterval = 60
        let bottomInset: CGFloat = 92
        let topInset: CGFloat = 72

        var layout: TerrainLayout {
            TerrainLayout(
                pointsPerSecond: pointsPerSecond,
                bottomInset: bottomInset,
                topInset: topInset
            )
        }
    }

    private let configuration = Configuration()
    private let trackingCamera = SKCameraNode()
    private let gridNode = SKNode()
    private let fillNode = SKShapeNode()
    private let lineNode = SKShapeNode()
    private let collisionNode = SKNode()

    private var source = BoundedRandomWalkSource()
    private var sampleBuffer = RollingSampleBuffer()
    private var rendererStartTime: TimeInterval?
    private var nextSampleTimestamp: TimeInterval = 0
    private var isConfigured = false

    override func didMove(to view: SKView) {
        guard !isConfigured else { return }
        isConfigured = true

        backgroundColor = NSColor(red: 0.965, green: 0.945, blue: 0.89, alpha: 1)
        physicsWorld.gravity = CGVector(dx: 0, dy: -18)

        configureTerrainNodes()
        configureCamera()
        prefillSamples()
        rebuildGrid()
        rebuildTerrain()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard isConfigured else { return }

        trackingCamera.position.y = size.height / 2
        rebuildGrid()
        rebuildTerrain()
    }

    override func update(_ currentTime: TimeInterval) {
        guard isConfigured else { return }

        if rendererStartTime == nil {
            rendererStartTime = currentTime
        }
        guard let rendererStartTime else { return }

        let elapsed = currentTime - rendererStartTime
        var addedSample = false
        while nextSampleTimestamp <= elapsed {
            sampleBuffer.append(source.nextSample(at: nextSampleTimestamp))
            nextSampleTimestamp += configuration.sampleInterval
            addedSample = true
        }

        let visibleRightX = CGFloat(elapsed - configuration.viewportDelay)
            * configuration.pointsPerSecond
        trackingCamera.position = CGPoint(
            x: visibleRightX - size.width / 2,
            y: size.height / 2
        )

        if addedSample {
            sampleBuffer.prune(before: elapsed - configuration.retentionDuration)
            rebuildTerrain()
        }
    }

    private func configureTerrainNodes() {
        fillNode.fillColor = NSColor(red: 0.24, green: 0.42, blue: 0.37, alpha: 0.16)
        fillNode.strokeColor = .clear
        fillNode.zPosition = -2
        addChild(fillNode)

        lineNode.strokeColor = NSColor(red: 0.105, green: 0.16, blue: 0.15, alpha: 1)
        lineNode.lineWidth = 4
        lineNode.lineCap = .round
        lineNode.lineJoin = .round
        lineNode.zPosition = -1
        addChild(lineNode)

        collisionNode.name = "terrain-collision"
        addChild(collisionNode)
    }

    private func configureCamera() {
        camera = trackingCamera
        trackingCamera.position = CGPoint(x: -size.width / 2, y: size.height / 2)
        addChild(trackingCamera)

        gridNode.zPosition = -20
        trackingCamera.addChild(gridNode)
    }

    private func prefillSamples() {
        var timestamp = -configuration.retentionDuration
        while timestamp <= 0 {
            sampleBuffer.append(source.nextSample(at: timestamp))
            timestamp += configuration.sampleInterval
        }
        nextSampleTimestamp = timestamp
    }

    private func rebuildTerrain() {
        let geometry = TerrainGeometry(
            samples: sampleBuffer.samples,
            layout: configuration.layout,
            sceneHeight: size.height
        )

        lineNode.path = geometry.linePath()
        fillNode.path = geometry.fillPath()

        if let linePath = geometry.linePath() {
            let body = SKPhysicsBody(edgeChainFrom: linePath)
            body.friction = 0.92
            body.restitution = 0.04
            collisionNode.physicsBody = body
        } else {
            collisionNode.physicsBody = nil
        }
    }

    private func rebuildGrid() {
        gridNode.removeAllChildren()

        let path = CGMutablePath()
        let width = size.width
        let height = size.height
        let minorSpacing: CGFloat = 40
        let originX = -width / 2
        let originY = -height / 2

        var x = originX
        while x <= width / 2 {
            path.move(to: CGPoint(x: x, y: originY))
            path.addLine(to: CGPoint(x: x, y: height / 2))
            x += minorSpacing
        }

        var y = originY
        while y <= height / 2 {
            path.move(to: CGPoint(x: originX, y: y))
            path.addLine(to: CGPoint(x: width / 2, y: y))
            y += minorSpacing
        }

        let lines = SKShapeNode(path: path)
        lines.strokeColor = NSColor(red: 0.18, green: 0.25, blue: 0.23, alpha: 0.10)
        lines.lineWidth = 1
        gridNode.addChild(lines)
    }
}
