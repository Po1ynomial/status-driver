import AppKit
import SpriteKit
import StatusDriverCore

@MainActor
final class TerrainScene: SKScene {
    var onMetricSelectionRequest: ((MetricIdentity) -> Void)?

    private struct Configuration {
        let sampleInterval: TimeInterval = 0.15
        let visibleDuration: TimeInterval = 60
        let commitDelay: TimeInterval = 1
        let retentionDuration: TimeInterval = 65
        let rightCollisionMargin: CGFloat = 120
        let bottomInset: CGFloat = 48
        let topInset: CGFloat = 64
        let resetClearance: CGFloat = 48

        func timeline(width: CGFloat) -> GraphTimelineLayout {
            GraphTimelineLayout(width: max(1, width), visibleDuration: visibleDuration)
        }

        func terrainLayout(width: CGFloat) -> TerrainLayout {
            TerrainLayout(
                pointsPerSecond: timeline(width: width).pointsPerSecond,
                bottomInset: bottomInset,
                topInset: topInset
            )
        }
    }

    private let configuration = Configuration()
    private let trackingCamera = SKCameraNode()
    private let gridNode = SKNode()
    private var fillNode = SKShapeNode()
    private var lineNode = SKShapeNode()
    private let collisionNode = SKNode()

    private lazy var histories = MetricHistoryStore(
        sampleInterval: configuration.sampleInterval,
        retentionDuration: configuration.retentionDuration
    )
    private var selectedMetric: MetricIdentity = .cpu
    private var vehicleVisibility = VehicleVisibilityState()
    private var vehicle: Vehicle?
    private var pressedControls: Set<DrivingControl> = []
    private var latestReadingTimestamp: TimeInterval?
    private var isDarkAppearance = false
    private var isConfigured = false

    override func didMove(to view: SKView) {
        guard !isConfigured else { return }
        isConfigured = true

        physicsWorld.gravity = CGVector(dx: 0, dy: -18)
        configureTerrainNodes()
        applyGraphStyle()
        configureCamera()
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

        updateCamera()
        rebuildGrid()
        rebuildTerrain(rebuildCollisions: true)
        if vehicleVisibility.isVisible {
            resetVehicle()
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard isConfigured else { return }

        updateCamera()
        ensureVisibleVehicleExists()
        vehicle?.update(controls: pressedControls)
        resetVehicleIfOutsideViewport()
    }

    func ingest(_ reading: MetricReading) {
        let update = histories.ingestUpdate(reading)
        guard update.wasAccepted else { return }

        latestReadingTimestamp = max(latestReadingTimestamp ?? reading.timestamp, reading.timestamp)
        if isConfigured, reading.metric == selectedMetric, update == .historyChanged {
            updateCamera()
            rebuildTerrain(rebuildCollisions: true)
        }
    }

    func applyAppearance(isDark: Bool) {
        guard isDarkAppearance != isDark else { return }
        isDarkAppearance = isDark
        applyGraphStyle()
        if isConfigured {
            rebuildGrid()
        }
    }

    @discardableResult
    func selectMetric(_ metric: MetricIdentity) -> Bool {
        guard metric != selectedMetric, histories.samples(for: metric).count >= 2 else {
            return false
        }

        selectedMetric = metric
        applyGraphStyle()
        rebuildTerrain(rebuildCollisions: true)
        if vehicleVisibility.isVisible {
            resetVehicle()
        }
        view?.window?.makeFirstResponder(view)
        return true
    }

    override func keyDown(with event: NSEvent) {
        if let metric = metricSelection(forKeyCode: event.keyCode) {
            if !event.isARepeat {
                onMetricSelectionRequest?(metric)
            }
            return
        }

        guard let input = drivingInput(forKeyCode: event.keyCode) else { return }
        switch input {
        case let .control(control):
            if vehicleVisibility.isVisible {
                pressedControls.insert(control)
            }
        case .reset where !event.isARepeat:
            resetVehicle()
        case .toggleCar where !event.isARepeat:
            toggleVehicle()
        case .reset, .toggleCar:
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
        fillNode.strokeColor = .clear
        fillNode.zPosition = -2
        addChild(fillNode)

        lineNode.lineWidth = 4
        lineNode.lineCap = .butt
        lineNode.lineJoin = .bevel
        lineNode.zPosition = -1
        addChild(lineNode)

        collisionNode.name = "terrain-collision"
        addChild(collisionNode)
    }

    private func applyGraphStyle() {
        let color: NSColor
        switch (selectedMetric, isDarkAppearance) {
        case (.cpu, false):
            color = NSColor(red: 0.10, green: 0.48, blue: 0.76, alpha: 1)
        case (.cpu, true):
            color = NSColor(red: 0.30, green: 0.68, blue: 0.96, alpha: 1)
        case (.memory, false):
            color = NSColor(red: 0.53, green: 0.34, blue: 0.74, alpha: 1)
        case (.memory, true):
            color = NSColor(red: 0.72, green: 0.52, blue: 0.93, alpha: 1)
        }

        backgroundColor = isDarkAppearance
            ? NSColor(red: 0.085, green: 0.095, blue: 0.11, alpha: 1)
            : NSColor(red: 0.975, green: 0.978, blue: 0.97, alpha: 1)

        let linePath = lineNode.path
        let fillPath = fillNode.path
        lineNode.removeFromParent()
        fillNode.removeFromParent()

        fillNode = SKShapeNode(path: fillPath ?? CGMutablePath())
        fillNode.fillColor = color.withAlphaComponent(isDarkAppearance ? 0.20 : 0.14)
        fillNode.strokeColor = .clear
        fillNode.zPosition = -2
        addChild(fillNode)

        // Replacing the node avoids SpriteKit retaining its first rendered stroke style.
        lineNode = SKShapeNode(path: linePath ?? CGMutablePath())
        lineNode.strokeColor = color
        lineNode.lineWidth = 4
        lineNode.lineCap = .butt
        lineNode.lineJoin = .bevel
        lineNode.zPosition = -1
        addChild(lineNode)
    }

    private func configureCamera() {
        camera = trackingCamera
        addChild(trackingCamera)

        gridNode.zPosition = -20
        trackingCamera.addChild(gridNode)
        updateCamera()
    }

    private func rebuildTerrain(rebuildCollisions: Bool) {
        let geometry = terrainGeometry(sceneHeight: size.height)
        lineNode.path = geometry.linePath()
        fillNode.path = geometry.fillPath()

        if rebuildCollisions {
            if let collisionPath = geometry.collisionPath(
                rightExtension: configuration.rightCollisionMargin
            ) {
                let body = SKPhysicsBody(edgeChainFrom: collisionPath)
                body.friction = 0.92
                body.restitution = 0.02
                body.categoryBitMask = PhysicsCategory.terrain
                body.collisionBitMask = PhysicsCategory.chassis | PhysicsCategory.wheel
                body.contactTestBitMask = 0
                collisionNode.physicsBody = body
            } else {
                collisionNode.physicsBody = nil
            }
        }
    }

    private func terrainGeometry(sceneHeight: CGFloat) -> TerrainGeometry {
        TerrainGeometry(
            samples: histories.samples(for: selectedMetric),
            layout: configuration.terrainLayout(width: size.width),
            sceneHeight: sceneHeight
        )
    }

    private func terrainHeight(atWorldX x: CGFloat, sceneHeight: CGFloat) -> CGFloat? {
        terrainGeometry(sceneHeight: sceneHeight).height(atWorldX: x)
    }

    private func updateCamera() {
        let timeline = configuration.timeline(width: size.width)
        let endingTimestamp = (latestReadingTimestamp ?? 0) - configuration.commitDelay
        trackingCamera.position = CGPoint(
            x: timeline.cameraCenterX(endingAt: endingTimestamp),
            y: size.height / 2
        )
    }

    private func toggleVehicle() {
        if vehicleVisibility.toggle() {
            ensureVisibleVehicleExists()
        } else {
            pressedControls.removeAll()
            vehicle?.remove(from: self)
            vehicle = nil
        }
    }

    private func ensureVisibleVehicleExists() {
        guard vehicleVisibility.isVisible,
              vehicle == nil,
              histories.samples(for: selectedMetric).count >= 2 else { return }
        replaceVehicle(at: vehicleResetPosition())
    }

    private func replaceVehicle(at position: CGPoint) {
        vehicle?.remove(from: self)
        vehicle = Vehicle(in: self, at: position)
    }

    private func resetVehicle() {
        guard vehicleVisibility.isVisible else { return }
        pressedControls.removeAll()
        guard histories.samples(for: selectedMetric).count >= 2 else {
            vehicle?.remove(from: self)
            vehicle = nil
            return
        }
        replaceVehicle(at: vehicleResetPosition())
    }

    private func resetVehicleIfOutsideViewport() {
        guard let vehicle else { return }
        let viewport = CGRect(
            x: trackingCamera.position.x - size.width / 2,
            y: trackingCamera.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        if vehicle.isFullyOutside(viewport) {
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
        let originX = -width / 2
        let originY = -height / 2
        let verticalSpacing = width / 12
        let horizontalSpacing = height / 8

        for index in 0...12 {
            let x = originX + CGFloat(index) * verticalSpacing
            path.move(to: CGPoint(x: x, y: originY))
            path.addLine(to: CGPoint(x: x, y: height / 2))
        }
        for index in 0...8 {
            let y = originY + CGFloat(index) * horizontalSpacing
            path.move(to: CGPoint(x: originX, y: y))
            path.addLine(to: CGPoint(x: width / 2, y: y))
        }

        let lines = SKShapeNode(path: path)
        lines.strokeColor = isDarkAppearance
            ? NSColor(white: 1, alpha: 0.10)
            : NSColor(white: 0, alpha: 0.09)
        lines.lineWidth = 1
        gridNode.addChild(lines)
    }
}
