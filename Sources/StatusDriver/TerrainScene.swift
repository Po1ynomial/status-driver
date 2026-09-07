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
        let topInset: CGFloat = 92
        let resetClearance: CGFloat = 48

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
    private var vehicle: Vehicle?
    private var pressedControls: Set<DrivingControl> = []
    private var rendererStartTime: TimeInterval?
    private var elapsedTime: TimeInterval = 0
    private var nextSampleTimestamp: TimeInterval = 0
    private var vehicleCreationFramesRemaining = 3
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
        rebuildTerrain(rebuildCollisions: true)
        view.window?.makeFirstResponder(view)
    }

    override func willMove(from view: SKView) {
        pressedControls.removeAll()
        super.willMove(from: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard isConfigured else { return }

        let oldCameraX = trackingCamera.position.x
        let oldVehiclePosition = vehicle?.chassis.position
        let oldTerrainHeight = oldVehiclePosition.flatMap {
            terrainHeight(atWorldX: $0.x, sceneHeight: oldSize.height)
        }

        updateCamera()
        rebuildGrid()
        rebuildTerrain(rebuildCollisions: true)
        if vehicle == nil {
            vehicleCreationFramesRemaining = 3
        }

        if let oldVehiclePosition, let oldTerrainHeight {
            let horizontalOffset = trackingCamera.position.x - oldCameraX
            let newVehicleX = oldVehiclePosition.x + horizontalOffset
            let newTerrainHeight = terrainHeight(atWorldX: newVehicleX, sceneHeight: size.height)
                ?? oldTerrainHeight
            replaceVehicle(
                at: CGPoint(
                    x: newVehicleX,
                    y: oldVehiclePosition.y + newTerrainHeight - oldTerrainHeight
                )
            )
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard isConfigured else { return }

        if rendererStartTime == nil {
            rendererStartTime = currentTime
        }
        guard let rendererStartTime else { return }

        elapsedTime = currentTime - rendererStartTime
        var addedSample = false
        while nextSampleTimestamp <= elapsedTime {
            let sample = source.nextSample(at: nextSampleTimestamp)
            sampleBuffer.append(sample)
            nextSampleTimestamp += configuration.sampleInterval
            addedSample = true
        }

        updateCamera()

        if addedSample {
            sampleBuffer.prune(before: elapsedTime - configuration.retentionDuration)
            rebuildTerrain(rebuildCollisions: true)
        }

        createVehicleAfterLayoutSettles()
        vehicle?.update(controls: pressedControls)
        resetVehicleIfOutsideViewport()
    }

    override func keyDown(with event: NSEvent) {
        guard let input = drivingInput(forKeyCode: event.keyCode) else { return }

        switch input {
        case let .control(control):
            pressedControls.insert(control)
        case .reset where !event.isARepeat:
            resetVehicle()
        case .reset:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        guard case let .control(control) = drivingInput(forKeyCode: event.keyCode) else {
            return
        }
        pressedControls.remove(control)
    }

    override func mouseDown(with event: NSEvent) {
        view?.window?.makeFirstResponder(view)
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
        addChild(trackingCamera)

        gridNode.zPosition = -20
        trackingCamera.addChild(gridNode)
        updateCamera()
    }

    private func prefillSamples() {
        var timestamp = -configuration.retentionDuration
        while timestamp <= 0 {
            sampleBuffer.append(source.nextSample(at: timestamp))
            timestamp += configuration.sampleInterval
        }
        nextSampleTimestamp = timestamp
    }

    private func rebuildTerrain(rebuildCollisions: Bool) {
        let geometry = terrainGeometry(sceneHeight: size.height)
        lineNode.path = geometry.linePath()
        fillNode.path = geometry.fillPath()

        if rebuildCollisions, let linePath = geometry.linePath() {
            let body = SKPhysicsBody(edgeChainFrom: linePath)
            body.friction = 0.92
            body.restitution = 0.02
            body.categoryBitMask = PhysicsCategory.terrain
            body.collisionBitMask = PhysicsCategory.chassis | PhysicsCategory.wheel
            body.contactTestBitMask = 0
            collisionNode.physicsBody = body
        }
    }

    private func terrainGeometry(sceneHeight: CGFloat) -> TerrainGeometry {
        TerrainGeometry(
            samples: sampleBuffer.samples,
            layout: configuration.layout,
            sceneHeight: sceneHeight
        )
    }

    private func terrainHeight(atWorldX x: CGFloat, sceneHeight: CGFloat) -> CGFloat? {
        terrainGeometry(sceneHeight: sceneHeight).height(atWorldX: x)
    }

    private func updateCamera() {
        let visibleRightX = CGFloat(elapsedTime - configuration.viewportDelay)
            * configuration.pointsPerSecond
        trackingCamera.position = CGPoint(
            x: visibleRightX - size.width / 2,
            y: size.height / 2
        )
    }

    private func createVehicleAfterLayoutSettles() {
        guard vehicle == nil else { return }
        guard vehicleCreationFramesRemaining == 0 else {
            vehicleCreationFramesRemaining -= 1
            return
        }

        replaceVehicle(at: vehicleResetPosition())
    }

    private func replaceVehicle(at position: CGPoint) {
        vehicle?.remove(from: self)
        vehicle = Vehicle(in: self, at: position)
    }

    private func resetVehicle() {
        pressedControls.removeAll()
        replaceVehicle(at: vehicleResetPosition())
    }

    private func resetVehicleIfOutsideViewport() {
        let viewport = CGRect(
            x: trackingCamera.position.x - size.width / 2,
            y: trackingCamera.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        if vehicle?.isFullyOutside(viewport) == true {
            resetVehicle()
        }
    }

    private func vehicleResetPosition() -> CGPoint {
        let x = trackingCamera.position.x
        let terrainY = terrainHeight(atWorldX: x, sceneHeight: size.height)
            ?? configuration.bottomInset
        return CGPoint(x: x, y: terrainY + configuration.resetClearance)
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
